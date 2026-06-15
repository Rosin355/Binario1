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
}

@main
struct Binario1App: App {
    var body: some Scene {
        WindowGroup {
            StationBoardView(
                viewModel: StationBoardViewModel(
                    service: AppEnvironment.makeTrainBoardService(),
                    station: AppEnvironment.initialStation
                )
            )
        }
    }
}
