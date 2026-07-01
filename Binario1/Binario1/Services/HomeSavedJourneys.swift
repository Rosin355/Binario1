//
//  HomeSavedJourneys.swift
//  Binario1
//
//  Supplies the Home personalized spotlight with the user's REAL, persisted saved
//  journeys (see `SavedJourneyStore`). No more mock/demo data: on first launch the
//  store is seeded once from the sample journeys, after which it reflects whatever
//  the user has saved/deleted. The previous Padova → Venezia S. Lucia demo entry has
//  been removed — personalization no longer depends on any hardcoded demo journey.
//

import Foundation

enum HomeSavedJourneys {
    /// The persisted saved journeys for the Home spotlight. Seeds first-launch
    /// samples once, then returns the stored list.
    static func current(store: SavedJourneyStoring = UserDefaultsSavedJourneyStore(),
                        now: Date = Date()) -> [SavedJourney] {
        store.seedIfNeeded(SavedJourneySeed.initial(now: now))
        return store.load()
    }
}
