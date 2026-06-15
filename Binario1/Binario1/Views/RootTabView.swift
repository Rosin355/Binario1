//
//  RootTabView.swift
//  Binario1
//
//  Root tab navigation: Partenze (the station board), Viaggi (the commuter
//  dashboard) and Info. Viaggi is the second tab. Search is a later milestone.
//

import SwiftUI

struct RootTabView: View {
    @State private var stationViewModel = StationBoardViewModel(
        service: AppEnvironment.makeTrainBoardService(),
        station: AppEnvironment.initialStation,
        allowsStationChange: AppEnvironment.allowsStationChange
    )
    @State private var tripsViewModel = TripsViewModel(service: MockTripsService())

    var body: some View {
        TabView {
            Tab("tab.departures", systemImage: "tram.fill") {
                StationBoardView(viewModel: stationViewModel)
            }
            Tab("tab.trips", systemImage: "bookmark.fill") {
                TripsView(viewModel: tripsViewModel)
            }
            Tab("tab.info", systemImage: "info.circle") {
                InfoView()
            }
        }
        .tint(BoardColors.amber)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootTabView()
}
