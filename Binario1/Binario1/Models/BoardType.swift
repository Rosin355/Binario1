//
//  BoardType.swift
//  Binario1
//

import SwiftUI

enum BoardType: String, Codable, CaseIterable, Identifiable {
    case departures
    case arrivals

    var id: String { rawValue }

    /// Title shown in the segmented control / header (PARTENZE / ARRIVI).
    var titleKey: LocalizedStringKey {
        switch self {
        case .departures: "board.departures"
        case .arrivals:   "board.arrivals"
        }
    }

    /// "Prossime partenze" / "Prossimi arrivi".
    var nextSectionTitleKey: LocalizedStringKey {
        switch self {
        case .departures: "section.nextDepartures"
        case .arrivals:   "section.nextArrivals"
        }
    }

    /// "Tutte le partenze" / "Tutti gli arrivi".
    var allSectionTitleKey: LocalizedStringKey {
        switch self {
        case .departures: "section.allDepartures"
        case .arrivals:   "section.allArrivals"
        }
    }

    /// Column header for the place column (DESTINAZIONE / PROVENIENZA).
    var placeColumnKey: LocalizedStringKey {
        switch self {
        case .departures: "column.destination"
        case .arrivals:   "column.origin"
        }
    }

    /// Accessibility format key for a row on this board.
    var accessibilityRowKey: String {
        switch self {
        case .departures: "accessibility.row.departure"
        case .arrivals:   "accessibility.row.arrival"
        }
    }
}
