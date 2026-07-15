//
//  NextTrainDisplay.swift
//  Binario1
//
//  Display-ready projection of the next REAL train for a saved route, built from a
//  resolved board row. Only real fields — the board provides no arrival/duration, so
//  none is shown or fabricated. When a route can't be resolved the views render an
//  honest "not available" state instead of this projection.
//

import Foundation

struct NextTrainDisplay: Equatable {
    let origin: String
    let destination: String
    let departureText: String       // scheduled "HH:mm"
    let trainText: String           // "AV 9437"
    let platform: String?           // real actual/planned
    let status: JourneyStatus       // real (onTime / delayed(+N) / cancelled)
    let accessibilityLabel: String

    var originBoard: String { JourneyDisplayData.shortStation(origin) }
    var destinationBoard: String { JourneyDisplayData.shortStation(destination) }
    var hasPlatform: Bool { platform?.isEmpty == false }
    var platformDisplay: String { hasPlatform ? platform! : "--" }

    /// Map a resolved row's status/delay into the badge status, never inventing a
    /// delay count — only a real, positive `delayMinutes` becomes `.delayed`.
    static func journeyStatus(from r: ResolvedNextTrain) -> JourneyStatus {
        if r.status == .cancelled { return .cancelled }
        if let d = r.delayMinutes, d > 0 { return .delayed(minutes: d) }
        return .onTime
    }

    static func make(_ r: ResolvedNextTrain) -> NextTrainDisplay {
        let train = trainText(r.category, r.trainNumber)
        let mappedStatus = journeyStatus(from: r)
        let a11y = String(
            format: String(localized: "accessibility.journey.nextTrain"),
            r.origin, r.destination,
            train,
            BoardFormatters.spokenTime(r.scheduledTime),
            (r.platform?.isEmpty == false) ? r.platform! : "--",
            mappedStatus.spokenText
        )
        return NextTrainDisplay(
            origin: r.origin, destination: r.destination,
            departureText: BoardFormatters.clock(r.scheduledTime),
            trainText: train, platform: r.platform, status: mappedStatus,
            accessibilityLabel: a11y
        )
    }

    private static func trainText(_ category: String, _ number: String) -> String {
        let c = category.trimmingCharacters(in: .whitespaces)
        let n = number.trimmingCharacters(in: .whitespaces)
        return c.isEmpty ? n : "\(c) \(n)"
    }
}
