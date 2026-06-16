//
//  JourneyStatusBadgeView.swift
//  Binario1
//
//  Journey status indicator: a colored dot + label, matching the design.
//   • On time  → green dot + green "In orario" (no box)
//   • Delayed  → red dot + red-outlined "+N min" badge
//   • Cancelled→ red dot + red-outlined "CANC" badge
//  Hidden from VoiceOver — the parent card carries the full spoken label.
//

import SwiftUI

struct JourneyStatusBadgeView: View {
    let status: JourneyStatus
    var fontSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: dotColor.opacity(0.7), radius: 3)
            content
        }
        .fixedSize()
        .accessibilityHidden(true)
    }

    private var dotColor: Color {
        switch status {
        case .onTime:              return BoardColors.statusGreen
        case .delayed, .cancelled: return BoardColors.delay
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .onTime:
            Text("status.onTime")
                .font(BoardFont.text(fontSize, .semibold))
                .foregroundStyle(BoardColors.statusGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .delayed(let m):
            badge(Text(String(format: String(localized: "status.delay.short"), m)))
        case .cancelled:
            badge(Text("status.cancelled"))
        }
    }

    private func badge(_ text: Text) -> some View {
        text
            .font(BoardFont.text(fontSize, .bold))
            .foregroundStyle(BoardColors.delay)
            .ledGlow(BoardColors.delay, radius: 3, opacity: 0.4)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(BoardColors.delay.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(BoardColors.delay.opacity(0.9), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        JourneyStatusBadgeView(status: .onTime)
        JourneyStatusBadgeView(status: .delayed(minutes: 12))
        JourneyStatusBadgeView(status: .cancelled)
    }
    .padding()
    .background(BoardColors.background)
}
