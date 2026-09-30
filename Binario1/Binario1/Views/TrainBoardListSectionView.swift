//
//  TrainBoardListSectionView.swift
//  Binario1
//
//  "Tutte le partenze" / "Tutti gli arrivi" — the full board as a dense list,
//  with right-aligned RITARDO / BINARIO column labels and a selected row.
//

import SwiftUI

struct TrainBoardListSectionView: View {
    let rows: [TrainBoardRow]
    let boardType: BoardType
    var stationName: String = ""
    var selectedRowID: TrainBoardRow.ID?
    /// What following a row would start, or nil when it cannot honestly be followed.
    /// Nil closure → rows are not tappable (previews, non-live sources).
    var followTarget: ((TrainBoardRow) -> FollowedTrainTarget?)? = nil
    /// The one row currently showing the follow dialog (shared with the featured
    /// section: only one dialog may be armed board-wide).
    var followCandidate: Binding<FollowCandidate?> = .constant(nil)
    var followTracker: FollowedTrainTracker? = nil
    var onFollowError: () -> Void = {}

    /// "Tutte le partenze da Padova" / "Tutti gli arrivi a Padova" (uppercased by the
    /// section header). Falls back to the plain title when no station name is given.
    private var fullBoardTitle: String? {
        guard !stationName.isEmpty else { return nil }
        return String(format: NSLocalizedString(boardType.allSectionTitleFormatKey, comment: ""), stationName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    TrainBoardRowView(
                        row: row,
                        boardType: boardType,
                        isSelected: row.id == selectedRowID
                    )
                    .followableRow(
                        anchorID: "list-\(row.id)",
                        target: followTarget?(row),
                        candidate: followCandidate,
                        tracker: followTracker,
                        onFollowError: onFollowError
                    )
                    if index < rows.count - 1 {
                        Rectangle().fill(BoardColors.gridLine).frame(height: 1)
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

    private var header: some View {
        HStack(spacing: 8) {
            BoardSectionHeader(titleKey: boardType.allSectionTitleKey, titleString: fullBoardTitle)
            Text("column.delay.full")
                .lineLimit(1).fixedSize()
                .frame(width: 46, alignment: .trailing)
            Text("column.platform.full")
                .lineLimit(1).fixedSize()
                .frame(width: 54, alignment: .trailing)
        }
        .font(BoardFont.text(9, .semibold))
        .tracking(0.5)
        .foregroundStyle(BoardColors.amberFaint)
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

#Preview {
    let rows = MockTrainBoardService.embeddedFallback.rows
    return ScrollView {
        TrainBoardListSectionView(rows: rows, boardType: .departures, selectedRowID: rows.first?.id)
            .padding()
    }
    .background(BoardColors.background)
}
