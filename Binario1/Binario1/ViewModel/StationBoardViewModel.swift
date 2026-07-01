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
    /// Backend-reported fallback flag (alternate/last-known data), for the header.
    private(set) var sourceIsFallback = false

    /// Data is considered stale if older than this.
    private let staleThreshold: TimeInterval = 3 * 60

    private let service: TrainBoardService
    private var isRefreshing = false
    private var lastFetchAt: Date?
    private var lastFetchKey: String?
    /// Minimum gap between automatic (non-forced) fetches of the SAME board, to
    /// collapse accidental duplicate triggers (a double `.task` fire, a lifecycle
    /// re-entry). Manual refresh (`force`) and a board-type change bypass it; the
    /// periodic auto-refresh (30s) sits well above it.
    private let minAutoRefreshInterval: TimeInterval = 8

    /// Whether the header `Cambia` action may switch stations. A single fixed
    /// station source (e.g. the Padova scheduled timetable) locks this so the
    /// station title can never disagree with the board rows.
    let allowsStationChange: Bool

    /// The user's saved journeys (from Viaggi, persisted), used to personalize the
    /// featured section. Empty → the generic "next departures" behavior. Refreshed
    /// from `savedJourneysProvider` (if set) on each board refresh, so add/delete in
    /// Viaggi is reflected on Home's next refresh/load.
    private var savedJourneys: [SavedJourney]

    /// Re-reads the persisted saved journeys on refresh. Nil → keep the initial
    /// snapshot (used by tests/previews that inject a fixed list).
    private let savedJourneysProvider: (() -> [SavedJourney])?

    /// Current-time source, injectable for deterministic tests of the scheduled
    /// demo window. Defaults to the wall clock.
    private let now: () -> Date

    init(service: TrainBoardService, station: Station = .bolognaCentrale,
         allowsStationChange: Bool = true, now: @escaping () -> Date = { Date() },
         savedJourneys: [SavedJourney] = [],
         savedJourneysProvider: (() -> [SavedJourney])? = nil) {
        self.service = service
        self.station = station
        self.allowsStationChange = allowsStationChange
        self.now = now
        self.savedJourneys = savedJourneys
        self.savedJourneysProvider = savedJourneysProvider
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

    /// Board rows matching a saved journey that departs from THIS station (departures
    /// only): origin = current station AND destination name matches. Up to 3, in
    /// scheduled order. Cancelled / severely delayed matches are intentionally kept —
    /// the user still wants to see "my train", problems included.
    var personalizedFeaturedRows: [TrainBoardRow] {
        guard boardType == .departures, !savedJourneys.isEmpty, !isScheduledSampleOutOfWindow else { return [] }
        let fromHere = savedJourneys.filter { StationNameMatcher.matches(station.displayName, $0.origin) }
        guard !fromHere.isEmpty else { return [] }
        let matched = sortedRows.filter { row in
            fromHere.contains { StationNameMatcher.matches(row.destination, $0.destination) }
        }
        return Array(matched.prefix(3))
    }

    /// True when the featured section shows the user's saved-journey trains
    /// ("I tuoi prossimi treni") instead of the generic next departures.
    var usesPersonalizedFeatured: Bool { !personalizedFeaturedRows.isEmpty }

    /// Featured cards: the user's saved-journey trains when any match, otherwise the
    /// 3 most imminent departures (generic fallback — never an empty hero).
    var featuredRows: [TrainBoardRow] {
        let personalized = personalizedFeaturedRows
        return personalized.isEmpty ? Array(sortedRows.prefix(3)) : personalized
    }

    /// Localization key for the featured section title (personalized vs generic vs
    /// programmed-sample). The view wraps it in `LocalizedStringKey`.
    var featuredTitleKey: String {
        if usesPersonalizedFeatured { return "section.yourNextTrains" }
        if isScheduledSampleOutOfWindow { return "section.programmedDepartures" }
        return boardType == .departures ? "section.nextDepartures" : "section.nextArrivals"
    }

    /// The full board for "Tutte le partenze". With a personalized spotlight this is
    /// the COMPLETE station board; in generic mode it begins at the 3rd featured
    /// train so the highlighted/imminent train heads the list (existing design).
    var listRows: [TrainBoardRow] {
        usesPersonalizedFeatured ? sortedRows : Array(sortedRows.dropFirst(2))
    }

    /// A bundled scheduled *sample* whose programmed window does not include the
    /// current local time. Its rows are a timetable demo, not current departures,
    /// so nothing should be presented as the next/current train.
    var isScheduledSampleOutOfWindow: Bool {
        guard let window = scheduledWindow, window.isSample else { return false }
        return !window.contains(now())
    }

    /// The highlighted train. In personalized mode it's the user's soonest matching
    /// train; otherwise the 3rd featured card (which also heads the generic list).
    var imminentRowID: TrainBoardRow.ID? {
        // A scheduled sample outside its demo window must not present any row as the
        // current/next departure (e.g. don't highlight a 06:14 train at 17:40).
        if isScheduledSampleOutOfWindow { return nil }
        if usesPersonalizedFeatured { return personalizedFeaturedRows.first?.id }
        let featured = featuredRows
        return featured.count >= 3 ? featured[2].id : featured.last?.id
    }

    // MARK: - Actions

    /// Loads the board. `force` (manual pull-to-refresh) bypasses the dedupe guard;
    /// non-forced calls for the SAME board within `minAutoRefreshInterval` are
    /// skipped so accidental duplicate triggers never double-fetch.
    func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }                 // never overlap requests
        let key = "\(station.id)|\(boardType.rawValue)"
        if !force, key == lastFetchKey, let last = lastFetchAt,
           now().timeIntervalSince(last) < minAutoRefreshInterval {
            #if DEBUG
            print("[Board] refresh deduped (same board, last fetch \(Int(now().timeIntervalSince(last)))s ago)")
            #endif
            return
        }
        // Re-read persisted saved journeys so Home reflects Viaggi add/delete on the
        // next refresh/load (no-op when no provider was injected).
        if let savedJourneysProvider { savedJourneys = savedJourneysProvider() }
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
            sourceIsFallback = response.sourceIsFallback
            errorMessageKey = nil
            lastFetchKey = key
            lastFetchAt = now()
        } catch {
            if Task.isCancelled { return }                  // superseded by a newer refresh
            errorMessageKey = "error.dataUnavailable"
            sourceIsStale = true
            lastFetchKey = key
            lastFetchAt = now()
        }
    }

    /// Switches board type. Mutating `boardType` retriggers the view's `.task(id:)`,
    /// which performs the fetch — so we deliberately do NOT fetch here (that would
    /// be a duplicate request on every board-type switch).
    func selectBoardType(_ type: BoardType) {
        guard boardType != type else { return }
        boardType = type
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
