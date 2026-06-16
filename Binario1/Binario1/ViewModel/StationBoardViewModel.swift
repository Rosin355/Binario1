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
    /// Programmed-sample window metadata (e.g. the Padova 06:00–06:59 demo), if the
    /// current source is bundled sample data.
    private(set) var scheduledWindow: ScheduledSampleWindow?
    /// Origin of the current board — drives the header source label.
    private(set) var sourceKind: BoardSourceKind = .mock

    /// Data is considered stale if older than this.
    private let staleThreshold: TimeInterval = 3 * 60

    private let service: TrainBoardService
    private var isRefreshing = false

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (e.g. the Padova scheduled timetable) locks this so the
    /// station title can never disagree with the board rows.
    let allowsStationChange: Bool

    /// Current-time source, injectable for deterministic tests of the scheduled
    /// demo window. Defaults to the wall clock.
    private let now: () -> Date

    init(service: TrainBoardService, station: Station = .bolognaCentrale,
         allowsStationChange: Bool = true, now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.station = station
        self.allowsStationChange = allowsStationChange
        self.now = now
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

    /// A bundled scheduled *sample* whose programmed window does not include the
    /// current local time. Its rows are a timetable demo, not current departures,
    /// so nothing should be presented as the next/current train.
    var isScheduledSampleOutOfWindow: Bool {
        guard let window = scheduledWindow, window.isSample else { return false }
        return !window.contains(now())
    }

    /// The highlighted train — the 3rd featured card and the first (selected) list row.
    var imminentRowID: TrainBoardRow.ID? {
        // A scheduled sample outside its demo window must not present any row as the
        // current/next departure (e.g. don't highlight a 06:14 train at 17:40).
        if isScheduledSampleOutOfWindow { return nil }
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
            scheduledWindow = response.scheduledWindow
            sourceKind = response.sourceKind
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
        // Single-station sources (e.g. Padova scheduled timetable) stay put so the
        // station title and the board rows can never disagree.
        guard allowsStationChange else { return }
        let all = Station.demoStations
        let next = (all.firstIndex(of: station).map { $0 + 1 } ?? 0) % all.count
        station = all[next]
        await refresh()
    }
}
