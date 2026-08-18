//
//  CercaViewModel.swift
//  Binario1
//
//  Drives the Cerca (Search) tab. Station search now comes from the REAL bundled
//  catalog (`StationCatalog`) and returns canonical Station entities. Route results
//  can be SAVED as a saved journey into the persistent `SavedJourneyStore` (shared
//  with Viaggi + the Home spotlight); the saved origin/destination are the catalog's
//  CANONICAL displayNames, so the B4 resolver can match the live board reliably.
//

import Foundation
import Observation

/// Outcome of trying to save a route as a saved journey.
enum SaveJourneyResult: Equatable {
    case saved
    case alreadySaved
    case invalid   // couldn't parse a departure + destination pair
}

/// Which search flow the Cerca cards open.
enum SearchMode: String, CaseIterable, Identifiable, Equatable {
    case station, route, train
    var id: String { rawValue }
}

@Observable
@MainActor
final class CercaViewModel {

    /// Bound to the native `.searchable` field.
    var query: String = ""

    private let catalog: StationCatalog
    private let savedStore: SavedJourneyStoring
    /// Ids of routes already saved — drives the "Saved" state without hitting the
    /// store on every row render. Refreshed after each save.
    private(set) var savedRouteIDs: Set<String> = []

    /// Which search flow is open. `nil` = the three category cards are shown.
    var selectedMode: SearchMode?
    /// Route-form fields (used when `selectedMode == .route`).
    var departureField: String = ""
    var destinationField: String = ""

    /// Ids of the stations this build can honestly show a board for. Injected (rather
    /// than read from `AppEnvironment` inline) so tests don't depend on the build
    /// configuration. See `AppEnvironment.boardStationIDs`.
    private let boardStationIDs: Set<String>

    init(catalog: StationCatalog = DefaultStationCatalog.shared,
         savedStore: SavedJourneyStoring = UserDefaultsSavedJourneyStore(),
         boardStationIDs: Set<String> = AppEnvironment.boardStationIDs) {
        self.catalog = catalog
        self.savedStore = savedStore
        self.boardStationIDs = boardStationIDs
        self.savedRouteIDs = Set(savedStore.load().map(\.id))
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Station search results as real catalog ENTITIES (ranked). Empty query → all.
    var stations: [Station] { catalog.search(trimmedQuery) }

    var hasResults: Bool { !stations.isEmpty }

    // MARK: - Station mode: results + live-board availability

    /// Whether tapping this station opens a REAL board. False → the board screen shows
    /// the honest "unavailable for this station" state and performs no live fetch
    /// (enforced in `StationBoardViewModel`, not here — this only drives the badge).
    func hasLiveBoard(_ station: Station) -> Bool { boardStationIDs.contains(station.id) }

    /// The list shown in `.station` mode.
    ///
    /// Empty query → a useful INITIAL list instead of an empty state that reads like a
    /// bug: the stations with a live board first, then the rest of the catalog (stored
    /// order). A typed query keeps the catalog's own ranking untouched.
    var stationResults: [Station] {
        guard !isSearching else { return stations }
        let all = catalog.all
        let withBoard = all.filter { hasLiveBoard($0) }
        let rest = all.filter { !hasLiveBoard($0) }
        return withBoard + rest
    }

    /// Show the "no results" state ONLY for a query that genuinely matched nothing.
    /// An idle (empty) field always has the initial list, so it can never look broken.
    var showsNoResults: Bool { isSearching && stationResults.isEmpty }

    // MARK: - Search mode + route form

    func selectMode(_ mode: SearchMode?) { selectedMode = mode }

    /// Reverse the route-form departure/destination.
    func swapRoute() { swap(&departureField, &destinationField) }

    /// The catalog station currently entered in each field (canonical resolution).
    /// Nil when the text isn't a known station (e.g. a bare "Roma" → must be
    /// disambiguated to "Roma Termini" via the suggestions).
    var departureStation: Station? { catalog.station(named: departureField) }
    var destinationStation: Station? { catalog.station(named: destinationField) }

    /// Save is allowed only when BOTH fields resolve to catalog stations, so the
    /// saved journey always stores canonical names (no free-text footgun).
    var canSaveCurrentRoute: Bool { departureStation != nil && destinationStation != nil }

    /// Ranked suggestions for a route field; empty once the field already holds an
    /// exact station name.
    func departureSuggestions(limit: Int = 6) -> [Station] { suggestions(departureField, limit: limit) }
    func destinationSuggestions(limit: Int = 6) -> [Station] { suggestions(destinationField, limit: limit) }

    private func suggestions(_ text: String, limit: Int) -> [Station] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }
        if let s = catalog.station(named: t),
           DefaultStationCatalog.fold(s.displayName) == DefaultStationCatalog.fold(t) {
            return []   // exact station already entered → no dropdown
        }
        return catalog.search(t, limit: limit)
    }

    /// Pick a station suggestion into a route field (sets the canonical displayName).
    func selectDeparture(_ station: Station) { departureField = station.displayName }
    func selectDestination(_ station: Station) { destinationField = station.displayName }

    /// Save the route-form pair (canonical station names). On success fields clear.
    @discardableResult
    func saveCurrentRoute(now: Date = Date()) -> SaveJourneyResult {
        guard let origin = departureStation, let destination = destinationStation else { return .invalid }
        let result = saveRoute(origin: origin.displayName, destination: destination.displayName, now: now)
        if result == .saved { departureField = ""; destinationField = "" }
        return result
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

    /// Save a "Origin → Destination" route string as a saved journey.
    @discardableResult
    func saveRoute(_ route: String, now: Date = Date()) -> SaveJourneyResult {
        guard let c = routeComponents(route) else { return .invalid }
        return saveRoute(origin: c.origin, destination: c.destination, now: now)
    }

    /// Save an origin/destination pair as a saved journey (upsert by stable id → no
    /// duplicates). Names are resolved to the catalog's CANONICAL displayName when the
    /// station is known (so B4 matches the live board); an unknown name is stored as
    /// typed (best-effort). Marked `isCustomRoute` so Viaggi shows the REAL route.
    @discardableResult
    func saveRoute(origin: String, destination: String, now: Date = Date()) -> SaveJourneyResult {
        let o = canonicalName(origin)
        let d = canonicalName(destination)
        guard !o.isEmpty, !d.isEmpty else { return .invalid }
        let id = routeID(origin: o, destination: d)
        refreshSavedState()   // reflect deletions made elsewhere before deciding
        if savedRouteIDs.contains(id) { return .alreadySaved }
        // Departure/platform/duration are unknown for a search-saved route; Viaggi
        // resolves the REAL next train from the board (B4), Home matches on names.
        let journey = SavedJourney(
            id: id, direction: .homeToWork,
            origin: o, destination: d,
            departure: now, platform: nil, durationMinutes: 0,
            status: .onTime, isFavorite: false, isCustomRoute: true
        )
        savedStore.add(journey)   // upsert
        refreshSavedState()
        return .saved
    }

    /// Canonical catalog displayName for a typed name, or the trimmed text if the
    /// station isn't in the catalog (kept honest — no invented name).
    private func canonicalName(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.station(named: t)?.displayName ?? t
    }
}
