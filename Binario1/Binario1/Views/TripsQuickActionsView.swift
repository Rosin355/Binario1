//
//  TripsQuickActionsView.swift
//  Binario1
//
//  Three placeholder commuter actions (Nuovo viaggio / Segui treno / Avvisi),
//  matching the design: compact pills with a horizontal icon + label. No behavior
//  yet — these anchor future flows (App Intents, follow-train, alerts).
//

import SwiftUI

struct TripsQuickActionsView: View {
    var body: some View {
        HStack(spacing: 10) {
            action("plus", "trips.action.newTrip")
            action("bell", "trips.action.followTrain")
            action("megaphone", "trips.action.alerts")
        }
    }

    private func action(_ symbol: String, _ titleKey: LocalizedStringKey) -> some View {
        Button { } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(titleKey)
                    .font(BoardFont.text(12, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(BoardColors.amber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(BoardColors.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(BoardColors.border.opacity(0.7), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
    }
}

#Preview {
    TripsQuickActionsView()
        .padding()
        .background(BoardColors.background)
}
