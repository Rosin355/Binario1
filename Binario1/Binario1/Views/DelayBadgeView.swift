//
//  DelayBadgeView.swift
//  Binario1
//
//  Delay chip in board-consistent amber / red-orange. Small delays use an amber
//  outline; larger delays (and cancellations) use red. Dynamic Type friendly.
//

import SwiftUI

struct DelayBadgeView: View {
    let row: TrainBoardRow
    /// Featured cards show "+15'", the dense list shows "15'".
    var showPlusSign: Bool = false
    var fontSize: CGFloat = 13

    /// Threshold above which a delay is shown in red.
    private let redThreshold = 10

    private var isCancelled: Bool { row.status.isCancelled }
    private var minutes: Int { row.delayMinutes ?? 0 }
    private var isRed: Bool { isCancelled || minutes >= redThreshold }

    private var text: String {
        if isCancelled { return "CANC" }
        return (showPlusSign ? "+" : "") + "\(minutes)'"
    }

    private var tint: Color { isRed ? BoardColors.delay : BoardColors.amber }

    var body: some View {
        Text(text)
            .font(BoardFont.digits(fontSize, .bold))
            .foregroundStyle(tint)
            .ledGlow(tint, radius: 3, opacity: 0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint.opacity(isRed ? 0.16 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(tint.opacity(0.85), lineWidth: 1)
                    )
            )
            .fixedSize()
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
