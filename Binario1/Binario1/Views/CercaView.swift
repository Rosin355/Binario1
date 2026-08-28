//
//  CercaView.swift
//  Binario1
//
//  The Cerca (Search) tab — backs the native `Tab(role: .search)`. Uses the system
//  `.searchable` field; when idle it offers three category entries (stazione /
//  tratta / treno). Station search draws real catalog ENTITIES; the route form's
//  PARTENZA / DESTINAZIONE resolve to catalog stations (canonical names) before
//  saving, so a saved route matches the live board reliably (B4).
//

import SwiftUI

struct CercaView: View {
    /// When set, Cerca acts as a station PICKER (the Partenze "Cambia" sheet): the
    /// station list only, every row REPORTS BACK through this closure instead of
    /// pushing a board, and a Close item is offered. Nil = the full Cerca tab.
    /// Same view, same view model — the two entry points cannot drift apart.
    private let onSelectStation: ((Station) -> Void)?
    private let onCancel: (() -> Void)?

    @State private var viewModel = CercaViewModel()

    /// Explicit init: the memberwise one would be private (the `@State` is private),
    /// and `CercaView()` must keep working for the tab.
    init(onSelectStation: ((Station) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onSelectStation = onSelectStation
        self.onCancel = onCancel
    }

    private var isPicker: Bool { onSelectStation != nil }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack {
                BoardBackgroundView()
                ScrollView {
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isPicker ? "search.picker.title" : "tab.search")
            .navigationBarTitleDisplayMode(isPicker ? .inline : .automatic)
            .searchable(text: $vm.query, prompt: Text("search.prompt"))
            .toolbar {
                if isPicker {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.close") { onCancel?() }
                    }
                }
            }
            // Tapping a station opens the SAME board screen the Partenze tab shows,
            // built by the composition root (no duplicated wiring). A station the
            // build can't honestly serve renders the existing honest state there and
            // never fetches — see `AppEnvironment.makeStationBoardViewModel(for:)`.
            .navigationDestination(for: Station.self) { station in
                StationBoardView(viewModel: AppEnvironment.makeStationBoardViewModel(for: station))
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .preferredColorScheme(.dark)
        // Re-sync saved state on (re)appear so a deletion made in Viaggi clears the
        // stale "Saved" state and re-enables saving.
        .task { viewModel.refreshSavedState() }
    }

    @ViewBuilder
    private var content: some View {
        if isPicker {
            // Picker: the station list only — no category cards, no mode header (and
            // so no back chevron): the sheet itself is the way out.
            stationModeContent
        } else if let mode = viewModel.selectedMode {
            VStack(alignment: .leading, spacing: 16) {
                modeHeader(mode)
                switch mode {
                case .station: stationModeContent
                case .route:   routeForm
                case .train:   trainComingSoon
                }
            }
        } else if viewModel.isSearching {
            groupedResults
        } else {
            categoryCards
        }
    }

    // MARK: - Grouped results (free-text search without a chosen mode) → stations only

    @ViewBuilder
    private var groupedResults: some View {
        if viewModel.hasResults {
            stationsSection(viewModel.stations)
        } else {
            emptyState
        }
    }

    // MARK: - Category cards → open a search mode

    private var categoryCards: some View {
        VStack(spacing: 12) {
            categoryButton(.station, "search.station", "mappin.and.ellipse")
            categoryButton(.route, "search.route", "arrow.triangle.swap")
            categoryButton(.train, "search.train", "train.side.front.car")
        }
    }

    private func categoryButton(_ mode: SearchMode, _ titleKey: LocalizedStringKey, _ icon: String) -> some View {
        Button { viewModel.selectMode(mode) } label: { categoryRow(titleKey, icon) }
            .buttonStyle(.plain)
    }

    private func modeHeader(_ mode: SearchMode) -> some View {
        HStack(spacing: 10) {
            Button { viewModel.selectMode(nil) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BoardColors.amber)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(BoardColors.amber.opacity(0.5), lineWidth: 1.2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            BoardSectionHeader(titleKey: modeTitleKey(mode), systemImage: modeIcon(mode))
        }
    }

    private func modeTitleKey(_ mode: SearchMode) -> LocalizedStringKey {
        switch mode {
        case .station: "search.station"
        case .route:   "search.route"
        case .train:   "search.train"
        }
    }

    private func modeIcon(_ mode: SearchMode) -> String {
        switch mode {
        case .station: "mappin.and.ellipse"
        case .route:   "arrow.triangle.swap"
        case .train:   "train.side.front.car"
        }
    }

    // MARK: - Station results (real catalog entities)

    private func stationsSection(_ stations: [Station]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardSectionHeader(titleKey: "search.stations", systemImage: "tram.fill")
            panelList(stations) { station in
                if let onSelectStation {
                    // Picker: report the choice back; the tab REPLACES its station.
                    // No push, no stack, no back chevron.
                    Button { onSelectStation(station) } label: { stationRow(station) }
                        .buttonStyle(.plain)
                } else {
                    NavigationLink(value: station) { stationRow(station) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func stationRow(_ station: Station) -> some View {
        let hasBoard = viewModel.hasLiveBoard(station)
        return HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName)
                    .font(BoardFont.text(15, .semibold))
                    .foregroundStyle(BoardColors.amberBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let city = station.city, city != station.displayName {
                    Text(city)
                        .font(BoardFont.text(11))
                        .foregroundStyle(BoardColors.amberDim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            // Only stations this build can honestly serve advertise a board, so the
            // user doesn't tap into the unavailable state by accident.
            if hasBoard {
                liveBadge
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BoardColors.amberDim)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(hasBoard ? Text("accessibility.station.liveBoard") : Text(verbatim: ""))
    }

    /// Compact amber chip marking a station with a real-time board — same vocabulary
    /// as the board header's "DATI LIVE" label.
    private var liveBadge: some View {
        Text("search.station.liveBadge")
            .font(BoardFont.text(9, .bold))
            .tracking(1)
            .foregroundStyle(BoardColors.amber)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(BoardColors.amber.opacity(0.55), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    // MARK: - Idle categories

    private func categoryRow(_ titleKey: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BoardColors.amber.opacity(0.12))
                    .overlay(Circle().stroke(BoardColors.amber.opacity(0.55), lineWidth: 1.2))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BoardColors.amber)
            }
            .frame(width: 42, height: 42)
            Text(titleKey)
                .font(BoardFont.text(16, .semibold))
                .foregroundStyle(BoardColors.amberBright)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BoardColors.amberDim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BoardColors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BoardColors.borderDim, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.amberDim)
            Text("search.noResults")
                .font(BoardFont.text(15))
                .foregroundStyle(BoardColors.amberDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Route mode — Partenza / Destinazione / swap / save (catalog entities)

    private var routeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            routeStationField("search.departure", text: $viewModel.departureField,
                              suggestions: viewModel.departureSuggestions(),
                              onPick: { viewModel.selectDeparture($0) })

            HStack {
                Spacer()
                Button { viewModel.swapRoute() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("search.swapRoute")
                    }
                    .font(BoardFont.text(12, .semibold))
                    .foregroundStyle(BoardColors.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BoardColors.amber.opacity(0.5), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("search.swapRoute"))
            }

            routeStationField("search.destination", text: $viewModel.destinationField,
                              suggestions: viewModel.destinationSuggestions(),
                              onPick: { viewModel.selectDestination($0) })

            Text("search.route.pickStations")
                .font(BoardFont.text(11))
                .foregroundStyle(BoardColors.amberDim)
                .fixedSize(horizontal: false, vertical: true)

            Button { viewModel.saveCurrentRoute() } label: {
                Text("search.saveRoute")
                    .font(BoardFont.text(15, .bold))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(viewModel.canSaveCurrentRoute ? BoardColors.background : BoardColors.amberDim)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.canSaveCurrentRoute ? BoardColors.amber : BoardColors.panel))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BoardColors.borderDim, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSaveCurrentRoute)
            .accessibilityLabel(Text("search.saveRoute"))
        }
    }

    /// A route field + its live catalog suggestions (tap to select a canonical station).
    private func routeStationField(_ labelKey: LocalizedStringKey, text: Binding<String>,
                                   suggestions: [Station], onPick: @escaping (Station) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            routeField(labelKey, text: text)
            if !suggestions.isEmpty {
                panelList(suggestions) { station in
                    Button { onPick(station) } label: { suggestionRow(station) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func suggestionRow(_ station: Station) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 18)
            Text(station.displayName)
                .font(BoardFont.text(14, .semibold))
                .foregroundStyle(BoardColors.amberBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 6)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
    }

    private func routeField(_ labelKey: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelKey)
                .font(BoardFont.text(9, .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amberDim)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(BoardFont.text(16, .semibold))
                .foregroundStyle(BoardColors.amberBright)
                .tint(BoardColors.amber)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BoardColors.panel))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BoardColors.borderDim, lineWidth: 1))
        }
    }

    // MARK: - Station mode (tap a station → its board; LIVE chip marks the served ones)

    @ViewBuilder
    private var stationModeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // An empty field shows the INITIAL list (live-board stations first), never
            // an empty state that reads like a failure. "No results" is reserved for a
            // typed query that genuinely matched nothing.
            if viewModel.showsNoResults {
                emptyState
            } else {
                stationsSection(viewModel.stationResults)
            }
            Text("search.station.note")
                .font(BoardFont.text(12))
                .foregroundStyle(BoardColors.amberDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Train mode (no live lookup yet — clear coming state)

    private var trainComingSoon: some View {
        VStack(spacing: 12) {
            Image(systemName: "train.side.front.car")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.amberDim)
            Text("search.train.coming")
                .font(BoardFont.text(14))
                .foregroundStyle(BoardColors.amberDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Shared panel list container

    private func panelList<Element: Identifiable, RowContent: View>(
        _ items: [Element],
        @ViewBuilder row: @escaping (Element) -> RowContent
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, element in
                row(element)
                if index < items.count - 1 {
                    Rectangle().fill(BoardColors.gridLine).frame(height: 1)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BoardColors.panel))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BoardColors.borderDim, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("Cerca IT") {
    CercaView().environment(\.locale, Locale(identifier: "it"))
}

#Preview("Cerca EN") {
    CercaView().environment(\.locale, Locale(identifier: "en"))
}
