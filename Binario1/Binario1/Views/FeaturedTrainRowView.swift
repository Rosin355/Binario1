//
//  FeaturedTrainRowView.swift
//  Binario1
//
//  A featured "Prossime partenze" row laid out as a board grid:
//
//    17:12 │ ICN 794          +15' │ BINARIO
//          │ TORINO P.N.           │   1
//
//  Columns are separated by faint vertical dividers. The imminent row gets a
//  brighter amber outline.
//

import SwiftUI

struct FeaturedTrainRowView: View {
    let row: TrainBoardRow
    let boardType: BoardType
    var isImminent: Bool = false

    private var place: String { BoardDestinationFormatter.display(row.displayPlace(for: boardType)) }
    private var hasDelayChip: Bool { row.hasDelay || row.status.isCancelled }

    var body: some View {
        HStack(spacing: 0) {
            // Time
            Text(row.timeString())
                .font(BoardFont.digits(24))
                .foregroundStyle(BoardColors.amber)
                .ledGlow(BoardColors.amber, radius: 3, opacity: 0.32)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 14)

            divider

            // Train + destination (+ delay chip)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(row.category)
                            .font(BoardFont.category(13).italic())
                            .foregroundStyle(BoardColors.amber)
                            .lineLimit(1)
                            .fixedSize()
                        Text(row.trainNumber)
                            .font(BoardFont.text(12))
                            .foregroundStyle(BoardColors.amberDim)
                    }
                    Text(place)
                        .font(BoardFont.text(18, .semibold))
                        .foregroundStyle(row.status.isCancelled ? BoardColors.amberDim : BoardColors.amberBright)
                        .strikethrough(row.status.isCancelled, color: BoardColors.delay)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 6)
                if hasDelayChip {
                    DelayBadgeView(row: row, showPlusSign: true, fontSize: 13)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)

            divider

            // Platform
            VStack(spacing: 0) {
                Text("column.platform.full")
                    .font(BoardFont.text(8, .semibold))
                    .tracking(1)
                    .foregroundStyle(BoardColors.amberDim)
                Text(row.platformDisplay)
                    .font(BoardFont.digits(23))
                    .foregroundStyle(BoardColors.platform)
                    .ledGlow(BoardColors.platform, radius: 4, opacity: 0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 80)
        }
        .frame(minHeight: 54)
        .background(isImminent ? BoardColors.amber.opacity(0.07) : .clear)
        .overlay {
            if isImminent {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(BoardColors.amberBright.opacity(0.9), lineWidth: 1.6)
                    .padding(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BoardFormatters.accessibilityLabel(for: row, boardType: boardType)))
    }

    private var divider: some View {
        Rectangle()
            .fill(BoardColors.gridLine)
            .frame(width: 1)
            .padding(.vertical, 9)
    }
}

#Preview {
    let rows = MockTrainBoardService.embeddedFallback.rows
    return VStack(spacing: 0) {
        FeaturedTrainRowView(row: rows[0], boardType: .departures)
        FeaturedTrainRowView(row: rows[1], boardType: .departures)
        FeaturedTrainRowView(row: rows[2], boardType: .departures, isImminent: true)
    }
    .background(BoardColors.panel)
    .padding()
    .background(BoardColors.background)
}
