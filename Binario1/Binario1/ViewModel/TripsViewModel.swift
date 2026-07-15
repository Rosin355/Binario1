//
//  TripsViewModel.swift
//  Binario1
//
//  Drives the Viaggi (Trips) dashboard. Saved journeys are PERSISTED locally
//  (`SavedJourneyStore`, shared with the Home spotlight); suggested/recent stay mock.
//

import Foundation
import Observation

@Observable
@MainActor
final class TripsViewModel {

    // Inputs
    var selectedFilter: TripsFilter = .today

    // Output state
    private(set) var savedJourneys: [SavedJourney] = []
    private(set) var suggestedJourney: SuggestedJourney?
    private(set) var recentJourneys: [RecentJourney] = []
    private(set) var isLoading = false
    private(set) var errorMessageKey: String?
    /// When the dashboard was last (mock-)refreshed — shown as "Aggiornato HH:mm".
    private(set) var lastUpdated: Date?

    /// Next REAL train per saved journey (keyed by id), resolved against the live/mock
    /// board via `resolver`. Missing/`.unavailable` → the card shows an honest state,
    /// never a placeholder. Empty until `load()` resolves (or when no resolver is set).
    private(set) var nextTrainResolutions: [String: NextTrainResolution] = [:]

    private let service: TripsService
    /// Persistent saved journeys — the single source of truth shared with Home.
    private let savedStore: SavedJourneyStoring
    /// Resolves the next real train for saved routes against the board. Nil (tests /
    /// previews without a board) → every route falls into the honest state.
    private let resolver: NextTrainResolving?

    init(service: TripsService,
         savedStore: SavedJourneyStoring = UserDefaultsSavedJourneyStore(),
         resolver: NextTrainResolving? = nil) {
        self.service = service
        self.savedStore = savedStore
        self.resolver = resolver
    }

    var hasData: Bool {
        !savedJourneys.isEmpty || suggestedJourney != nil || !recentJourneys.isEmpty
    }

    // MARK: - Filter → visible sections

    var showsSuggestedSection: Bool {
        selectedFilter == .today && suggestedJourney != nil
    }
    /// The saved section is relevant on Oggi/Salvati regardless of count.
    private var savedSectionRelevant: Bool {
        selectedFilter == .today || selectedFilter == .saved
    }
    var showsSavedSection: Bool {
        savedSectionRelevant && !savedJourneys.isEmpty
    }
    /// Show a small empty state when the saved section is relevant but has no journeys.
    var showsSavedEmptyState: Bool {
        savedSectionRelevant && savedJourneys.isEmpty
    }
    /// B4: Recents are HIDDEN until there is REAL journey history. The mock recents
    /// are kept in the model (for when a real history source lands) but are never
    /// shown, so the dashboard can't present demo data as if it were a real history.
    var showsRecentSection: Bool { false }

    // MARK: - Actions

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await service.loadTrips()
            // Saved journeys come from the persistent store (seeded once on first
            // launch); suggested/recent remain mock-derived (recents are not shown).
            savedStore.seedIfNeeded(SavedJourneySeed.initial())
            savedJourneys = savedStore.load()
            suggestedJourney = data.suggested
            recentJourneys = data.recent
            lastUpdated = Date()
            errorMessageKey = nil
        } catch {
            errorMessageKey = "error.dataUnavailable"
        }
        // Resolve each saved route's next REAL train against the board. Kept separate
        // from the mock load so a resolver failure never blocks the dashboard.
        await resolveNextTrains()
    }

    func selectFilter(_ filter: TripsFilter) {
        selectedFilter = filter
    }

    /// Delete a saved journey from the persistent store and refresh the visible list.
    /// Home reflects the change on its next refresh/load (it re-reads the same store).
    func deleteSavedJourney(id: String) {
        savedStore.delete(id: id)
        savedJourneys = savedStore.load()
        // Drop the stale resolution; the remaining routes' next trains are unchanged
        // (same board), so the habit centerpiece recomputes without a refetch.
        nextTrainResolutions[id] = nil
    }

    // MARK: - Next real train (resolved from the board)

    /// Resolves the next real train for every saved route. No-op (all unavailable)
    /// when no resolver is injected.
    private func resolveNextTrains() async {
        guard let resolver else {
            nextTrainResolutions = [:]
            return
        }
        nextTrainResolutions = await resolver.resolve(savedJourneys)
    }

    /// The resolved next real train for a saved route, or nil when it can't be
    /// resolved (→ the card shows an honest "not available" state, never a placeholder).
    func nextTrain(for journeyID: String) -> NextTrainDisplay? {
        guard case .resolved(let train)? = nextTrainResolutions[journeyID] else { return nil }
        return NextTrainDisplay.make(train)
    }

    // MARK: - "Dalle tue abitudini" — the soonest REAL next train

    /// The soonest resolved real train across the saved routes — the centerpiece card.
    /// Nil when nothing resolves (the section is then hidden; per-route honest states
    /// still show in the saved list). Real board data only — no save-time placeholder.
    var habitNextTrain: NextTrainDisplay? {
        let resolved = nextTrainResolutions.values.compactMap { resolution -> ResolvedNextTrain? in
            if case .resolved(let train) = resolution { return train }
            return nil
        }
        guard let soonest = resolved.min(by: { $0.scheduledTime < $1.scheduledTime }) else { return nil }
        return NextTrainDisplay.make(soonest)
    }
}
