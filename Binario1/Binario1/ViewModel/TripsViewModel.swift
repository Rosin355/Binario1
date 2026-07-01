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

    /// Delete a saved journey from the persistent store and refresh the visible list.
    /// Home reflects the change on its next refresh/load (it re-reads the same store).
    func deleteSavedJourney(id: String) {
        savedStore.delete(id: id)
        savedJourneys = savedStore.load()
    }

    // MARK: - "Dalle tue abitudini" — next likely saved journey

    /// The user's next likely trip = the saved journey whose scheduled time-of-day is
    /// soonest upcoming from `now` (wrapping past midnight). Nil when nothing is saved.
    /// Uses only the local saved-journey timing — no prediction/AI.
    func nextHabitJourney(now: Date = Date()) -> SavedJourney? {
        guard !savedJourneys.isEmpty else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = BoardFormatters.romeTimeZone
        func minutesOfDay(_ date: Date) -> Int {
            let c = cal.dateComponents([.hour, .minute], from: date)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let nowMin = minutesOfDay(now)
        func minutesUntil(_ j: SavedJourney) -> Int {
            let diff = minutesOfDay(j.departure) - nowMin
            return diff >= 0 ? diff : diff + 24 * 60
        }
        return savedJourneys.min { minutesUntil($0) < minutesUntil($1) }
    }
}
