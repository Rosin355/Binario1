// rfi_stations_tsv_test.ts — the shared artifact's two copies must stay IDENTICAL.
//
// iOS reads `Binario1/Binario1/Resources/rfi-stations.tsv` from its bundle; Deno
// cannot, so the artifact is embedded in `rfi_stations_tsv.ts`. The duplication is
// unavoidable (the two runtimes cannot share a file) but it must be a VERIFIED
// COPY, not two lists free to drift — which is what this test enforces.
//
// The file is read at test time rather than imported, deliberately: a static import
// reaching outside `supabase/` would put an edge into the module graph that
// `supabase functions deploy` bundles from. Reading needs `--allow-read`, which the
// CI test step passes.
//
// Run: `deno test --allow-read`

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { RFI_STATIONS_TSV } from "./rfi_stations_tsv.ts";

const IOS_COPY = new URL("../../../Binario1/Binario1/Resources/rfi-stations.tsv", import.meta.url);

Deno.test("the iOS and backend copies of the artifact are byte-identical", async () => {
  let iosBytes: Uint8Array;
  try {
    iosBytes = await Deno.readFile(IOS_COPY);
  } catch (error) {
    throw new Error(
      `Could not read the iOS copy at ${IOS_COPY.pathname}. The two copies must be ` +
        `verified against each other, so a missing file is a failure, not a skip. ` +
        `Regenerate both with \`node tools/generate-rfi-stations-tsv.mjs\`. (${error})`,
    );
  }

  const backendBytes = new TextEncoder().encode(RFI_STATIONS_TSV);

  // Compare byte length first: it localises "one copy was regenerated and the other
  // was not" without printing 46 KB of diff.
  assertEquals(
    backendBytes.length,
    iosBytes.length,
    "the two copies differ in byte length — regenerate BOTH with tools/generate-rfi-stations-tsv.mjs",
  );

  for (let i = 0; i < iosBytes.length; i++) {
    if (iosBytes[i] !== backendBytes[i]) {
      const context = new TextDecoder().decode(iosBytes.slice(Math.max(0, i - 40), i + 40));
      throw new Error(`copies diverge at byte ${i}, near: ${JSON.stringify(context)}`);
    }
  }
});

Deno.test("the artifact declares its provenance and extraction date", () => {
  // The artifact is a dated snapshot; without the date nobody can tell how stale it
  // is. These are the header lines the generator writes.
  assert(
    RFI_STATIONS_TSV.includes("https://iechub.rfi.it/ArriviPartenze/"),
    "the artifact does not name its source",
  );
  assert(
    /^# Extracted: \d{4}-\d{2}-\d{2}$/m.test(RFI_STATIONS_TSV),
    "the artifact does not carry an extraction date",
  );
  // And it says out loud that the count is not a constant, so nobody asserts it.
  assert(RFI_STATIONS_TSV.includes("DATED SNAPSHOT"));
});

Deno.test("the artifact stays safe to embed raw in a template literal", () => {
  // The single typographic normalization (backtick → apostrophe) is what makes the
  // embedded copy possible without escaping. If a backtick ever came back, the
  // generated TS would break in a way that is confusing to debug.
  assert(!RFI_STATIONS_TSV.includes("`"), "a backtick survived the normalization");
  assert(!RFI_STATIONS_TSV.includes("${"), "a template interpolation appeared in the artifact");
});
