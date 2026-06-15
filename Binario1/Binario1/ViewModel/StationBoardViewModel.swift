//
//  StationBoardViewModel.swift
//  Binario1
//

import Foundation
import Observation

@Observable
@MainActor
final class StationBoardViewModel {

    // Inputs / state
    var station: Station
    var boardType: BoardType = .departures

    // Output state
    private(set) var rows: [TrainBoardRow] = []
    private(set) var isLoading = false
    private(set) var errorMessageKey: String?
    private(set) var lastUpdated: Date?
    private(set) var sourceIsStale = false
    private(set) var warningMessageKey: String?
    /// True when the board is showing a programmed/scheduled timetable (RFI Quadro
    /// Orario), not live data.
    private(set) var isScheduled = false

    /// Data is considered stale if older than this.
    private let staleThreshold: TimeInterval = 3 * 60

    private let service: TrainBoardService
    private var isRefreshing = false

    init(service: TrainBoardService, station: Station = .bolognaCentrale) {
        self.service = service
        self.station = station
    }

    // MARK: - Derived data

    /// Whether the loaded data is too old to trust.
    var isStale: Bool {
        if sourceIsStale { return true }
        guard let lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) > staleThreshold
    }

    var hasData: Bool { !rows.isEmpty }
    var isEmpty: Bool { !isLoading && rows.isEmpty && errorMessageKey == nil }

    /// Board ordered by scheduled departure (a real board keeps delayed trains
    /// in their scheduled slot rather than re-sorting them by expected time).
    private var sortedRows: [TrainBoardRow] {
        rows.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    /// The 3 most imminent trains, shown as large cards in "Prossime partenze".
    var featuredRows: [TrainBoardRow] {
        Array(sortedRows.prefix(3))
    }

    /// The full board for "Tutte le partenze". Begins at the 3rd featured train so
    /// the highlighted/imminent train heads the list (matching the design).
    var listRows: [TrainBoardRow] {
        Array(sortedRows.dropFirst(2))
    }

    /// The highlighted train — the 3rd featured card and the first (selected) list row.
    var imminentRowID: TrainBoardRow.ID? {
        let featured = featuredRows
        return featured.count >= 3 ? featured[2].id : featured.last?.id
    }

    // MARK: - Actions

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = rows.isEmpty
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let response = try await service.fetchBoard(stationId: station.id, type: boardType)
            rows = response.rows.sorted { $0.scheduledTime < $1.scheduledTime }
            lastUpdated = response.generatedAt
            sourceIsStale = response.isStale
            warningMessageKey = response.warningMessageKey
            isScheduled = response.isScheduled
            errorMessageKey = nil
        } catch {
            errorMessageKey = "error.dataUnavailable"
            sourceIsStale = true
        }
    }

    func selectBoardType(_ type: BoardType) async {
        guard boardType != type else { return }
        boardType = type
        await refresh()
    }

    /// Cycle to the next mock station (drives the header station-change flip and
    /// exercises long-name layout). The board data remains mock.
    func changeStation() async {
        let all = Station.demoStations
        let next = (all.firstIndex(of: station).map { $0 + 1 } ?? 0) % all.count
        station = all[next]
        await refresh()
    }
}
