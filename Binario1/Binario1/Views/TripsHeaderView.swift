//
//  TripsHeaderView.swift
//  Binario1
//
//  Viaggi header: the same animated LED dot-matrix title used on Home (reused
//  `DotMatrixStationTitleView`), plus a subtitle with an "Aggiornato HH:mm ●" status.
//  No "Binario 1" brand lockup (Cerca owns search; this stays focused on Viaggi).
//

import SwiftUI

struct TripsHeaderView: View {
    var lastUpdated: Date?
    /// Bumped on Viaggi tab entry to replay the title's intro animation (as on Home).
    var animationToken: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Animated LED title — reuses the Home component (no duplicated animation).
            DotMatrixStationTitleView(stationName: String(localized: "trips.title"),
                                      animationToken: animationToken)

            // Subtitle + last-updated (single line).
            HStack(alignment: .firstTextBaseline) {
                Text("trips.subtitle")
                    .font(BoardFont.text(13))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 10)
                updatedLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var updatedLabel: some View {
        if let lastUpdated {
            HStack(spacing: 6) {
                Text(String(format: String(localized: "label.updatedAt"),
                            BoardFormatters.clock(lastUpdated)))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(1)
                Circle()
                    .fill(BoardColors.amber)
                    .frame(width: 6, height: 6)
                    .ledGlow(BoardColors.amber, radius: 3, opacity: 0.7)
                    .accessibilityHidden(true)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    TripsHeaderView(lastUpdated: Date())
        .padding()
        .background(BoardColors.background)
}
