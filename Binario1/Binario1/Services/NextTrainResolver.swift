//
//  NextTrainResolver.swift
//  Binario1
//
//  Resolves the next REAL train for the user's saved journeys against the live/mock
//  board, through the existing `TrainBoardService` abstraction. Used by Viaggi to
//  replace the old save-time placeholders. Never fabricates times/platforms/delays:
//  when a saved route can't be resolved the outcome is `.unavailable` and the UI
//  shows an honest state.
//
//  The board today serves a single station (Padova in DEBUG/TESTFLIGHT, the bundled
//  mock otherwise). That served station is INJECTED — never hardcoded — so journeys
//  whose origin isn't served fall into the honest state (as expected for now).
//

import Foundation

/// Real next-train details resolved from a board row for a saved route. Carries only
/// real fields (no duration/arrival, which the board doesn't provide).
struct ResolvedNextTrain: Equatable {
    let journeyID: String
    let origin: String              // saved journey's origin (full name)
    let destination: String         // saved journey's destination (full name)
    let scheduledTime: Date
    let expectedTime: Date?
    let delayMinutes: Int?
    let platform: String?           // actual ?? planned, nil when the board has none
    let category: String
    let trainNumber: String
    let status: TrainStatus

    init(journey: SavedJourney, row: TrainBoardRow) {
        journeyID = journey.id
        origin = journey.origin
        destination = journey.destination
        scheduledTime = row.scheduledTime
        expectedTime = row.expectedTime
        delayMinutes = row.delayMinutes
        platform = row.hasPlatform ? row.platformDisplay : nil
        category = row.category
        trainNumber = row.trainNumber
        status = row.status
    }
}

/// Outcome of resolving a saved journey against the board.
enum NextTrainResolution: Equatable {
    /// A real, future board row matched the saved route.
    case resolved(ResolvedNextTrain)
    /// No real next train: the origin isn't served by the live board, or there is no
    /// future row heading to the destination. The UI shows an honest "not available"
    /// state — never a placeholder time/platform/duration.
    case unavailable
}

protocol NextTrainResolving: Sendable {
    /// Resolves each saved journey's next real train, keyed by journey id.
    func resolve(_ journeys: [SavedJourney]) async -> [String: NextTrainResolution]
}

final class NextTrainResolver: NextTrainResolving, @unchecked Sendable {
    private let service: TrainBoardService
    private let boardStation: Station
    private let catalog: StationCatalog?
    private let now: @Sendable () -> Date

    init(service: TrainBoardService, boardStation: Station,
         catalog: StationCatalog? = nil,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.service = service
        self.boardStation = boardStation
        self.catalog = catalog
        self.now = now
    }

    func resolve(_ journeys: [SavedJourney]) async -> [String: NextTrainResolution] {
        var result: [String: NextTrainResolution] = [:]

        // Only journeys departing from the served station can resolve; the rest are
        // honestly "unavailable" without a wasted fetch.
        let served = SavedJourneyMatcher.journeysDeparting(from: boardStation.displayName, in: journeys, catalog: catalog)
        let servedIDs = Set(served.map(\.id))
        for journey in journeys where !servedIDs.contains(journey.id) {
            result[journey.id] = .unavailable
        }
        guard !served.isEmpty else { return result }

        // Fetch the served board once (departures).
        let rows: [TrainBoardRow]
        do {
            let response = try await service.fetchBoard(stationId: boardStation.id, type: .departures)
            rows = response.rows.sorted { $0.scheduledTime < $1.scheduledTime }
        } catch {
            for journey in served { result[journey.id] = .unavailable }
            return result
        }

        let currentTime = now()
        for journey in served {
            // First future row (scheduled at/after now) heading to the destination.
            if let row = rows.first(where: {
                $0.scheduledTime >= currentTime && SavedJourneyMatcher.row($0, matchesDestinationOf: journey, catalog: catalog)
            }) {
                result[journey.id] = .resolved(ResolvedNextTrain(journey: journey, row: row))
            } else {
                result[journey.id] = .unavailable
            }
        }
        return result
    }
}
