//
//  RootTabView.swift
//  Binario1
//
//  Root tab navigation: Partenze (the station board), Viaggi (the commuter
//  dashboard) and Info. Viaggi is the second tab. Search is a later milestone.
//  The tab bar is themed to the matte-black / amber board identity.
//

import SwiftUI
import UIKit

struct RootTabView: View {
    @State private var stationViewModel = StationBoardViewModel(
        service: AppEnvironment.makeTrainBoardService(),
        station: AppEnvironment.initialStation,
        allowsStationChange: AppEnvironment.allowsStationChange
    )
    @State private var tripsViewModel = TripsViewModel(service: MockTripsService())

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            Tab("tab.departures", systemImage: "tram.fill") {
                StationBoardView(viewModel: stationViewModel)
            }
            Tab("tab.trips", systemImage: "suitcase.fill") {
                TripsView(viewModel: tripsViewModel)
            }
            // Third primary tab is now native Search (Cerca). The old Info/About
            // content (`InfoView`) is kept for a future secondary settings area.
            Tab("tab.search", systemImage: "magnifyingglass", role: .search) {
                CercaView()
            }
        }
        .tint(BoardColors.amber)
        .preferredColorScheme(.dark)
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
