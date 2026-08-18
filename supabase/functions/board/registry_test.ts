// registry_test.ts — pure tests for the station registry + board-type / URL helpers.
// No network. Run: `deno test`.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseBoardType, resolveStation, rfiMonitorURL, STATIONS } from "./registry.ts";

Deno.test("registry resolves the VERIFIED stations and rejects others", () => {
  const padova = resolveStation("padova");
  assert(padova);
  assertEquals(padova!.slug, "padova");
  assertEquals(padova!.displayName, "Padova");
  assertEquals(padova!.rfiLivePlaceId, "2000");
  assertEquals(padova!.prmScheduledId, "1861");        // distinct id system, kept separate
  assertEquals(resolveStation("PADOVA "), padova);     // case/space-insensitive

  // Roma Termini: rfiLivePlaceId VERIFIED (2416); prmScheduledId intentionally absent
  // (never guessed) — the live board path does not use it.
  const roma = resolveStation("roma-termini");
  assert(roma);
  assertEquals(roma!.slug, "roma-termini");
  assertEquals(roma!.displayName, "Roma Termini");
  assertEquals(roma!.rfiLivePlaceId, "2416");
  assertEquals(roma!.prmScheduledId, undefined);
  assertEquals(resolveStation("ROMA-TERMINI "), roma); // case/space-insensitive

  // Terme Euganee-Abano-Montegrotto: rfiLivePlaceId VERIFIED (2829 → "Stazione di
  // TERME EUGANEE-ABANO-MONTEGROTTO"); prmScheduledId intentionally absent.
  // The slug MUST equal the iOS catalog id (Resources/stations.json) exactly.
  const terme = resolveStation("terme-euganee-abano-montegrotto");
  assert(terme);
  assertEquals(terme!.slug, "terme-euganee-abano-montegrotto");
  assertEquals(terme!.displayName, "Terme Euganee-Abano-Montegrotto");   // official RFI name
  assertEquals(terme!.rfiLivePlaceId, "2829");
  assertEquals(terme!.prmScheduledId, undefined);
  assertEquals(resolveStation("TERME-EUGANEE-ABANO-MONTEGROTTO "), terme);

  // The old, non-official slug must NOT resolve: one id only, no duplicate entity.
  assertEquals(resolveStation("montegrotto-terme"), undefined);
  // ABANO TERME (placeId 364) is a SEPARATE RFI station, deliberately NOT registered.
  assertEquals(resolveStation("abano-terme"), undefined);

  // A bare "roma" is NOT a station slug → handler returns 404 unknown_station.
  assertEquals(resolveStation("roma"), undefined);
  assertEquals(resolveStation(null), undefined);
  assertEquals(Object.keys(STATIONS).length, 3);       // no unverified stations activated
});

Deno.test("every registry entry carries a verified live placeId", () => {
  for (const [key, entry] of Object.entries(STATIONS)) {
    assertEquals(entry.slug, key);                     // key ↔ slug stay aligned (iOS sends the slug)
    assert(entry.rfiLivePlaceId.length > 0);
    assert(entry.displayName.length > 0);
  }
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
