// registry.ts — station registry + board-type / RFI-URL helpers. Pure (no Deno
// APIs, no network) so they are unit-testable with `deno test`.
//
// IMPORTANT: `rfiLivePlaceId` (RFI LIVE monitor id) and `prmScheduledId` (PRM
// "Quadro Orario" SCHEDULE id) are DIFFERENT id systems — never mix them.
// Add a new station ONLY when its rfiLivePlaceId is VERIFIED against the live RFI
// monitor. Do not activate guessed/unverified ids.

export interface StationEntry {
  slug: string;
  displayName: string;
  rfiLivePlaceId: string; // RFI live station-monitor placeId (Monitor?placeId=…)
  /// PRM "Quadro Orario" id — a DIFFERENT id system, not interchangeable. OPTIONAL:
  /// omitted when not verified for a station. The LIVE board path never reads it
  /// (it uses `rfiLivePlaceId` only), so a station can be live-active without it.
  /// A scheduled/PRM feature must NOT be activated for a station lacking this id.
  prmScheduledId?: string;
}

/// Verified-active stations only — each `rfiLivePlaceId` confirmed against the live
/// RFI monitor (https://iechub.rfi.it/…/Monitor?placeId=…, page title "Stazione di X").
/// TODO(future — each requires a VERIFIED rfiLivePlaceId before activation):
///   Bologna Centrale, Venezia Santa Lucia, Milano Centrale.
///   Do NOT add them with guessed placeIds.
export const STATIONS: Record<string, StationEntry> = {
  padova: { slug: "padova", displayName: "Padova", rfiLivePlaceId: "2000", prmScheduledId: "1861" },
  // Verified: placeId 2416 → "Stazione di ROMA TERMINI". prmScheduledId NOT verified
  // → intentionally omitted (never guessed); live board works without it.
  "roma-termini": { slug: "roma-termini", displayName: "Roma Termini", rfiLivePlaceId: "2416" },
  // Verified: placeId 2829 → "Stazione di TERME EUGANEE-ABANO-MONTEGROTTO", 17 real
  // departure rows. Taken from RFI's own station list (the `PlaceId` select on
  // iechub.rfi.it/ArriviPartenze/, 2434 entries) — no guessed id. RFI has NO station
  // named "Montegrotto Terme"; this is the one serving it, between ABANO TERME
  // (placeId 364, a DIFFERENT station, not registered here) and BATTAGLIA TERME.
  // displayName is the OFFICIAL RFI name — see the naming policy in docs/12_DECISIONS.md.
  // prmScheduledId NOT verified → intentionally omitted.
  "terme-euganee-abano-montegrotto": {
    slug: "terme-euganee-abano-montegrotto",
    displayName: "Terme Euganee-Abano-Montegrotto",
    rfiLivePlaceId: "2829",
  },
};

export function resolveStation(slug: string | null | undefined): StationEntry | undefined {
  return STATIONS[(slug ?? "").toLowerCase().trim()];
}

export type BoardType = "departures" | "arrivals";

/** Parse the `type` query param; null when unsupported. Absent/empty → departures. */
export function parseBoardType(raw: string | null | undefined): BoardType | null {
  const t = (raw ?? "").toLowerCase().trim();
  if (t === "") return "departures";
  return t === "departures" || t === "arrivals" ? t : null;
}

/** RFI live monitor URL. departures → arrivals=False, arrivals → arrivals=True. */
export function rfiMonitorURL(placeId: string, type: BoardType): string {
  const arrivals = type === "arrivals" ? "True" : "False";
  return `https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=${arrivals}&placeId=${placeId}`;
}
