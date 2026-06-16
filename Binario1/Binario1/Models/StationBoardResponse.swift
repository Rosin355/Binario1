//
//  StationBoardResponse.swift
//  Binario1
//

import Foundation

struct StationBoardResponse: Equatable {
    let station: Station
    let boardType: BoardType
    let locale: String?
    let supportedLocales: [String]
    let rows: [TrainBoardRow]
    let generatedAt: Date
    let sourceUpdatedAt: Date?
    let isStale: Bool
    let warningMessageKey: String?
    /// True when the data is a *programmed/scheduled* timetable (e.g. RFI Quadro
    /// Orario), not live data — no real delays/cancellations/platform changes.
    var isScheduled: Bool = false
    /// Present when the rows come from a programmed-timetable *sample* with a
    /// fixed time window (e.g. the bundled Padova 06:00–06:59 demo). Lets the UI
    /// label the demo window and avoid presenting an out-of-window sample as the
    /// current/next departure.
    var scheduledWindow: ScheduledSampleWindow? = nil
    /// Where this board came from — drives the header source label
    /// (mock "Aggiornato", scheduled demo, or "Monitor RFI online").
    var sourceKind: BoardSourceKind = .mock
}

/// The origin of a board response, for the UI source label only.
enum BoardSourceKind: Equatable {
    case mock
    case scheduledSample
    case rfiLive
}

/// Metadata describing a programmed-timetable *sample* window (demo data).
/// Not live data: it only states which time band the sample covers.
struct ScheduledSampleWindow: Equatable {
    let startLabel: String      // e.g. "06:00"
    let endLabel: String        // e.g. "06:59"
    let start: Date             // window start on the reference day
    let end: Date               // last instant of the window on the reference day
    /// True for bundled demo sample data (`sourceKind == "scheduledSample"`).
    let isSample: Bool

    /// Whether `date` falls within the programmed window.
    func contains(_ date: Date) -> Bool { date >= start && date <= end }
}
