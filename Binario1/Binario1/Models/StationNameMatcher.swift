//
//  StationNameMatcher.swift
//  Binario1
//
//  Lightweight MVP matcher between free-text station names — used to line up a
//  saved journey (from Viaggi) against a live board row's destination. NOT a route
//  planner: it only canonicalizes a name (uppercase, diacritic-fold, drop
//  punctuation, expand a few common Italian abbreviations) and compares.
//

import Foundation

enum StationNameMatcher {

    /// Canonical form: uppercased, diacritic-folded, punctuation → space, common
    /// abbreviations expanded ("S." → SANTA, "C.LE" → CENTRALE, "P.NUOVA" → PORTA
    /// NUOVA). Stable enough to compare "VENEZIA S.LUCIA" with "Venezia Santa Lucia".
    static func canonical(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: nil).uppercased()
        // Map anything that isn't a letter/number to a space.
        var t = String(folded.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
        t = collapseSpaces(t)
        // Pad so the replacements below hit whole, space-delimited tokens only.
        t = " " + t + " "
        let expansions: [(String, String)] = [
            (" S ", " SANTA "),
            (" SS ", " SANTI "),
            (" C LE ", " CENTRALE "),
            (" CLE ", " CENTRALE "),
            (" CENT ", " CENTRALE "),
            (" P NUOVA ", " PORTA NUOVA "),
            (" PTA ", " PORTA "),
            (" P TA ", " PORTA "),
        ]
        for (from, to) in expansions { t = t.replacingOccurrences(of: from, with: to) }
        return collapseSpaces(t).trimmingCharacters(in: .whitespaces)
    }

    /// True when two station names refer to the same place. Exact canonical equality,
    /// or one canonical token set is a subset of the other **only when the smaller
    /// name has ≥ 2 tokens**. The ≥2-token rule prevents a single shared generic
    /// token (e.g. "Centrale") or a bare city prefix (e.g. "Venezia") from matching
    /// two genuinely different stations — Venezia Mestre vs Venezia Santa Lucia, or
    /// Milano Centrale vs Milano Porta Garibaldi — do NOT match.
    static func matches(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        let ca = canonical(a), cb = canonical(b)
        guard !ca.isEmpty, !cb.isEmpty else { return false }
        if ca == cb { return true }
        let ta = Set(ca.split(separator: " ")), tb = Set(cb.split(separator: " "))
        guard min(ta.count, tb.count) >= 2 else { return false }
        return ta.isSubset(of: tb) || tb.isSubset(of: ta)
    }

    private static func collapseSpaces(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t
    }
}
