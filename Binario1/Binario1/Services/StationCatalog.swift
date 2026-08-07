//
//  StationCatalog.swift
//  Binario1
//
//  Real (not mock) station catalog loaded once from the bundled `stations.json`.
//  Backs Cerca so search returns canonical Station ENTITIES: choosing "Roma Termini"
//  saves the canonical displayName, which the B4 resolver / Home spotlight then match
//  against the live board row "ROMA TERMINI" through the shared StationNameMatcher.
//
//  Names are public facts; provider codes are NOT fabricated (only carried where a
//  verified value already existed in code — null otherwise).
//

import Foundation

protocol StationCatalog: Sendable {
    /// All catalog stations (stored order).
    var all: [Station] { get }
    /// Stations SERVED by the live board backend (their `id` is a verified slug in the
    /// backend registry). Derived from the catalog's `servedByLiveBoard` flag — the
    /// list is never duplicated in code. Drives the live station picker; any other
    /// station must not attempt a live fetch (honest unavailable state instead).
    var liveServed: [Station] { get }
    /// Ranked search by display name (prefix > token-prefix > substring) then city.
    /// Empty query → `all`. Diacritic/case-insensitive; no abbreviation expansion so
    /// a single letter doesn't expand (e.g. "s" ≠ "SANTA").
    func search(_ query: String, limit: Int) -> [Station]
    /// Canonical lookup: the station whose displayName OR a board alias canonicalizes
    /// equal to `name` (via StationNameMatcher). Nil when the name isn't a known
    /// station (e.g. a bare "Roma" that must be disambiguated to "Roma Termini").
    func station(named name: String) -> Station?
}

extension StationCatalog {
    func search(_ query: String) -> [Station] { search(query, limit: 20) }
    /// Default derivation: filter the catalog by the `servedByLiveBoard` flag.
    var liveServed: [Station] { all.filter(\.isServedByLiveBoard) }
    /// Whether the live board backend serves this station id (registry slug).
    func servesLiveBoard(stationID: String) -> Bool {
        liveServed.contains { $0.id == stationID }
    }
}

final class DefaultStationCatalog: StationCatalog, @unchecked Sendable {
    /// Shared instance backed by the bundled `stations.json`.
    static let shared = DefaultStationCatalog()

    let all: [Station]

    init(bundle: Bundle = .main, resourceName: String = "stations") {
        all = Self.load(bundle: bundle, resourceName: resourceName)
    }

    /// Test/preview seam: build a catalog from an explicit list.
    init(stations: [Station]) {
        all = stations
    }

    private static func load(bundle: Bundle, resourceName: String) -> [Station] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Station].self, from: data),
              !decoded.isEmpty else {
            // Never ship an empty catalog: fall back to the stations already known in
            // code (verified metadata only). No fabricated entries.
            return Self.embeddedFallback
        }
        return decoded
    }

    /// Minimal fallback used only if the bundled JSON is missing/corrupt.
    static let embeddedFallback: [Station] = [
        .padova, .bolognaCentrale, .firenzeSMN, .milanoPortaGaribaldi,
        .veneziaSantaLucia, .reggioEmiliaAV,
    ]

    // MARK: - Search

    func search(_ query: String, limit: Int = 20) -> [Station] {
        let q = Self.fold(query)
        guard !q.isEmpty else { return all }
        let ranked = all.compactMap { station -> (station: Station, rank: Int)? in
            guard let r = Self.rank(station, query: q) else { return nil }
            return (station, r)
        }
        return ranked
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.station.displayName < $1.station.displayName }
            .prefix(limit)
            .map(\.station)
    }

    private static func rank(_ s: Station, query q: String) -> Int? {
        let name = fold(s.displayName)
        let city = s.city.map(fold) ?? ""
        if name == q { return 0 }
        if name.hasPrefix(q) { return 1 }
        if name.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 2 }
        if name.contains(q) { return 3 }
        if !city.isEmpty, city.contains(q) { return 4 }
        return nil
    }

    // MARK: - Canonical lookup

    func station(named name: String) -> Station? {
        let target = StationNameMatcher.canonical(name)
        guard !target.isEmpty else { return nil }
        return all.first { station in
            StationNameMatcher.canonical(station.displayName) == target
            || (station.boardAliases ?? []).contains { StationNameMatcher.canonical($0) == target }
        }
    }

    // MARK: - Folding (light: uppercase + diacritic-fold + punctuation→space)

    static func fold(_ s: String) -> String {
        let folded = s.folding(options: .diacriticInsensitive, locale: nil).uppercased()
        var t = String(folded.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
