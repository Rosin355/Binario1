//
//  BackendBoardService.swift
//  Binario1
//
//  Phase 1 of the backend-adapter migration (see docs/13_BACKEND_ADAPTER.md):
//  an app-facing `TrainBoardService` that consumes the *normalized backend JSON*
//  contract via a `BackendBoardFetching` source. This phase ships only the local
//  **fixture** fetcher — NO live backend networking yet. Decodes `BackendBoardDTO`
//  and maps it through `BackendBoardMapper`; any decode/map failure or empty board
//  falls back to the mock service (mandatory).
//

import Foundation

/// Source of normalized backend board JSON. Phase 1 implements only the fixture
/// fetcher; a live `URLSession` fetcher arrives in Phase 2.
protocol BackendBoardFetching: Sendable {
    func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data
}

/// Local fixture fetcher: loads the bundled normalized DEPARTURES fixture JSON. No
/// network. There is no arrivals fixture, so arrivals throw → the service falls back.
///
/// The bundled fixture describes ONE station (Padova). It therefore refuses any other
/// slug instead of silently returning Padova's board for it — defense in depth against
/// showing one station's rows under another station's name.
struct FixtureBackendBoardFetcher: BackendBoardFetching {
    var resourceName: String = "backend-padova-departures.sample"
    var bundle: Bundle = .main
    /// The station this fixture actually represents.
    var stationSlug: String = "padova"

    func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
        guard type == .departures else { throw TrainBoardServiceError.resourceMissing }  // departures-only fixture
        guard stationSlug.trimmingCharacters(in: .whitespaces).lowercased()
                == self.stationSlug.lowercased() else {
            throw BoardUnavailableError.stationNotServed(stationID: stationSlug)         // not this fixture's station
        }
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw TrainBoardServiceError.resourceMissing
        }
        return data
    }
}

final class BackendBoardService: TrainBoardService, @unchecked Sendable {
    private let fetcher: BackendBoardFetching
    private let fallback: TrainBoardService
    private let referenceDate: @Sendable () -> Date
    /// Source kind stamped on a successful response: `.backendFixture` for the local
    /// fixture (Phase 1), `.backendLive` for the deployed backend (Phase 2B).
    private let stampSourceKind: BoardSourceKind
    /// When set, emit concise DEBUG logs under `[<tag>]` (e.g. "BackendLive").
    private let debugLogTag: String?
    /// Station the `fallback` actually represents (the bundled fixture is Padova).
    /// When set, the fallback is used ONLY for that station: for any other station a
    /// failure surfaces `BoardUnavailableError` instead, so one station's board can
    /// never be shown under another station's name. Nil → unconstrained (tests/mock).
    private let fallbackStationID: String?

    init(fetcher: BackendBoardFetching = FixtureBackendBoardFetcher(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() },
         stampSourceKind: BoardSourceKind = .backendFixture,
         debugLogTag: String? = nil,
         fallbackStationID: String? = nil) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.referenceDate = referenceDate
        self.stampSourceKind = stampSourceKind
        self.debugLogTag = debugLogTag
        self.fallbackStationID = fallbackStationID
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        // Both departures and arrivals flow to the fetcher (the live backend supports
        // both; the local fixture serves departures only and throws → fallback).
        do {
            let data = try await fetcher.fetchBoardJSON(stationSlug: stationId, type: type, locale: "it")
            let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: data)
            var response = BackendBoardMapper.map(dto, referenceDate: referenceDate())
            // Stamp where the data came through so the header never misrepresents it.
            response.sourceKind = stampSourceKind
            guard !response.rows.isEmpty else {
                return try await fallbackBoard(stationId: stationId, type: type, reason: "empty-parse")
            }
            log("OK · rows=\(response.rows.count) · source=\(dto.source.kind) · fallback=\(dto.source.isFallback ?? false) · stale=\(dto.source.isStale ?? false)")
            return response
        } catch {
            return try await fallbackBoard(stationId: stationId, type: type,
                                           reason: "fetch-error · error=\(error)")
        }
    }

    /// Fall back ONLY when the fallback data belongs to the requested station.
    /// Otherwise surface `BoardUnavailableError` → the UI shows the honest
    /// "board unavailable for this station" state instead of another station's board.
    private func fallbackBoard(stationId: String, type: BoardType, reason: String) async throws -> StationBoardResponse {
        guard fallbackApplies(to: stationId) else {
            log("UNAVAILABLE · station=\(stationId) · reason=\(reason) · no fallback for this station")
            throw BoardUnavailableError.stationNotServed(stationID: stationId)
        }
        log("FALLBACK · reason=\(reason) · using=fixture")
        return try await fallback.fetchBoard(stationId: stationId, type: type)
    }

    private func fallbackApplies(to stationId: String) -> Bool {
        guard let fallbackStationID else { return true }   // unconstrained (tests / mock source)
        return fallbackStationID == stationId
    }

    private func log(_ message: String) {
        #if DEBUG
        if let tag = debugLogTag { print("[\(tag)] \(message)") }
        #endif
    }
}
