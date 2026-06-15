//
//  Binario1App.swift
//  Binario1
//
//  Created by Romesh Singhabahu on 13/06/26.
//

import SwiftUI

/// Composition root. Selects the board data source.
enum AppEnvironment {
    /// Flip to `.scheduledPadova` to drive the Home board from the RFI Quadro
    /// Orario programmed timetable (scheduled data, mock fallback). Default `.mock`.
    static let sourceMode: BoardSourceMode = .mock

    static func makeTrainBoardService() -> TrainBoardService {
        switch sourceMode {
        case .mock:
            return MockTrainBoardService()
        case .scheduledPadova, .remoteWithMockFallback:
            return ScheduledTrainBoardService(fallback: MockTrainBoardService())
        }
    }

    static var initialStation: Station {
        switch sourceMode {
        case .mock:                                   return .bolognaCentrale
        case .scheduledPadova, .remoteWithMockFallback: return .padova
        }
    }

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (`.scheduledPadova` = Padova Quadro Orario) MUST stay
    /// locked, otherwise the station title could disagree with the board rows.
    /// `.remoteWithMockFallback` is reserved for a future multi-station remote.
    static var allowsStationChange: Bool {
        switch sourceMode {
        case .mock, .remoteWithMockFallback: return true
        case .scheduledPadova:               return false
        }
    }
}

@main
struct Binario1App: App {
    var body: some Scene {
        WindowGroup {
            StationBoardView(
                viewModel: StationBoardViewModel(
                    service: AppEnvironment.makeTrainBoardService(),
                    station: AppEnvironment.initialStation,
                    allowsStationChange: AppEnvironment.allowsStationChange
                )
            )
        }
    }
}
