// rfi_test.ts — pure parser/normalization tests. No network (never calls live RFI).
// Run: `deno test` inside supabase/functions/board/.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cleanText,
  decodeHtmlEntities,
  detailsNote,
  isBoardingCell,
  isCancelledRow,
  normalizeCategory,
  normalizeDelay,
  normalizePlatform,
  normalizeStatus,
  parseRFIMonitorHTML,
  type ParsedRow,
} from "./rfi.ts";
import { PADOVA_DEPARTURES_HTML, ROMA_TERMINI_DEPARTURES_HTML } from "./rfi_fixtures.ts";

// Fixtures are REAL RFI HTML (see rfi_fixtures.ts). The previous hand-written ones
// marked a boarding train with `<tr class="riga lampeggia">` — a shape the live page
// does not have — which is exactly why the departing test passed while the parser was
// wrong. Row-level expectations below were counted on the real download.

function rowOf(html: string, trainNumber: string) {
  const row = parseRFIMonitorHTML(html).rows.find((r) => r.trainNumber === trainNumber);
  assert(row, `row ${trainNumber} missing from fixture`);
  return row!;
}

Deno.test("REAL HTML: departing comes only from the boarding column", () => {
  const board = parseRFIMonitorHTML(PADOVA_DEPARTURES_HTML);
  assertEquals(board.rows.length, 4);
  // 8906 and 8929 carry <img class="exlampeggio"> in the RExLampeggio cell.
  assertEquals(board.rows.filter((r) => r.isDeparting).map((r) => r.trainNumber), ["8906", "8929"]);
  // 3513 and 17087 have aria-label="No" and an empty cell — even though BOTH rows
  // contain the substring "lampeggi" (cell id RExLampeggio / class ExLampeggio_classtd).
  assert(PADOVA_DEPARTURES_HTML.includes("RExLampeggio"));
  assert(!rowOf(PADOVA_DEPARTURES_HTML, "3513").isDeparting);
  assert(!rowOf(PADOVA_DEPARTURES_HTML, "17087").isDeparting);
});

Deno.test("REAL HTML: an on-time train is not reported as departing", () => {
  // The regression this guards: with the substring test every row matched, so every
  // row without a delay became "departing" (32 of 40 rows on the live board).
  const row = rowOf(PADOVA_DEPARTURES_HTML, "17087");
  assertEquals(row.delay, null);
  assertEquals(
    normalizeStatus({ delayMinutes: null, isCancelled: false, isDeparting: row.isDeparting }),
    "onTime",
  );
});

Deno.test("REAL HTML: boarding train with no delay maps to departing", () => {
  const row = rowOf(PADOVA_DEPARTURES_HTML, "8929");
  assertEquals(row.delay, null);
  assert(row.isDeparting);
  assertEquals(
    normalizeStatus({ delayMinutes: null, isCancelled: false, isDeparting: row.isDeparting }),
    "departing",
  );
  // A delay still wins over boarding (8906 is boarding AND 5 minutes late).
  const late = rowOf(PADOVA_DEPARTURES_HTML, "8906");
  assert(late.isDeparting);
  assertEquals(
    normalizeStatus({ delayMinutes: normalizeDelay(late.delay), isCancelled: false, isDeparting: true }),
    "delayed",
  );
});

Deno.test("REAL HTML: info is the Informazioni note, not the boarding cell or the stop list", () => {
  assertEquals(rowOf(PADOVA_DEPARTURES_HTML, "3513").info, "CARROZZA 1 IN TESTA AL TRENO");
  // 17087 has a popup with "Fermate successive" but no "Informazioni" block.
  assertEquals(rowOf(PADOVA_DEPARTURES_HTML, "17087").info, null);
  assertEquals(rowOf(ROMA_TERMINI_DEPARTURES_HTML, "4622").info, "NO-STOP");
  // The itinerary must never leak into the board note.
  for (const html of [PADOVA_DEPARTURES_HTML, ROMA_TERMINI_DEPARTURES_HTML]) {
    for (const r of parseRFIMonitorHTML(html).rows) {
      if (r.info == null) continue;
      assert(!r.info.includes("FERMA A:"), `info leaked the stop list: ${r.info}`);
      assert(!r.info.includes("Fermate successive"), `info leaked the popup title: ${r.info}`);
    }
  }
});

Deno.test("REAL HTML: row fields at Padova", () => {
  const row = rowOf(PADOVA_DEPARTURES_HTML, "3513");
  assertEquals(row.operatorName, "TRENITALIA");
  assertEquals(row.destination, "VENEZIA S.LUCIA");
  assertEquals(row.time, "12:22");
  assertEquals(row.delay, "20");
  assertEquals(row.platform, "5");
  assertEquals(normalizeCategory(row.category), "RV");
  assertEquals(normalizeCategory(rowOf(PADOVA_DEPARTURES_HTML, "8906").category), "AV");
});

Deno.test("REAL HTML: Roma Termini — missing platform is never invented", () => {
  const board = parseRFIMonitorHTML(ROMA_TERMINI_DEPARTURES_HTML);
  assertEquals(board.stationName, "ROMA TERMINI");
  assertEquals(board.rows.length, 5);
  // RFI leaves the platform blank at Roma until it is confirmed.
  const noStop = rowOf(ROMA_TERMINI_DEPARTURES_HTML, "4622");
  assertEquals(noStop.platform, null);
  assertEquals(normalizePlatform(noStop.platform), "--");
  assertEquals(normalizeCategory(noStop.category), "RV"); // "Categoria REGIONALE VELOCE"
  // A published platform still comes through.
  assertEquals(rowOf(ROMA_TERMINI_DEPARTURES_HTML, "12657").platform, "17");
  // Alphanumeric train numbers exist on the real board.
  assertEquals(rowOf(ROMA_TERMINI_DEPARTURES_HTML, "CB706").trainNumber, "CB706");
});

Deno.test("REAL HTML: Roma Termini — departing and on-time rows are distinguished", () => {
  const boarding = rowOf(ROMA_TERMINI_DEPARTURES_HTML, "12657");
  assert(boarding.isDeparting);
  const quiet = rowOf(ROMA_TERMINI_DEPARTURES_HTML, "12522");
  assert(!quiet.isDeparting);
  assertEquals(
    normalizeStatus({ delayMinutes: null, isCancelled: false, isDeparting: quiet.isDeparting }),
    "onTime",
  );
});

Deno.test("isBoardingCell / detailsNote work on the raw cell HTML", () => {
  assert(isBoardingCell('<img class="exlampeggio" alt="Si" src="/x/LampeggioGrey.png" />'));
  assert(isBoardingCell('<img class="exlampeggio" alt="Si" src="/x/LampeggioGold.png" />'));
  assert(!isBoardingCell("   \n  ")); // aria-label="No" renders an empty cell
  assert(!isBoardingCell(null));
  assertEquals(detailsNote(null), null);
  assertEquals(detailsNote("<div>no popup here</div>"), null);
  assertEquals(
    detailsNote(
      '<div class="titoloInfoAggiuntive">Fermate successive</div><div class="testoinfoaggiuntive">FERMA A:X (1:00)</div>' +
        '<div class="titoloInfoAggiuntive">Informazioni</div><div class="testoinfoaggiuntive"> TRENO PARZIALE </div>',
    ),
    "TRENO PARZIALE",
  );
});

Deno.test("REAL HTML: updatedAt is NOT captured by the current pattern (known gap)", () => {
  // The live page renders "aggiornato il 18/08/2026 alle ore 12:34:29" across several
  // <span>s; the updated-at pattern finds no HH:mm and returns null, so the backend
  // falls back to its own fetchedAt. Honest, but the source timestamp is lost.
  // Asserted so the gap is visible instead of silently assumed to work.
  assertEquals(parseRFIMonitorHTML(PADOVA_DEPARTURES_HTML).updatedAt, null);
});

Deno.test("REAL HTML: parses the station name and skips the header row", () => {
  const board = parseRFIMonitorHTML(PADOVA_DEPARTURES_HTML);
  assertEquals(board.stationName, "PADOVA");
  assertEquals(board.rows.length, 4); // the <thead> <th> row is skipped
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

Deno.test("end-to-end: REAL rows normalize without leaking source strings", () => {
  // NOTE: no cancelled train appeared in either real download, so cancellation stays
  // covered only by the pure isCancelledRow test above. See 17_VIAGGIATRENO_SPIKE.md.
  for (const html of [PADOVA_DEPARTURES_HTML, ROMA_TERMINI_DEPARTURES_HTML]) {
    const board = parseRFIMonitorHTML(html);
    assert(board.rows.length > 0);
    for (const r of board.rows) {
      const category = normalizeCategory(r.category);
      assert(!category.includes("Categoria"));
      assert(!category.includes("&#"));
      assert(category.length <= 5); // compact code or UNK
      assert(!(r.platform ?? "").includes("<"));
      assertEquals(normalizePlatform(r.platform), r.platform ?? "--");
    }
  }
});
