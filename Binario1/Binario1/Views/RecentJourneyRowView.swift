//
//  RecentJourneyRowView.swift
//  Binario1
//
//  A compact recent-journey row, matching the design: strong LED time column,
//  board route on the main line, "category number · duration" on the secondary
//  line, an optional binario on the right, and a chevron affordance.
//

import SwiftUI

struct RecentJourneyRowView: View {
    let journey: RecentJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        HStack(spacing: 12) {
            // Reliable Text-based time (no dot renderer): always one line, fixed
            // column width, monospaced digits → never wraps ("08:32" stays intact).
            BoardNumberText(text: data.departureText, size: 17, weight: .bold,
                            color: BoardColors.amberBright, glow: 0.28)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.boardRoute)
                    .font(BoardFont.text(13.5, .semibold))
                    .tracking(0.2)
                    .foregroundStyle(BoardColors.amberBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                // "CAT NUM · duration" — only the numeric duration rolls.
                HStack(spacing: 4) {
                    if let train = data.trainText {
                        Text(train)
                        Text(verbatim: "·")
                    }
                    Text(data.durationText)
                        .boardNumericTransition(data.durationText)
                }
                .font(BoardFont.text(11))
                .foregroundStyle(BoardColors.amberDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 6)

            if data.hasPlatform {
                JourneyPlatformBadgeView(platform: data.platformDisplay, numberSize: 16,
                                         captionSize: 7, alignment: .trailing, animatesNumeric: true)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BoardColors.amberDim)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(data.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 0) {
        let rows = MockTripsService.sample(on: Date()).recent
        ForEach(Array(rows.enumerated()), id: \.element.id) { i, j in
            RecentJourneyRowView(journey: j)
            if i < rows.count - 1 { Rectangle().fill(BoardColors.gridLine).frame(height: 1) }
        }
    }
    .background(BoardColors.panel)
    .padding()
    .background(BoardColors.background)
}
