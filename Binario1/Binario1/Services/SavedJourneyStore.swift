//
//  SavedJourneyStore.swift
//  Binario1
//
//  Local persistence for the user's saved journeys (Viaggi). Small JSON blob in
//  UserDefaults — no backend, no accounts, no sync. This is the single source of
//  truth for saved journeys, read by both the Viaggi dashboard and the Home
//  personalized "I tuoi prossimi treni" spotlight.
//

import Foundation

protocol SavedJourneyStoring: Sendable {
    func load() -> [SavedJourney]
    func save(_ journeys: [SavedJourney])
    func add(_ journey: SavedJourney)          // upsert by id
    func delete(id: String)
    /// Seed initial sample journeys exactly once (first launch). Never re-seeds after
    /// the user has cleared them, so deletions stick.
    func seedIfNeeded(_ journeys: @autoclosure () -> [SavedJourney])
}

/// Initial sample saved journeys, persisted on first launch so the app isn't empty.
/// They are real, editable/deletable user data once persisted — NOT a hardcoded demo.
enum SavedJourneySeed {
    static func initial(now: Date = Date()) -> [SavedJourney] {
        MockTripsService.sample(on: now).saved
    }
}

final class UserDefaultsSavedJourneyStore: SavedJourneyStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "binario1.savedJourneys.v1"
    private let seededKey = "binario1.savedJourneys.seeded.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SavedJourney] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedJourney].self, from: data)) ?? []
    }

    func save(_ journeys: [SavedJourney]) {
        guard let data = try? JSONEncoder().encode(journeys) else { return }
        defaults.set(data, forKey: key)
    }

    func add(_ journey: SavedJourney) {
        var all = load()
        all.removeAll { $0.id == journey.id }   // upsert
        all.append(journey)
        save(all)
    }

    func delete(id: String) {
        save(load().filter { $0.id != id })
    }

    func seedIfNeeded(_ journeys: @autoclosure () -> [SavedJourney]) {
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)   // mark seeded once, regardless
        // Never clobber data the user already added (e.g. a journey saved from Cerca
        // before Viaggi's first load). Only seed samples into a genuinely empty store.
        if load().isEmpty {
            save(journeys())
        }
    }
}
