//
//  RootTabView.swift
//  Binario1
//
//  Root tab navigation: Partenze (the station board), Viaggi (the commuter
//  dashboard) and Cerca (native search). Entering Partenze replays its intro
//  animation. The tab bar is themed to the matte-black / amber board identity.
//

import SwiftUI
import UIKit

/// Primary tabs. Tracked for selection so the Partenze intro animation can replay
/// on tab (re)entry.
enum AppTab: Hashable {
    case departures, trips, search
}

struct RootTabView: View {
    @State private var stationViewModel = StationBoardViewModel(
        service: AppEnvironment.makeTrainBoardService(),
        station: AppEnvironment.initialStation,
        allowsStationChange: AppEnvironment.allowsStationChange,
        savedJourneys: HomeSavedJourneys.current(),            // initial snapshot (persisted)
        savedJourneysProvider: { HomeSavedJourneys.current() } // re-read on refresh → reflects Viaggi deletes
    )
    @State private var tripsViewModel = TripsViewModel(service: MockTripsService())

    @State private var selectedTab: AppTab = .departures
    /// Bumped each time the Partenze tab is (re)selected → replays its intro animation.
    @State private var departuresAnimationToken = 0

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.departures", systemImage: "tram.fill", value: AppTab.departures) {
                StationBoardView(viewModel: stationViewModel, animationToken: departuresAnimationToken)
            }
            Tab("tab.trips", systemImage: "suitcase.fill", value: AppTab.trips) {
                TripsView(viewModel: tripsViewModel)
            }
            // Third primary tab is native Search (Cerca). The old Info/About
            // content (`InfoView`) is kept for a future secondary settings area.
            Tab("tab.search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                CercaView()
            }
        }
        .tint(BoardColors.amber)
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { _, newTab in
            // Replay the Partenze intro animation on (re)entry — no data reload.
            if newTab == .departures { departuresAnimationToken += 1 }
        }
    }

    /// Matte-black opaque tab bar with amber selection / dim unselected, so the
    /// bar matches the board identity instead of the default translucent chrome.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BoardColors.background)
        appearance.shadowColor = UIColor(BoardColors.gridLine)

        let amber = UIColor(BoardColors.amber)
        let dim = UIColor(BoardColors.amberDim)
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.selected.iconColor = amber
            item.selected.titleTextAttributes = [.foregroundColor: amber]
            item.normal.iconColor = dim
            item.normal.titleTextAttributes = [.foregroundColor: dim]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    RootTabView()
}
