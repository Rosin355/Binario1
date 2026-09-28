//
//  DelayVisualState.swift
//  Binario1Shared — compiled into both the app and the Live Activity extension.
//
//  Extracted from DelayBadgeView so the board and the Live Activity share ONE delay
//  severity policy instead of two copies that could drift.
//

import SwiftUI

/// Severity → color policy for delays. Keeps small delays visually lighter than
/// major ones; red is reserved for significant problems / cancellations.
enum DelayVisualState: Equatable {
    case mild       // 1...4 min
    case medium     // 5...9 min
    case severe     // 10+ min
    case cancelled

    /// `nil` when there is no delay and the train is not cancelled → no badge.
    static func from(delayMinutes: Int?, isCancelled: Bool) -> DelayVisualState? {
        if isCancelled { return .cancelled }                 // cancelled wins over any delay
        guard let minutes = delayMinutes, minutes > 0 else { return nil }
        switch minutes {
        case 1...4: return .mild
        case 5...9: return .medium
        default:    return .severe
        }
    }

    var tint: Color {
        switch self {
        case .mild:      return BoardColors.amber
        case .medium:    return BoardColors.delayMedium
        case .severe:    return BoardColors.delay
        case .cancelled: return BoardColors.cancelled
        }
    }

    var fillOpacity: Double {
        switch self {
        case .mild:                return 0.10
        case .medium:              return 0.13
        case .severe, .cancelled:  return 0.16
        }
    }
}
