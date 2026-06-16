//
//  CercaViewModel.swift
//  Binario1
//
//  Drives the Cerca (Search) tab. MOCK-ONLY for now: a small in-memory catalog of
//  stations / routes / trains, filtered by the search query. No networking, no AI,
//  no persistence.
//

import Foundation
import Observation

@Observable
@MainActor
final class CercaViewModel {

    /// Bound to the native `.searchable` field.
    var query: String = ""

    let allStations: [String]
    let allRoutes: [String]
    let allTrains: [String]

    init(stations: [String] = CercaViewModel.mockStations,
         routes: [String] = CercaViewModel.mockRoutes,
         trains: [String] = CercaViewModel.mockTrains) {
        self.allStations = stations
        self.allRoutes = routes
        self.allTrains = trains
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isSearching: Bool { !trimmedQuery.isEmpty }

    var stations: [String] { matches(allStations) }
    var routes: [String] { matches(allRoutes) }
    var trains: [String] { matches(allTrains) }

    var hasResults: Bool { !stations.isEmpty || !routes.isEmpty || !trains.isEmpty }

    private func matches(_ items: [String]) -> [String] {
        guard isSearching else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    // MARK: - Mock catalog

    static let mockStations = [
        "Padova", "Bologna Centrale", "Montegrotto Terme", "Venezia Santa Lucia",
        "Firenze Santa Maria Novella", "Milano Porta Garibaldi", "Reggio Emilia AV Mediopadana",
    ]
    static let mockRoutes = [
        "Padova → Venezia Santa Lucia", "Montegrotto Terme → Padova",
        "Bologna Centrale → Padova", "Padova → Bologna Centrale",
    ]
    static let mockTrains = [
        "REG 1722", "REG 1741", "FR 8602", "RV 2774", "ITALO 9902",
    ]
}
