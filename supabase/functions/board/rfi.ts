// rfi.ts — RFI live station-monitor HTML → neutral parsed board + normalization
// helpers. Pure functions only (no network, no Deno APIs) so they are unit-testable
// with `deno test`. This is the SERVER-SIDE port of the proven iOS DEBUG parser
// (RFIStationMonitorParser / RFITrainCategoryNormalizer): the row reader is
// POSITIONAL over the table's <td> cells, which is more portable than fragile RFI
// class names. RFI HTML is not a stable contract and may change — keep this tolerant.

export interface ParsedRow {
  operatorName: string | null;
  category: string | null; // raw label, e.g. "Categoria Alta Velocita'"
  trainNumber: string | null;
  destination: string | null;
  time: string | null; // "HH:mm"
  delay: string | null; // raw cell, e.g. "10" / "" / "Ritardo 10"
  platform: string | null; // raw cell
  info: string | null;
  isDeparting: boolean;
}

export interface ParsedBoard {
  stationName: string | null;
  updatedAt: string | null; // raw "HH:mm" if found
  rows: ParsedRow[];
}

export type BoardStatus = "onTime" | "delayed" | "cancelled" | "departing";

// MARK: - HTML entity decoding

const NAMED_ENTITIES: Record<string, string> = {
  "&amp;": "&", "&apos;": "'", "&quot;": '"', "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
  "&agrave;": "à", "&egrave;": "è", "&eacute;": "é", "&igrave;": "ì", "&ograve;": "ò", "&ugrave;": "ù",
  "&Agrave;": "À", "&Egrave;": "È", "&Igrave;": "Ì", "&Ograve;": "Ò", "&Ugrave;": "Ù",
};

function fromCodePointSafe(value: number): string {
  try {
    return String.fromCodePoint(value);
  } catch {
    return "";
  }
}

/** Decode named + numeric (decimal/hex) HTML entities. Safe for short labels. */
export function decodeHtmlEntities(input: string): string {
  if (!input.includes("&")) return input;
  let s = input;
  for (const [k, v] of Object.entries(NAMED_ENTITIES)) s = s.split(k).join(v);
  s = s.replace(/&#(\d+);/g, (_m, d: string) => fromCodePointSafe(parseInt(d, 10)));
  s = s.replace(/&#[xX]([0-9a-fA-F]+);/g, (_m, h: string) => fromCodePointSafe(parseInt(h, 16)));
  return s;
}

/** Strip tags, decode entities, collapse whitespace. Returns "" when empty. */
export function cleanText(value: string | null | undefined): string {
  if (value == null) return "";
  let t = value.replace(/<[^>]+>/g, " ");
  t = decodeHtmlEntities(t);
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

function cleanOrNull(value: string | null | undefined): string | null {
  const c = cleanText(value);
  return c.length > 0 ? c : null;
}

// MARK: - Category normalization (verbose RFI label → compact board code)

const CATEGORY_MAP: Record<string, string> = {
  // Verbose labels (folded keys: lowercase, no accents, no apostrophe)
  "regionale": "REG", "regionale veloce": "RV", "alta velocita": "AV",
  "frecciarossa": "FR", "frecciargento": "FA", "frecciabianca": "FB",
  "intercity": "IC", "intercity notte": "ICN",
  "italo": "ITA", "eurocity": "EC", "euronight": "EN", "railjet": "RJ",
  // Codes already provided by the source
  "reg": "REG", "rv": "RV", "av": "AV", "fr": "FR", "fa": "FA", "fb": "FB",
  "ic": "IC", "icn": "ICN", "ita": "ITA", "ec": "EC", "en": "EN", "rj": "RJ",
};

function foldKey(s: string): string {
  return s
    .normalize("NFD").replace(/[̀-ͯ]/g, "") // strip diacritics: velocità → velocita
    .toLowerCase()
    .replace(/'/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Verbose / coded RFI category → compact board code. Never returns "Categoria …"
 * or raw HTML entities; unknown long labels collapse to "UNK".
 */
export function normalizeCategory(raw: string | null): string {
  if (!raw || !raw.trim()) return "UNK";
  let s = decodeHtmlEntities(raw);
  s = s.replace(/’/g, "'"); // right single quote → apostrophe
  s = s.replace(/\s+/g, " ").trim();
  s = s.replace(/^categoria\b\s*/i, "").trim(); // strip leading "Categoria"
  if (!s) return "UNK";
  const mapped = CATEGORY_MAP[foldKey(s)];
  if (mapped) return mapped;
  const upper = s.toUpperCase();
  if (upper.length <= 4 && /^[A-Z0-9]+$/.test(upper)) return upper; // already a short safe code
  return "UNK";
}

// MARK: - Delay / platform / status

/** Real positive delay in minutes, or null. "0"/""/non-numeric → null (never fake). */
export function normalizeDelay(raw: string | null): number | null {
  if (!raw) return null;
  const t = raw.trim();
  if (!/\d/.test(t)) return null;
  const digits = t.replace(/[^\d]/g, "");
  if (!digits) return null;
  const n = parseInt(digits, 10);
  return n > 0 ? n : null;
}

/** Cleaned platform, or "--" when missing (never invented). */
export function normalizePlatform(raw: string | null): string {
  const c = cleanText(raw ?? "");
  return c.length > 0 ? c : "--";
}

export function normalizeStatus(opts: {
  delayMinutes: number | null;
  isCancelled: boolean;
  isDeparting: boolean;
}): BoardStatus {
  if (opts.isCancelled) return "cancelled";
  if (opts.delayMinutes != null && opts.delayMinutes > 0) return "delayed";
  if (opts.isDeparting) return "departing";
  return "onTime";
}

/** True when the row's delay/info text marks it cancelled/soppresso. */
export function isCancelledRow(row: ParsedRow): boolean {
  const blob = `${row.delay ?? ""} ${row.info ?? ""}`.toLowerCase();
  return blob.includes("cancell") || blob.includes("soppress");
}

// MARK: - HTML parsing (positional <td> cells)

function firstGroup(s: string, re: RegExp): string | null {
  const m = s.match(re);
  return m && m[1] != null ? m[1] : null;
}

function allGroups(s: string, re: RegExp): string[] {
  const out: string[] = [];
  const r = new RegExp(re.source, re.flags.includes("g") ? re.flags : re.flags + "g");
  let m: RegExpExecArray | null;
  while ((m = r.exec(s)) !== null) {
    if (m[1] != null) out.push(m[1]);
    if (m.index === r.lastIndex) r.lastIndex++;
  }
  return out;
}

function tbodyScope(html: string): string {
  const open = html.search(/<tbody/i);
  if (open === -1) return html;
  const gt = html.indexOf(">", open);
  const close = html.toLowerCase().indexOf("</tbody>", gt);
  if (gt === -1 || close === -1) return html;
  return html.slice(gt + 1, close);
}

function imgAltOrText(cellHTML: string): string | null {
  const alt = firstGroup(cellHTML, /alt="([^"]*)"/i);
  if (alt) {
    const c = cleanOrNull(alt);
    if (c) return c;
  }
  const title = firstGroup(cellHTML, /title="([^"]*)"/i);
  if (title) {
    const c = cleanOrNull(title);
    if (c) return c;
  }
  return cleanOrNull(cellHTML);
}

function parseStationName(html: string): string | null {
  for (const pattern of [
    /id="nomestazione"[^>]*>([^<]+)/i,
    /class="nomestazione"[^>]*>([^<]+)/i,
    /<title>([^<]+)<\/title>/i,
  ]) {
    const raw = firstGroup(html, pattern);
    const cleaned = cleanOrNull(raw ?? "");
    if (cleaned) {
      // From "Monitor Partenze - PADOVA" keep the last token.
      const parts = cleaned.split(" - ");
      return (parts[parts.length - 1] ?? cleaned).trim();
    }
  }
  return null;
}

function parseUpdatedAt(html: string): string | null {
  const block = firstGroup(html, /aggiorn[^>]*>([^<]+)/i);
  if (!block) return null;
  const time = firstGroup(block, /(\d{1,2}[:.]\d{2})/);
  return time ? time.replace(".", ":") : null;
}

function parseRows(html: string): ParsedRow[] {
  const scope = tbodyScope(html);
  const rows = allGroups(scope, /<tr[^>]*>(.*?)<\/tr>/gis);
  const out: ParsedRow[] = [];
  for (const row of rows) {
    if (/<th/i.test(row)) continue; // header row
    const isDeparting = /lampeggi/i.test(row);
    const cells = allGroups(row, /<td[^>]*>(.*?)<\/td>/gis);
    if (cells.length < 5) continue;
    const text = (i: number) => (i < cells.length ? cleanOrNull(cells[i]) : null);
    const info = text(7);
    out.push({
      operatorName: imgAltOrText(cells[0] ?? ""),
      category: imgAltOrText(cells[1] ?? ""),
      trainNumber: text(2),
      destination: text(3),
      time: text(4),
      delay: text(5),
      platform: text(6),
      info,
      isDeparting: isDeparting || (info?.toLowerCase().includes("stazione") ?? false),
    });
  }
  return out;
}

export function parseRFIMonitorHTML(html: string): ParsedBoard {
  return {
    stationName: parseStationName(html),
    updatedAt: parseUpdatedAt(html),
    rows: parseRows(html),
  };
}
