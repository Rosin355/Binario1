//
//  DelayBadgeView.swift
//  Binario1
//
//  Delay chip with a SEMANTIC color policy (`DelayVisualState`): small delays read
//  amber, medium delays orange, large delays red-orange, cancelled red. The badge
//  renders only when there is a real delay or cancellation. Dynamic Type friendly.
//  `DelayVisualState` lives in Binario1Shared/: the Live Activity uses the same
//  thresholds, so there is one policy, not two.
//

import SwiftUI

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
