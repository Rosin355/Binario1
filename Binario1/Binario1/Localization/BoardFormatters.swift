//
//  BoardFormatters.swift
//  Binario1
//
//  Localized, language-neutral-friendly formatting helpers. Train names,
//  station names, platforms and numbers are never translated.
//

import Foundation

enum BoardFormatters {

    static let romeTimeZone = TimeZone(identifier: "Europe/Rome") ?? .current

    /// Compact "HH:mm" clock string for the header (24h, board style).
    static func clock(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = romeTimeZone
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Compact delay token for the board: "--", "+5", or "CANC".
    static func compactDelay(for row: TrainBoardRow) -> String {
        if row.status.isCancelled { return "CANC" }
        guard let delay = row.delayMinutes, delay > 0 else { return "--" }
        return "+\(delay)"
    }

    /// Spoken time for VoiceOver, respecting the user's locale (e.g. "5:45 PM").
    static func spokenTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = romeTimeZone
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    /// Spoken status, e.g. "in orario" / "on time", "ritardo 5 minuti" / "5 minutes late".
    static func spokenStatus(for row: TrainBoardRow) -> String {
        if row.status.isCancelled {
            return String(localized: "status.cancelled")
        }
        if let delay = row.delayMinutes, delay > 0 {
            let fmt = String(localized: "accessibility.delay.minutes")
            return String(format: fmt, delay)
        }
        return String(localized: String.LocalizationValue(row.status.localizationKeyString))
    }

    /// Full localized accessibility sentence for a row.
    static func accessibilityLabel(for row: TrainBoardRow, boardType: BoardType) -> String {
        let format = String(localized: String.LocalizationValue(boardType.accessibilityRowKey))
        return String(
            format: format,
            row.category,
            row.trainNumber,
            row.displayPlace(for: boardType),
            spokenTime(row.scheduledTime),
            spokenStatus(for: row),
            row.hasPlatform ? row.platformDisplay : "--"
        )
    }
}
