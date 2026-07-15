//
//  UsefulJourneyCardView.swift
//  Binario1
//
//  The "Dalle tue abitudini" centerpiece: the soonest REAL next train across the
//  user's saved routes. Large LED departure time + emphasized destination, "da
//  ORIGINE", the real train label, a large LED platform on the right, and a bottom
//  bar with the real status. Only real board fields — no fabricated duration/arrival.
//

import SwiftUI

struct UsefulJourneyCardView: View {
    let nextTrain: NextTrainDisplay

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Time + destination / origin / real train label
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        LEDText(text: nextTrain.departureText, size: 40, animatesNumeric: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextTrain.destinationBoard)
                                .font(BoardFont.text(18, .bold))
                                .foregroundStyle(BoardColors.amberBright)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(String(format: String(localized: "journey.from"), nextTrain.originBoard))
                                .font(BoardFont.text(11, .semibold))
                                .tracking(0.3)
                                .foregroundStyle(BoardColors.amberDim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(nextTrain.trainText)
                                .font(BoardFont.text(12, .semibold))
                                .foregroundStyle(BoardColors.amber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Spacer(minLength: 8)

                JourneyPlatformBadgeView(platform: nextTrain.platform, numberSize: 46,
                                         color: BoardColors.amberBright, alignment: .center,
                                         animatesNumeric: true)
            }

            Rectangle().fill(BoardColors.gridLine).frame(height: 1)

            // Bottom bar — real status only
            HStack {
                JourneyStatusBadgeView(status: nextTrain.status, fontSize: 13)
                Spacer()
                Image(systemName: "tram.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BoardColors.amber)
                    .ledGlow(BoardColors.amber, radius: 3, opacity: 0.4)
            }
        }
        .padding(14)
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
        .accessibilityLabel(Text(nextTrain.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let row = TrainBoardRow(
        id: "p", trainNumber: "9437", category: "AV", operatorName: "Trenitalia",
        origin: nil, destination: "Roma Termini",
        scheduledTime: Date(), expectedTime: nil, delayMinutes: nil,
        plannedPlatform: "3", actualPlatform: "3", status: .onTime, notes: nil, lastUpdated: Date()
    )
    let saved = SavedJourney(id: "x", direction: .homeToWork, origin: "Padova", destination: "Roma Termini",
                             departure: Date(), platform: nil, durationMinutes: 0, status: .onTime)
    return UsefulJourneyCardView(nextTrain: .make(ResolvedNextTrain(journey: saved, row: row)))
        .padding()
        .background(BoardColors.background)
}
