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
    /// Number of fetches currently in flight. Several can overlap: a forced fetch
    /// (station change / pull-to-refresh) starts IMMEDIATELY instead of queuing behind
    /// a slow one, and any superseded result is discarded on arrival. Drives the spinner.
    private var inFlightFetches = 0
    /// In-flight fetches per board KEY (`station|boardType`). Collapsing duplicates is
    /// per board, not global: an "any fetch in flight" guard silently dropped the
    /// arrivals request when the user toggled ARRIVI during a station change, leaving
    /// the departures payload to land under the arrivals header.
    private var inFlightKeys: [String: Int] = [:]
    /// Bumped whenever the SELECTION changes — station switch or board-type switch. A
    /// fetch captures the generation it started in; if it no longer matches when the
    /// response lands, that response is STALE and must never touch the board. This is
    /// what stops a slow Padova response from painting rows under the Roma Termini
    /// header, and a departures response from painting under the ARRIVI header.
    private var fetchGeneration = 0
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

    /// Station catalog used for alias-aware destination matching (so a saved
    /// "Venezia Santa Lucia" matches an abbreviated board row). Nil → plain canonical
    /// matching (existing behavior; keeps Home/Viaggi identical when both omit it).
    private let catalog: StationCatalog?

    /// Stations the `Cambia` action cycles through (live: only the ones the backend
    /// serves; mock: the demo carousel).

    /// Ids the LIVE board serves. Nil → no restriction (mock/demo sources). When set,
    /// a station outside it never triggers a fetch: the UI shows the honest
    /// "board unavailable for this station" state instead of another station's board.
    private let liveServedStationIDs: Set<String>?

    /// True when the current station has no board to show (not served by the live
    /// backend, or the backend replied `unknown_station`). An expected state, not an
    /// error: the UI renders an honest message, never raw error text or stale rows.
    private(set) var isBoardUnavailableForStation = false

    /// Current-time source, injectable for deterministic tests of the scheduled
    /// demo window. Defaults to the wall clock.
    private let now: () -> Date

    init(service: TrainBoardService, station: Station = .bolognaCentrale,
         allowsStationChange: Bool = true, now: @escaping () -> Date = { Date() },
         savedJourneys: [SavedJourney] = [],
         savedJourneysProvider: (() -> [SavedJourney])? = nil,
         catalog: StationCatalog? = nil,
         liveServedStationIDs: Set<String>? = nil) {
        self.service = service
        self.station = station
        self.allowsStationChange = allowsStationChange
        self.now = now
        self.savedJourneys = savedJourneys
        self.savedJourneysProvider = savedJourneysProvider
        self.catalog = catalog
        self.liveServedStationIDs = liveServedStationIDs
    }

    /// Whether the live board serves `station` (always true when unrestricted).
    private func isServed(_ station: Station) -> Bool {
        guard let liveServedStationIDs else { return true }
        return liveServedStationIDs.contains(station.id)
    }

    /// Whether a response's station identity must match the selected station.
    /// Enabled for the LIVE board only: the mock demo carousel deliberately serves the
    /// same bundled dataset under different station names, and must keep working.
    private var validatesStationIdentity: Bool { liveServedStationIDs != nil }

    /// Station ids compare case/whitespace-insensitively (backend lowercases slugs).
    private static func sameStation(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased()
        == b.trimmingCharacters(in: .whitespaces).lowercased()
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
        // Same predicate the Viaggi next-train resolver uses (shared helper) so the
        // two features can never diverge.
        let fromHere = SavedJourneyMatcher.journeysDeparting(from: station.displayName, in: savedJourneys, catalog: catalog)
        guard !fromHere.isEmpty else { return [] }
        let matched = SavedJourneyMatcher.rows(sortedRows, matchingDestinationsOf: fromHere, catalog: catalog)
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
        // The board this request is FOR. Captured up front: `boardType` can change
        // under us while the fetch is in flight, and the response must be judged
        // against what was asked, not against what is selected now.
        let requestedType = boardType
        let key = "\(station.id)|\(requestedType.rawValue)"
        // A forced refresh (station change / pull-to-refresh) must START NOW, in
        // parallel with any slow in-flight fetch. Non-forced calls collapse only onto
        // an identical board already in flight — a DIFFERENT station or board type
        // always gets its own request.
        guard force || inFlightKeys[key] == nil else { return }
        // A station the live board doesn't serve must never trigger a fetch (its
        // fallback would belong to another station). Honest state, no rows.
        guard isServed(station) else {
            markBoardUnavailable()
            return
        }
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
        // Identity of THIS request: if either changes before the response lands, the
        // response belongs to a selection the user has already left.
        let requestedStationID = station.id
        let generation = fetchGeneration
        beginFetch(key)
        if rows.isEmpty { isLoading = true }
        defer { endFetch(key) }

        do {
            let response = try await service.fetchBoard(stationId: requestedStationID, type: requestedType)
            // Superseded while in flight — the user switched STATION or BOARD TYPE →
            // drop it silently. Never paint rows that contradict the header, on either
            // axis.
            guard generation == fetchGeneration,
                  Self.sameStation(requestedStationID, station.id),
                  requestedType == boardType else {
                #if DEBUG
                print("[Board] discarded stale response for \(requestedStationID)|\(requestedType.rawValue) (now \(station.id)|\(boardType.rawValue))")
                #endif
                return
            }
            // The response must also SAY it is this station (live only — the mock demo
            // carousel intentionally reuses one dataset across stations).
            if validatesStationIdentity,
               !Self.sameStation(response.station.id, requestedStationID) {
                #if DEBUG
                print("[Board] identity mismatch · requested=\(requestedStationID) · responded=\(response.station.id) → honest state")
                #endif
                markBoardUnavailable()
                lastFetchKey = key
                lastFetchAt = now()
                return
            }
            // …and it must BE the board we asked for. Same principle as the station
            // identity check, other axis: a departures payload must never populate the
            // arrivals view. Not `markBoardUnavailable` — the STATION is served, it is
            // this payload that is wrong, so surface a retryable data error instead of
            // claiming the station has no board.
            guard response.boardType == requestedType else {
                #if DEBUG
                print("[Board] board-type mismatch · requested=\(requestedType.rawValue) · responded=\(response.boardType.rawValue) → discarded")
                #endif
                rows = []
                errorMessageKey = "error.dataUnavailable"
                lastFetchKey = key
                lastFetchAt = now()
                return
            }
            rows = response.rows.sorted { $0.scheduledTime < $1.scheduledTime }
            lastUpdated = response.generatedAt
            sourceIsStale = response.isStale
            warningMessageKey = response.warningMessageKey
            isScheduled = response.isScheduled
            scheduledWindow = response.scheduledWindow
            sourceKind = response.sourceKind
            sourceIsFallback = response.sourceIsFallback
            errorMessageKey = nil
            isBoardUnavailableForStation = false
            lastFetchKey = key
            lastFetchAt = now()
        } catch is BoardUnavailableError {
            if Task.isCancelled { return }
            guard isCurrent(generation, requestedStationID) else { return }   // stale failure
            // Expected: this station has no board (unknown_station / no station-specific
            // fallback). Honest state — never another station's rows, never raw error.
            markBoardUnavailable()
            lastFetchKey = key
            lastFetchAt = now()
        } catch {
            if Task.isCancelled { return }                  // superseded by a newer refresh
            guard isCurrent(generation, requestedStationID) else { return }   // stale failure
            errorMessageKey = "error.dataUnavailable"
            isBoardUnavailableForStation = false
            sourceIsStale = true
            lastFetchKey = key
            lastFetchAt = now()
        }
    }

    /// Whether a fetch that started in `generation` for `stationID` still describes the
    /// current selection (otherwise its result/failure must be ignored).
    private func isCurrent(_ generation: Int, _ stationID: String) -> Bool {
        generation == fetchGeneration && Self.sameStation(stationID, station.id)
    }

    /// Enter the honest "no board for this station" state: drop any rows (they belong
    /// to a different station) and clear the raw-error message.
    private func markBoardUnavailable() {
        rows = []
        isBoardUnavailableForStation = true
        errorMessageKey = nil
        isLoading = false
        sourceIsStale = false
        lastUpdated = nil
    }

    /// Switches board type. Mutating `boardType` retriggers the view's `.task(id:)`,
    /// which performs the fetch — so we deliberately do NOT fetch here (that would
    /// be a duplicate request on every board-type switch).
    ///
    /// The invalidation is the same a station change performs, on the other axis: the
    /// previous board's rows must never remain visible under the new header while the
    /// new board loads. Without it, ARRIVI showed the departures list — same times,
    /// same platforms, and an empty origin column.
    func selectBoardType(_ type: BoardType) {
        guard boardType != type else { return }
        boardType = type
        invalidateSelection()
    }

    /// Switch to an explicitly chosen station (the Partenze station picker) and reload.
    /// The ONLY path for changing station. The `changeStation()` carousel that used to
    /// delegate here was removed in B3-full: it had been unreachable from the UI since
    /// C3 replaced the carousel with the search sheet, and cycling a national catalog
    /// was never going to be usable.
    func selectStation(_ station: Station) async {
        guard allowsStationChange else { return }
        self.station = station
        invalidateSelection()
        await refresh(force: true)
    }

    /// Drop everything belonging to the PREVIOUS selection: bump the generation so any
    /// in-flight response is discarded when it lands, and clear the rows so the board
    /// can never show data contradicting its own header while the new one loads.
    private func invalidateSelection() {
        fetchGeneration += 1
        rows = []
        isBoardUnavailableForStation = false
        errorMessageKey = nil
        lastUpdated = nil
    }

    private func beginFetch(_ key: String) {
        inFlightKeys[key, default: 0] += 1
        inFlightFetches += 1
    }

    private func endFetch(_ key: String) {
        if let n = inFlightKeys[key], n > 1 { inFlightKeys[key] = n - 1 } else { inFlightKeys[key] = nil }
        inFlightFetches -= 1
        // Keep the spinner up while another (newer) fetch is still running.
        if inFlightFetches == 0 { isLoading = false }
    }

}
