//
//  TrainBoardRowView.swift
//  Binario1
//
//  One dense row of "Tutte le partenze":
//
//   ▌17:45  ES  9816   VENEZIA S.L. ............ 7'   [ 6 ]
//
//  time · italic category · number · destination · delay chip · platform box.
//  The selected row carries a left amber accent and a highlighted platform box.
//

import SwiftUI

struct TrainBoardRowView: View {
    let row: TrainBoardRow
    let boardType: BoardType
    var isSelected: Bool = false

    @Environment(\.dynamicTypeSize) private var typeSize

    private var place: String { BoardDestinationFormatter.display(row.displayPlace(for: boardType)) }
    private var dimmed: Bool { row.status.isPast || row.status.isCancelled }

    // Column widths (kept fixed for board alignment; relaxed at accessibility sizes).
    private var compact: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if compact { stacked } else { inline }
        }
        .padding(.vertical, 2)
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? BoardColors.amber.opacity(0.08) : .clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? BoardColors.amberBright : .clear)
                .frame(width: 3)
        }
        .opacity(dimmed ? 0.6 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BoardFormatters.accessibilityLabel(for: row, boardType: boardType)))
    }

    // MARK: Inline (default) layout

    private var inline: some View {
        HStack(spacing: 7) {
            timeText.frame(width: 52, alignment: .leading)
            categoryText.frame(width: 38, alignment: .leading)
            numberText.frame(width: 44, alignment: .leading)
            destText.frame(maxWidth: .infinity, alignment: .leading)
            delayColumn.frame(width: 42, alignment: .trailing)
            PlatformBadgeView(platform: row.platformDisplay, highlighted: isSelected, numberSize: 17)
                .frame(width: 54, alignment: .trailing)
        }
    }

    // MARK: Stacked layout (accessibility sizes)

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                timeText
                categoryText
                numberText
                Spacer(minLength: 0)
                PlatformBadgeView(platform: row.platformDisplay, highlighted: isSelected, numberSize: 17)
            }
            HStack(spacing: 8) {
                destText
                Spacer(minLength: 0)
                delayColumn
            }
        }
    }

    // MARK: Pieces

    private var timeText: some View {
        Text(row.timeString())
            .font(BoardFont.digits(15))
            .foregroundStyle(BoardColors.amber)
            .ledGlow(BoardColors.amber, radius: 2, opacity: 0.25)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var categoryText: some View {
        Text(row.category)
            .font(BoardFont.category(14).italic())
            .foregroundStyle(BoardColors.amber)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var numberText: some View {
        Text(row.trainNumber)
            .font(BoardFont.text(13))
            .foregroundStyle(BoardColors.amberDim)
            .lineLimit(1)
    }

    private var destText: some View {
        Text(place)
            .font(BoardFont.text(16, .semibold))
            .foregroundStyle(row.status.isCancelled ? BoardColors.amberDim : BoardColors.amberBright)
            .strikethrough(row.status.isCancelled, color: BoardColors.delay)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var delayColumn: some View {
        if row.hasDelay || row.status.isCancelled {
            DelayBadgeView(row: row, fontSize: 12)
        }
    }
}

#Preview {
    let rows = MockTrainBoardService.embeddedFallback.rows
    return VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
            TrainBoardRowView(row: r, boardType: .departures, isSelected: i == 0)
            Rectangle().fill(BoardColors.gridLine).frame(height: 1)
        }
    }
    .background(BoardColors.panel)
    .padding()
    .background(BoardColors.background)
}
