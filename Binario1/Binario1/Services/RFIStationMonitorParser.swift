//
//  RFIStationMonitorParser.swift
//  Binario1
//
//  DEBUG-ONLY real-data spike. Parses the RFI live station-monitor HTML into a
//  neutral DTO (`RFIMonitorBoard`/`RFIMonitorRow`) — no UI, no networking, no
//  domain mapping. Kept tolerant: malformed/short rows are skipped, not crashed.
//
//  NOTE: RFI HTML is not a stable contract and can change. The row reader is
//  POSITIONAL over the table's <td> cells (more portable than fragile class
//  names); station name / updated-at use light markers. Verified against REAL
//  downloads of the live page (Padova + Roma Termini, 2026-08-18), which are the
//  fixtures in Binario1Tests/Fixtures. Keep it that way: an invented fixture once hid
//  a wrong departing rule — see Binario1/docs/17_VIAGGIATRENO_SPIKE.md (Appendice A).
//

#if DEBUG
import Foundation

struct RFIMonitorRow: Equatable {
    let operatorName: String?
    let category: String?
    let trainNumber: String?
    let destination: String?
    let time: String?
    let delay: String?
    let platform: String?
    let info: String?
    let isDeparting: Bool?
}

struct RFIMonitorBoard: Equatable {
    let stationName: String?
    let updatedAt: String?      // raw "HH:mm" if found
    let rows: [RFIMonitorRow]
}

enum RFIStationMonitorParser {

    static func parse(_ html: String) -> RFIMonitorBoard {
        RFIMonitorBoard(
            stationName: stationName(in: html),
            updatedAt: updatedAt(in: html),
            rows: rows(in: html)
        )
    }

    // MARK: - Station / updated-at

    static func stationName(in html: String) -> String? {
        for pattern in ["id=\"nomestazione\"[^>]*>([^<]+)",
                        "class=\"nomestazione\"[^>]*>([^<]+)",
                        "<title>([^<]+)</title>"] {
            if let raw = firstGroup(in: html, pattern: pattern), let cleaned = clean(raw) {
                // From a <title> like "Monitor Partenze - PADOVA", keep the last token.
                return cleaned.components(separatedBy: " - ").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? cleaned
            }
        }
        return nil
    }

    static func updatedAt(in html: String) -> String? {
        if let block = firstGroup(in: html, pattern: "aggiorn[^>]*>([^<]+)"),
           let time = firstGroup(in: block, pattern: "(\\d{1,2}[:.]\\d{2})") {
            return time.replacingOccurrences(of: ".", with: ":")
        }
        return nil
    }

    // MARK: - Rows (positional <td> cells)

    /// Positional cell indexes of the RFI monitor table, verified against the live page
    /// (ids in the real markup, in order):
    ///   0 RVettore · 1 RCategoria · 2 RTreno · 3 RStazione · 4 ROrario
    ///   5 RRitardo · 6 RBinario · 7 RExLampeggio · 8 RDettagli
    static let boardingCellIndex = 7
    static let detailsCellIndex = 8

    /// True when the "In partenza"/"In arrivo" cell carries the boarding icon.
    ///
    /// The signal is an `<img class="exlampeggio" alt="Si">` INSIDE the RExLampeggio
    /// cell; when the train is not boarding the cell is empty and the `<td>` carries
    /// `aria-label="No"`. Testing the ROW for the substring "lampeggi" is WRONG: every
    /// row contains it as part of that cell's own id/class (RExLampeggio /
    /// ExLampeggio_classtd), and the `<tr>` class is only zebra striping
    /// ("row yellowRow" / "row greyRow"). Verified on the live monitor 2026-08-18:
    /// 2 of 40 rows at Padova, 2 of 40 at Roma Termini, 0 of 40 on the arrivals board.
    static func isBoardingCell(_ cellHTML: String?) -> Bool {
        guard let cellHTML else { return false }
        return firstGroup(in: cellHTML, pattern: "(<img[^>])") != nil
    }

    /// The free-text note from the details cell — the block under the "Informazioni"
    /// heading of the popup, never the "Fermate successive" stop list (a long itinerary,
    /// not a board note). Real values seen: "CARROZZA 1 IN TESTA AL TRENO",
    /// "VIA MONTEBELLUNA", "NO-STOP", "VIAGGIATORI DA … CON BUS SOSTITUTIVO ALLE ORE …".
    /// nil when the row has no Informazioni block (29 of 40 rows had one).
    static func detailsNote(_ cellHTML: String?) -> String? {
        guard let cellHTML,
              let raw = firstGroup(
                  in: cellHTML,
                  pattern: "titoloInfoAggiuntive[^>]*>\\s*Informazioni\\s*</div>\\s*<div[^>]*testoinfoaggiuntive[^>]*>(.*?)</div>"
              )
        else { return nil }
        return clean(raw)
    }

    static func rows(in html: String) -> [RFIMonitorRow] {
        let scope = substring(html, between: "<tbody", and: "</tbody>") ?? html
        // Capture the WHOLE <tr …>…</tr> element, opening tag included, so the header
        // guard and any future row-level attribute stay visible. NOTE: the row's own
        // class carries NO board information — see `isBoardingCell`.
        return allGroups(in: scope, pattern: "(<tr[^>]*>.*?</tr>)").compactMap { row in
            guard !row.localizedCaseInsensitiveContains("<th") else { return nil }  // header row
            let cells = allGroups(in: row, pattern: "<td[^>]*>(.*?)</td>")
            guard cells.count >= 5 else { return nil }
            func text(_ i: Int) -> String? { i < cells.count ? clean(cells[i]) : nil }
            func cell(_ i: Int) -> String? { i < cells.count ? cells[i] : nil }

            return RFIMonitorRow(
                operatorName: imgAltOrText(cells.indices.contains(0) ? cells[0] : ""),
                category: imgAltOrText(cells.indices.contains(1) ? cells[1] : ""),
                trainNumber: text(2),
                destination: text(3),
                time: text(4),
                delay: text(5),
                platform: text(6),
                info: detailsNote(cell(detailsCellIndex)),
                // ONLY the boarding column. The old "info contains 'stazione'" fallback
                // is gone: it read the wrong cell, and on the real page "IN STAZIONE"
                // appears only in the page-level notice banner, outside the table.
                isDeparting: isBoardingCell(cell(boardingCellIndex))
            )
        }
    }

    // MARK: - Helpers

    private static func imgAltOrText(_ cellHTML: String) -> String? {
        // alt/title run through `clean` so HTML entities (e.g. &#39;) are decoded too.
        if let alt = firstGroup(in: cellHTML, pattern: "alt=\"([^\"]*)\""), let c = clean(alt) { return c }
        if let title = firstGroup(in: cellHTML, pattern: "title=\"([^\"]*)\""), let c = clean(title) { return c }
        return clean(cellHTML)
    }

    /// Strip tags, decode HTML entities, collapse whitespace; nil if empty.
    static func clean(_ s: String) -> String? {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        t = HTMLEntityDecoder.decode(t)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    private static func firstGroup(in s: String, pattern: String) -> String? {
        guard let re = regex(pattern) else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    private static func allGroups(in s: String, pattern: String) -> [String] {
        guard let re = regex(pattern) else { return [] }
        let range = NSRange(s.startIndex..., in: s)
        return re.matches(in: s, range: range).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
            return String(s[r])
        }
    }

    private static func substring(_ s: String, between open: String, and close: String) -> String? {
        guard let openRange = s.range(of: open, options: .caseInsensitive),
              let gt = s.range(of: ">", range: openRange.upperBound..<s.endIndex),
              let closeRange = s.range(of: close, options: .caseInsensitive, range: gt.upperBound..<s.endIndex)
        else { return nil }
        return String(s[gt.upperBound..<closeRange.lowerBound])
    }
}
#endif
