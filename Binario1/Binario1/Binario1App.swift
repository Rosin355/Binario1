//
//  Binario1App.swift
//  Binario1
//
//  Created by Romesh Singhabahu on 13/06/26.
//

import SwiftUI

/// Composition root. Selects the board data source.
enum AppEnvironment {
    /// Active board data source, resolved per build configuration:
    /// **DEBUG → `.scheduledPadova`, RELEASE → `.mock`**.
    ///
    /// `.scheduledPadova` is a **DEBUG-only local demo**: the Home / Partenze
    /// board previews the RFI "Quadro Orario" *programmed* timetable for Padova.
    /// This is **scheduled data, NOT live data** — it has no real delays,
    /// cancellations or real-time platform changes, and it must **never** be
    /// presented as real-time railway truth. RELEASE builds fall back to `.mock`
    /// so this demo source can never become the production default.
    ///
    /// For UI work, set the active value to `.mock` (bundled Bologna mock board,
    /// station carousel enabled).
    #if DEBUG
    static let sourceMode: BoardSourceMode = .scheduledPadova
    #else
    static let sourceMode: BoardSourceMode = .mock
    #endif

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
            RootTabView()
        }
    }
}
