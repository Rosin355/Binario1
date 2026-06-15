//
//  RecentJourneyRowView.swift
//  Binario1
//
//  A compact recent-journey row: departure time, route, train, duration, optional
//  platform and a chevron affordance.
//

import SwiftUI

struct RecentJourneyRowView: View {
    let journey: RecentJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        HStack(spacing: 12) {
            Text(data.departureText)
                .font(BoardFont.digits(18))
                .foregroundStyle(BoardColors.amber)
                .ledGlow(BoardColors.amber, radius: 2, opacity: 0.25)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.routeText)
                    .font(BoardFont.text(14, .semibold))
                    .foregroundStyle(BoardColors.amberBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    if let train = data.trainText {
                        Text(train)
                            .font(BoardFont.text(11, .semibold))
                            .foregroundStyle(BoardColors.amberDim)
                    }
                    Text(data.durationText)
                        .font(BoardFont.text(11))
                        .foregroundStyle(BoardColors.amberFaint)
                }
            }

            Spacer(minLength: 6)

            if data.hasPlatform {
                PlatformBadgeView(platform: data.platformDisplay, numberSize: 15)
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
        ForEach(MockTripsService.sample(on: Date()).recent) { RecentJourneyRowView(journey: $0) }
    }
    .background(BoardColors.panel)
    .padding()
    .background(BoardColors.background)
}
