#!/usr/bin/env node
//
// generate-rfi-stations-tsv.mjs — regenerate the shared RFI station artifact.
//
// The artifact is a DATED SNAPSHOT of RFI's own station list, not a perpetual
// truth: nothing guarantees the list is stable, so the count is not something to
// rely on. Re-run this script to refresh it; do NOT hand-edit either copy.
//
// A caution about that count, learned the hard way. The repo carried both "2434"
// (registry.ts, 2026-08-18) and "2435" (docs, 2026-08-28), and the first run of this
// script also produced 2434 — which looked like RFI closing a station. It was not:
// the extraction was dropping MILANO CENTRALE, whose <option> carries
// `selected="selected"` BEFORE `value`, so a pattern anchored on `<option value=`
// missed it. The true count on 2026-08-31 is 2435, the same as on 2026-08-28. The
// `optionTags` check below exists so that class of silent loss fails loudly instead
// of being explained away as upstream drift.
//
// Source: the `<select name="PlaceId">` station picker on
// https://iechub.rfi.it/ArriviPartenze/ — RFI's own authoritative list, the same
// one the live station monitor is driven by. No alternative source, ever.
//
// Writes TWO byte-identical copies (one runtime cannot import the other's file):
//   1. Binario1/Binario1/Resources/rfi-stations.tsv        — iOS bundle resource
//   2. supabase/functions/board/rfi_stations_tsv.ts        — Deno embedded string
// `rfi_stations_tsv_test.ts` asserts they stay identical byte for byte.
//
// Usage:  node tools/generate-rfi-stations-tsv.mjs [--date YYYY-MM-DD]
//
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..");
const SOURCE_URL = "https://iechub.rfi.it/ArriviPartenze/";

const IOS_COPY = join(REPO, "Binario1/Binario1/Resources/rfi-stations.tsv");
const BACKEND_COPY = join(REPO, "supabase/functions/board/rfi_stations_tsv.ts");

/// Anchors verified by hand against the live monitor. If any of these stops
/// matching, the source page changed shape and the extraction is NOT to be
/// trusted — fail loudly rather than write a plausible-looking wrong file.
const ANCHORS = {
  2000: "PADOVA",
  2416: "ROMA TERMINI",
  2829: "TERME EUGANEE-ABANO-MONTEGROTTO",
  3009: "VENEZIA S.LUCIA",
  3062: "VIGODARZERE",
  364: "ABANO TERME",
  // The page's own pre-selected option, whose markup puts `selected` before
  // `value`. Kept as an anchor so the parser can never drop it again unnoticed.
  1728: "MILANO CENTRALE",
};

/// TYPOGRAPHIC normalization ONLY. RFI writes a backtick where it means an
/// apostrophe (CITTA` DI CASTELLO). Both forms mean the same character, and the
/// backtick would also have to be escaped inside the TS template literal.
///
/// The STRUCTURE is never touched: spacing, hyphens and slashes stay exactly as
/// RFI writes them ("BOLOGNA C.LE/AV", "CITTA` DI CASTELLO - ZONA INDUSTRIALE"
/// keeps its spaced hyphen). Normalizing structure would be inventing names.
function normalizeTypography(name) {
  return name.replaceAll("`", "'");
}

function decodeEntities(s) {
  return s.replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)))
    .replaceAll("&amp;", "&").replaceAll("&quot;", '"')
    .replaceAll("&lt;", "<").replaceAll("&gt;", ">");
}

function extract(html) {
  const select = html.match(/<select[^>]*name="PlaceId"[^>]*>([\s\S]*?)<\/select>/);
  if (!select) throw new Error("PlaceId select not found — the source page changed shape.");
  const inner = select[1];

  // `value` is NOT always the first attribute: the option for the station the page
  // is currently showing carries `selected="selected"` in front of it. A pattern
  // anchored on `<option value=` silently drops exactly that one station (it cost
  // us MILANO CENTRALE, placeId 1728, on the first run), so match attributes in
  // any order.
  const rows = [...inner.matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/g)].map((m) => {
    const value = m[1].match(/\bvalue\s*=\s*"(\d+)"/);
    if (!value) throw new Error(`<option> without a numeric value: ${m[0].slice(0, 120)}`);
    return { placeId: value[1], name: normalizeTypography(decodeEntities(m[2]).trim()) };
  });

  // Every <option> in the select must survive to a row. Anything else is silent
  // data loss, which is the one failure mode this artifact cannot have.
  const optionTags = (inner.match(/<option\b/g) ?? []).length;
  if (rows.length !== optionTags) {
    throw new Error(`Dropped rows: ${optionTags} <option> tags in the select, ${rows.length} extracted.`);
  }
  if (rows.length === 0) throw new Error("PlaceId select is empty.");
  return rows;
}

/// Everything that must hold for the snapshot to be usable. Deliberately NOT a
/// count check: the count is not an invariant, so checking it would reject a valid
/// refresh while proving nothing about the one it accepts.
function verify(rows) {
  const problems = [];

  const ids = new Set(), names = new Set();
  for (const { placeId, name } of rows) {
    if (ids.has(placeId)) problems.push(`duplicate placeId ${placeId}`);
    if (names.has(name)) problems.push(`duplicate name ${name}`);
    ids.add(placeId);
    names.add(name);
    if (name === "") problems.push(`empty name for placeId ${placeId}`);
    // A tab or newline would corrupt the TSV; a backtick or ${ would corrupt the
    // TS template literal the backend copy is embedded in.
    if (/[\t\r\n`]/.test(name)) problems.push(`unsafe character in "${name}"`);
    if (name.includes("${")) problems.push(`template interpolation in "${name}"`);
  }

  for (const [placeId, expected] of Object.entries(ANCHORS)) {
    const found = rows.find((r) => r.placeId === String(placeId));
    if (!found) problems.push(`anchor ${placeId} (${expected}) missing`);
    else if (found.name !== expected) {
      problems.push(`anchor ${placeId}: expected "${expected}", got "${found.name}"`);
    }
  }

  if (problems.length) {
    throw new Error(`Extraction failed verification:\n  - ${problems.join("\n  - ")}`);
  }
}

function buildTSV(rows, date) {
  const header = [
    `# RFI station list — official station names, the single source shared by iOS and backend.`,
    `#`,
    `# Source:    ${SOURCE_URL} — the <select name="PlaceId"> station picker,`,
    `#            RFI's own authoritative list (same ids the live monitor uses).`,
    `# Extracted: ${date}`,
    `# Entries:   ${rows.length} at extraction time.`,
    `#`,
    `# THIS IS A DATED SNAPSHOT, NOT A PERPETUAL TRUTH. Nothing guarantees RFI's`,
    `# list is stable, so the entry count is not a constant to rely on. Never assert`,
    `# the count in a test — assert properties (uniqueness, injectivity, known`,
    `# anchors). A count assertion proves nothing while it passes and breaks on any`,
    `# upstream change.`,
    `#`,
    `# Names are RFI's, verbatim, with ONE typographic normalization: where RFI`,
    `# types a backtick standing in for an apostrophe, it becomes an apostrophe`,
    `# (so "CITTA DI CASTELLO" carries a real apostrophe after CITTA).`,
    `# Structure is never touched — spacing, hyphens and slashes stay as RFI writes`,
    `# them. Regenerate with tools/generate-rfi-stations-tsv.mjs; never hand-edit.`,
    `#`,
    `# placeId\tname`,
  ].join("\n");
  const body = rows.map((r) => `${r.placeId}\t${r.name}`).join("\n");
  return `${header}\n${body}\n`;
}

function buildBackendCopy(tsv) {
  if (tsv.includes("`") || tsv.includes("${")) {
    throw new Error("TSV contains a character that cannot be embedded raw in a template literal.");
  }
  return `// rfi_stations_tsv.ts — BYTE-IDENTICAL copy of
// Binario1/Binario1/Resources/rfi-stations.tsv.
//
// The two runtimes cannot share a file, so the artifact is duplicated — but the
// duplication is a VERIFIED copy, not two lists free to drift:
// \`rfi_stations_tsv_test.ts\` asserts the two are identical byte for byte.
//
// GENERATED — do not hand-edit either copy. Regenerate BOTH together with
// \`node tools/generate-rfi-stations-tsv.mjs\`.
//
// Safe to embed raw: the artifact contains no backtick (the one typographic
// normalization removes them) and no \${ sequence — the generator verifies this
// before writing.

export const RFI_STATIONS_TSV = String.raw\`${tsv}\`;
`;
}

const dateArg = process.argv.indexOf("--date");
const date = dateArg !== -1
  ? process.argv[dateArg + 1]
  : new Date().toISOString().slice(0, 10);
if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error(`Bad --date: ${date}`);

console.log(`Fetching ${SOURCE_URL} …`);
const response = await fetch(SOURCE_URL);
if (!response.ok) throw new Error(`HTTP ${response.status} from ${SOURCE_URL}`);
const rows = extract(await response.text());
verify(rows);
console.log(`Extracted ${rows.length} stations; all anchors and invariants hold.`);

const tsv = buildTSV(rows, date);
writeFileSync(IOS_COPY, tsv);
writeFileSync(BACKEND_COPY, buildBackendCopy(tsv));
console.log(`Wrote ${IOS_COPY}`);
console.log(`Wrote ${BACKEND_COPY}`);
