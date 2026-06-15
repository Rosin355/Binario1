//
//  Journey.swift
//  Binario1
//
//  Domain models for the Viaggi (Trips) commuter dashboard. Mock-only for this
//  milestone: no live data, no persistence. Stays language-neutral — no UI text,
//  only stable values; localized labels are derived in the display layer.
//

import SwiftUI

/// Punctuality of a journey. Mock-only; never sourced from a live feed yet.
enum JourneyStatus: Equatable {
    case onTime
    case delayed(minutes: Int)
    case cancelled

    /// Larger delays / cancellations read in red, like the board's delay chip.
    var isCritical: Bool {
        switch self {
        case .onTime:          return false
        case .delayed(let m):  return m >= 10
        case .cancelled:       return true
        }
    }

    /// VoiceOver phrasing, reusing the board's existing status / delay strings.
    var spokenText: String {
        switch self {
        case .onTime:          return String(localized: "status.onTime")
        case .delayed(let m):  return String(format: String(localized: "accessibility.delay.minutes"), m)
        case .cancelled:       return String(localized: "status.cancelled")
        }
    }
}

/// A saved commuter route direction (home ↔ work). Localized role names come from
/// `journey.home` / `journey.work`.
enum JourneyDirection: Equatable {
    case homeToWork
    case workToHome

    var originRoleKey: String { self == .homeToWork ? "journey.home" : "journey.work" }
    var destinationRoleKey: String { self == .homeToWork ? "journey.work" : "journey.home" }
}

/// Trips dashboard filter (Oggi / Salvati / Recenti).
enum TripsFilter: String, CaseIterable, Identifiable {
    case today, saved, recent

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .today:  "trips.filter.today"
        case .saved:  "trips.filter.saved"
        case .recent: "trips.filter.recent"
        }
    }
}

struct SavedJourney: Identifiable, Equatable {
    let id: String
    let direction: JourneyDirection
    let origin: String              // full station name (accessibility source of truth)
    let destination: String
    let departure: Date
    let platform: String?
    let durationMinutes: Int
    let status: JourneyStatus
    var isFavorite: Bool = false
}

struct SuggestedJourney: Identifiable, Equatable {
    let id: String
    let origin: String
    let destination: String
    let departure: Date
    let arrival: Date
    let category: String            // REG, FR, IC, RV…
    let trainNumber: String
    let platform: String?
    let durationMinutes: Int
    let status: JourneyStatus
}

struct RecentJourney: Identifiable, Equatable {
    let id: String
    let origin: String
    let destination: String
    let departure: Date
    let category: String
    let trainNumber: String
    let durationMinutes: Int
    let platform: String?
}

/// Everything the Trips dashboard needs in one fetch (mock-only for now).
struct TripsData: Equatable {
    let saved: [SavedJourney]
    let suggested: SuggestedJourney?
    let recent: [RecentJourney]
}
