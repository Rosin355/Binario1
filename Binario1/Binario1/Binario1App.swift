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
                            stampSourceKind: .backendFixture,
                            // The fixture (and its mock fallback) only stand for Padova:
                            // any other station gets the honest unavailable state.
                            fallbackStationID: Station.padova.id)
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
            debugLogTag: "BackendLive",
            // The bundled fallback fixture is PADOVA: it may only stand in for Padova.
            // Any other station failing (e.g. 404 unknown_station) surfaces
            // BoardUnavailableError → honest state, never another station's board.
            fallbackStationID: Station.padova.id)
    }
    #endif

    static var initialStation: Station {
        switch sourceMode {
        case .mock:
            return .bolognaCentrale
        case .backendLivePadova:
            // Prefer the CATALOG entry (same id/slug the backend registry uses, plus
            // its live-served flag) so header, fetch slug and picker stay consistent.
            return DefaultStationCatalog.shared.station(named: Station.padova.displayName) ?? .padova
        case .scheduledPadova, .remoteWithMockFallback, .rfiLivePadova,
             .backendFixturePadova:
            return .padova
        }
    }

    /// Whether the header `Cambia` action may open the station picker. A single fixed
    /// station source (Padova scheduled demo, RFI live spike, local fixture) MUST stay
    /// locked, otherwise the station title could disagree with the board rows.
    ///
    /// B3-full: this used to read `selectableStations.count > 1`, a leftover from the
    /// carousel that C3 replaced with the search sheet. The condition was already
    /// conceptually stale then — with a picker over the whole catalog, "how many
    /// stations are served" is the wrong question — and with national coverage it is
    /// trivially true, which is worse: a condition that can no longer be false hides
    /// what it was meant to protect. What actually matters is whether the source is
    /// multi-station at all, so that is what it now says.
    static var allowsStationChange: Bool {
        switch sourceMode {
        case .mock, .remoteWithMockFallback, .backendLivePadova:
            return true
        case .scheduledPadova, .rfiLivePadova, .backendFixturePadova:
            return false
        }
    }

    /// Stations for which THIS build can honestly show a station board (the Cerca
    /// "apri il tabellone" destination).
    ///
    /// Live backend → exactly the registry slugs the backend serves (derived from the
    /// catalog's `servedByLiveBoard` flag via `liveServedStationIDs`). Every other
    /// source has NO live restriction (`liveServedStationIDs == nil`) *because its
    /// service ignores `stationId`*: `MockTrainBoardService` always returns the bundled
    /// Bologna dataset, the scheduled/fixture sources always return Padova. Left
    /// unrestricted, opening an arbitrary catalog station from Cerca would paint that
    /// one dataset under a DIFFERENT station's name. So those sources collapse to the
    /// single station they actually stand for — honest in every configuration.
    ///
    /// Never empty. Since B3-full the live registry covers the whole artifact, so for
    /// the live source this set legitimately IS the whole catalog — the backend really
    /// does serve every one of them. The guardrail it enforces is unchanged: a station
    /// OUTSIDE the served set must never become openable.
    static var boardStationIDs: Set<String> {
        liveServedStationIDs ?? [initialStation.id]
    }

    /// Board view model for a station opened from Cerca. Same service / catalog /
    /// saved-journey wiring as the Partenze tab, so it is the SAME experience — with
    /// two deliberate differences:
    ///  • the station is LOCKED (`allowsStationChange: false`): the user searched this
    ///    station, the header must never cycle away from it;
    ///  • `liveServedStationIDs` is always non-nil, so the existing guardrails stay
    ///    armed — a station outside `boardStationIDs` short-circuits to the honest
    ///    "board unavailable" state WITHOUT any fetch, and the response-identity check
    ///    (`validatesStationIdentity`) rejects rows that claim another station.
    @MainActor
    static func makeStationBoardViewModel(for station: Station) -> StationBoardViewModel {
        StationBoardViewModel(
            service: makeTrainBoardService(),
            station: station,
            allowsStationChange: false,
            savedJourneys: HomeSavedJourneys.current(),
            savedJourneysProvider: { HomeSavedJourneys.current() },
            catalog: DefaultStationCatalog.shared,
            liveServedStationIDs: boardStationIDs
        )
    }

    /// Ids of the stations the LIVE board serves. Nil when the source isn't the live
    /// backend (no station restriction applies — e.g. the mock carousel).
    static var liveServedStationIDs: Set<String>? {
        switch sourceMode {
        case .backendLivePadova:
            return Set(DefaultStationCatalog.shared.liveServed.map(\.id))
        case .mock, .remoteWithMockFallback, .scheduledPadova, .rfiLivePadova, .backendFixturePadova:
            return nil
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
