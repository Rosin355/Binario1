// sample-verify-monitor.ts — Passo 3: stratified sample verification.
//
// Before national coverage is switched on, check that the live RFI monitor really
// answers for stations across the whole artifact — not just the handful verified by
// hand — and that the BACKEND'S OWN PARSER (`rfi.ts`, imported here, not
// reimplemented) understands what comes back.
//
// Deliberately read-only and polite: GET only, small concurrency, no retries storm.
//
// Run:  deno run --allow-net --allow-read tools/sample-verify-monitor.ts [--size N]

import { parseRFIMonitorHTML } from "../supabase/functions/board/rfi.ts";
import { parseStationsTSV, rfiMonitorURL } from "../supabase/functions/board/registry.ts";

const ARTIFACT = new URL("../Binario1/Binario1/Resources/rfi-stations.tsv", import.meta.url);
const CONCURRENCY = 4;

const sizeArg = Deno.args.indexOf("--size");
const SAMPLE_SIZE = sizeArg !== -1 ? Number(Deno.args[sizeArg + 1]) : 75;

const registry = parseStationsTSV(await Deno.readTextFile(ARTIFACT));
const all = [...registry.values()];

/// Stations named in the curated overlay: the big hubs, and the ones already verified
/// by hand in earlier tickets. These MUST be in the sample.
const CURATED = [
  "padova", "venezia-s-lucia", "venezia-mestre", "bologna-centrale",
  "firenze-santa-maria-novella", "milano-centrale", "milano-porta-garibaldi",
  "roma-termini", "roma-tiburtina", "napoli-centrale", "torino-porta-nuova",
  "torino-porta-susa", "verona-porta-nuova", "reggio-emilia-av-mediopadana",
  "genova-piazza-principe", "bari-centrale", "terme-euganee-abano-montegrotto",
  "vigodarzere",          // required by the ticket: the small-station probe
  "abano-terme",          // newly reachable, settled the disambiguation debt
];

const isOperational = (n: string) =>
  n.startsWith("PM ") || n.startsWith("PC ") || n.startsWith("BIVIO ") || n.endsWith(" PES");

// Strata. "Size" is not in RFI's list, so it is what we MEASURE (row counts below);
// what we can stratify on beforehand is the shape of the sample: the known hubs, a
// deliberate spread across the whole alphabet, and the operational points, which are
// expected to behave differently and are checked separately rather than mixed in.
const curated = CURATED.map((slug) => registry.get(slug)).filter((e) => e !== undefined);
const operational = all.filter((e) => isOperational(e.displayName)).slice(0, 6);
const ordinary = all.filter((e) => !isOperational(e.displayName) && !CURATED.includes(e.slug));

const spreadCount = Math.max(0, SAMPLE_SIZE - curated.length - operational.length);
const step = ordinary.length / spreadCount;
const spread = Array.from({ length: spreadCount }, (_, i) => ordinary[Math.floor(i * step)]);

const sample = [...curated, ...spread, ...operational];

interface Result {
  slug: string;
  name: string;
  placeId: string;
  status: number | string;
  rows: number;
  rawRows: number;
  parsedName: string | null;
  problems: string[];
  stratum: string;
}

async function probe(entry: typeof all[number], stratum: string): Promise<Result> {
  const url = rfiMonitorURL(entry.rfiLivePlaceId, "departures");
  const result: Result = {
    slug: entry.slug, name: entry.displayName, placeId: entry.rfiLivePlaceId,
    status: 0, rows: 0, rawRows: 0, parsedName: null, problems: [], stratum,
  };
  try {
    const response = await fetch(url, { headers: { "User-Agent": "Binario1-sample-verify" } });
    result.status = response.status;
    const html = await response.text();
    if (!response.ok) { result.problems.push(`HTTP ${response.status}`); return result; }

    const board = parseRFIMonitorHTML(html);
    result.parsedName = board.stationName;
    result.rawRows = board.rows.length;

    // Count what the HANDLER would actually serve, not what the parser sees. The RFI
    // page pads its table to a minimum of ~15 slots with entirely blank rows, and
    // `index.ts` already drops them with `.filter(r => r.scheduledTime.length > 0)`.
    // Counting raw parser rows would report a defect that does not exist.
    const served = board.rows.filter((r) => (r.time ?? "").length > 0);
    result.rows = served.length;

    // Structural compatibility: does the page look like the one the parser expects?
    if (board.stationName === null) result.problems.push("no station name parsed");
    if (served.length === 0) {
      // RFI says this itself, in the page, rather than serving a broken board.
      result.problems.push(
        /DATI NON DISPONIBILI/i.test(html) ? "RFI: DATI NON DISPONIBILI" : "zero rows served",
      );
    }
    for (const row of served.slice(0, 5)) {
      if (!row.destination) result.problems.push("a served row has no destination");
      if (!row.trainNumber) result.problems.push("a served row has no train number");
      if (!row.category) result.problems.push("a served row has no category");
    }
  } catch (error) {
    result.status = "ERROR";
    result.problems.push(String(error).slice(0, 120));
  }
  return result;
}

const tagged: Array<[typeof all[number], string]> = [
  ...curated.map((e) => [e, "curated"] as [typeof all[number], string]),
  ...spread.map((e) => [e, "spread"] as [typeof all[number], string]),
  ...operational.map((e) => [e, "operational"] as [typeof all[number], string]),
];

console.log(`Probing ${tagged.length} stations (of ${all.length} in the artifact), concurrency ${CONCURRENCY}…\n`);

const results: Result[] = [];
for (let i = 0; i < tagged.length; i += CONCURRENCY) {
  const batch = tagged.slice(i, i + CONCURRENCY);
  results.push(...await Promise.all(batch.map(([e, s]) => probe(e, s))));
  Deno.stderr.writeSync(new TextEncoder().encode(`\r  ${results.length}/${tagged.length}`));
}
console.log("\n");

const passenger = results.filter((r) => r.stratum !== "operational");
const ok = passenger.filter((r) => r.problems.length === 0);
const empty = passenger.filter((r) => r.status === 200 && r.rows === 0);
const rfiSaysUnavailable = empty.filter((r) => r.problems.some((p) => p.includes("DATI NON DISPONIBILI")));
const failed = passenger.filter((r) => r.status !== 200);
const odd = passenger.filter((r) => r.status === 200 && r.rows > 0 && r.problems.length > 0);

console.log("=".repeat(70));
console.log(`PASSENGER STATIONS: ${passenger.length} probed`);
console.log(`  fully coherent (200 + real rows + parser happy): ${ok.length}` +
  `  → ${(100 * ok.length / passenger.length).toFixed(1)}%`);
console.log(`  HTTP 200 but ZERO rows: ${empty.length}` +
  `  (of which RFI itself says DATI NON DISPONIBILI: ${rfiSaysUnavailable.length})`);
console.log(`  non-200 / error:        ${failed.length}`);
console.log(`  rows but odd structure: ${odd.length}`);

const counts = passenger.map((r) => r.rows).sort((a, b) => a - b);
const at = (q: number) => counts[Math.floor(q * (counts.length - 1))];
console.log(`  row counts — min ${counts[0]}, p25 ${at(0.25)}, median ${at(0.5)}, p75 ${at(0.75)}, max ${counts[counts.length - 1]}`);

if (failed.length) {
  console.log("\n--- NON-200 / ERROR (in full) ---");
  for (const r of failed) console.log(`  ${r.placeId.padStart(5)} ${r.name} → ${r.status} ${r.problems.join("; ")}`);
}
if (empty.length) {
  console.log("\n--- HTTP 200 BUT EMPTY (in full) ---");
  for (const r of empty) {
    console.log(`  ${r.placeId.padStart(5)} ${r.name}  → ${r.problems.join("; ")}` +
      `  (parser saw ${r.rawRows} raw rows, parsed name: ${r.parsedName ?? "none"})`);
  }
}
if (odd.length) {
  console.log("\n--- DIFFERENT STRUCTURE (in full) ---");
  for (const r of odd) console.log(`  ${r.placeId.padStart(5)} ${r.name} served=${r.rows} raw=${r.rawRows} → ${[...new Set(r.problems)].join("; ")}`);
}

console.log("\n--- OPERATIONAL POINTS (excluded from the percentage; expected to differ) ---");
for (const r of results.filter((r) => r.stratum === "operational")) {
  console.log(`  ${r.placeId.padStart(5)} ${r.name} → HTTP ${r.status}, served=${r.rows} (raw ${r.rawRows})` +
    (r.problems.length ? `, ${[...new Set(r.problems)].join("; ")}` : ""));
}

console.log("\n--- ANCHORS ---");
for (const slug of ["padova", "vigodarzere", "terme-euganee-abano-montegrotto", "abano-terme", "milano-centrale"]) {
  const r = results.find((x) => x.slug === slug);
  if (r) console.log(`  ${r.name} (${r.placeId}) → HTTP ${r.status}, served=${r.rows} (raw ${r.rawRows}), parsed name "${r.parsedName}"`);
}
