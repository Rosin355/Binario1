//
//  UsefulJourneyCardView.swift
//  Binario1
//
//  The "Prossimo viaggio utile" centerpiece, matching the design: a large LED
//  departure time with the emphasized destination + "da ORIGINE", a 3-column
//  detail grid (Durata / Treno / Arrivo), a large LED platform on the right, and
//  a bottom bar with "● In orario" and a train glyph.
//

import SwiftUI

struct UsefulJourneyCardView: View {
    let journey: SuggestedJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    // Time + destination
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        LEDText(text: data.departureText, size: 40, animatesNumeric: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(data.destinationBoard)
                                .font(BoardFont.text(18, .bold))
                                .foregroundStyle(BoardColors.amberBright)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(String(format: String(localized: "journey.from"), data.originBoard))
                                .font(BoardFont.text(11, .semibold))
                                .tracking(0.3)
                                .foregroundStyle(BoardColors.amberDim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    // Detail grid
                    HStack(spacing: 0) {
                        detail("journey.duration", data.durationText, numeric: true)
                        gridSeparator
                        detail("journey.train", data.trainText ?? "--")
                        gridSeparator
                        detail("journey.arrival", data.arrivalText ?? "--", numeric: true)
                    }
                }

                Spacer(minLength: 8)

                JourneyPlatformBadgeView(platform: journey.platform, numberSize: 46,
                                         color: BoardColors.amberBright, alignment: .center,
                                         animatesNumeric: true)
            }

            Rectangle().fill(BoardColors.gridLine).frame(height: 1)

            // Bottom bar
            HStack {
                JourneyStatusBadgeView(status: journey.status, fontSize: 13)
                Spacer()
                Image(systemName: "tram.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BoardColors.amber)
                    .ledGlow(BoardColors.amber, radius: 3, opacity: 0.4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BoardColors.amberBright.opacity(0.9), lineWidth: 1.4)
                )
        )
        .ledGlow(BoardColors.amberBright, radius: 9, opacity: 0.18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(data.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func detail(_ captionKey: LocalizedStringKey, _ value: String, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(captionKey)
                .font(BoardFont.text(8, .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amberDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            detailValue(value, numeric: numeric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailValue(_ value: String, numeric: Bool) -> some View {
        let base = Text(value)
            .font(BoardFont.text(14, .semibold))
            .foregroundStyle(BoardColors.amber)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        if numeric {
            base.boardNumericTransition(value)
        } else {
            base
        }
    }

    private var gridSeparator: some View {
        Rectangle()
            .fill(BoardColors.gridLine)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 6)
    }
}

#Preview {
    UsefulJourneyCardView(journey: MockTripsService.sample(on: Date()).suggested!)
        .padding()
        .background(BoardColors.background)
}
