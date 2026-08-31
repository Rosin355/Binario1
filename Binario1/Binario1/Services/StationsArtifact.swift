//
//  StationsArtifact.swift
//  Binario1
//
//  Reads the SHARED station artifact (`rfi-stations.tsv`) — RFI's own `PlaceId`
//  list, the single source both iOS and the backend build their catalog/registry
//  from. The backend keeps a byte-identical copy in
//  `supabase/functions/board/rfi_stations_tsv.ts`; a backend test asserts the two
//  never drift.
//
//  The artifact is a DATED SNAPSHOT, not a perpetual truth: RFI opens and closes
//  stations, so the entry count moves between extractions. Nothing here — and no
//  test — may assert the count. Regenerate with
//  `node tools/generate-rfi-stations-tsv.mjs`; never hand-edit.
//
//  Station NAMES are RFI's, verbatim and UPPERCASE, exactly as the authoritative
//  list writes them. Title-casing 2400+ Italian names would mean inventing a
//  spelling RFI never wrote (233 carry particles like DI/DEL/DELLA, 232 carry
//  dotted abbreviations, 47 use an apostrophe where Italian wants an accent), and
//  the naming policy in docs/12_DECISIONS.md forbids invented names.
//

import Foundation

enum StationsArtifact {

    /// One parsed line of the artifact.
    struct Entry: Equatable {
        let placeId: String
        /// RFI's official name, verbatim (uppercase).
        let name: String
    }

    // MARK: - Slug

    /// Station name → catalog id, which MUST equal the backend registry slug or the
    /// live fetch 404s (`unknown_station`). This mirrors `stationSlug` in
    /// `supabase/functions/board/registry.ts` character for character.
    ///
    /// Deliberately plain — lowercase, each run of non-alphanumerics becomes one
    /// hyphen, no leading/trailing hyphen — and it reproduces the slugs that were
    /// hand-written before national coverage with no special case.
    static func slug(for name: String) -> String {
        let lowered = name.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        var out = ""
        var pendingHyphen = false
        for character in lowered {
            if character.isASCII && (character.isLetter || character.isNumber) {
                if pendingHyphen && !out.isEmpty { out.append("-") }
                pendingHyphen = false
                out.append(character)
            } else {
                pendingHyphen = true
            }
        }
        return out
    }

    // MARK: - Operational points

    /// Prefixes/suffixes RFI uses for OPERATIONAL POINTS — places on the network that
    /// are not passenger stations: `PM …` (posto di movimento), `PC …` (posto di
    /// comunicazione), `BIVIO …`, and the `… PES` suffix.
    ///
    /// The classification is OURS, not RFI's, so it lives in code rather than being
    /// baked into the copy of RFI's list — the artifact stays a faithful projection of
    /// the source. A test pins the entries it selects, so a change in the rule (or in
    /// the list) has to be looked at rather than absorbed.
    private static let operationalPrefixes = ["PM ", "PC ", "BIVIO "]
    private static let operationalSuffix = " PES"

    static func isOperationalPoint(name: String) -> Bool {
        operationalPrefixes.contains { name.hasPrefix($0) } || name.hasSuffix(operationalSuffix)
    }

    // MARK: - Parsing

    enum ArtifactError: Error, CustomStringConvertible {
        case malformedLine(number: Int, content: String)
        case emptySlug(number: Int, name: String)
        case duplicateSlug(number: Int, slug: String)
        case empty

        var description: String {
            switch self {
            case let .malformedLine(number, content):
                "rfi-stations.tsv line \(number): expected \"placeId<TAB>name\", got \"\(content)\""
            case let .emptySlug(number, name):
                "rfi-stations.tsv line \(number): name \"\(name)\" yields an empty slug"
            case let .duplicateSlug(number, slug):
                "rfi-stations.tsv line \(number): slug \"\(slug)\" collides with an earlier station"
            case .empty:
                "rfi-stations.tsv contains no station rows"
            }
        }
    }

    /// Parse the artifact. `#` comments and blank lines are skipped; every other line
    /// must be `placeId<TAB>name`. Throws rather than returning a partial catalog: a
    /// slug collision would silently drop a station, which is the one failure this
    /// artifact cannot have.
    static func parse(_ text: String) throws -> [Entry] {
        var entries: [Entry] = []
        var seen = Set<String>()
        var number = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            number += 1
            if line.isEmpty || line.hasPrefix("#") { continue }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count == 2, !columns[0].isEmpty, !columns[1].isEmpty else {
                throw ArtifactError.malformedLine(number: number, content: String(line))
            }
            let name = String(columns[1])
            let id = slug(for: name)
            guard !id.isEmpty else { throw ArtifactError.emptySlug(number: number, name: name) }
            guard seen.insert(id).inserted else {
                throw ArtifactError.duplicateSlug(number: number, slug: id)
            }
            entries.append(Entry(placeId: String(columns[0]), name: name))
        }
        guard !entries.isEmpty else { throw ArtifactError.empty }
        return entries
    }

    /// Base catalog stations, before the curated overlay is applied.
    ///
    /// `servedByLiveBoard` is TRUE for every entry: the backend registry is built from
    /// this same artifact, so presence here *is* presence in the registry. It stays a
    /// stored flag rather than an assumption so a future partial rollout can turn it
    /// off per station without touching call sites.
    static func stations(from entries: [Entry]) -> [Station] {
        entries.map { entry in
            Station(
                id: slug(for: entry.name),
                name: entry.name,
                city: nil,
                displayName: entry.name,
                countryCode: "IT",
                timezone: "Europe/Rome",
                providerCodes: nil,
                servedByLiveBoard: true,
                operationalPoint: isOperationalPoint(name: entry.name) ? true : nil
            )
        }
    }

    /// Load and parse the bundled artifact. Nil when it is missing or unreadable —
    /// the caller falls back rather than shipping an empty catalog.
    static func loadBundled(bundle: Bundle = .main, resourceName: String = "rfi-stations") -> [Station]? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let entries = try? parse(text) else { return nil }
        return stations(from: entries)
    }
}
