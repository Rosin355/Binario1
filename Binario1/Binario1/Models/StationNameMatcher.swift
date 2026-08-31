//
//  StationNameMatcher.swift
//  Binario1
//
//  Lightweight MVP matcher between free-text station names — used to line up a
//  saved journey (from Viaggi) against a live board row's destination. NOT a route
//  planner: it only canonicalizes a name (uppercase, diacritic-fold, drop
//  punctuation, expand a few common Italian abbreviations) and compares.
//
//  C4: the comparison is CANONICAL EQUALITY, never a token-subset test. Adding a
//  token means a DIFFERENT station — see docs/12_DECISIONS.md.
//

import Foundation

enum StationNameMatcher {

    /// Expansions that span a SPACE, so they must run on the padded string before the
    /// token pass ("C LE" is two tokens that become one).
    private static let multiTokenExpansions: [(String, String)] = [
        (" C LE ", " CENTRALE "),
        (" P NUOVA ", " PORTA NUOVA "),
        (" P TA ", " PORTA "),
    ]

    /// Single-token expansions, applied token-wise.
    ///
    /// Every saint form collapses to the NEUTRAL token "S". RFI writes "S." for both
    /// genders (231 of the official names in the 2026-08-31 snapshot), so expanding it
    /// to "SANTA" guessed a
    /// gender and guessed wrong on the masculine majority ("S.GIOVANNI" is *San*
    /// Giovanni) — and, worse, it made the 4 names RFI spells out in full ("SAN
    /// PAOLO") fail to match their own abbreviated form. Collapsing instead of
    /// guessing makes "SAN GIOVANNI", "S.GIOVANNI" and "SANTO GIOVANNI" one name and
    /// asserts nothing about gender.
    private static let tokenExpansions: [String: String] = [
        "S": "S", "SS": "S", "SAN": "S", "SANT": "S",
        "SANTA": "S", "SANTO": "S", "SANTI": "S",
        "CLE": "CENTRALE", "CENT": "CENTRALE", "PTA": "PORTA",
    ]

    /// Canonical form: uppercased, diacritic-folded, punctuation → space, common
    /// abbreviations expanded ("S." → S, "C.LE" → CENTRALE, "P.NUOVA" → PORTA NUOVA).
    /// Stable enough to compare "VENEZIA S.LUCIA" with "Venezia Santa Lucia".
    static func canonical(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: nil).uppercased()
        // Map anything that isn't a letter/number to a space.
        var t = String(folded.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
        // Pad so the multi-token replacements below hit whole, space-delimited tokens.
        t = " " + collapseSpaces(t) + " "
        for (from, to) in multiTokenExpansions { t = t.replacingOccurrences(of: from, with: to) }
        // Token-wise, NOT `replacingOccurrences`: a padded string replacement consumes
        // the space shared by two adjacent tokens, so the second one would be skipped
        // ("SS SANTA X" would leave the SANTA behind).
        return t.split(separator: " ").map { tokenExpansions[String($0)] ?? String($0) }
            .joined(separator: " ")
    }

    /// True when two station names refer to the same place: **canonical equality**.
    ///
    /// There is deliberately no subset rule. A name that adds tokens is a DIFFERENT
    /// station — "REGGIO EMILIA" is not "REGGIO EMILIA AV MEDIOPADANA", "GENOVA PIAZZA
    /// PRINCIPE" is not the SOTTERRANEA one, "BOLOGNA CENTRALE" is not "BOLOGNA
    /// C.LE/AV". The old ≥2-token subset test collided 53 real pairs of the RFI
    /// station list, 8 of them on stations already shipped. The bridge between the
    /// form a board PRINTS and the official name is the abbreviation expansion above
    /// plus explicit `boardAliases` — never a permissive match.
    static func matches(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        let ca = canonical(a), cb = canonical(b)
        guard !ca.isEmpty, !cb.isEmpty else { return false }
        return ca == cb
    }

    /// Alias-aware match between a catalog `station` and a free-text board name.
    /// True when the board name equals the station's displayName OR any of its
    /// `boardAliases` (e.g. "Venezia S.L." → Venezia S.Lucia), each compared through
    /// `matches(_:_:)`, so an alias can only ADD matches.
    ///
    /// An OPERATIONAL POINT never matches: a posto di movimento / posto di
    /// comunicazione is not a terminus, so it is never printed in a board's
    /// destination column. Without this guard "NAPOLI AFRAGOLA PES" would be a
    /// candidate answer for a board row reading "NAPOLI AFRAGOLA".
    static func matches(station: Station, boardName: String?) -> Bool {
        guard !station.isOperationalPoint else { return false }
        if matches(station.displayName, boardName) { return true }
        for alias in station.boardAliases ?? [] where matches(alias, boardName) { return true }
        return false
    }

    private static func collapseSpaces(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t
    }
}
