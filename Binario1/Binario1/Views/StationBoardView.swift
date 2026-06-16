//
//  StationBoardView.swift
//  Binario1
//
//  Mobile-first Binario1 board: app header, board-type control, a spacious
//  "next departures" section, the full board list, and a subtle ticker —
//  all keeping the physical-tabellone identity.
//

import SwiftUI

struct StationBoardView: View {
    @State var viewModel: StationBoardViewModel
    @State private var isFavorite = false
    /// Bumped when the Partenze tab is (re)entered → replays the title intro
    /// animation without reloading data.
    var animationToken: Int = 0

    var body: some View {
        ZStack {
            BoardBackgroundView()

            VStack(spacing: 0) {
                StationBoardHeaderView(
                    stationName: viewModel.station.displayName,
                    lastUpdated: viewModel.lastUpdated,
                    isStale: viewModel.isStale,
                    isScheduled: viewModel.isScheduled,
                    scheduledWindow: viewModel.scheduledWindow,
                    sourceKind: viewModel.sourceKind,
                    canChangeStation: viewModel.allowsStationChange,
                    animationToken: animationToken,
                    isFavorite: isFavorite,
                    onToggleFavorite: { isFavorite.toggle() },
                    onChangeStation: { Task { await viewModel.changeStation() } }
                )
                .padding(.top, 2)

                BoardTypeSegmentedControl(
                    selected: viewModel.boardType,
                    onSelect: { type in
                        Task { await viewModel.selectBoardType(type) }
                    }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                content

                BoardTickerView()
            }
        }
        .preferredColorScheme(.dark)
        .task(id: viewModel.boardType) {
            await viewModel.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if let errorKey = viewModel.errorMessageKey, !viewModel.hasData {
            errorState(errorKey)
        } else if viewModel.isLoading && !viewModel.hasData {
            loadingState
        } else if viewModel.isEmpty {
            emptyState
        } else {
            board
        }
    }

    private var board: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                NextDeparturesSectionView(
                    rows: viewModel.featuredRows,
                    boardType: viewModel.boardType,
                    imminentRowID: viewModel.imminentRowID,
                    titleKey: viewModel.isScheduledSampleOutOfWindow
                        ? LocalizedStringKey("section.programmedDepartures") : nil
                )

                TrainBoardListSectionView(
                    rows: viewModel.listRows,
                    boardType: viewModel.boardType,
                    selectedRowID: viewModel.imminentRowID
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(BoardColors.amber)
            Text("label.loading")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(BoardColors.amberDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ key: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.delay)
            Text(LocalizedStringKey(key))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(BoardColors.amberBright)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("action.retry")
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(BoardColors.amber)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(BoardColors.amber.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tram")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.amberDim)
            Text("empty.noTrains")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(BoardColors.amberDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Departures IT") {
    StationBoardView(viewModel: StationBoardViewModel(service: MockTrainBoardService()))
        .environment(\.locale, Locale(identifier: "it"))
}

#Preview("Departures EN") {
    StationBoardView(viewModel: StationBoardViewModel(service: MockTrainBoardService()))
        .environment(\.locale, Locale(identifier: "en"))
}
