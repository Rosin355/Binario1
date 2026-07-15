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
    /// **DEBUG → `.backendLivePadova`, TESTFLIGHT → `.backendLivePadova`,
    /// RELEASE → `.mock`**.
    ///
    /// To switch DEBUG source, flip the value below:
    ///   • `.backendLivePadova`    — deployed Supabase backend adapter (falls back to
    ///                               the fixture when the endpoint is not configured)
    ///   • `.backendFixturePadova` — normalized backend JSON fixture (Phase 1 path)
    ///   • `.rfiLivePadova`        — DEBUG-only direct RFI live monitor (dev fallback)
    ///   • `.scheduledPadova`      — PRM Quadro Orario programmed-timetable demo
    ///   • `.mock`                 — bundled mock (also the plain-RELEASE default)
    ///
    /// `TESTFLIGHT` is set ONLY by the dedicated TestFlight archive build
    /// configuration (a Release-family config that also bakes in the backend app
    /// token). A plain RELEASE build has neither `DEBUG` nor `TESTFLIGHT` defined and
    /// therefore always resolves to `.mock` — no spike/fixture/backend mode can ever
    /// become the production (App Store) default.
    #if DEBUG
    static let sourceMode: BoardSourceMode = .backendLivePadova
    #elseif TESTFLIGHT
    static let sourceMode: BoardSourceMode = .backendLivePadova
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
            return makeBackendFixtureService()
            #else
            return MockTrainBoardService()   // backend fixture never ships as a release default
            #endif
        case .backendLivePadova:
            #if DEBUG || TESTFLIGHT
            return makeBackendLiveService()
            #else
            return MockTrainBoardService()   // backend live never ships as a plain-release default
            #endif
        }
    }

    #if DEBUG || TESTFLIGHT
    /// Local normalized-fixture backend service (no network). Also the fallback used
    /// by `makeBackendLiveService` when the endpoint is unreachable, so it must be
    /// available under TESTFLIGHT too (not only DEBUG).
    private static func makeBackendFixtureService() -> TrainBoardService {
        BackendBoardService(fetcher: FixtureBackendBoardFetcher(),
                            fallback: MockTrainBoardService(),
                            stampSourceKind: .backendFixture)
    }

    /// Deployed backend adapter. When the endpoint URL is configured, calls the
    /// Supabase `/board` function; on any failure it falls back to the local backend
    /// fixture (NOT silently — `BackendBoardService` logs `[BackendLive] FALLBACK …`).
    /// When the URL is still a placeholder, it uses the fixture directly.
    private static func makeBackendLiveService() -> TrainBoardService {
        let cfg = BackendEndpointConfig.debug
        guard cfg.isConfigured else {
            print("[BackendLive] base URL not configured (placeholder) → using fixture · set BackendEndpointConfig.debug")
            return makeBackendFixtureService()
        }
        return BackendBoardService(
            fetcher: URLSessionBackendBoardFetcher(config: cfg),
            fallback: makeBackendFixtureService(),
            stampSourceKind: .backendLive,
            debugLogTag: "BackendLive")
    }
    #endif

    static var initialStation: Station {
        switch sourceMode {
        case .mock:
            return .bolognaCentrale
        case .scheduledPadova, .remoteWithMockFallback, .rfiLivePadova,
             .backendFixturePadova, .backendLivePadova:
            return .padova
        }
    }

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (Padova scheduled demo or RFI live spike) MUST stay locked,
    /// otherwise the station title could disagree with the board rows.
    /// `.remoteWithMockFallback` is reserved for a future multi-station remote.
    static var allowsStationChange: Bool {
        switch sourceMode {
        case .mock, .remoteWithMockFallback:
            return true
        case .scheduledPadova, .rfiLivePadova, .backendFixturePadova, .backendLivePadova:
            return false
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
