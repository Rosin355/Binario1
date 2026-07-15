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
    /// The next REAL train for this route (resolved from the board). Nil → an honest
    /// "next train unavailable" state instead of placeholder time/platform/duration.
    var nextTrain: NextTrainDisplay? = nil
    /// When provided, shows a small remove (trash) affordance + a VoiceOver action.
    var onRemove: (() -> Void)? = nil

    /// Identity-only projection (route/title). Its time/duration fields are NOT used
    /// here — the detail row shows the resolved real train instead.
    private var data: JourneyDisplayData { .make(journey) }
    /// Custom routes (saved from Cerca) show the real route as the title, not the
    /// "Casa → Lavoro" role alias.
    private var isCustom: Bool { journey.isCustomRoute == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
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
                HStack(spacing: 10) {
                    Image(systemName: journey.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(journey.isFavorite ? BoardColors.amberBright : BoardColors.amberDim)
                    if let onRemove {
                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BoardColors.amberDim)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Rectangle().fill(BoardColors.gridLine).frame(height: 1)

            detailRow
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BoardColors.borderDim, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityActions {
            // The visible trash button is hidden by `children: .ignore`; expose an
            // equivalent VoiceOver action when the card is removable.
            if let onRemove {
                Button("action.removeSavedJourney", action: onRemove)
            }
        }
    }

    /// Real next-train detail (4-column board grid) when resolved, otherwise an honest
    /// "next train unavailable" line — never a placeholder time/platform/duration.
    @ViewBuilder
    private var detailRow: some View {
        if let nextTrain {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                GridRow {
                    detailLabel("journey.nextDeparture")
                    detailLabel("journey.platform")
                    detailLabel("journey.train")
                    detailLabel("journey.status")
                }
                GridRow(alignment: .firstTextBaseline) {
                    LEDText(text: nextTrain.departureText, size: 22, animatesNumeric: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LEDText(text: nextTrain.platformDisplay, size: 18, color: BoardColors.platform, animatesNumeric: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(nextTrain.trainText)
                        .font(BoardFont.text(13, .semibold))
                        .foregroundStyle(BoardColors.amber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    JourneyStatusBadgeView(status: nextTrain.status, fontSize: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BoardColors.amberDim)
                Text("journey.nextTrain.unavailable")
                    .font(BoardFont.text(12.5, .semibold))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityText: String {
        if let nextTrain { return nextTrain.accessibilityLabel }
        return String(format: String(localized: "accessibility.journey.nextTrainUnavailable"),
                      journey.origin, journey.destination)
    }

    private var directionIcon: some View {
        ZStack {
            Circle()
                .fill(BoardColors.amber.opacity(0.12))
                .overlay(Circle().stroke(BoardColors.amber.opacity(0.55), lineWidth: 1.2))
            Image(systemName: isCustom ? "bookmark.fill" : (journey.direction == .homeToWork ? "house.fill" : "briefcase.fill"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
        }
        .frame(width: 38, height: 38)
    }

    private var directionTitle: Text {
        if isCustom {
            // Real route, e.g. "Padova → Venezia S. Lucia" (uses the board-short names).
            return Text(verbatim: data.boardRoute)
        }
        return Text(LocalizedStringKey(journey.direction.originRoleKey))
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
    let saved = MockTripsService.sample(on: Date()).saved
    let row = TrainBoardRow(
        id: "r", trainNumber: "9437", category: "AV", operatorName: nil,
        origin: nil, destination: saved[0].destination,
        scheduledTime: Date().addingTimeInterval(600), expectedTime: nil, delayMinutes: 12,
        plannedPlatform: "3", actualPlatform: "3", status: .delayed, notes: nil, lastUpdated: Date()
    )
    return VStack(spacing: 12) {
        // Resolved: real next train (time / platform / train / delay).
        SavedJourneyCardView(journey: saved[0],
                             nextTrain: .make(ResolvedNextTrain(journey: saved[0], row: row)))
        // Honest state: no real next train available.
        SavedJourneyCardView(journey: saved[1])
    }
    .padding()
    .background(BoardColors.background)
}
