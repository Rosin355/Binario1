//
//  TripsHeaderView.swift
//  Binario1
//
//  Viaggi header: small BINARIO1 brand, large board-style "VIAGGI" title, a
//  commuter subtitle, and an optional "+" for a future "new trip" flow.
//

import SwiftUI

struct TripsHeaderView: View {
    var onNewTrip: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("trips.brand")                       // BINARIO1
                    .font(BoardFont.text(11, .semibold))
                    .tracking(3)
                    .foregroundStyle(BoardColors.amberDim)
                Text("trips.title")                       // VIAGGI / TRIPS
                    .font(BoardFont.digits(34, .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(BoardColors.amberBright)
                    .ledGlow(BoardColors.amber, radius: 4, opacity: 0.35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("trips.subtitle")
                    .font(BoardFont.text(13))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if let onNewTrip {
                Button(action: onNewTrip) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BoardColors.amber)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().stroke(BoardColors.border.opacity(0.8), lineWidth: 1.2)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("trips.action.newTrip"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TripsHeaderView(onNewTrip: {})
        .padding()
        .background(BoardColors.background)
}
