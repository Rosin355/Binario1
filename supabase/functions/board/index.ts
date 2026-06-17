// Supabase Edge Function: `board`
//
// Phase 2A backend-adapter spike for Binario1.
//   iOS app → THIS function → RFI public monitor HTML → normalized JSON → iOS app
//
// Endpoint:  GET /board?stationSlug=padova&type=departures&locale=it
// Returns JSON compatible with the iOS `BackendBoardDTO` (see docs/13_BACKEND_ADAPTER.md).
//
// Scope of this spike: Padova DEPARTURES only, public/no-JWT, no DB, no secrets.
// It only fetches PUBLIC RFI HTML and normalizes it server-side.

import {
  isCancelledRow,
  normalizeCategory,
  normalizeDelay,
  normalizePlatform,
  normalizeStatus,
  parseRFIMonitorHTML,
} from "./rfi.ts";

// Tiny station registry. NOTE: the RFI live `placeId` (2000) and the PRM scheduled
// id (1861) are DIFFERENT id systems — never mix them.
const STATIONS = {
  padova: {
    id: "padova",
    name: "Padova",
    rfiLivePlaceId: "2000",
    prmScheduledId: "1861",
  },
} as const;

type StationEntry = (typeof STATIONS)[keyof typeof STATIONS];

// CORS: permissive for the dev spike. TODO(prod): restrict Allow-Origin to the app.
const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Simple in-memory cache (per warm instance). TTL 30s. Good enough for the spike;
// TODO(prod): move to a shared cache / KV and add rate limiting + abuse protection.
const CACHE_TTL_MS = 30_000;
type CacheEntry = { at: number; body: BoardResponse };
const cache = new Map<string, CacheEntry>();

interface BoardResponse {
  station: { id: string; name: string; sourcePlaceId: string };
  boardType: "departures";
  source: {
    kind: "rfiLive";
    label: string;
    updatedAt: string;
    fetchedAt: string;
    isFallback: boolean;
    isStale: boolean;
  };
  rows: Array<{
    id: string;
    scheduledTime: string;
    category: string;
    trainNumber: string;
    destination: string;
    platform: string;
    delayMinutes: number;
    status: string;
    notes: string[];
  }>;
  // NOTE(spike): diagnostics are development-only. Reduce or hide in production.
  diagnostics: Record<string, unknown>;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function errorResponse(code: string, message: string, status: number): Response {
  return jsonResponse({ error: { code, message } }, status);
}

// Rome-local date prefix "YYYY-MM-DD" (for stable row ids and updatedAt).
function romeDatePrefix(d: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Rome",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d);
}

// Rome UTC offset like "+02:00" (DST-aware), for the updatedAt ISO string.
function romeOffset(d: Date): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Europe/Rome",
    timeZoneName: "longOffset",
  }).formatToParts(d);
  const tz = parts.find((p) => p.type === "timeZoneName")?.value ?? "GMT+00:00";
  const off = tz.replace("GMT", "").trim();
  return /^[+-]\d{2}:\d{2}$/.test(off) ? off : "+00:00";
}

function rfiMonitorURL(placeId: string): string {
  return `https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=${placeId}`;
}

function staleFallback(cached: CacheEntry, fetchedAt: string, reason: string): Response {
  return jsonResponse({
    ...cached.body,
    source: { ...cached.body.source, isFallback: true, isStale: true, fetchedAt },
    diagnostics: { ...cached.body.diagnostics, cache: reason },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse("method_not_allowed", "Use GET.", 405);
  }

  const url = new URL(req.url);
  const stationSlug = (url.searchParams.get("stationSlug") ?? "").toLowerCase().trim();
  const type = (url.searchParams.get("type") ?? "departures").toLowerCase().trim();
  const locale = (url.searchParams.get("locale") ?? "it").toLowerCase().trim();

  // Validation
  if (!stationSlug) {
    return errorResponse("missing_stationSlug", "Query param 'stationSlug' is required.", 400);
  }
  const station = (STATIONS as Record<string, StationEntry>)[stationSlug];
  if (!station) {
    return errorResponse("unknown_station", `Unknown station '${stationSlug}'.`, 404);
  }
  if (type !== "departures") {
    return errorResponse("unsupported_board_type", "Only type='departures' is supported in this spike.", 400);
  }
  if (locale !== "it" && locale !== "en") {
    return errorResponse("unsupported_locale", "Only locale 'it' or 'en' is supported.", 400);
  }

  const cacheKey = `${stationSlug}:${type}:${locale}`;
  const now = Date.now();
  const cached = cache.get(cacheKey);

  // Fresh cache hit
  if (cached && now - cached.at < CACHE_TTL_MS) {
    return jsonResponse({
      ...cached.body,
      source: { ...cached.body.source, isFallback: false, isStale: false },
      diagnostics: { ...cached.body.diagnostics, cache: "hit" },
    });
  }

  const fetchedAt = new Date().toISOString();
  let html = "";
  let sourceStatus = 0;
  let contentType = "";
  let sourceBytes = 0;

  try {
    const res = await fetch(rfiMonitorURL(station.rfiLivePlaceId), {
      headers: {
        "User-Agent": "Binario1-board-adapter/0.1 (+spike)",
        "Accept": "text/html,application/xhtml+xml",
      },
    });
    sourceStatus = res.status;
    contentType = res.headers.get("content-type") ?? "";
    html = await res.text();
    sourceBytes = new TextEncoder().encode(html).length;
    if (!res.ok) throw new Error(`RFI HTTP ${res.status}`);
  } catch (err) {
    // Serve stale-but-recent cache if we have any; otherwise structured 502.
    if (cached) return staleFallback(cached, fetchedAt, "stale-fallback-fetch-error");
    return errorResponse("source_fetch_failed", `RFI fetch failed: ${String(err)}`, 502);
  }

  const parsed = parseRFIMonitorHTML(html);
  const day = new Date();
  const datePrefix = romeDatePrefix(day);
  const offset = romeOffset(day);

  const rows = parsed.rows
    .map((r) => {
      const category = normalizeCategory(r.category);
      const delayMinutes = normalizeDelay(r.delay);
      const platform = normalizePlatform(r.platform);
      const cancelled = isCancelledRow(r);
      const status = normalizeStatus({ delayMinutes, isCancelled: cancelled, isDeparting: r.isDeparting });
      const time = r.time ?? "";
      return {
        id: `${category}-${r.trainNumber ?? "?"}-${datePrefix}T${time}`,
        scheduledTime: time,
        category,
        trainNumber: r.trainNumber ?? "",
        destination: r.destination ?? "",
        platform,
        // Contract keeps a number; 0 means "no delay" (cancelled also → 0).
        delayMinutes: cancelled ? 0 : (delayMinutes ?? 0),
        status,
        notes: r.info ? [r.info] : [],
      };
    })
    .filter((r) => r.scheduledTime.length > 0); // require a scheduled time

  if (rows.length === 0) {
    if (cached) return staleFallback(cached, fetchedAt, "stale-fallback-empty-parse");
    return errorResponse("source_parse_empty", "RFI returned no parseable rows.", 502);
  }

  const updatedAt = parsed.updatedAt ? `${datePrefix}T${parsed.updatedAt}:00${offset}` : fetchedAt;
  const label = locale === "en" ? "RFI online monitor" : "Monitor RFI online";

  const body: BoardResponse = {
    station: { id: station.id, name: station.name, sourcePlaceId: station.rfiLivePlaceId },
    boardType: "departures",
    source: { kind: "rfiLive", label, updatedAt, fetchedAt, isFallback: false, isStale: false },
    rows,
    diagnostics: {
      sourceStatus,
      sourceBytes,
      parsedRows: rows.length,
      contentType,
      cache: "miss",
    },
  };

  cache.set(cacheKey, { at: now, body });
  return jsonResponse(body);
});
