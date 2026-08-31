//
//  StationCatalog.swift
//  Binario1
//
//  The real (not mock) station catalog. Built from TWO files, with distinct jobs:
//
//    • `rfi-stations.tsv`  — the SHARED ARTIFACT: RFI's own PlaceId list, the single
//      source of station ids and official names, shared byte-for-byte with the
//      backend registry (see `StationsArtifact`);
//    • `stations.json`     — a CURATED OVERLAY adding only what RFI's list does not
//      carry: city, verified provider codes, `boardAliases`, `searchAliases`.
//
//  Backs Cerca so search returns canonical Station ENTITIES: choosing a station
//  saves its canonical displayName, which the B4 resolver / Home spotlight then
//  match against the live board row through the shared StationNameMatcher.
//
//  Names are public facts; provider codes are NOT fabricated (only carried where a
//  verified value already existed — null otherwise).
//
//  At national scale both lookups are INDEXED at init. They were O(catalog) scans
//  recomputing a fold/canonical form per entry per call: search ran that on every
//  keystroke, and `station(named:)` runs once per board row, so a 40-row board cost
//  ~100k canonicalizations per refresh.
//

import Foundation

/// Curated metadata merged over an artifact entry. Deliberately NOT a `Station`:
/// ids and official names come from the artifact, so an overlay cannot rename or
/// invent a station — only annotate one.
struct StationOverlay: Decodable, Equatable {
    let id: String
    var city: String?
    var providerCodes: ProviderCodes?
    var boardAliases: [String]?
    var searchAliases: [String]?
}

protocol StationCatalog: Sendable {
    /// All catalog stations (stored order), operational points included. This is the
    /// complete catalog — use `searchable` for anything the user picks from.
    var all: [Station] { get }
    /// The stations a USER may pick: `all` minus the operational points. Search, the
    /// idle list and the picker all read this, so a posto di movimento can never be
    /// opened as a board. `station(named:)` still resolves the excluded ones, so a
    /// name persisted or printed anywhere keeps mapping to its entity.
    var searchable: [Station] { get }
    /// Stations SERVED by the live board backend (their `id` is a slug in the backend
    /// registry). Derived from the catalog's `servedByLiveBoard` flag — the list is
    /// never duplicated in code. Any other station must not attempt a live fetch
    /// (honest unavailable state instead).
    var liveServed: [Station] { get }
    /// Ranked search by display name (prefix > token-prefix > substring) then city.
    /// Empty query → `searchable`. Diacritic/case-insensitive; no abbreviation expansion so
    /// a single letter doesn't expand (e.g. "s" ≠ "SANTA"). Operational points are
    /// never returned (see `Station.operationalPoint`).
    func search(_ query: String, limit: Int) -> [Station]
    /// Canonical lookup: the station whose displayName OR a board/search alias
    /// canonicalizes equal to `name` (via StationNameMatcher). Nil when the name isn't a known
    /// station (e.g. a bare "Roma" that must be disambiguated to "Roma Termini").
    func station(named name: String) -> Station?
    /// Whether the live board backend serves this station id (registry slug).
    func servesLiveBoard(stationID: String) -> Bool
}

extension StationCatalog {
    func search(_ query: String) -> [Station] { search(query, limit: 20) }
    /// Default derivation: the catalog minus the operational points.
    var searchable: [Station] { all.filter { !$0.isOperationalPoint } }
    /// Default derivation: filter the catalog by the `servedByLiveBoard` flag.
    var liveServed: [Station] { all.filter(\.isServedByLiveBoard) }
    func servesLiveBoard(stationID: String) -> Bool {
        liveServed.contains { $0.id == stationID }
    }
}

final class DefaultStationCatalog: StationCatalog, @unchecked Sendable {
    /// Shared instance backed by the bundled artifact + overlay.
    static let shared = DefaultStationCatalog()

    let all: [Station]
    let searchable: [Station]
    let liveServed: [Station]

    /// One prepared row per searchable station: the folds are computed ONCE here
    /// instead of per keystroke per station.
    private struct SearchEntry {
        let station: Station
        let name: String
        let aliases: [String]
        let city: String
    }
    private let searchIndex: [SearchEntry]

    /// Canonical form → station, covering official names first and aliases second, so
    /// an official name always wins a key an alias would also claim.
    private let canonicalIndex: [String: Station]
    private let liveServedIDs: Set<String>

    init(bundle: Bundle = .main,
         artifactName: String = "rfi-stations",
         overlayName: String = "stations") {
        let base = StationsArtifact.loadBundled(bundle: bundle, resourceName: artifactName)
            ?? Self.embeddedFallback
        let overlays = Self.loadOverlays(bundle: bundle, resourceName: overlayName)
        all = Self.merge(base: base, overlays: overlays)
        (searchable, liveServed, liveServedIDs, searchIndex, canonicalIndex) = Self.buildIndices(all)
    }

    /// Test/preview seam: build a catalog from an explicit list.
    init(stations: [Station]) {
        all = stations
        (searchable, liveServed, liveServedIDs, searchIndex, canonicalIndex) = Self.buildIndices(stations)
    }

    // MARK: - Loading

    private static func loadOverlays(bundle: Bundle, resourceName: String) -> [StationOverlay] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([StationOverlay].self, from: data) else {
            return []      // catalog still works, just without the curated metadata
        }
        return decoded
    }

    /// Apply the curated overlay onto the artifact entries, by id. An overlay whose id
    /// is not in the artifact is IGNORED here (a test fails on it instead): it cannot
    /// introduce a station, because ids and names belong to the artifact alone.
    static func merge(base: [Station], overlays: [StationOverlay]) -> [Station] {
        let byID = Dictionary(overlays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return base.map { station in
            guard let overlay = byID[station.id] else { return station }
            var merged = station
            merged.city = overlay.city
            merged.providerCodes = overlay.providerCodes
            merged.boardAliases = overlay.boardAliases
            merged.searchAliases = overlay.searchAliases
            return merged
        }
    }

    /// Minimal fallback used only if the bundled artifact is missing/corrupt.
    /// Never an empty catalog, and never fabricated entries.
    static let embeddedFallback: [Station] = [
        .padova, .bolognaCentrale, .firenzeSMN, .milanoPortaGaribaldi,
        .veneziaSLucia, .reggioEmiliaAV,
    ]

    // MARK: - Indices

    private static func buildIndices(
        _ stations: [Station]
    ) -> ([Station], [Station], Set<String>, [SearchEntry], [String: Station]) {
        let searchable = stations.filter { !$0.isOperationalPoint }
        let served = stations.filter(\.isServedByLiveBoard)

        let index = searchable.map { station in
            SearchEntry(
                station: station,
                name: fold(station.displayName),
                aliases: (station.searchAliases ?? []).map(fold),
                city: station.city.map(fold) ?? ""
            )
        }

        // Two passes so an OFFICIAL name always owns its canonical key: an alias may
        // only claim a key no official name has taken. Without this, load order would
        // decide whether a name resolves to its own station or to whichever station
        // happens to list it as an alias.
        var canonical: [String: Station] = [:]
        for station in stations {
            let key = StationNameMatcher.canonical(station.displayName)
            if !key.isEmpty, canonical[key] == nil { canonical[key] = station }
        }
        for station in stations {
            for alias in (station.boardAliases ?? []) + (station.searchAliases ?? []) {
                let key = StationNameMatcher.canonical(alias)
                if !key.isEmpty, canonical[key] == nil { canonical[key] = station }
            }
        }

        return (searchable, served, Set(served.map(\.id)), index, canonical)
    }

    // MARK: - Search

    func search(_ query: String, limit: Int = 20) -> [Station] {
        let q = Self.fold(query)
        guard !q.isEmpty else { return searchable }
        let ranked = searchIndex.compactMap { entry -> (station: Station, rank: Int)? in
            guard let r = Self.rank(entry, query: q) else { return nil }
            return (entry.station, r)
        }
        return ranked
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.station.displayName < $1.station.displayName }
            .prefix(limit)
            .map(\.station)
    }

    /// Operational points are absent from `searchIndex` entirely: opening a board for a
    /// posto di movimento would promise a timetable that does not exist. They stay in
    /// the catalog and `station(named:)` still resolves them, so a name keeps mapping
    /// to an entity — see `Station.operationalPoint`.
    private static func rank(_ entry: SearchEntry, query q: String) -> Int? {
        // A `searchAliases` hit ranks exactly like a displayName hit — "montegrotto"
        // must find "TERME EUGANEE-ABANO-MONTEGROTTO" as readily as its official name.
        // Best (lowest) rank across the official name and every alias wins.
        var best = nameRank(entry.name, q)
        for alias in entry.aliases {
            if let r = nameRank(alias, q) { best = min(best ?? r, r) }
        }
        if let best { return best }
        if !entry.city.isEmpty, entry.city.contains(q) { return 4 }
        return nil
    }

    /// Rank of a query against ONE name form (official or alias). Nil = no match.
    private static func nameRank(_ name: String, _ q: String) -> Int? {
        if name == q { return 0 }
        if name.hasPrefix(q) { return 1 }
        if name.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 2 }
        if name.contains(q) { return 3 }
        return nil
    }

    // MARK: - Canonical lookup

    func station(named name: String) -> Station? {
        let target = StationNameMatcher.canonical(name)
        guard !target.isEmpty else { return nil }
        return canonicalIndex[target]
    }

    func servesLiveBoard(stationID: String) -> Bool { liveServedIDs.contains(stationID) }

    // MARK: - Folding (light: uppercase + diacritic-fold + punctuation→space)

    static func fold(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: nil).uppercased()
        var t = String(folded.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
