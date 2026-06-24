// Supabase Edge Function: `board`
//
// Phase 2A backend-adapter spike for Binario1.
//   iOS app → THIS function → RFI public monitor HTML → normalized JSON → iOS app
//
// Endpoint:  GET /board?stationSlug=padova&type=departures&locale=it
// Returns JSON compatible with the iOS `BackendBoardDTO` (see docs/13_BACKEND_ADAPTER.md).
//
// Scope: Padova DEPARTURES only, no DB. Fetches PUBLIC RFI HTML and normalizes it
// server-side. Hardening Phase 1 adds a lightweight app-token header
// (X-Binario-App-Token), best-effort in-memory rate limiting, and a diagnostics
// policy gated by BINARIO_BOARD_ENV. `verify_jwt` stays false; token validation is
// code-level. Secrets are set via `supabase secrets set …`, never committed.

import {
  isCancelledRow,
  normalizeCategory,
  normalizeDelay,
  normalizePlatform,
  normalizeStatus,
  parseRFIMonitorHTML,
} from "./rfi.ts";
import {
  clientKey,
  InMemoryRateLimiter,
  type RateLimitResult,
  resolveEnv,
  shouldIncludeDiagnostics,
  validateAppToken,
} from "./hardening.ts";
import { type BoardType, parseBoardType, resolveStation, rfiMonitorURL } from "./registry.ts";

// Hardening Phase 1 config (read once per warm instance). Secrets are set via
// `supabase secrets set …` — never committed. See README / docs/13.
const APP_TOKEN = Deno.env.get("BINARIO_BOARD_APP_TOKEN"); // lightweight app token (optional)
const APP_ENV = resolveEnv(Deno.env.get("BINARIO_BOARD_ENV")); // development | production
const INCLUDE_DIAGNOSTICS = shouldIncludeDiagnostics(APP_ENV);
const RATE_LIMIT_PER_MIN = 60;
const limiter = new InMemoryRateLimiter(RATE_LIMIT_PER_MIN, 60_000);

// Station registry lives in registry.ts (single VERIFIED station: Padova).
// rfiLivePlaceId (live monitor) and prmScheduledId (PRM schedule) are different id
// systems and are never mixed.

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
  boardType: BoardType;
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

function jsonResponse(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, ...extraHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function errorResponse(code: string, message: string, status: number, extraHeaders: Record<string, string> = {}): Response {
  return jsonResponse({ error: { code, message } }, status, extraHeaders);
}

function rateLimitHeaders(rl: RateLimitResult): Record<string, string> {
  return {
    "X-RateLimit-Limit": String(rl.limit),
    "X-RateLimit-Remaining": String(rl.remaining),
  };
}

/** Apply the diagnostics policy: omit `diagnostics` entirely in production. */
function applyDiagnosticsPolicy(body: BoardResponse): Record<string, unknown> {
  if (INCLUDE_DIAGNOSTICS) return body as unknown as Record<string, unknown>;
  const { diagnostics: _omit, ...rest } = body;
  return rest;
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

function staleFallback(cached: CacheEntry, fetchedAt: string, reason: string, extraHeaders: Record<string, string>): Response {
  const body: BoardResponse = {
    ...cached.body,
    source: { ...cached.body.source, isFallback: true, isStale: true, fetchedAt },
    diagnostics: { ...cached.body.diagnostics, cache: reason },
  };
  return jsonResponse(applyDiagnosticsPolicy(body), 200, extraHeaders);
}

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse("method_not_allowed", "Use GET.", 405);
  }

  // App-token (lightweight abuse reduction — NOT user auth). When the env token is
  // set, require a matching X-Binario-App-Token; when unset, allow in development
  // only. Token values are never logged or echoed.
  const tokenResult = validateAppToken(APP_TOKEN, req.headers.get("X-Binario-App-Token"));
  if (tokenResult === "missing" || tokenResult === "invalid") {
    return errorResponse("unauthorized", "Missing or invalid app token", 401);
  }
  if (tokenResult === "unconfigured") {
    if (APP_ENV === "production") {
      return errorResponse("unauthorized", "Missing or invalid app token", 401);
    }
    console.warn("[board] BINARIO_BOARD_APP_TOKEN not configured — allowing request (development only)");
  }

  // Best-effort in-memory rate limit (per warm instance; see hardening.ts TODO).
  const rl = limiter.check(clientKey(req.headers), Date.now());
  const rlHeaders = rateLimitHeaders(rl);
  if (!rl.allowed) {
    return errorResponse("rate_limited", "Too many requests", 429, {
      ...rlHeaders,
      "Retry-After": String(rl.retryAfterSeconds),
    });
  }

  const url = new URL(req.url);
  const stationSlug = (url.searchParams.get("stationSlug") ?? "").toLowerCase().trim();
  const type = (url.searchParams.get("type") ?? "departures").toLowerCase().trim();
  const locale = (url.searchParams.get("locale") ?? "it").toLowerCase().trim();

  // Validation
  if (!stationSlug) {
    return errorResponse("missing_stationSlug", "Query param 'stationSlug' is required.", 400);
  }
  const station = resolveStation(stationSlug);
  if (!station) {
    return errorResponse("unknown_station", `Unknown station '${stationSlug}'.`, 404);
  }
  const boardType = parseBoardType(type);
  if (!boardType) {
    return errorResponse("unsupported_board_type", "Query param 'type' must be 'departures' or 'arrivals'.", 400);
  }
  if (locale !== "it" && locale !== "en") {
    return errorResponse("unsupported_locale", "Only locale 'it' or 'en' is supported.", 400);
  }

  const cacheKey = `${stationSlug}:${boardType}:${locale}`;
  const now = Date.now();
  const cached = cache.get(cacheKey);

  // Fresh cache hit
  if (cached && now - cached.at < CACHE_TTL_MS) {
    const body: BoardResponse = {
      ...cached.body,
      source: { ...cached.body.source, isFallback: false, isStale: false },
      diagnostics: { ...cached.body.diagnostics, cache: "hit" },
    };
    return jsonResponse(applyDiagnosticsPolicy(body), 200, rlHeaders);
  }

  const fetchedAt = new Date().toISOString();
  let html = "";
  let sourceStatus = 0;
  let contentType = "";
  let sourceBytes = 0;

  try {
    const res = await fetch(rfiMonitorURL(station.rfiLivePlaceId, boardType), {
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
    if (cached) return staleFallback(cached, fetchedAt, "stale-fallback-fetch-error", rlHeaders);
    return errorResponse("source_fetch_failed", `RFI fetch failed: ${String(err)}`, 502, rlHeaders);
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
      // The isDeparting heuristic (blinking / "in stazione") is a DEPARTURES-monitor
      // signal; never emit a "departing" status on an arrivals board.
      const isDeparting = boardType === "departures" ? r.isDeparting : false;
      const status = normalizeStatus({ delayMinutes, isCancelled: cancelled, isDeparting });
      const time = r.time ?? "";
      return {
        id: `${category}-${r.trainNumber ?? "?"}-${datePrefix}T${time}`,
        scheduledTime: time,
        category,
        trainNumber: r.trainNumber ?? "",
        // For arrivals the RFI monitor's place cell is the ORIGIN/provenance; the
        // contract keeps the `destination` field name (iOS maps it to origin for
        // arrivals). Departures unchanged: this is the destination.
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
    if (cached) return staleFallback(cached, fetchedAt, "stale-fallback-empty-parse", rlHeaders);
    return errorResponse("source_parse_empty", "RFI returned no parseable rows.", 502, rlHeaders);
  }

  const updatedAt = parsed.updatedAt ? `${datePrefix}T${parsed.updatedAt}:00${offset}` : fetchedAt;
  const label = locale === "en" ? "RFI online monitor" : "Monitor RFI online";

  const body: BoardResponse = {
    station: { id: station.slug, name: station.displayName, sourcePlaceId: station.rfiLivePlaceId },
    boardType,
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
  return jsonResponse(applyDiagnosticsPolicy(body), 200, rlHeaders);
});
