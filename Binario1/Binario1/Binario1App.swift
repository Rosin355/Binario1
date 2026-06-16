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
    /// **DEBUG → `.rfiLivePadova` (real-data spike), RELEASE → `.mock`**.
    ///
    /// `.rfiLivePadova` is a **DEBUG-only** adapter that reads the RFI live station
    /// monitor for Padova (live monitor placeId 2000). It is a technical validation
    /// spike — not a production guarantee — and falls back to mock on any
    /// fetch/parse failure. `.scheduledPadova` (PRM Quadro Orario demo) remains
    /// available; flip the value below to use it. RELEASE always uses `.mock`, so
    /// neither spike can become the production default.
    #if DEBUG
    static let sourceMode: BoardSourceMode = .rfiLivePadova
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
        }
    }

    static var initialStation: Station {
        switch sourceMode {
        case .mock:                                                     return .bolognaCentrale
        case .scheduledPadova, .remoteWithMockFallback, .rfiLivePadova: return .padova
        }
    }

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (Padova scheduled demo or RFI live spike) MUST stay locked,
    /// otherwise the station title could disagree with the board rows.
    /// `.remoteWithMockFallback` is reserved for a future multi-station remote.
    static var allowsStationChange: Bool {
        switch sourceMode {
        case .mock, .remoteWithMockFallback:   return true
        case .scheduledPadova, .rfiLivePadova: return false
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
