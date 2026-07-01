//
//  NextDeparturesSectionView.swift
//  Binario1
//
//  "Prossime partenze" / "Prossimi arrivi" — one rounded board panel holding the
//  3 most imminent trains as large featured rows, separated by faint dividers.
//

import SwiftUI

struct NextDeparturesSectionView: View {
    let rows: [TrainBoardRow]
    let boardType: BoardType
    let imminentRowID: TrainBoardRow.ID?
    /// Optional title override (e.g. "Programmed departures" for an out-of-window
    /// scheduled demo). Defaults to the board's "Next departures/arrivals" title.
    var titleKey: LocalizedStringKey? = nil

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                BoardSectionHeader(titleKey: titleKey ?? boardType.nextSectionTitleKey, systemImage: "tram.fill")

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        FeaturedTrainRowView(
                            row: row,
                            boardType: boardType,
                            isImminent: row.id == imminentRowID
                        )
                        if index < rows.count - 1 {
                            Rectangle()
                                .fill(BoardColors.gridLine)
                                .frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BoardColors.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BoardColors.borderDim, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// Small amber section header with an optional leading icon and an optional
/// trailing label (e.g. "See all" on the Viaggi dashboard).
struct BoardSectionHeader: View {
    let titleKey: LocalizedStringKey
    /// Pre-formatted (already localized) title, e.g. "Tutte le partenze da Padova".
    /// When set it overrides `titleKey` (rendered verbatim, still uppercased).
    var titleString: String? = nil
    var systemImage: String?
    var trailingKey: LocalizedStringKey? = nil
    var trailingAction: (() -> Void)? = nil

    private var titleText: Text {
        if let titleString { return Text(verbatim: titleString) }
        return Text(titleKey)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BoardColors.amber)
            }
            titleText
                .font(BoardFont.text(11, .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amber)
                .ledGlow(BoardColors.amber, radius: 2, opacity: 0.3)
            if let trailingKey {
                Spacer(minLength: 8)
                trailing(trailingKey)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func trailing(_ key: LocalizedStringKey) -> some View {
        if let trailingAction {
            Button(action: trailingAction) { trailingLabel(key) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(key))
                .accessibilityAddTraits(.isButton)
        } else {
            trailingLabel(key)
        }
    }

    private func trailingLabel(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(BoardFont.text(11, .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(BoardColors.amberDim)
    }
}
