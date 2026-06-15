//
//  SavedJourneyCardView.swift
//  Binario1
//
//  A saved commuter route (Casa → Lavoro). Shows direction, route, next
//  departure, duration, platform and a status chip on a dark board panel.
//

import SwiftUI

struct SavedJourneyCardView: View {
    let journey: SavedJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title: direction + favorite
            HStack(spacing: 8) {
                directionTitle
                    .font(BoardFont.text(15, .bold))
                    .foregroundStyle(BoardColors.amberBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Image(systemName: journey.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(journey.isFavorite ? BoardColors.amberBright : BoardColors.amberDim)
            }

            // Route
            Text(data.routeText)
                .font(BoardFont.text(13))
                .foregroundStyle(BoardColors.amberDim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Rectangle().fill(BoardColors.gridLine).frame(height: 1)

            // Next departure + duration + platform
            HStack(alignment: .center, spacing: 14) {
                captioned("journey.nextDeparture") {
                    Text(data.departureText)
                        .font(BoardFont.digits(26))
                        .foregroundStyle(BoardColors.amber)
                        .ledGlow(BoardColors.amber, radius: 3, opacity: 0.3)
                }
                captioned("journey.duration") {
                    Text(data.durationText)
                        .font(BoardFont.text(15, .semibold))
                        .foregroundStyle(BoardColors.amberDim)
                }
                Spacer(minLength: 6)
                JourneyPlatformBadgeView(platform: journey.platform)
            }

            HStack {
                JourneyStatusBadgeView(status: journey.status)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BoardColors.borderDim, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(data.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private var directionTitle: Text {
        Text(LocalizedStringKey(journey.direction.originRoleKey))
        + Text(verbatim: "  →  ")
        + Text(LocalizedStringKey(journey.direction.destinationRoleKey))
    }

    @ViewBuilder
    private func captioned<Content: View>(_ captionKey: LocalizedStringKey,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(captionKey)
                .font(BoardFont.text(8, .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amberDim)
            content()
        }
    }
}

#Preview {
    let now = Date()
    return VStack(spacing: 12) {
        ForEach(MockTripsService.sample(on: now).saved) { SavedJourneyCardView(journey: $0) }
    }
    .padding()
    .background(BoardColors.background)
}
