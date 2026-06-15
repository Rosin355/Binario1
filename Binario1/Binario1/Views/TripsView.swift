//
//  TripsView.swift
//  Binario1
//
//  Viaggi — the personal commuter dashboard: saved routes, the best next trip,
//  recent journeys and quick actions. Keeps the Binario1 board identity (matte
//  black, amber, subtle texture/glow) but is more card-based than the board.
//

import SwiftUI

struct TripsView: View {
    @State var viewModel: TripsViewModel

    var body: some View {
        ZStack {
            BoardBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TripsHeaderView(onNewTrip: {})

                    TripsFilterControl(
                        selected: viewModel.selectedFilter,
                        onSelect: { viewModel.selectFilter($0) }
                    )

                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let errorKey = viewModel.errorMessageKey, !viewModel.hasData {
            errorState(errorKey)
        } else if viewModel.isLoading && !viewModel.hasData {
            ProgressView()
                .tint(BoardColors.amber)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            if viewModel.showsSuggestedSection, let suggested = viewModel.suggestedJourney {
                section("trips.section.useful", icon: "star.fill") {
                    UsefulJourneyCardView(journey: suggested)
                }
            }

            if viewModel.showsSavedSection {
                section("trips.section.saved", icon: "bookmark.fill", trailingKey: "trips.seeAll") {
                    VStack(spacing: 12) {
                        ForEach(viewModel.savedJourneys) { SavedJourneyCardView(journey: $0) }
                    }
                }
            }

            if viewModel.showsRecentSection {
                section("trips.section.recent", icon: "clock.arrow.circlepath", trailingKey: "trips.seeAll") {
                    recentPanel
                }
            }

            TripsQuickActionsView()
                .padding(.top, 2)
        }
    }

    private var recentPanel: some View {
        VStack(spacing: 0) {
            let rows = viewModel.recentJourneys
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, journey in
                RecentJourneyRowView(journey: journey)
                if index < rows.count - 1 {
                    Rectangle().fill(BoardColors.gridLine).frame(height: 1)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BoardColors.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BoardColors.borderDim, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func section<Content: View>(_ titleKey: LocalizedStringKey,
                                        icon: String,
                                        trailingKey: LocalizedStringKey? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardSectionHeader(titleKey: titleKey, systemImage: icon, trailingKey: trailingKey)
            content()
        }
    }

    private func errorState(_ key: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(BoardColors.delay)
            Text(LocalizedStringKey(key))
                .font(BoardFont.text(15))
                .foregroundStyle(BoardColors.amberBright)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

#Preview("Viaggi IT") {
    TripsView(viewModel: TripsViewModel(service: {
        let s = MockTripsService(); s.artificialDelay = .zero; return s
    }()))
    .environment(\.locale, Locale(identifier: "it"))
}

#Preview("Viaggi EN") {
    TripsView(viewModel: TripsViewModel(service: {
        let s = MockTripsService(); s.artificialDelay = .zero; return s
    }()))
    .environment(\.locale, Locale(identifier: "en"))
}
