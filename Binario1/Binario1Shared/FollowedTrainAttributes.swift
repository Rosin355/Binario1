//
//  FollowedTrainAttributes.swift
//  Binario1Shared — compiled into both the app and the Live Activity extension.
//
//  The whole contract between the app (which reads the board) and the extension
//  (which only draws). The extension never fetches, holds no token and knows no
//  source mode: everything it shows arrives through these types, so the Release
//  guardrail lives entirely in the app.
//
//  `ContentState` is also the future ActivityKit PUSH payload (LA2): its property
//  names are the JSON keys, so keep them stable. `readAtUnix` is seconds since 1970
//  on purpose — a `Date` would be decoded against Foundation's 2001 reference date,
//  a silent trap for whoever writes the backend sender.
//

import ActivityKit
import Foundation

nonisolated struct FollowedTrainAttributes: ActivityAttributes, Hashable {
    /// Identity of the followed train. Deliberately NOT the board row id: that id
    /// embeds the FETCH date, so the same train changes id across midnight (debt
    /// recorded in 11_PROGRESS). Station + train number + programmed time is stable.
    let stationSlug: String
    let stationName: String
    let category: String
    let trainNumber: String
    let destination: String
    /// Programmed departure "HH:mm", Europe/Rome — part of the identity key.
    let scheduledTime: String
    /// Programmed departure instant, used by the app to decide when to end.
    let scheduledAtUnix: TimeInterval

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var tracking: FollowedTrainTracking
        /// Positive minutes, or nil: never 0, never invented.
        var delayMinutes: Int?
        var isCancelled: Bool
        /// Platform as the board prints it ("6", "7 OV"), or nil when unassigned.
        var platform: String?
        /// When WE last read this train's board (backend fetch), not when RFI
        /// updated it — RFI's own update time is not captured.
        var readAtUnix: TimeInterval

        var readAt: Date { Date(timeIntervalSince1970: readAtUnix) }
    }
}

nonisolated enum FollowedTrainTracking: String, Codable, Hashable, Sendable {
    /// The last fresh live read listed the train.
    case onBoard
    /// A fresh live read no longer listed it. We do NOT say "departed": that would
    /// be an inference presented as a fact.
    case noLongerOnBoard
}

nonisolated enum FollowedTrainPolicy {
    /// After this long without a new read, iOS marks the content stale and the
    /// extension says so on its own — even with the app closed.
    static let staleAfter: TimeInterval = 3 * 60
    /// The app ends the activity this long after the last known expected departure.
    static let endAfterDeparture: TimeInterval = 15 * 60
    /// How often the app re-reads the board while in the foreground.
    static let refreshInterval: TimeInterval = 60

    static func staleDate(for state: FollowedTrainAttributes.ContentState) -> Date {
        state.readAt.addingTimeInterval(staleAfter)
    }
}
