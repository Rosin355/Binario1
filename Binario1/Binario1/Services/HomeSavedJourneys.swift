//
//  HomeSavedJourneys.swift
//  Binario1
//
//  MVP adapter that supplies the Home featured section with the user's saved
//  journeys. For now it reuses the bundled Viaggi (Trips) mock data so the Home
//  "I tuoi prossimi treni" spotlight can match against the live board.
//
//  TODO: this becomes real when saved journeys are persisted/shared from the Viaggi
//  tab (no persistence in this pass). Keep it the single source the Home VM reads.
//

import Foundation

enum HomeSavedJourneys {
    /// The user's saved journeys for the Home spotlight (mock-backed for now).
    ///
    /// Includes one DEMO entry (Padova → Venezia Santa Lucia) so the spotlight can
    /// actually activate against the DEBUG Padova backend board, whose departures
    /// include Venezia Santa Lucia. The Viaggi mock journeys (Montegrotto ↔ Padova)
    /// target an intermediate stop that is never a board terminus, so on their own
    /// they would always fall back to the generic next-departures view. This demo
    /// entry is Home-only (Viaggi is unchanged) and goes away once real saved
    /// journeys are persisted/shared.
    static func current(now: Date = Date()) -> [SavedJourney] {
        var journeys = MockTripsService.sample(on: now).saved
        journeys.append(SavedJourney(
            id: "home-demo-padova-venezia", direction: .workToHome,
            origin: "Padova", destination: "Venezia Santa Lucia",
            departure: now, platform: nil, durationMinutes: 28, status: .onTime
        ))
        return journeys
    }
}
