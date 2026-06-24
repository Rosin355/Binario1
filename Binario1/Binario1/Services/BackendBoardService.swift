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
struct FixtureBackendBoardFetcher: BackendBoardFetching {
    var resourceName: String = "backend-padova-departures.sample"
    var bundle: Bundle = .main

    func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
        guard type == .departures else { throw TrainBoardServiceError.resourceMissing }  // departures-only fixture
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

    init(fetcher: BackendBoardFetching = FixtureBackendBoardFetcher(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() },
         stampSourceKind: BoardSourceKind = .backendFixture,
         debugLogTag: String? = nil) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.referenceDate = referenceDate
        self.stampSourceKind = stampSourceKind
        self.debugLogTag = debugLogTag
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
                log("FALLBACK · reason=empty-parse · using=fixture")
                return try await fallback.fetchBoard(stationId: stationId, type: type)
            }
            log("OK · rows=\(response.rows.count) · source=\(dto.source.kind) · fallback=\(dto.source.isFallback ?? false) · stale=\(dto.source.isStale ?? false)")
            return response
        } catch {
            log("FALLBACK · reason=fetch-error · using=fixture · error=\(error)")
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        if let tag = debugLogTag { print("[\(tag)] \(message)") }
        #endif
    }
}
