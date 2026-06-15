//
//  TrainStatus.swift
//  Binario1
//

import SwiftUI

enum TrainStatus: String, Codable, Equatable {
    case scheduled
    case onTime
    case delayed
    case cancelled
    case departing
    case departed
    case arriving
    case arrived
    case platformChanged
    case unknown

    /// Localized status label key (technical enum stays language-neutral).
    var localizationKey: LocalizedStringKey {
        switch self {
        case .scheduled:       "status.scheduled"
        case .onTime:          "status.onTime"
        case .delayed:         "status.delayed"
        case .cancelled:       "status.cancelled"
        case .departing:       "status.departing"
        case .departed:        "status.departed"
        case .arriving:        "status.arriving"
        case .arrived:         "status.arrived"
        case .platformChanged: "status.platformChanged"
        case .unknown:         "status.unknown"
        }
    }

    /// Plain (non-LocalizedStringKey) key, for String(format:) accessibility composition.
    var localizationKeyString: String {
        switch self {
        case .scheduled:       "status.scheduled"
        case .onTime:          "status.onTime"
        case .delayed:         "status.delayed"
        case .cancelled:       "status.cancelled"
        case .departing:       "status.departing"
        case .departed:        "status.departed"
        case .arriving:        "status.arriving"
        case .arrived:         "status.arrived"
        case .platformChanged: "status.platformChanged"
        case .unknown:         "status.unknown"
        }
    }

    var isCancelled: Bool { self == .cancelled }

    /// Whether this row has already left / arrived (dimmed on the board).
    var isPast: Bool { self == .departed || self == .arrived }

    /// Whether this row is actively boarding/arriving (highlighted).
    var isActive: Bool { self == .departing || self == .arriving }
}
