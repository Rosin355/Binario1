//
//  SavedJourneyCardView.swift
//  Binario1
//
//  A saved commuter route, matching the design: circular home/work icon, route
//  title + board route line, a top-right star, and a 4-column detail row
//  (Prossima partenza / Binario / Durata / Stato).
//

import SwiftUI

struct SavedJourneyCardView: View {
    let journey: SavedJourney

    private var data: JourneyDisplayData { .make(journey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            // Identity row
            HStack(alignment: .top, spacing: 12) {
                directionIcon
                VStack(alignment: .leading, spacing: 3) {
                    directionTitle
                        .font(BoardFont.text(15, .bold))
                        .foregroundStyle(BoardColors.amberBright)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(data.boardRoute)
                        .font(BoardFont.text(12, .semibold))
                        .tracking(0.3)
                        .foregroundStyle(BoardColors.amberDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 6)
                Image(systemName: journey.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(journey.isFavorite ? BoardColors.amberBright : BoardColors.amberDim)
            }

            Rectangle().fill(BoardColors.gridLine).frame(height: 1)

            // Detail row — a clean 4-column board grid: labels aligned on top,
            // values aligned on one shared text baseline. 07:18 is the largest
            // value; the platform is smaller so it doesn't dominate the row.
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    detailLabel("journey.nextDeparture")
                    detailLabel("journey.platform")
                    detailLabel("journey.duration")
                    detailLabel("journey.status")
                }
                GridRow(alignment: .firstTextBaseline) {
                    LEDText(text: data.departureText, size: 22, animatesNumeric: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LEDText(text: data.platformDisplay, size: 18, color: BoardColors.platform, animatesNumeric: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(data.durationText)
                        .font(BoardFont.text(14, .semibold))
                        .foregroundStyle(BoardColors.amberDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .boardNumericTransition(data.durationText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    JourneyStatusBadgeView(status: journey.status, fontSize: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BoardColors.borderDim, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(data.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private var directionIcon: some View {
        ZStack {
            Circle()
                .fill(BoardColors.amber.opacity(0.12))
                .overlay(Circle().stroke(BoardColors.amber.opacity(0.55), lineWidth: 1.2))
            Image(systemName: journey.direction == .homeToWork ? "house.fill" : "briefcase.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
        }
        .frame(width: 44, height: 44)
    }

    private var directionTitle: Text {
        Text(LocalizedStringKey(journey.direction.originRoleKey))
        + Text(verbatim: "  →  ")
        + Text(LocalizedStringKey(journey.direction.destinationRoleKey))
    }

    private func detailLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(BoardFont.text(8, .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(BoardColors.amberDim)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(MockTripsService.sample(on: Date()).saved) { SavedJourneyCardView(journey: $0) }
    }
    .padding()
    .background(BoardColors.background)
}
