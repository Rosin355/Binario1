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
}
