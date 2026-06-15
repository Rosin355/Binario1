//
//  BoardTextFitting.swift
//  Binario1
//
//  Board text-fitting policy. Real station boards abbreviate long names to keep
//  the rigid grid aligned. These formatters produce compact display strings;
//  the FULL, untruncated name always stays available in the data model and is
//  what accessibility labels read.
//

import Foundation

/// Splits a full station name into the two LED title lines (primary / secondary),
/// keeping short qualifiers full ("CENTRALE") but abbreviating long ones so the
/// dot-matrix title never overflows the header.
enum StationNameFormatter {

    /// Multi-word city prefixes that should stay on the primary line.
    private static let compoundCities: [String: String] = [
        "REGGIO EMILIA": "REGGIO E.",
        "REGGIO CALABRIA": "REGGIO C.",
        "FORLI CESENA": "FORLÌ",
    ]

    static func boardTitle(for fullName: String) -> (primary: String, secondary: String) {
        let upper = fullName.trimmingCharacters(in: .whitespaces).uppercased()
        guard !upper.isEmpty else { return ("", "") }

        var primary = ""
        var rest = ""
        if let match = compoundCities.first(where: { upper.hasPrefix($0.key) }) {
            primary = match.value
            rest = String(upper.dropFirst(match.key.count)).trimmingCharacters(in: .whitespaces)
        } else {
            let words = upper.split(separator: " ").map(String.init)
            primary = words.first ?? upper
            rest = words.dropFirst().joined(separator: " ")
        }

        var secondary = rest
        if secondary.count > 9 { secondary = abbreviateQualifier(secondary) }
        return (cap(primary, 12), cap(secondary, 13))
    }

    private static func abbreviateQualifier(_ s: String) -> String {
        var r = s
        // Multi-word abbreviations first.
        r = r.replacingOccurrences(of: "SANTA MARIA NOVELLA", with: "S.M.N.")
        r = r.replacingOccurrences(of: "SANTA LUCIA", with: "S. LUCIA")
        // Then single words.
        let map: [String: String] = [
            "SANTA": "S.", "SANTO": "S.", "SAN": "S.",
            "PORTA": "P.", "CENTRALE": "C.LE", "MEDIOPADANA": "MEDIOP.",
        ]
        return r.split(separator: " ").map { map[String($0)] ?? String($0) }.joined(separator: " ")
    }

    private static func cap(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : String(s.prefix(max(0, n - 1))) + "…"
    }
}

/// Compact, board-style destination/origin text. Backend data is usually already
/// abbreviated (e.g. "VENEZIA S.L."); this is an idempotent safety net for full
/// names. The original value remains the accessibility source of truth.
enum BoardDestinationFormatter {
    static func display(_ name: String) -> String {
        var r = name.uppercased()
        r = r.replacingOccurrences(of: "SANTA MARIA NOVELLA", with: "S.M.N.")
        r = r.replacingOccurrences(of: "SANTA LUCIA", with: "S. LUCIA")
        let map: [String: String] = ["CENTRALE": "C.LE", "SANTA": "S.", "PORTA": "P."]
        return r.split(separator: " ").map { map[String($0)] ?? String($0) }.joined(separator: " ")
    }
}
