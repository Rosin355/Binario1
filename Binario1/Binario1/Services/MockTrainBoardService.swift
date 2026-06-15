//
//  MockTrainBoardService.swift
//  Binario1
//
//  Loads the bundled `board-response.sample.json` and re-bases all times
//  relative to "now" so the board always feels live. Falls back to an
//  embedded Bologna Centrale dataset if the resource is missing.
//
//  No networking — MVP only.
//

import Foundation

final class MockTrainBoardService: TrainBoardService, @unchecked Sendable {

    /// Set to a non-nil error to simulate a failed fetch (used in tests/previews).
    var simulatedError: Error?
    /// Artificial latency to exercise the loading state.
    var artificialDelay: Duration = .milliseconds(250)

    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "board-response.sample", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        if artificialDelay > .zero {
            try? await Task.sleep(for: artificialDelay)
        }
        if let simulatedError { throw simulatedError }

        let base = try loadBaseResponse()
        let typed = Self.adapt(base, to: type)
        return Self.rebasedToNow(typed)
    }

    // MARK: - Loading

    private func loadBaseResponse() throws -> StationBoardResponse {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return Self.embeddedFallback
        }
        do {
            let dto = try JSONDecoder().decode(BoardResponseDTO.self, from: data)
            return TrainBoardMapper.response(dto)
        } catch {
            throw TrainBoardServiceError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Board type adaptation

    /// The sample file is a departures board. Synthesize an arrivals board from
    /// the same trains so both segments show meaningful data in the MVP.
    static func adapt(_ response: StationBoardResponse, to type: BoardType) -> StationBoardResponse {
        guard type != response.boardType else { return response }

        let rows = response.rows.map { row -> TrainBoardRow in
            guard type == .arrivals else { return row }
            let newStatus: TrainStatus
            switch row.status {
            case .departing: newStatus = .arriving
            case .departed:  newStatus = .arrived
            default:         newStatus = row.status
            }
            return TrainBoardRow(
                id: row.id,
                trainNumber: row.trainNumber,
                category: row.category,
                operatorName: row.operatorName,
                origin: row.destination,   // swap: where it came from
                destination: nil,
                scheduledTime: row.scheduledTime,
                expectedTime: row.expectedTime,
                delayMinutes: row.delayMinutes,
                plannedPlatform: row.plannedPlatform,
                actualPlatform: row.actualPlatform,
                status: newStatus,
                notes: row.notes,
                lastUpdated: row.lastUpdated
            )
        }

        return StationBoardResponse(
            station: response.station,
            boardType: type,
            locale: response.locale,
            supportedLocales: response.supportedLocales,
            rows: rows,
            generatedAt: response.generatedAt,
            sourceUpdatedAt: response.sourceUpdatedAt,
            isStale: response.isStale,
            warningMessageKey: response.warningMessageKey
        )
    }

    // MARK: - Time rebasing

    /// Shifts every row so the earliest train sits ~4 minutes in the past,
    /// preserving the relative spacing authored in the JSON. Stamps freshness
    /// fields to `now` so the board is never spuriously stale.
    static func rebasedToNow(_ response: StationBoardResponse, now: Date = Date()) -> StationBoardResponse {
        guard let earliest = response.rows.map(\.scheduledTime).min() else { return response }

        // Anchor the first train ~1 minute out so the whole board reads as upcoming.
        let target = now.addingTimeInterval(60)
        let delta = target.timeIntervalSince(earliest)

        let rows = response.rows.map { row in
            TrainBoardRow(
                id: row.id,
                trainNumber: row.trainNumber,
                category: row.category,
                operatorName: row.operatorName,
                origin: row.origin,
                destination: row.destination,
                scheduledTime: row.scheduledTime.addingTimeInterval(delta),
                expectedTime: row.expectedTime?.addingTimeInterval(delta),
                delayMinutes: row.delayMinutes,
                plannedPlatform: row.plannedPlatform,
                actualPlatform: row.actualPlatform,
                status: row.status,
                notes: row.notes,
                lastUpdated: now
            )
        }

        return StationBoardResponse(
            station: response.station,
            boardType: response.boardType,
            locale: response.locale,
            supportedLocales: response.supportedLocales,
            rows: rows,
            generatedAt: now,
            sourceUpdatedAt: now,
            isStale: false,
            warningMessageKey: response.warningMessageKey
        )
    }

    // MARK: - Embedded fallback (used only if the bundled JSON is unavailable)

    static let embeddedFallback: StationBoardResponse = {
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        func t(_ minutes: Int) -> Date { base.addingTimeInterval(Double(minutes) * 60) }
        func mk(_ id: String, _ cat: String, _ num: String, _ dest: String,
                _ off: Int, delay: Int? = nil, plat: String?, status: TrainStatus) -> TrainBoardRow {
            TrainBoardRow(
                id: id, trainNumber: num, category: cat, operatorName: "Trenitalia",
                origin: nil, destination: dest,
                scheduledTime: t(off),
                expectedTime: delay.map { t(off + $0) },
                delayMinutes: delay,
                plannedPlatform: plat, actualPlatform: plat,
                status: status, notes: nil, lastUpdated: base
            )
        }
        let rows = [
            mk("f1", "ICN", "794", "TORINO P.N.", 0, delay: 150, plat: "1", status: .departed),
            mk("f2", "ES", "9811", "LECCE", 3, delay: 35, plat: "4", status: .departing),
            mk("f3", "AV", "9533", "NAPOLI C.LE", 6, plat: "11", status: .onTime),
            mk("f4", "RV", "2236", "VENEZIA S.L.", 9, plat: "4", status: .scheduled),
            mk("f5", "REG", "11465", "VIGNOLA", 12, plat: "7", status: .scheduled),
            mk("f6", "AV", "9985", "MILANO C.LE", 16, delay: 10, plat: "3", status: .delayed),
            mk("f7", "IC", "588", "TRIESTE C.LE", 21, plat: "1", status: .scheduled),
            mk("f8", "REG", "11458", "POGGIO RUSCO", 26, plat: nil, status: .cancelled),
            mk("f9", "FR", "9705", "ROMA TERMINI", 31, plat: "9", status: .scheduled),
            mk("f10", "REG", "3007", "RAVENNA", 37, plat: "10", status: .scheduled),
        ]
        return StationBoardResponse(
            station: .bolognaCentrale,
            boardType: .departures,
            locale: "it-IT",
            supportedLocales: ["it-IT", "en-US"],
            rows: rows,
            generatedAt: base,
            sourceUpdatedAt: base,
            isStale: false,
            warningMessageKey: nil
        )
    }()
}
