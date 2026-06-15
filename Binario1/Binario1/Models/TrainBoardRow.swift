//
//  TrainBoardRow.swift
//  Binario1
//
//  Domain model for a single board entry. Stays language-neutral: no UI text,
//  only stable values (status enum, delay minutes, compact platform string).
//

import Foundation

struct TrainBoardRow: Identifiable, Equatable, Hashable {
    let id: String
    let trainNumber: String
    let category: String          // FR, REG, IC, RV, ITALO, AV, ES …
    let operatorName: String?

    let origin: String?
    let destination: String?

    let scheduledTime: Date
    let expectedTime: Date?
    let delayMinutes: Int?

    let plannedPlatform: String?
    let actualPlatform: String?

    let status: TrainStatus
    let notes: String?
    let lastUpdated: Date
}

extension TrainBoardRow {
    /// Destination for departures, origin for arrivals; "--" when missing.
    func displayPlace(for boardType: BoardType) -> String {
        let value = boardType == .departures ? destination : origin
        guard let value, !value.isEmpty else { return "--" }
        return value
    }

    /// Prefer the actual platform, fall back to planned, else "--".
    var platformDisplay: String {
        if let actualPlatform, !actualPlatform.isEmpty { return actualPlatform }
        if let plannedPlatform, !plannedPlatform.isEmpty { return plannedPlatform }
        return "--"
    }

    var hasPlatform: Bool { platformDisplay != "--" }

    /// Effective time used for ordering / "next" logic.
    var effectiveTime: Date { expectedTime ?? scheduledTime }

    var hasDelay: Bool { (delayMinutes ?? 0) > 0 }

    /// Compact board-style train label, e.g. "FR 9421".
    var trainLabel: String {
        let cat = category.trimmingCharacters(in: .whitespaces)
        let num = trainNumber.trimmingCharacters(in: .whitespaces)
        return cat.isEmpty ? num : "\(cat) \(num)"
    }

    /// "HH:mm" in the board's (Italian) timezone.
    func timeString(timezone: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        let c = cal.dateComponents([.hour, .minute], from: scheduledTime)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Whether this train is still upcoming (not departed/arrived/cancelled).
    func isUpcoming(now: Date) -> Bool {
        if status.isCancelled || status.isPast { return false }
        return effectiveTime >= now.addingTimeInterval(-60)
    }

    func minutesUntil(now: Date) -> Int {
        Int(effectiveTime.timeIntervalSince(now) / 60.0)
    }
}
