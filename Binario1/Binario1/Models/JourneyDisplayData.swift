//
//  JourneyDisplayData.swift
//  Binario1
//
//  Display-ready, localized projection of a journey for the Viaggi cards/rows.
//  Keeps time/duration formatting and accessibility-label composition out of the
//  views (data-driven), reusing the board's existing formatters.
//

import Foundation

struct JourneyDisplayData: Equatable {
    var origin: String
    var destination: String
    var departureText: String       // "07:18"
    var arrivalText: String?        // "18:13"
    var trainText: String?          // "REG 1722"
    var platform: String?           // "2"
    var durationText: String        // "37 min"
    var status: JourneyStatus
    var accessibilityLabel: String

    var routeText: String { "\(origin) → \(destination)" }
    var hasPlatform: Bool { platform?.isEmpty == false }
    var platformDisplay: String { hasPlatform ? platform! : "--" }
}

extension JourneyDisplayData {

    // MARK: - Helpers

    private static func durationText(_ minutes: Int) -> String { "\(minutes) min" }

    private static func spokenDuration(_ minutes: Int) -> String {
        String(format: String(localized: "accessibility.duration.minutes"), minutes)
    }

    private static func trainText(_ category: String, _ number: String) -> String {
        let c = category.trimmingCharacters(in: .whitespaces)
        let n = number.trimmingCharacters(in: .whitespaces)
        return c.isEmpty ? n : "\(c) \(n)"
    }

    private static func platformOrDash(_ platform: String?) -> String {
        platform?.isEmpty == false ? platform! : "--"
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    // MARK: - Factories

    static func make(_ j: SavedJourney) -> JourneyDisplayData {
        let a11y = String(
            format: String(localized: "accessibility.journey.saved"),
            localized(j.direction.originRoleKey),
            localized(j.direction.destinationRoleKey),
            j.origin, j.destination,
            BoardFormatters.spokenTime(j.departure),
            platformOrDash(j.platform),
            spokenDuration(j.durationMinutes),
            j.status.spokenText
        )
        return JourneyDisplayData(
            origin: j.origin, destination: j.destination,
            departureText: BoardFormatters.clock(j.departure),
            arrivalText: nil, trainText: nil, platform: j.platform,
            durationText: durationText(j.durationMinutes),
            status: j.status, accessibilityLabel: a11y
        )
    }

    static func make(_ j: SuggestedJourney) -> JourneyDisplayData {
        let train = trainText(j.category, j.trainNumber)
        let a11y = String(
            format: String(localized: "accessibility.journey.useful"),
            j.origin, j.destination,
            BoardFormatters.spokenTime(j.departure),
            BoardFormatters.spokenTime(j.arrival),
            train, platformOrDash(j.platform),
            spokenDuration(j.durationMinutes),
            j.status.spokenText
        )
        return JourneyDisplayData(
            origin: j.origin, destination: j.destination,
            departureText: BoardFormatters.clock(j.departure),
            arrivalText: BoardFormatters.clock(j.arrival),
            trainText: train, platform: j.platform,
            durationText: durationText(j.durationMinutes),
            status: j.status, accessibilityLabel: a11y
        )
    }

    static func make(_ j: RecentJourney) -> JourneyDisplayData {
        let train = trainText(j.category, j.trainNumber)
        var a11y = String(
            format: String(localized: "accessibility.journey.recent"),
            train, j.origin, j.destination,
            BoardFormatters.spokenTime(j.departure),
            spokenDuration(j.durationMinutes)
        )
        if let p = j.platform, !p.isEmpty {
            a11y += String(format: String(localized: "accessibility.journey.platformClause"), p)
        }
        return JourneyDisplayData(
            origin: j.origin, destination: j.destination,
            departureText: BoardFormatters.clock(j.departure),
            arrivalText: nil, trainText: train, platform: j.platform,
            durationText: durationText(j.durationMinutes),
            status: .onTime, accessibilityLabel: a11y   // recents carry no live status badge
        )
    }
}
