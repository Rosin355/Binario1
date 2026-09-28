//
//  FollowedTrainDisplay.swift
//  Binario1Shared — compiled into both the app and the Live Activity extension.
//
//  Everything the Live Activity shows, derived in ONE place from attributes + state,
//  so every surface (compact, expanded, lock screen) reads the same values: if the
//  badge says platform 6, nothing else can say 2. Pure and testable from the app's
//  test target; the extension views only lay it out.
//
//  Honest-state rules: platform missing → "--"; no delay → no delay element at all;
//  values not confirmed by the latest fresh read are flagged, never shown as current.
//

import Foundation

nonisolated struct FollowedTrainDisplay: Equatable {

    enum Delay: Equatable {
        case minutes(Int)
        case cancelled
    }

    enum Timestamp: Equatable {
        /// "letto 14:32" — the values come from a read that is still recent.
        case read(clock: String)
        /// "non aggiornato · letto 14:32" — past `staleDate`, nothing newer arrived.
        case stale(clock: String)
    }

    /// Programmed departure "HH:mm" (the board convention: delay shown apart).
    let time: String
    let category: String
    let trainNumber: String
    /// "REG 17088".
    let trainLabel: String
    let destination: String
    /// Platform as printed, or "--" when unassigned.
    let platformText: String
    var hasPlatform: Bool { platformText != Self.noPlatform }
    let delay: Delay?
    /// True only when the latest FRESH read listed the train. False when stale or no
    /// longer on the board: the values are then last-seen, and drawn as such.
    let valuesAreCurrent: Bool
    /// Present when a fresh read no longer lists the train; carries the programmed
    /// time for "non più sul tabellone · partenza prevista HH:mm".
    let noLongerOnBoardScheduled: String?
    let timestamp: Timestamp

    static let noPlatform = "--"

    init(attributes: FollowedTrainAttributes,
         state: FollowedTrainAttributes.ContentState,
         isStale: Bool) {
        time = attributes.scheduledTime
        let category = attributes.category.trimmingCharacters(in: .whitespaces)
        let number = attributes.trainNumber.trimmingCharacters(in: .whitespaces)
        self.category = category
        trainNumber = number
        trainLabel = category.isEmpty ? number : "\(category) \(number)"
        destination = attributes.destination

        if let platform = state.platform?.trimmingCharacters(in: .whitespaces), !platform.isEmpty {
            platformText = platform
        } else {
            platformText = Self.noPlatform
        }

        if state.isCancelled {
            delay = .cancelled
        } else if let minutes = state.delayMinutes, minutes > 0 {
            delay = .minutes(minutes)
        } else {
            delay = nil
        }

        valuesAreCurrent = state.tracking == .onBoard && !isStale
        noLongerOnBoardScheduled = state.tracking == .noLongerOnBoard ? attributes.scheduledTime : nil

        let clock = FollowedTrainClock.string(from: state.readAt)
        timestamp = isStale ? .stale(clock: clock) : .read(clock: clock)
    }

    // MARK: Localized text (table "LiveActivity", shipped in both bundles)

    var timestampText: String {
        switch timestamp {
        case .read(let clock):
            return String(format: String(localized: "la.timestamp.read", table: "LiveActivity"), clock)
        case .stale(let clock):
            return String(format: String(localized: "la.timestamp.stale", table: "LiveActivity"), clock)
        }
    }

    var noLongerOnBoardText: String? {
        noLongerOnBoardScheduled.map {
            String(format: String(localized: "la.status.noLongerOnBoard", table: "LiveActivity"), $0)
        }
    }

    /// "+5'" or the localized cancellation word; nil when there is no delay.
    var delayText: String? {
        switch delay {
        case .minutes(let minutes): return "+\(minutes)'"
        case .cancelled:            return String(localized: "la.status.cancelled", table: "LiveActivity")
        case nil:                   return nil
        }
    }

    @MainActor var delayVisualState: DelayVisualState? {
        switch delay {
        case .minutes(let minutes): return DelayVisualState.from(delayMinutes: minutes, isCancelled: false)
        case .cancelled:            return .cancelled
        case nil:                   return nil
        }
    }

    /// One sentence for VoiceOver, built from the same values the layout shows.
    var accessibilityText: String {
        var parts = [trainLabel, destination, time]
        if let delayText { parts.append(delayText) }
        parts.append(String(format: String(localized: "la.accessibility.platform", table: "LiveActivity"),
                            hasPlatform ? platformText : String(localized: "la.accessibility.noPlatform", table: "LiveActivity")))
        if let noLongerOnBoardText { parts.append(noLongerOnBoardText) }
        parts.append(timestampText)
        return parts.joined(separator: ", ")
    }
}

/// "HH:mm" in the board's timezone (Europe/Rome), like the rest of the app.
nonisolated enum FollowedTrainClock {
    static let timeZone = TimeZone(identifier: "Europe/Rome") ?? .current

    static func string(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
