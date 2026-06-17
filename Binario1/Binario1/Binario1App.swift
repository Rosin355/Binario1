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
    /// **DEBUG → `.backendFixturePadova` (backend-adapter Phase 1), RELEASE → `.mock`**.
    ///
    /// To switch DEBUG source, flip the value below:
    ///   • `.backendFixturePadova` — normalized backend JSON fixture (Phase 1 path)
    ///   • `.rfiLivePadova`        — DEBUG-only direct RFI live monitor (kept as dev fallback)
    ///   • `.scheduledPadova`      — PRM Quadro Orario programmed-timetable demo
    ///   • `.mock`                 — bundled mock (also the RELEASE default)
    /// All of these except `.mock` are **DEBUG-only**; RELEASE always uses `.mock`,
    /// so no spike/fixture can become the production default.
    #if DEBUG
    static let sourceMode: BoardSourceMode = .backendFixturePadova
    #else
    static let sourceMode: BoardSourceMode = .mock
    #endif

    static func makeTrainBoardService() -> TrainBoardService {
        switch sourceMode {
        case .mock:
            return MockTrainBoardService()
        case .scheduledPadova, .remoteWithMockFallback:
            return ScheduledTrainBoardService(fallback: MockTrainBoardService())
        case .rfiLivePadova:
            #if DEBUG
            return RFILiveBoardService(fallback: MockTrainBoardService())
            #else
            return MockTrainBoardService()   // spike never ships as a release default
            #endif
        case .backendFixturePadova:
            #if DEBUG
            return BackendBoardService(fallback: MockTrainBoardService())
            #else
            return MockTrainBoardService()   // backend fixture never ships as a release default
            #endif
        }
    }

    static var initialStation: Station {
        switch sourceMode {
        case .mock:
            return .bolognaCentrale
        case .scheduledPadova, .remoteWithMockFallback, .rfiLivePadova, .backendFixturePadova:
            return .padova
        }
    }

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (Padova scheduled demo or RFI live spike) MUST stay locked,
    /// otherwise the station title could disagree with the board rows.
    /// `.remoteWithMockFallback` is reserved for a future multi-station remote.
    static var allowsStationChange: Bool {
        switch sourceMode {
        case .mock, .remoteWithMockFallback:                            return true
        case .scheduledPadova, .rfiLivePadova, .backendFixturePadova:   return false
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
