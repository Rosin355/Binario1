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
  prmScheduledId: string; // PRM "Quadro Orario" id — different system, not interchangeable
}

/// Verified-active stations only.
/// TODO(future — each requires a VERIFIED rfiLivePlaceId before activation):
///   Bologna Centrale, Venezia Santa Lucia, Montegrotto Terme, Milano Centrale.
///   Do NOT add them with guessed placeIds.
export const STATIONS: Record<string, StationEntry> = {
  padova: { slug: "padova", displayName: "Padova", rfiLivePlaceId: "2000", prmScheduledId: "1861" },
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
