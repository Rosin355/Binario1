//
//  CercaViewModel.swift
//  Binario1
//
//  Drives the Cerca (Search) tab. Search catalog is MOCK-ONLY (stations / routes /
//  trains filtered by the query). Route results can be SAVED as a saved journey into
//  the persistent `SavedJourneyStore` (shared with Viaggi + the Home spotlight).
//

import Foundation
import Observation

/// Outcome of trying to save a route as a saved journey.
enum SaveJourneyResult: Equatable {
    case saved
    case alreadySaved
    case invalid   // couldn't parse a departure + destination pair
}

@Observable
@MainActor
final class CercaViewModel {

    /// Bound to the native `.searchable` field.
    var query: String = ""

    let allStations: [String]
    let allRoutes: [String]
    let allTrains: [String]

    private let savedStore: SavedJourneyStoring
    /// Ids of routes already saved — drives the "Saved" state without hitting the
    /// store on every row render. Refreshed after each save.
    private(set) var savedRouteIDs: Set<String> = []

    init(stations: [String] = CercaViewModel.mockStations,
         routes: [String] = CercaViewModel.mockRoutes,
         trains: [String] = CercaViewModel.mockTrains,
         savedStore: SavedJourneyStoring = UserDefaultsSavedJourneyStore()) {
        self.allStations = stations
        self.allRoutes = routes
        self.allTrains = trains
        self.savedStore = savedStore
        self.savedRouteIDs = Set(savedStore.load().map(\.id))
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

    // MARK: - Save a route as a saved journey

    /// Split a "Origin → Destination" route into its two stations, or nil if it can't
    /// be parsed into a non-empty departure + destination pair.
    func routeComponents(_ route: String) -> (origin: String, destination: String)? {
        let separator = route.contains("→") ? "→" : "->"
        let parts = route.components(separatedBy: separator)
        guard parts.count >= 2 else { return nil }
        let origin = parts[0].trimmingCharacters(in: .whitespaces)
        let destination = parts[1...].joined(separator: separator).trimmingCharacters(in: .whitespaces)
        guard !origin.isEmpty, !destination.isEmpty else { return nil }
        return (origin, destination)
    }

    /// Whether the route can be saved (parses into a valid departure/destination pair).
    func canSaveRoute(_ route: String) -> Bool { routeComponents(route) != nil }

    /// Stable id for a saved route (canonicalized origin/destination) so re-saving the
    /// same pair upserts instead of duplicating.
    func routeID(origin: String, destination: String) -> String {
        "cerca:\(StationNameMatcher.canonical(origin))>\(StationNameMatcher.canonical(destination))"
    }

    func isRouteSaved(_ route: String) -> Bool {
        guard let c = routeComponents(route) else { return false }
        return savedRouteIDs.contains(routeID(origin: c.origin, destination: c.destination))
    }

    /// Re-sync the saved-state cache from the store. Call when the tab appears so a
    /// deletion made in Viaggi clears the stale "Saved" state and re-enables saving.
    func refreshSavedState() {
        savedRouteIDs = Set(savedStore.load().map(\.id))
    }

    /// Save the route as a saved journey (upsert by stable id → no duplicates).
    @discardableResult
    func saveRoute(_ route: String, now: @autoclosure () -> Date = Date()) -> SaveJourneyResult {
        guard let c = routeComponents(route) else { return .invalid }
        let id = routeID(origin: c.origin, destination: c.destination)
        refreshSavedState()   // reflect deletions made elsewhere before deciding
        if savedRouteIDs.contains(id) { return .alreadySaved }
        // Departure/platform/duration are unknown for a search-saved route (display
        // placeholders — Home matches on origin/destination only). Direction is a
        // placeholder `.homeToWork`; the card still shows the real route sub-line.
        let journey = SavedJourney(
            id: id, direction: .homeToWork,
            origin: c.origin, destination: c.destination,
            departure: now(), platform: nil, durationMinutes: 0,
            status: .onTime, isFavorite: false
        )
        savedStore.add(journey)   // upsert
        refreshSavedState()
        return .saved
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
