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
    /// Presents the Info / reliability-disclaimer screen as a sheet. This is the
    /// entry point to `InfoView` after Info stopped being a primary tab.
    @State private var showsInfo = false
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
                    sourceIsFallback: viewModel.sourceIsFallback,
                    sourceIsStale: viewModel.sourceIsStale,
                    canChangeStation: viewModel.allowsStationChange,
                    animationToken: animationToken,
                    isFavorite: isFavorite,
                    onToggleFavorite: { isFavorite.toggle() },
                    onChangeStation: { Task { await viewModel.changeStation() } },
                    onShowInfo: { showsInfo = true }
                )
                .padding(.top, 2)

                #if DEBUG
                if AppEnvironment.sourceMode == .rfiLivePadova {
                    RFILiveDiagnosticsBanner()
                        .padding(.bottom, 2)
                }
                #endif

                BoardTypeSegmentedControl(
                    selected: viewModel.boardType,
                    onSelect: { viewModel.selectBoardType($0) }   // .task(id:) does the fetch
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                content

                BoardTickerView()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsInfo) {
            InfoView()
        }
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
        if viewModel.isBoardUnavailableForStation {
            // Expected state (station not served by the live board / unknown_station):
            // an honest message, never raw error text and never another station's rows.
            boardUnavailableState
        } else if let errorKey = viewModel.errorMessageKey, !viewModel.hasData {
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
                    titleKey: LocalizedStringKey(viewModel.featuredTitleKey)
                )

                TrainBoardListSectionView(
                    rows: viewModel.listRows,
                    boardType: viewModel.boardType,
                    stationName: viewModel.station.displayName,
                    selectedRowID: viewModel.imminentRowID
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh(force: true) }
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

    /// Honest "no live board for this station" state. Offers switching back to a
    /// served station rather than pretending data exists.
    private var boardUnavailableState: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.amberDim)
            Text("board.unavailableForStation")
                .font(BoardFont.text(15, .semibold))
                .foregroundStyle(BoardColors.amberBright)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.allowsStationChange {
                Button {
                    Task { await viewModel.changeStation() }
                } label: {
                    Text("action.changeStation.short")
                        .font(BoardFont.text(14, .bold))
                        .tracking(0.5)
                        .foregroundStyle(BoardColors.amber)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(BoardColors.amber.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
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
