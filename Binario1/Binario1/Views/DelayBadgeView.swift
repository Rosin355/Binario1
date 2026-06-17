//
//  DelayBadgeView.swift
//  Binario1
//
//  Delay chip with a SEMANTIC color policy (`DelayVisualState`): small delays read
//  amber, medium delays orange, large delays red-orange, cancelled red. The badge
//  renders only when there is a real delay or cancellation. Dynamic Type friendly.
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

struct DelayBadgeView: View {
    let row: TrainBoardRow
    /// Featured cards show "+15'", the dense list shows "15'".
    var showPlusSign: Bool = false
    var fontSize: CGFloat = 13

    var body: some View {
        if let state = DelayVisualState.from(delayMinutes: row.delayMinutes, isCancelled: row.status.isCancelled) {
            Text(label(for: state))
                .font(BoardFont.digits(fontSize, .bold))
                .foregroundStyle(state.tint)
                .ledGlow(state.tint, radius: 3, opacity: 0.4)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(state.tint.opacity(state.fillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(state.tint.opacity(0.85), lineWidth: 1)
                        )
                )
                .fixedSize()
        }
    }

    private func label(for state: DelayVisualState) -> String {
        if state == .cancelled { return "CANC" }
        let minutes = row.delayMinutes ?? 0
        return (showPlusSign ? "+" : "") + "\(minutes)'"
    }
}

#Preview {
    let rows = MockTrainBoardService.embeddedFallback.rows
    return VStack(alignment: .trailing, spacing: 12) {
        ForEach(rows.prefix(4)) { DelayBadgeView(row: $0, showPlusSign: true) }
        ForEach(rows.prefix(4)) { DelayBadgeView(row: $0) }
    }
    .padding()
    .background(BoardColors.background)
}
