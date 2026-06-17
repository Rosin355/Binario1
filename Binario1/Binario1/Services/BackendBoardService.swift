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

/// Phase 1 fetcher: loads the bundled normalized fixture JSON. No network.
struct FixtureBackendBoardFetcher: BackendBoardFetching {
    var resourceName: String = "backend-padova-departures.sample"
    var bundle: Bundle = .main

    func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
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

    init(fetcher: BackendBoardFetching = FixtureBackendBoardFetcher(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.referenceDate = referenceDate
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        // The Phase 1 fixture is Padova DEPARTURES; arrivals fall back to mock.
        guard type == .departures else {
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
        do {
            let data = try await fetcher.fetchBoardJSON(stationSlug: stationId, type: type, locale: "it")
            let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: data)
            var response = BackendBoardMapper.map(dto, referenceDate: referenceDate())
            // Phase 1: this came from a local backend FIXTURE — label it as such so
            // the header never claims a real backend/live connection.
            response.sourceKind = .backendFixture
            guard !response.rows.isEmpty else {
                return try await fallback.fetchBoard(stationId: stationId, type: type)
            }
            return response
        } catch {
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
    }
}
