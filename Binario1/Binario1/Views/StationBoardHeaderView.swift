//
//  StationBoardHeaderView.swift
//  Binario1
//
//  Station-context header (replaces the old "Binario1" brand lockup, which read
//  ambiguously as a platform number):
//
//    STAZIONE DI                       Aggiornato 17:12 ●   ★
//    BOLOGNA                                          [ Cambia ]
//    CENTRALE
//

import SwiftUI

struct StationBoardHeaderView: View {
    let stationName: String          // full name, e.g. "Bologna Centrale"
    let lastUpdated: Date?
    let isStale: Bool
    var isScheduled: Bool = false     // programmed timetable (not live)
    var scheduledWindow: ScheduledSampleWindow? = nil  // demo sample time window, if any
    var canChangeStation: Bool = true // false → station locked (single-station source)
    /// Increment to replay the title's intro animation (e.g. on Partenze tab entry).
    var animationToken: Int = 0
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)?
    var onChangeStation: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1 — station context label + updated + favorite
            HStack(alignment: .center, spacing: 10) {
                Text("header.stationContext")        // "STAZIONE DI" / "STATION"
                    .font(BoardFont.text(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(BoardColors.amberDim)
                Spacer(minLength: 8)
                updatedLabel
                favoriteButton
            }

            // Row 2 — static dot-matrix station title + change-station action
            HStack(alignment: .bottom, spacing: 10) {
                DotMatrixStationTitleView(stationName: stationName, animationToken: animationToken)
                Spacer(minLength: 8)
                if onChangeStation != nil { changeButton.padding(.bottom, 4) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var changeButton: some View {
        // When the station is locked (single-station scheduled source) the control
        // stays visible but disabled and dimmed, with a VoiceOver hint explaining why.
        let button = Button {
            onChangeStation?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: canChangeStation ? "arrow.triangle.2.circlepath" : "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("action.changeStation.short")     // "Cambia" / "Change"
                    .font(BoardFont.text(12, .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(canChangeStation ? BoardColors.amber : BoardColors.amberDim.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((canChangeStation ? BoardColors.amber : BoardColors.amberDim)
                        .opacity(canChangeStation ? 0.5 : 0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canChangeStation)
        .accessibilityLabel(Text("accessibility.changeStation"))

        if canChangeStation {
            button
        } else {
            button.accessibilityHint(Text("accessibility.stationLocked"))
        }
    }

    private var favoriteButton: some View {
        Button {
            onToggleFavorite?()
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isFavorite ? BoardColors.amberBright : BoardColors.amber.opacity(0.7))
                .ledGlow(BoardColors.amber, radius: isFavorite ? 4 : 0, opacity: 0.4)
                .frame(width: 32, height: 32)
                .background(
                    Circle().stroke(Color(red: 0.34, green: 0.27, blue: 0.16).opacity(0.8), lineWidth: 1.2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(onToggleFavorite == nil)
        .accessibilityLabel(Text("accessibility.favorite"))
    }

    /// Programmed-timetable label. For a demo *sample* it names the time window
    /// ("Orario programmato · demo 06:00–06:59"); otherwise the plain scheduled label.
    private var scheduledSourceLabel: Text {
        if let w = scheduledWindow, w.isSample {
            return Text(String(format: String(localized: "source.scheduledSampleWindow"), w.startLabel, w.endLabel))
        }
        return Text("source.scheduled")     // "Orario programmato" / "Scheduled timetable"
    }

    @ViewBuilder
    private var updatedLabel: some View {
        if isScheduled {
            // Programmed timetable is NOT live — clear label, no live dot.
            scheduledSourceLabel
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(BoardColors.amberDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if let lastUpdated {
            HStack(spacing: 6) {
                Text(String(format: String(localized: "label.updatedAt"), BoardFormatters.clock(lastUpdated)))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(isStale ? BoardColors.delay : BoardColors.amberDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Circle()
                    .fill(isStale ? BoardColors.delay : BoardColors.amber)
                    .frame(width: 6, height: 6)
                    .ledGlow(isStale ? BoardColors.delay : BoardColors.amber, radius: 3, opacity: 0.7)
            }
        }
    }
}

#Preview {
    StationBoardHeaderView(
        stationName: "Bologna Centrale",
        lastUpdated: Date(),
        isStale: false,
        isFavorite: false,
        onToggleFavorite: {},
        onChangeStation: {}
    )
    .background(BoardColors.background)
}
