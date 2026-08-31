// registry_test.ts — pure tests for the station registry + board-type / URL helpers.
// No network. Run: `deno test`.
//
// The registry is now built from the shared TSV artifact, which is a DATED
// SNAPSHOT of RFI's own list: RFI opens and closes stations, so the entry count
// moves between extractions. These tests therefore assert PROPERTIES —
// injectivity, key↔slug alignment, known anchors — and never the count, which
// would turn the suite red the day RFI opens a stop.

import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  parseBoardType,
  parseStationsTSV,
  resolveStation,
  rfiMonitorURL,
  STATIONS,
  stationSlug,
} from "./registry.ts";

Deno.test("registry resolves the anchor stations verified against the live monitor", () => {
  const padova = resolveStation("padova");
  assert(padova);
  assertEquals(padova!.slug, "padova");
  assertEquals(padova!.displayName, "PADOVA");
  assertEquals(padova!.rfiLivePlaceId, "2000");
  assertEquals(padova!.prmScheduledId, "1861");        // distinct id system, kept separate
  assertEquals(resolveStation("PADOVA "), padova);     // case/space-insensitive

  // prmScheduledId stays absent everywhere it was never verified — never guessed.
  const roma = resolveStation("roma-termini");
  assert(roma);
  assertEquals(roma!.rfiLivePlaceId, "2416");
  assertEquals(roma!.prmScheduledId, undefined);
  assertEquals(resolveStation("ROMA-TERMINI "), roma);

  // The slug MUST equal the iOS catalog id (Resources/stations.json) exactly.
  const terme = resolveStation("terme-euganee-abano-montegrotto");
  assert(terme);
  assertEquals(terme!.rfiLivePlaceId, "2829");

  const venezia = resolveStation("venezia-s-lucia");
  assert(venezia);
  assertEquals(venezia!.rfiLivePlaceId, "3009");
});

Deno.test("national coverage: the four pre-existing slugs survive the rule unchanged", () => {
  // These were hand-written before national coverage. The generic slug rule has to
  // reproduce them with no special case, or every saved id and every registry key
  // silently breaks.
  for (const slug of ["padova", "roma-termini", "venezia-s-lucia", "terme-euganee-abano-montegrotto"]) {
    assert(STATIONS.has(slug), `pre-existing slug "${slug}" no longer resolves`);
  }
});

Deno.test("ABANO TERME now resolves: it is a separate RFI station, no longer absent", () => {
  // Until national coverage this was asserted ABSENT, and the iOS catalog pointed
  // the "Abano" searchAliases at Terme Euganee to compensate (the disambiguation
  // debt recorded in docs/12_DECISIONS.md). placeId 364 is now in the registry, so
  // the debt is settled and those aliases have been removed on the iOS side.
  const abano = resolveStation("abano-terme");
  assert(abano);
  assertEquals(abano!.rfiLivePlaceId, "364");
  assertEquals(abano!.displayName, "ABANO TERME");
  // …and it is a DIFFERENT entity from the station that used to answer for it.
  assert(abano!.rfiLivePlaceId !== resolveStation("terme-euganee-abano-montegrotto")!.rfiLivePlaceId);
});

Deno.test("unknown slugs still 404 rather than resolving to something close", () => {
  // A name RFI does not use is not a station, national coverage or not.
  assertEquals(resolveStation("montegrotto-terme"), undefined);
  // A bare city name is not a slug: RFI has 18 names starting "ROMA" and none is "ROMA".
  assertEquals(resolveStation("roma"), undefined);
  assertEquals(resolveStation(null), undefined);
  assertEquals(resolveStation(""), undefined);
  assertEquals(resolveStation("definitely-not-a-station"), undefined);
});

Deno.test("every registry entry carries a live placeId and an aligned key", () => {
  for (const [key, entry] of STATIONS) {
    assertEquals(entry.slug, key);                     // key ↔ slug stay aligned (iOS sends the slug)
    assert(entry.rfiLivePlaceId.length > 0);
    assert(/^\d+$/.test(entry.rfiLivePlaceId), `placeId "${entry.rfiLivePlaceId}" is not numeric`);
    assert(entry.displayName.length > 0);
  }
});

Deno.test("the slug rule is INJECTIVE over the whole artifact", () => {
  // The registry is a Map keyed by slug: two names collapsing onto one slug would
  // silently drop a station instead of failing. `parseStationsTSV` throws on a
  // collision, so reaching here at all means the artifact is collision-free — this
  // test states the invariant explicitly and pins the placeId side too.
  const placeIds = new Set<string>();
  for (const entry of STATIONS.values()) {
    assert(!placeIds.has(entry.rfiLivePlaceId), `duplicate placeId ${entry.rfiLivePlaceId}`);
    placeIds.add(entry.rfiLivePlaceId);
  }
  assertEquals(placeIds.size, STATIONS.size);          // a bijection slug ↔ placeId
});

Deno.test("a slug collision is refused at init, never silently absorbed", () => {
  // The property above holds for today's snapshot; this is the guard for the day it
  // does not. Two names differing only in punctuation collapse onto one slug.
  assertThrows(
    () => parseStationsTSV("1\tSAN PAOLO\n2\tSAN-PAOLO\n"),
    Error,
    "collides",
  );
});

Deno.test("parseStationsTSV skips comments and blank lines, rejects malformed rows", () => {
  const ok = parseStationsTSV("# header\n\n42\tSOME PLACE\n");
  assertEquals(ok.size, 1);
  assertEquals(ok.get("some-place")!.rfiLivePlaceId, "42");

  assertThrows(() => parseStationsTSV("42\n"), Error, "placeId<TAB>name");
  assertThrows(() => parseStationsTSV("42\tA\tB\n"), Error, "placeId<TAB>name");
  assertThrows(() => parseStationsTSV("42\t...\n"), Error, "empty slug");
});

Deno.test("stationSlug: plain rule, no special cases", () => {
  assertEquals(stationSlug("PADOVA"), "padova");
  assertEquals(stationSlug("ROMA TERMINI"), "roma-termini");
  assertEquals(stationSlug("VENEZIA S.LUCIA"), "venezia-s-lucia");
  assertEquals(stationSlug("TERME EUGANEE-ABANO-MONTEGROTTO"), "terme-euganee-abano-montegrotto");
  assertEquals(stationSlug("CITTA' DI CASTELLO - ZONA INDUSTRIALE"), "citta-di-castello-zona-industriale");
  assertEquals(stationSlug("BOLOGNA C.LE/AV"), "bologna-c-le-av");
});

Deno.test("parseBoardType accepts departures/arrivals, defaults, rejects junk", () => {
  assertEquals(parseBoardType("departures"), "departures");
  assertEquals(parseBoardType("arrivals"), "arrivals");
  assertEquals(parseBoardType("ARRIVALS "), "arrivals");
  assertEquals(parseBoardType(null), "departures");    // default
  assertEquals(parseBoardType(""), "departures");
  assertEquals(parseBoardType("sideways"), null);      // unsupported → handler returns 400
});

Deno.test("rfiMonitorURL maps board type to the RFI arrivals flag", () => {
  const dep = rfiMonitorURL("2000", "departures");
  const arr = rfiMonitorURL("2000", "arrivals");
  assert(dep.includes("arrivals=False"));
  assert(dep.includes("placeId=2000"));
  assert(arr.includes("arrivals=True"));
  assert(arr.includes("placeId=2000"));
  assert(!dep.includes("arrivals=True"));
});

// The "no fetch outside the registry → honest state" guardrail, at TOTAL coverage.
//
// Until B3-full the registry held 3 stations, so any other slug was a real unserved
// station and the invariant tested itself. National coverage removes that: every name
// RFI publishes now resolves. The guardrail is still the most important thing this
// module does, so it is exercised against a SYNTHETIC unserved station instead of a
// real one — a fixture registry built from a TSV that deliberately omits it.
Deno.test("GUARDRAIL: a station outside the registry never resolves, at total coverage", () => {
  // A two-station fixture registry. `SINTETICA DI PROVA` is NOT in it and is not an
  // RFI name — it exists only to keep this invariant covered.
  const fixture = parseStationsTSV(
    "# fixture\n2000\tPADOVA\n2416\tROMA TERMINI\n",
  );
  assert(fixture.has("padova"));
  assert(fixture.has("roma-termini"));

  const syntheticSlug = stationSlug("SINTETICA DI PROVA");
  assertEquals(syntheticSlug, "sintetica-di-prova");
  assertEquals(fixture.get(syntheticSlug), undefined);
  // …so the handler's `resolveStation` branch returns 404 unknown_station and NO fetch
  // to RFI is ever attempted for it. There is no placeId to fetch with: the entry does
  // not exist, which is exactly the point — an unknown station can never be turned
  // into a URL, so it cannot show another station's board.
  assertEquals([...fixture.values()].find((e) => e.slug === syntheticSlug), undefined);

  // And the real registry agrees: a name RFI does not publish stays unknown even now.
  assertEquals(resolveStation(syntheticSlug), undefined);
  assertEquals(resolveStation("montegrotto-terme"), undefined);
});

// Every entry in the real registry can be turned into a monitor URL that carries ITS
// OWN placeId — never another station's. Checked on a deterministic spread rather than
// on the whole list, which would be slow without proving anything more.
Deno.test("GUARDRAIL: each station's monitor URL carries its own placeId", () => {
  const all = [...STATIONS.values()];
  const step = Math.floor(all.length / 50) || 1;
  for (let i = 0; i < all.length; i += step) {
    const entry = all[i];
    const url = rfiMonitorURL(entry.rfiLivePlaceId, "departures");
    assert(url.includes(`placeId=${entry.rfiLivePlaceId}`), `${entry.slug} URL lost its placeId`);
    assert(url.includes("arrivals=False"));
  }
});
