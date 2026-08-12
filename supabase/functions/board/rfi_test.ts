// rfi_test.ts — pure parser/normalization tests. No network (never calls live RFI).
// Run: `deno test` inside supabase/functions/board/.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cleanText,
  decodeHtmlEntities,
  isCancelledRow,
  normalizeCategory,
  normalizeDelay,
  normalizePlatform,
  normalizeStatus,
  parseRFIMonitorHTML,
  type ParsedRow,
} from "./rfi.ts";

// Representative RFI-monitor-shaped fixture (positional <td> cells), with a verbose
// category + numeric entity, a delayed row, and a cancelled row with no platform.
const FIXTURE = `
<html><head><title>Monitor Partenze - PADOVA</title></head><body>
<div id="aggiornamento">Aggiornato alle 10:49</div>
<table><thead><tr><th>Treno</th></tr></thead>
<tbody>
  <tr>
    <td><img alt="Trenitalia"></td>
    <td><img alt="Categoria Alta Velocita&#39;"></td>
    <td>9805</td><td>Napoli Centrale</td><td>10:58</td><td>0</td><td>1</td><td></td>
  </tr>
  <tr>
    <td><img alt="Trenitalia"></td>
    <td><img alt="Categoria Regionale Veloce"></td>
    <td>2774</td><td>Venezia Santa Lucia</td><td>10:52</td><td>10</td><td>2</td><td></td>
  </tr>
  <tr class="lampeggio">
    <td><img alt="Trenitalia"></td>
    <td><img alt="INTERCITY"></td>
    <td>603</td><td>Roma Termini</td><td>11:20</td><td></td><td>3</td><td>In stazione</td>
  </tr>
  <tr>
    <td><img alt="Trenitalia"></td>
    <td><img alt="Categoria Regionale"></td>
    <td>5932</td><td>Castelfranco Veneto</td><td>11:30</td><td>Cancellato</td><td></td><td>Treno cancellato</td>
  </tr>
</tbody></table></body></html>`;

// A boarding train whose ONLY marker is the blinking CSS class on the <tr> itself
// (no "In stazione" info text). Guards the row-capture regex: if it captures just the
// inner cells, the class is invisible and `isDeparting` silently stays false.
const BLINKING_FIXTURE = `
<html><head><title>Monitor Partenze - PADOVA</title></head><body>
<table><thead><tr><th>Treno</th></tr></thead>
<tbody>
  <tr class="riga lampeggia">
    <td><img alt="Italo"></td>
    <td><img alt="Categoria Italo"></td>
    <td>9902</td><td>Milano Centrale</td><td>17:34</td><td>0</td><td></td><td></td>
  </tr>
</tbody></table></body></html>`;

Deno.test("blinking row class marks the train as departing", () => {
  const board = parseRFIMonitorHTML(BLINKING_FIXTURE);
  assertEquals(board.rows.length, 1);
  const row = board.rows[0];
  assertEquals(row.trainNumber, "9902");
  assertEquals(row.info, null); // no "In stazione" text — the class is the only signal
  assert(row.isDeparting, "blinking <tr> class must set isDeparting");
  assertEquals(
    normalizeStatus({ delayMinutes: null, isCancelled: false, isDeparting: row.isDeparting }),
    "departing",
  );
});

Deno.test("parses station name and updated time", () => {
  const board = parseRFIMonitorHTML(FIXTURE);
  assertEquals(board.stationName, "PADOVA");
  assertEquals(board.updatedAt, "10:49");
  assertEquals(board.rows.length, 4); // header <th> row skipped
});

Deno.test("normalizeCategory maps verbose labels + decodes entities, never leaks", () => {
  assertEquals(normalizeCategory("Categoria Alta Velocita&#39;"), "AV");
  assertEquals(normalizeCategory("Categoria Regionale Veloce"), "RV");
  assertEquals(normalizeCategory("Categoria Regionale"), "REG");
  assertEquals(normalizeCategory("INTERCITY"), "IC");
  assertEquals(normalizeCategory("Frecciarossa"), "FR");
  assertEquals(normalizeCategory("EuroCity"), "EC");
  assertEquals(normalizeCategory("RJ"), "RJ");
  assertEquals(normalizeCategory("RV"), "RV");
  assertEquals(normalizeCategory(null), "UNK");
  assertEquals(normalizeCategory("   "), "UNK");
  assertEquals(normalizeCategory("Qualcosa Di Sconosciuto"), "UNK");
});

Deno.test("decodeHtmlEntities decodes numeric + named", () => {
  assertEquals(decodeHtmlEntities("Velocita&#39;"), "Velocita'");
  assertEquals(decodeHtmlEntities("Citt&#224;"), "Città");
  assertEquals(decodeHtmlEntities("A&amp;B"), "A&B");
  assert(!decodeHtmlEntities("Velocita&#39;").includes("&#"));
});

Deno.test("cleanText strips tags + entities + collapses whitespace", () => {
  assertEquals(cleanText("  <b>Venezia</b>   Mestre  "), "Venezia Mestre");
  assertEquals(cleanText(null), "");
});

Deno.test("normalizeDelay returns positive minutes or null", () => {
  assertEquals(normalizeDelay("10"), 10);
  assertEquals(normalizeDelay("Ritardo 5"), 5);
  assertEquals(normalizeDelay("0"), null);
  assertEquals(normalizeDelay(""), null);
  assertEquals(normalizeDelay(null), null);
  assertEquals(normalizeDelay("in orario"), null);
});

Deno.test("normalizePlatform → value or '--'", () => {
  assertEquals(normalizePlatform("2"), "2");
  assertEquals(normalizePlatform(""), "--");
  assertEquals(normalizePlatform(null), "--");
});

Deno.test("normalizeStatus precedence", () => {
  assertEquals(normalizeStatus({ delayMinutes: null, isCancelled: true, isDeparting: true }), "cancelled");
  assertEquals(normalizeStatus({ delayMinutes: 5, isCancelled: false, isDeparting: true }), "delayed");
  assertEquals(normalizeStatus({ delayMinutes: null, isCancelled: false, isDeparting: true }), "departing");
  assertEquals(normalizeStatus({ delayMinutes: 0, isCancelled: false, isDeparting: false }), "onTime");
});

Deno.test("isCancelledRow detects cancellato/soppresso", () => {
  const base: ParsedRow = {
    operatorName: null, category: null, trainNumber: null, destination: null,
    time: null, delay: null, platform: null, info: null, isDeparting: false,
  };
  assert(isCancelledRow({ ...base, delay: "Cancellato" }));
  assert(isCancelledRow({ ...base, info: "Treno soppresso" }));
  assert(!isCancelledRow({ ...base, delay: "10" }));
});

Deno.test("end-to-end: parsed rows normalize without leaking source strings", () => {
  const board = parseRFIMonitorHTML(FIXTURE);
  for (const r of board.rows) {
    const category = normalizeCategory(r.category);
    assert(!category.includes("Categoria"));
    assert(!category.includes("&#"));
    assert(category.length <= 5); // compact code or UNK
  }
  // The cancelled row maps to cancelled + no platform.
  const cancelled = board.rows.find((r) => isCancelledRow(r));
  assert(cancelled);
  assertEquals(normalizePlatform(cancelled!.platform), "--");
});
