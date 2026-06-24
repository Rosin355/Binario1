// registry_test.ts — pure tests for the station registry + board-type / URL helpers.
// No network. Run: `deno test`.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseBoardType, resolveStation, rfiMonitorURL, STATIONS } from "./registry.ts";

Deno.test("registry resolves Padova (only verified station) and rejects others", () => {
  const padova = resolveStation("padova");
  assert(padova);
  assertEquals(padova!.slug, "padova");
  assertEquals(padova!.displayName, "Padova");
  assertEquals(padova!.rfiLivePlaceId, "2000");
  assertEquals(padova!.prmScheduledId, "1861");        // distinct id system, kept separate
  assertEquals(resolveStation("PADOVA "), padova);     // case/space-insensitive
  assertEquals(resolveStation("roma"), undefined);
  assertEquals(resolveStation(null), undefined);
  assertEquals(Object.keys(STATIONS).length, 1);       // no unverified stations activated
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
