// registry.ts — station registry + board-type / RFI-URL helpers. Pure (no Deno
// APIs, no network) so they are unit-testable with `deno test`.
//
// IMPORTANT: `rfiLivePlaceId` (RFI LIVE monitor id) and `prmScheduledId` (PRM
// "Quadro Orario" SCHEDULE id) are DIFFERENT id systems — never mix them.
//
// The registry is BUILT FROM THE SHARED ARTIFACT (`rfi_stations_tsv.ts`), parsed
// into a Map once at module init. That artifact is RFI's own `PlaceId` list, so
// no id here is ever guessed — the previous hand-maintained literal has been
// replaced, not extended. See docs/12_DECISIONS.md.
//
// The artifact is a DATED SNAPSHOT: nothing guarantees RFI's list is stable, so
// the entry count is not a constant to rely on. Never assert the count — assert
// properties.

import { RFI_STATIONS_TSV } from "./rfi_stations_tsv.ts";

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

/// PRM ids are NOT in the shared artifact (a different id system) and are never
/// guessed: this overlay carries only the ones verified by hand. A station absent
/// here is live-active without a PRM id, which is the normal case.
const PRM_SCHEDULED_IDS: Readonly<Record<string, string>> = { padova: "1861" };

/// Station name → registry slug, and the contract between app and backend: the
/// iOS catalog's `Station.id` MUST equal this slug or the fetch 404s.
///
/// The rule is deliberately plain — lowercase, every run of non-alphanumerics
/// becomes one hyphen, no leading/trailing hyphen. It reproduces the four slugs
/// that were hand-written before national coverage ("padova", "roma-termini",
/// "venezia-s-lucia", "terme-euganee-abano-montegrotto") with no special cases,
/// and it is INJECTIVE over the whole artifact — asserted in `registry_test.ts`,
/// because a collision would silently drop a station from the Map.
export function stationSlug(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

/// Parse the shared TSV artifact. `#` comments and blank lines are skipped; every
/// remaining line must be `placeId<TAB>name`. Malformed input throws at init
/// rather than yielding a half-built registry.
export function parseStationsTSV(tsv: string): Map<string, StationEntry> {
  const stations = new Map<string, StationEntry>();
  let lineNumber = 0;
  for (const line of tsv.split("\n")) {
    lineNumber++;
    if (line === "" || line.startsWith("#")) continue;
    const [rfiLivePlaceId, displayName, ...extra] = line.split("\t");
    if (extra.length > 0 || !rfiLivePlaceId || !displayName) {
      throw new Error(
        `rfi-stations.tsv line ${lineNumber}: expected "placeId<TAB>name", got ${JSON.stringify(line)}`,
      );
    }
    const slug = stationSlug(displayName);
    if (slug === "") {
      throw new Error(
        `rfi-stations.tsv line ${lineNumber}: name ${JSON.stringify(displayName)} yields an empty slug`,
      );
    }
    if (stations.has(slug)) {
      // A Map would silently keep the last writer and a station would vanish from
      // the registry with no error. Refuse to start instead.
      throw new Error(`rfi-stations.tsv line ${lineNumber}: slug "${slug}" collides with an earlier station`);
    }
    const prmScheduledId = PRM_SCHEDULED_IDS[slug];
    stations.set(slug, {
      slug,
      displayName,
      rfiLivePlaceId,
      ...(prmScheduledId ? { prmScheduledId } : {}),
    });
  }
  return stations;
}

/// Every station RFI's own list knows about, keyed by slug. Built once at init.
export const STATIONS: ReadonlyMap<string, StationEntry> = parseStationsTSV(RFI_STATIONS_TSV);

export function resolveStation(slug: string | null | undefined): StationEntry | undefined {
  return STATIONS.get((slug ?? "").toLowerCase().trim());
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
