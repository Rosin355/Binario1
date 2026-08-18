//
//  BoardTextFitting.swift
//  Binario1
//
//  Board text-fitting policy. The board ROWS abbreviate long names to keep the
//  rigid grid aligned (`BoardDestinationFormatter`); the HEADER title never does
//  (`StationTitleLayout`, which wraps and scales instead). The FULL, untruncated
//  name always stays in the data model and is what accessibility labels read.
//

import Foundation
import UIKit

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

/// Layout policy for the LED station title in the board header.
///
/// The header shows the **full** station name — see `docs/12_DECISIONS.md`
/// ("nomi stazione completi sempre disponibili … l'abbreviazione è solo per il
/// display compatto del tabellone"). Nothing here abbreviates or ellipsizes:
/// `BoardDestinationFormatter` stays for the board ROWS.
///
/// Fitting order, in this order and no other:
///   1. **wrap onto more lines at full font size** (a long qualifier takes a second
///      line rather than shrinking the whole title);
///   2. **scale the whole title down**, one shared scale, never below `minScale`;
///   3. only then could a glyph be cut — which for every name in the bundled catalog,
///      at the widths an iPhone header offers, never happens (asserted in tests).
///
/// One shared scale (not per line) so the primary line can never end up *smaller*
/// than the secondary one, which independent scaling would allow at 34 vs 22 pt.
enum StationTitleLayout {

    struct Layout: Equatable {
        /// City line, full — never abbreviated, never ellipsized.
        let primary: String
        /// Qualifier lines, word-wrapped. Empty for a single-word station.
        let secondary: [String]
        /// Shared scale applied to both base sizes, in `[minScale, 1]`.
        let scale: CGFloat

        var lines: [String] { primary.isEmpty ? secondary : [primary] + secondary }
        /// Glyphs actually drawn (spaces at line breaks are dropped by the wrap).
        var totalGlyphs: Int { lines.reduce(0) { $0 + $1.count } }
    }

    /// Never shrink past this fraction of the base size; wrapping happens first and
    /// truncation is what we refuse to reach.
    static let minScale: CGFloat = 0.6
    /// Horizontal gap between glyph cells in the title's `HStack`.
    static let glyphSpacing: CGFloat = 1
    /// Longest qualifier wrap before the scale step takes over (bounds header height).
    static let maxSecondaryLines = 3

    /// Advance width of one glyph ÷ font size, MEASURED for the title font
    /// (`.system(size:weight:.heavy, design:.monospaced)` → `monospacedSystemFont`).
    /// A monospaced face has a uniform advance, so one probe glyph is enough.
    static let glyphAdvanceRatio: CGFloat = {
        let probe: CGFloat = 100
        let font = UIFont.monospacedSystemFont(ofSize: probe, weight: .heavy)
        let measured = ("M" as NSString).size(withAttributes: [.font: font]).width / probe
        return measured > 0 ? measured : 0.6      // fallback keeps the layout sane
    }()

    /// Multi-word city names that must stay whole on the primary line, so the split
    /// never reads "REGGIO / EMILIA AV MEDIOPADANA" or "TERME / EUGANEE-ABANO-…".
    /// Split knowledge only — no abbreviation (that is `BoardDestinationFormatter`'s
    /// job, for the rows). Longest first: a longer compound must win over a shorter
    /// one that happens to prefix it.
    private static let compoundCities = [
        "TERME EUGANEE", "REGGIO EMILIA", "REGGIO CALABRIA", "FORLI CESENA",
    ].sorted { $0.count > $1.count }

    /// Separators a station name uses between its parts. The hyphen matters:
    /// "TERME EUGANEE-ABANO-MONTEGROTTO" has NO space after the compound city, so a
    /// space-only boundary check would miss it and split the compound in half.
    private static let partSeparators: Set<Character> = [" ", "-"]

    /// The compound city `upper` starts with, plus what follows it — but only when the
    /// compound ends on a real boundary (end of name, space or hyphen), never mid-word.
    private static func compoundPrefix(of upper: String) -> (city: String, rest: String)? {
        for city in compoundCities where upper.hasPrefix(city) {
            let rest = upper.dropFirst(city.count)
            guard let separator = rest.first else { return (city, "") }   // exact match
            guard partSeparators.contains(separator) else { continue }    // mid-word → not it
            return (city, String(rest.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Full name → (city line, qualifier). Uppercased, never shortened.
    static func split(_ fullName: String) -> (city: String, qualifier: String) {
        let upper = fullName.trimmingCharacters(in: .whitespaces).uppercased()
        guard !upper.isEmpty else { return ("", "") }
        if let match = compoundPrefix(of: upper) { return (match.city, match.rest) }
        let words = upper.split(separator: " ").map(String.init)
        return (words.first ?? upper, words.dropFirst().joined(separator: " "))
    }

    /// Width one line of `text` occupies at `size`.
    static func width(_ text: String, size: CGFloat) -> CGFloat {
        let n = CGFloat(text.count)
        guard n > 0 else { return 0 }
        return n * size * glyphAdvanceRatio + (n - 1) * glyphSpacing
    }

    /// Largest font size at which `text` fits `available` on one line. Solved exactly:
    /// the inter-glyph spacing is CONSTANT and does not scale with the font, so a naive
    /// `available / width(text, base)` ratio overshoots and still overflows.
    ///   available = n·size·ratio + (n-1)·spacing  →  size = (available - (n-1)·spacing) / (n·ratio)
    static func fittingSize(_ text: String, available: CGFloat) -> CGFloat {
        let n = CGFloat(text.count)
        guard n > 0 else { return .greatestFiniteMagnitude }
        let usable = available - (n - 1) * glyphSpacing
        guard usable > 0 else { return 0 }
        return usable / (n * glyphAdvanceRatio)
    }

    /// Greedy word wrap at FULL size — step 1, before any scaling. Past
    /// `maxSecondaryLines` the remaining words keep filling the last line and the
    /// scale step absorbs the overflow.
    static func wrap(_ text: String, size: CGFloat, available: CGFloat,
                     maxLines: Int = maxSecondaryLines) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        guard available > 0 else { return [words.joined(separator: " ")] }
        var lines: [String] = []
        for word in words {
            guard let current = lines.last else { lines.append(word); continue }
            let merged = current + " " + word
            if width(merged, size: size) <= available || lines.count >= maxLines {
                lines[lines.count - 1] = merged
            } else {
                lines.append(word)
            }
        }
        return lines
    }

    /// Full layout for `fullName` in `available` points. `available <= 0` (first
    /// render, before geometry is known) → natural split at full size.
    static func layout(fullName: String, available: CGFloat,
                       primaryBase: CGFloat, secondaryBase: CGFloat) -> Layout {
        let (city, qualifier) = split(fullName)
        let secondary = wrap(qualifier, size: secondaryBase, available: available)
        guard available > 0 else { return Layout(primary: city, secondary: secondary, scale: 1) }

        var scale: CGFloat = 1
        if !city.isEmpty {
            scale = min(scale, fittingSize(city, available: available) / primaryBase)
        }
        for line in secondary {
            scale = min(scale, fittingSize(line, available: available) / secondaryBase)
        }
        return Layout(primary: city, secondary: secondary, scale: min(1, max(minScale, scale)))
    }

    /// True when the title would STILL overflow at the minimum scale — i.e. the point
    /// where glyphs start being cut. Used by tests to pin that no catalog name reaches
    /// it at realistic header widths.
    static func overflowsAtMinScale(fullName: String, available: CGFloat,
                                    primaryBase: CGFloat, secondaryBase: CGFloat) -> Bool {
        let l = layout(fullName: fullName, available: available,
                       primaryBase: primaryBase, secondaryBase: secondaryBase)
        guard available > 0 else { return false }
        if width(l.primary, size: primaryBase * l.scale) > available + 0.5 { return true }
        return l.secondary.contains { width($0, size: secondaryBase * l.scale) > available + 0.5 }
    }
}
