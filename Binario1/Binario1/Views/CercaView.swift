//
//  CercaView.swift
//  Binario1
//
//  The Cerca (Search) tab — backs the native `Tab(role: .search)`. Uses the system
//  `.searchable` field; when idle it offers three category entries (stazione /
//  tratta / treno), and while searching it shows mock results grouped into
//  Stazioni / Tratte / Treni (or "Nessun risultato"). Mock data only.
//

import SwiftUI

struct CercaView: View {
    @State private var viewModel = CercaViewModel()

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
            .navigationTitle("tab.search")
            .searchable(text: $vm.query, prompt: Text("search.prompt"))
        }
        .preferredColorScheme(.dark)
        // Re-sync saved state on (re)appear so a deletion made in Viaggi clears the
        // stale "Saved" state and re-enables saving.
        .task { viewModel.refreshSavedState() }
    }

    @ViewBuilder
    private var content: some View {
        if let mode = viewModel.selectedMode {
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

    // MARK: - Grouped results (free-text search without a chosen mode)

    @ViewBuilder
    private var groupedResults: some View {
        if viewModel.hasResults {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.stations.isEmpty {
                    resultSection("search.stations", "tram.fill",
                                  viewModel.stations, rowIcon: "mappin.and.ellipse")
                }
                if !viewModel.routes.isEmpty {
                    resultSection("search.routes", "arrow.left.arrow.right",
                                  viewModel.routes, rowIcon: "arrow.triangle.swap", savable: true)
                }
                if !viewModel.trains.isEmpty {
                    resultSection("search.trains", "train.side.front.car",
                                  viewModel.trains, rowIcon: "train.side.front.car")
                }
            }
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

    // MARK: - Results

    private func resultSection(_ titleKey: LocalizedStringKey, _ icon: String,
                               _ items: [String], rowIcon: String, savable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardSectionHeader(titleKey: titleKey, systemImage: icon)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    resultRow(item, icon: rowIcon, savable: savable)
                    if index < items.count - 1 {
                        Rectangle().fill(BoardColors.gridLine).frame(height: 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BoardColors.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BoardColors.borderDim, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func resultRow(_ text: String, icon: String, savable: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 22)
            Text(text)
                .font(BoardFont.text(15, .semibold))
                .foregroundStyle(BoardColors.amberBright)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Spacer(minLength: 6)
            if savable, viewModel.canSaveRoute(text) {
                saveRouteButton(text)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        // Savable rows keep the save button as its own accessible element.
        .accessibilityElement(children: savable ? .contain : .combine)
    }

    /// Small bookmark save affordance for a route row; shows "Saved" once persisted.
    @ViewBuilder
    private func saveRouteButton(_ route: String) -> some View {
        let saved = viewModel.isRouteSaved(route)
        Button {
            viewModel.saveRoute(route)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12, weight: .semibold))
                Text(saved ? "search.saved" : "search.save")
                    .font(BoardFont.text(11, .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(saved ? BoardColors.amberBright : BoardColors.amber)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke((saved ? BoardColors.amberBright : BoardColors.amber).opacity(0.5), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(saved)
        .accessibilityLabel(Text(saved ? "search.saved" : "action.saveJourney"))
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

    // MARK: - Route mode — Partenza / Destinazione / swap / save

    private var routeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            routeField("search.departure", text: $viewModel.departureField)

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

            routeField("search.destination", text: $viewModel.destinationField)

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

    // MARK: - Station mode (informational: live board is Padova-only for now)

    @ViewBuilder
    private var stationModeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.stations.isEmpty {
                emptyState
            } else {
                resultSection("search.stations", "tram.fill",
                              viewModel.stations, rowIcon: "mappin.and.ellipse")
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
}

#Preview("Cerca IT") {
    CercaView().environment(\.locale, Locale(identifier: "it"))
}

#Preview("Cerca EN") {
    CercaView().environment(\.locale, Locale(identifier: "en"))
}
