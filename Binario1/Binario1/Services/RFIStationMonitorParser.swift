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
//  names); station name / updated-at use light markers. These were tuned against a
//  representative fixture (Binario1Tests/Fixtures) and will need verification
//  against the live page — that verification is exactly the point of this spike.
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

    static func rows(in html: String) -> [RFIMonitorRow] {
        let scope = substring(html, between: "<tbody", and: "</tbody>") ?? html
        // Capture the WHOLE <tr …>…</tr> element, opening tag included: RFI marks a
        // boarding train with a blinking CSS class on the <tr> itself, so a pattern
        // that captured only the inner cells could never see it (`isDeparting` from
        // "lampeggi" was dead code — every row fell back to onTime/delayed).
        return allGroups(in: scope, pattern: "(<tr[^>]*>.*?</tr>)").compactMap { row in
            guard !row.localizedCaseInsensitiveContains("<th") else { return nil }  // header row
            let isDeparting = row.localizedCaseInsensitiveContains("lampeggi")
            let cells = allGroups(in: row, pattern: "<td[^>]*>(.*?)</td>")
            guard cells.count >= 5 else { return nil }
            func text(_ i: Int) -> String? { i < cells.count ? clean(cells[i]) : nil }

            let info = text(7)
            return RFIMonitorRow(
                operatorName: imgAltOrText(cells.indices.contains(0) ? cells[0] : ""),
                category: imgAltOrText(cells.indices.contains(1) ? cells[1] : ""),
                trainNumber: text(2),
                destination: text(3),
                time: text(4),
                delay: text(5),
                platform: text(6),
                info: info,
                isDeparting: isDeparting || (info?.localizedCaseInsensitiveContains("stazione") ?? false)
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
