//
//  TripsService.swift
//  Binario1
//
//  App-facing source for the Viaggi (Trips) dashboard. Protocol-based so it can be
//  swapped for a real source later. This milestone is MOCK-ONLY: no networking,
//  no persistence, no live data.
//

import Foundation

protocol TripsService: Sendable {
    func loadTrips() async throws -> TripsData
}

/// Bundled mock commuter data for the Viaggi dashboard. Times are anchored to the
/// reference day so they read as plausible "today" values; no live data.
final class MockTripsService: TripsService, @unchecked Sendable {
    /// Simulated latency so loading states are exercised. Set to `.zero` in tests.
    var artificialDelay: Duration = .milliseconds(200)

    private let referenceDate: @Sendable () -> Date

    init(referenceDate: @escaping @Sendable () -> Date = { Date() }) {
        self.referenceDate = referenceDate
    }

    func loadTrips() async throws -> TripsData {
        if artificialDelay > .zero { try? await Task.sleep(for: artificialDelay) }
        return Self.sample(on: referenceDate())
    }

    /// The mock dashboard content (saved, suggested, recent).
    static func sample(on now: Date) -> TripsData {
        func at(_ h: Int, _ m: Int) -> Date { time(h, m, on: now) }

        let saved = [
            SavedJourney(
                id: "saved-home-work", direction: .homeToWork,
                origin: "Montegrotto Terme", destination: "Padova",
                departure: at(7, 18), platform: "2", durationMinutes: 37,
                status: .onTime, isFavorite: true
            ),
            SavedJourney(
                id: "saved-work-home", direction: .workToHome,
                origin: "Padova", destination: "Montegrotto Terme",
                departure: at(17, 46), platform: "4", durationMinutes: 39,
                status: .delayed(minutes: 12)
            ),
        ]

        let suggested = SuggestedJourney(
            id: "useful-padova-venezia",
            origin: "Padova", destination: "Venezia Santa Lucia",
            departure: at(17, 45), arrival: at(18, 13),
            category: "REG", trainNumber: "1722", platform: "6",
            durationMinutes: 28, status: .onTime
        )

        let recent = [
            RecentJourney(
                id: "recent-bologna-padova", origin: "Bologna Centrale", destination: "Padova",
                departure: at(8, 32), category: "FR", trainNumber: "8602",
                durationMinutes: 62, platform: "5"
            ),
            RecentJourney(
                id: "recent-padova-venezia", origin: "Padova", destination: "Venezia Santa Lucia",
                departure: at(9, 15), category: "REG", trainNumber: "2245",
                durationMinutes: 28, platform: "3"
            ),
            RecentJourney(
                id: "recent-bologna-firenze", origin: "Bologna Centrale", destination: "Firenze Santa Maria Novella",
                departure: at(7, 50), category: "FR", trainNumber: "9543",
                durationMinutes: 37, platform: "5"
            ),
        ]

        return TripsData(saved: saved, suggested: suggested, recent: recent)
    }

    private static func time(_ h: Int, _ m: Int, on reference: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = BoardFormatters.romeTimeZone
        var comps = cal.dateComponents([.year, .month, .day], from: reference)
        comps.hour = h; comps.minute = m; comps.second = 0
        return cal.date(from: comps) ?? reference
    }
}
