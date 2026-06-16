//
//  RFITrainCategoryNormalizer.swift
//  Binario1
//
//  DEBUG-ONLY. Source-specific normalization for the RFI live monitor:
//   • `HTMLEntityDecoder` — decodes the small set of entities RFI labels use
//     (numeric `&#39;`/`&#224;` and a few named), kept isolated/testable.
//   • `RFITrainCategoryNormalizer` — turns verbose RFI category labels
//     ("Categoria Alta Velocita&#39;") into the app's compact board codes ("AV").
//
//  The UI must never receive raw source category strings — this runs in the
//  parser/mapper layer, never in views.
//

#if DEBUG
import Foundation

enum HTMLEntityDecoder {
    private static let named: [String: String] = [
        "&amp;": "&", "&apos;": "'", "&quot;": "\"", "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
        "&agrave;": "à", "&egrave;": "è", "&eacute;": "é", "&igrave;": "ì",
        "&ograve;": "ò", "&ugrave;": "ù",
        "&Agrave;": "À", "&Egrave;": "È", "&Igrave;": "Ì", "&Ograve;": "Ò", "&Ugrave;": "Ù",
    ]

    /// Decode named + numeric (decimal/hex) HTML entities. Safe for short labels.
    static func decode(_ input: String) -> String {
        guard input.contains("&") else { return input }
        var s = input
        for (k, v) in named { s = s.replacingOccurrences(of: k, with: v) }
        s = decodeNumeric(s, pattern: "&#([0-9]+);", radix: 10)
        s = decodeNumeric(s, pattern: "&#[xX]([0-9a-fA-F]+);", radix: 16)
        return s
    }

    private static func decodeNumeric(_ s: String, pattern: String, radix: Int) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        let matches = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return s }
        var result = ""
        var last = 0
        for m in matches {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let code = ns.substring(with: m.range(at: 1))
            if let value = UInt32(code, radix: radix), let scalar = Unicode.Scalar(value) {
                result.append(Character(scalar))
            } else {
                result += ns.substring(with: m.range)
            }
            last = m.range.location + m.range.length
        }
        result += ns.substring(with: NSRange(location: last, length: ns.length - last))
        return result
    }
}

enum RFITrainCategoryNormalizer {

    /// Verbose / coded RFI category label → compact board code. Unknown long
    /// labels collapse to "UNK"; never returns "Categoria …" or raw entities.
    static func normalize(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "UNK" }

        // 1–3. Decode entities, normalize the right-single-quote, collapse spaces.
        var s = HTMLEntityDecoder.decode(raw)
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
             .trimmingCharacters(in: .whitespaces)

        // 4. Strip a leading "Categoria" (any case).
        if let r = s.range(of: "^categoria\\b\\s*", options: [.regularExpression, .caseInsensitive]) {
            s = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        guard !s.isEmpty else { return "UNK" }

        // 5–6. Map known labels (accent/apostrophe/case-insensitive key).
        if let code = map[foldKey(s)] { return code }

        // Unknown: keep only if it's already a short safe code.
        let upper = s.uppercased()
        if upper.count <= 4, upper.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil {
            return upper
        }
        return "UNK"
    }

    /// Lowercased, diacritic-folded, apostrophe-stripped key for map lookup.
    private static func foldKey(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it"))
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static let map: [String: String] = [
        // Verbose labels
        "regionale": "REG", "regionale veloce": "RV",
        "alta velocita": "AV",
        "frecciarossa": "FR", "frecciargento": "FA", "frecciabianca": "FB",
        "intercity": "IC", "intercity notte": "ICN",
        "italo": "ITA", "eurocity": "EC", "euronight": "EN",
        // Codes already provided by the source
        "reg": "REG", "rv": "RV", "av": "AV", "fr": "FR", "fa": "FA", "fb": "FB",
        "ic": "IC", "icn": "ICN", "ita": "ITA", "ec": "EC", "en": "EN",
    ]
}
#endif
