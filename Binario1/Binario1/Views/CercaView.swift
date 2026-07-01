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
        if viewModel.isSearching {
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
        } else {
            VStack(spacing: 12) {
                categoryRow("search.station", "mappin.and.ellipse")
                categoryRow("search.route", "arrow.triangle.swap")
                categoryRow("search.train", "train.side.front.car")
            }
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
}

#Preview("Cerca IT") {
    CercaView().environment(\.locale, Locale(identifier: "it"))
}

#Preview("Cerca EN") {
    CercaView().environment(\.locale, Locale(identifier: "en"))
}
