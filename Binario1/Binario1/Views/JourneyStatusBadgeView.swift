//
//  JourneyStatusBadgeView.swift
//  Binario1
//
//  Status chip for a journey, in the board's amber / red-orange language (mirrors
//  DelayBadgeView styling). On-time / cancelled use localized labels; a delay
//  shows "+N min". Hidden from VoiceOver — the parent card carries the full label.
//

import SwiftUI

struct JourneyStatusBadgeView: View {
    let status: JourneyStatus
    var fontSize: CGFloat = 13

    private var tint: Color { status.isCritical ? BoardColors.delay : BoardColors.amber }

    var body: some View {
        label
            .font(BoardFont.text(fontSize, .bold))
            .foregroundStyle(tint)
            .ledGlow(tint, radius: 3, opacity: 0.4)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint.opacity(status.isCritical ? 0.16 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(tint.opacity(0.85), lineWidth: 1)
                    )
            )
            .fixedSize()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var label: some View {
        switch status {
        case .onTime:         Text("status.onTime")
        case .delayed(let m): Text(verbatim: "+\(m) min")
        case .cancelled:      Text("status.cancelled")
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        JourneyStatusBadgeView(status: .onTime)
        JourneyStatusBadgeView(status: .delayed(minutes: 12))
        JourneyStatusBadgeView(status: .cancelled)
    }
    .padding()
    .background(BoardColors.background)
}
