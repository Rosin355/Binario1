//
//  TripsQuickActionsView.swift
//  Binario1
//
//  Three placeholder commuter actions (Nuovo viaggio / Segui treno / Avvisi).
//  No behavior yet — these anchor future flows (App Intents, follow-train, alerts).
//

import SwiftUI

struct TripsQuickActionsView: View {
    var body: some View {
        HStack(spacing: 10) {
            action("plus.circle", "trips.action.newTrip")
            action("dot.radiowaves.up.forward", "trips.action.followTrain")
            action("bell", "trips.action.alerts")
        }
    }

    private func action(_ symbol: String, _ titleKey: LocalizedStringKey) -> some View {
        Button { } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(titleKey)
                    .font(BoardFont.text(11, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(BoardColors.amber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BoardColors.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BoardColors.borderDim, lineWidth: 1)
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
