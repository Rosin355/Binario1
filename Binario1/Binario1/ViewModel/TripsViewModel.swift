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

    private let service: TripsService
    /// Persistent saved journeys — the single source of truth shared with Home.
    private let savedStore: SavedJourneyStoring

    init(service: TripsService, savedStore: SavedJourneyStoring = UserDefaultsSavedJourneyStore()) {
        self.service = service
        self.savedStore = savedStore
    }

    var hasData: Bool {
        !savedJourneys.isEmpty || suggestedJourney != nil || !recentJourneys.isEmpty
    }

    // MARK: - Filter → visible sections

    var showsSuggestedSection: Bool {
        selectedFilter == .today && suggestedJourney != nil
    }
    var showsSavedSection: Bool {
        (selectedFilter == .today || selectedFilter == .saved) && !savedJourneys.isEmpty
    }
    var showsRecentSection: Bool {
        (selectedFilter == .today || selectedFilter == .recent) && !recentJourneys.isEmpty
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await service.loadTrips()
            // Saved journeys come from the persistent store (seeded once on first
            // launch); suggested/recent remain mock-derived for now.
            savedStore.seedIfNeeded(SavedJourneySeed.initial())
            savedJourneys = savedStore.load()
            suggestedJourney = data.suggested
            recentJourneys = data.recent
            lastUpdated = Date()
            errorMessageKey = nil
        } catch {
            errorMessageKey = "error.dataUnavailable"
        }
    }

    func selectFilter(_ filter: TripsFilter) {
        selectedFilter = filter
    }
}
