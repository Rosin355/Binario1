//
//  UsefulJourneyCardView.swift
//  Binario1
//
//  The "Prossimo viaggio utile" centerpiece: big departure → arrival times, the
//  train, duration, status and a large, easy-to-scan platform badge.
//

import SwiftUI

struct UsefulJourneyCardView: View {
    let journey: SuggestedJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(data.routeText)
                .font(BoardFont.text(16, .bold))
                .foregroundStyle(BoardColors.amberBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(data.departureText)
                            .font(BoardFont.digits(40))
                            .foregroundStyle(BoardColors.amber)
                            .ledGlow(BoardColors.amber, radius: 5, opacity: 0.4)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BoardColors.amberDim)
                        Text(data.arrivalText ?? "--")
                            .font(BoardFont.digits(28))
                            .foregroundStyle(BoardColors.amberDim)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                    HStack(spacing: 8) {
                        if let train = data.trainText {
                            Text(train)
                                .font(BoardFont.text(13, .semibold))
                                .foregroundStyle(BoardColors.amberDim)
                        }
                        Text(data.durationText)
                            .font(BoardFont.text(13))
                            .foregroundStyle(BoardColors.amberFaint)
                    }
                }

                Spacer(minLength: 8)

                JourneyPlatformBadgeView(platform: journey.platform, highlighted: true, numberSize: 30)
            }

            HStack {
                JourneyStatusBadgeView(status: journey.status)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BoardColors.border.opacity(0.7), lineWidth: 1.2)
                )
        )
        .ledGlow(BoardColors.amber, radius: 8, opacity: 0.12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(data.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    UsefulJourneyCardView(journey: MockTripsService.sample(on: Date()).suggested!)
        .padding()
        .background(BoardColors.background)
}
