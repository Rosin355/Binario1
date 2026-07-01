//
//  Binario1Tests.swift
//  Binario1Tests
//
//  Created by Romesh Singhabahu on 13/06/26.
//

import Testing
import Foundation
@testable import Binario1

struct Binario1Tests {

    // MARK: - Mapping

    @Test func mapsStatusFallbackFromDelay() {
        #expect(TrainBoardMapper.status(nil, delayMinutes: 5) == .delayed)
        #expect(TrainBoardMapper.status(nil, delayMinutes: 0) == .unknown)
        #expect(TrainBoardMapper.status("cancelled", delayMinutes: nil) == .cancelled)
        #expect(TrainBoardMapper.status("garbage", delayMinutes: 3) == .delayed)
    }

    @Test func parsesISODates() {
        let d = TrainBoardMapper.date("2026-06-13T15:36:00+02:00")
        #expect(d != nil)
        #expect(TrainBoardMapper.date("not-a-date") == nil)
        #expect(TrainBoardMapper.date(nil) == nil)
    }

    // MARK: - Row display rules

    @Test func displayPlaceFollowsBoardType() {
        let row = TrainBoardRow(
            id: "1", trainNumber: "9421", category: "FR", operatorName: "Trenitalia",
            origin: "VENEZIA", destination: "ROMA TERMINI",
            scheduledTime: Date(), expectedTime: nil, delayMinutes: nil,
            plannedPlatform: "5", actualPlatform: "6",
            status: .onTime, notes: nil, lastUpdated: Date()
        )
        #expect(row.displayPlace(for: .departures) == "ROMA TERMINI")
        #expect(row.displayPlace(for: .arrivals) == "VENEZIA")
        #expect(row.platformDisplay == "6")          // actual preferred over planned
        #expect(row.trainLabel == "FR 9421")
    }

    @Test func platformFallsBackAndCanBeMissing() {
        let noActual = TrainBoardRow(
            id: "2", trainNumber: "1", category: "REG", operatorName: nil,
            origin: nil, destination: "X", scheduledTime: Date(), expectedTime: nil,
            delayMinutes: nil, plannedPlatform: "3", actualPlatform: nil,
            status: .scheduled, notes: nil, lastUpdated: Date()
        )
        #expect(noActual.platformDisplay == "3")

        let none = TrainBoardRow(
            id: "3", trainNumber: "1", category: "REG", operatorName: nil,
            origin: nil, destination: "X", scheduledTime: Date(), expectedTime: nil,
            delayMinutes: nil, plannedPlatform: nil, actualPlatform: nil,
            status: .scheduled, notes: nil, lastUpdated: Date()
        )
        #expect(none.platformDisplay == "--")
        #expect(none.hasPlatform == false)
    }

    // MARK: - Mock service

    @Test func mockServiceLoadsBolognaDepartures() async throws {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        let response = try await service.fetchBoard(stationId: "bologna-centrale", type: .departures)
        #expect(response.station.id == "bologna-centrale")
        #expect(response.boardType == .departures)
        #expect(!response.rows.isEmpty)
    }

    @Test func mockServiceAdaptsToArrivals() async throws {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        let response = try await service.fetchBoard(stationId: "bologna-centrale", type: .arrivals)
        #expect(response.boardType == .arrivals)
        // Arrivals expose an origin (mapped from the sample's destination).
        #expect(response.rows.contains { ($0.origin?.isEmpty == false) })
    }

    @Test func rebasingKeepsDataFresh() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rebased = MockTrainBoardService.rebasedToNow(
            MockTrainBoardService.embeddedFallback, now: now
        )
        #expect(rebased.generatedAt == now)
        #expect(rebased.isStale == false)
        // Earliest train anchored ~1 minute after now (whole board reads as upcoming).
        let earliest = rebased.rows.map(\.scheduledTime).min()!
        #expect(abs(earliest.timeIntervalSince(now) - 60) < 1)
    }

    // MARK: - ViewModel

    @MainActor
    @Test func viewModelRefreshPopulatesAndIsNotStale() async {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        let vm = StationBoardViewModel(service: service, station: .bolognaCentrale)
        await vm.refresh()
        #expect(vm.hasData)
        #expect(vm.errorMessageKey == nil)
        #expect(vm.isStale == false)
        #expect(vm.featuredRows.count <= 3)
    }

    @MainActor
    @Test func viewModelSurfacesError() async {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        service.simulatedError = TrainBoardServiceError.resourceMissing
        let vm = StationBoardViewModel(service: service, station: .bolognaCentrale)
        await vm.refresh()
        #expect(vm.errorMessageKey == "error.dataUnavailable")
        #expect(vm.isStale == true)
    }

    // MARK: - Station-change locking (source-mode consistency)

    @MainActor
    @Test func lockedStationStaysFixed() async {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        // Single-station scheduled source: station change is locked.
        let vm = StationBoardViewModel(service: service, station: .padova, allowsStationChange: false)
        #expect(vm.allowsStationChange == false)
        await vm.changeStation()                       // must be a no-op
        #expect(vm.station.id == Station.padova.id)    // title stays PADOVA
    }

    @MainActor
    @Test func unlockedStationCanChange() async {
        let service = MockTrainBoardService()
        service.artificialDelay = .zero
        // Mock mode keeps the default: station change allowed.
        let vm = StationBoardViewModel(service: service, station: .bolognaCentrale)
        #expect(vm.allowsStationChange == true)
        let before = vm.station.id
        await vm.changeStation()
        #expect(vm.station.id != before)               // carousel still advances
    }

    // MARK: - Source mode (DEBUG demo vs RELEASE)

    @Test func sourceModeMatchesBuildConfiguration() {
        #if DEBUG
        // DEBUG = local Padova scheduled demo; station selection is locked.
        #expect(AppEnvironment.sourceMode == .scheduledPadova)
        #expect(AppEnvironment.allowsStationChange == false)
        #else
        // RELEASE = bundled mock board; station carousel enabled.
        #expect(AppEnvironment.sourceMode == .mock)
        #expect(AppEnvironment.allowsStationChange == true)
        #endif
    }

    // MARK: - Scheduled timetable (Padova / RFI Quadro Orario spike)

    private static let sampleScheduledJSON = """
    {
      "stationId": "1861",
      "stationName": "Padova",
      "source": "RFI Quadro Orario",
      "hourRange": "06.00-06.59",
      "boardType": "departures",
      "scheduledWindowStart": "06:00",
      "scheduledWindowEnd": "06:59",
      "sourceKind": "scheduledSample",
      "departures": [
        { "time": "06.05", "category": "REG", "trainNumber": "5928", "destination": "VENEZIA S. LUCIA", "plannedPlatform": "1", "operatorName": "Trenitalia", "periodicity": "Giornaliero", "notes": null },
        { "time": "06.27", "category": "REG", "trainNumber": "5930", "destination": "CALALZO", "plannedPlatform": null, "operatorName": "Trenitalia", "periodicity": null, "notes": "Binario in assegnazione" },
        { "time": "06.41", "category": "ITALO", "trainNumber": "9902", "destination": "MILANO C.LE", "plannedPlatform": "6", "operatorName": "Italo", "periodicity": null, "notes": null },
        { "time": "06.55", "category": null, "trainNumber": "17105", "destination": "MONSELICE", "plannedPlatform": "4", "operatorName": "Trenitalia", "periodicity": null, "notes": null }
      ]
    }
    """

    private func decodeSampleScheduled() throws -> ScheduledTimetableDTO {
        try JSONDecoder().decode(ScheduledTimetableDTO.self, from: Data(Self.sampleScheduledJSON.utf8))
    }

    @Test func scheduledCategoryNormalization() {
        #expect(ScheduledTimetableMapper.category(from: "REG") == "REG")
        #expect(ScheduledTimetableMapper.category(from: "italo") == "ITA")
        #expect(ScheduledTimetableMapper.category(from: "Regionale") == "REG")
        #expect(ScheduledTimetableMapper.category(from: "FRECCIAROSSA") == "FR")
        #expect(ScheduledTimetableMapper.category(from: nil) == "UNKNOWN")
        #expect(ScheduledTimetableMapper.category(from: "  ") == "UNKNOWN")
        #expect(ScheduledTimetableMapper.category(from: "Sconosciuto") == "UNKNOWN")
    }

    @Test func scheduledTimeParsing() {
        let tz = TimeZone(identifier: "Europe/Rome")!
        let ref = Date(timeIntervalSince1970: 1_800_000_000)
        let d = ScheduledTimetableMapper.time("06.05", on: ref, timezone: tz)
        #expect(d != nil)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: d!)
        #expect(c.hour == 6 && c.minute == 5)
        #expect(ScheduledTimetableMapper.time("not-a-time", on: ref, timezone: tz) == nil)
        #expect(ScheduledTimetableMapper.time("25.00", on: ref, timezone: tz) == nil)
    }

    @Test func scheduledMappingProducesScheduledRowsNoFakeDelay() throws {
        let dto = try decodeSampleScheduled()
        let response = ScheduledTimetableMapper.map(dto)
        #expect(response.isScheduled == true)
        #expect(response.station.name == "Padova")
        #expect(response.boardType == .departures)
        #expect(response.rows.count == 4)

        // No fake live info on any scheduled row.
        for row in response.rows {
            #expect(row.status == .scheduled)
            #expect(row.delayMinutes == nil)
            #expect(row.hasDelay == false)
            #expect(row.actualPlatform == nil)
            #expect(row.expectedTime == nil)
        }

        let first = response.rows[0]
        #expect(first.category == "REG")
        #expect(first.destination == "VENEZIA S. LUCIA")
        #expect(first.platformDisplay == "1")          // programmed platform
        #expect(first.trainNumber == "5928")
    }

    @Test func scheduledMissingPlatformAndCategory() throws {
        let dto = try decodeSampleScheduled()
        let response = ScheduledTimetableMapper.map(dto)
        let calalzo = response.rows.first { $0.trainNumber == "5930" }!
        #expect(calalzo.platformDisplay == "--")        // missing programmed platform
        #expect(calalzo.notes == "Binario in assegnazione")

        let italo = response.rows.first { $0.trainNumber == "9902" }!
        #expect(italo.category == "ITA")                // "ITALO" normalized

        let unknownCat = response.rows.first { $0.trainNumber == "17105" }!
        #expect(unknownCat.category == "UNKNOWN")       // missing category
    }

    @Test func scheduledServiceLoadsPadova() async throws {
        let service = ScheduledTrainBoardService(
            provider: BundledScheduledTimetableProvider(),
            fallback: { let m = MockTrainBoardService(); m.artificialDelay = .zero; return m }()
        )
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.isScheduled == true)
        #expect(response.station.name == "Padova")
        #expect(!response.rows.isEmpty)
        #expect(response.rows.allSatisfy { $0.status == .scheduled && $0.delayMinutes == nil })
    }

    /// Provider that always fails — exercises the mandatory mock fallback.
    private struct FailingScheduledProvider: ScheduledTimetableProvider {
        func load(stationId: String) async throws -> ScheduledTimetableDTO {
            throw TrainBoardServiceError.resourceMissing
        }
    }

    @Test func scheduledServiceFallsBackToMockOnFailure() async throws {
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = ScheduledTrainBoardService(provider: FailingScheduledProvider(), fallback: mock)
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(!response.rows.isEmpty)            // fell back to mock data
        #expect(response.isScheduled == false)     // mock is not scheduled
    }

    @Test func scheduledServiceArrivalsFallBackToMock() async throws {
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = ScheduledTrainBoardService(provider: BundledScheduledTimetableProvider(), fallback: mock)
        let response = try await service.fetchBoard(stationId: "padova", type: .arrivals)
        #expect(response.isScheduled == false)     // arrivals not part of the scheduled spike
        #expect(response.boardType == .arrivals)
    }

    // MARK: - Scheduled sample time window (demo safety)

    /// A fixed wall-clock instant in Europe/Rome, for deterministic window tests.
    private static func romeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    /// Provider returning the inline Padova sample (which carries window metadata).
    private struct SamplePadovaProvider: ScheduledTimetableProvider {
        func load(stationId: String) async throws -> ScheduledTimetableDTO {
            try JSONDecoder().decode(ScheduledTimetableDTO.self,
                                     from: Data(Binario1Tests.sampleScheduledJSON.utf8))
        }
    }

    @Test func scheduledSampleWindowMetadata() throws {
        let ref = Self.romeDate(2026, 6, 15, 17, 40)            // afternoon
        let response = ScheduledTimetableMapper.map(try decodeSampleScheduled(), referenceDate: ref)
        let window = try #require(response.scheduledWindow)
        #expect(window.startLabel == "06:00")
        #expect(window.endLabel == "06:59")
        #expect(window.isSample == true)
        #expect(window.contains(Self.romeDate(2026, 6, 15, 6, 30)) == true)    // inside
        #expect(window.contains(ref) == false)                                 // 17:40 outside
        #expect(window.contains(Self.romeDate(2026, 6, 15, 5, 59)) == false)   // before window
    }

    @Test func scheduledSampleDoesNotRollMorningRowsToTomorrow() throws {
        let ref = Self.romeDate(2026, 6, 15, 17, 40)
        let response = ScheduledTimetableMapper.map(try decodeSampleScheduled(), referenceDate: ref)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        let earliest = try #require(response.rows.min(by: { $0.scheduledTime < $1.scheduledTime }))
        // 06:05 stays on the reference day — no "tomorrow" inference — i.e. earlier than 17:40.
        #expect(cal.isDate(earliest.scheduledTime, inSameDayAs: ref))
        #expect(earliest.scheduledTime < ref)
    }

    @MainActor
    @Test func noNextHighlightWhenScheduledSampleOutsideWindow() async {
        let outside = Self.romeDate(2026, 6, 15, 17, 40)
        let service = ScheduledTrainBoardService(
            provider: SamplePadovaProvider(),
            fallback: { let m = MockTrainBoardService(); m.artificialDelay = .zero; return m }(),
            referenceDate: { outside }
        )
        let vm = StationBoardViewModel(service: service, station: .padova,
                                       allowsStationChange: false, now: { outside })
        await vm.refresh()
        #expect(vm.isScheduled == true)
        #expect(vm.isScheduledSampleOutOfWindow == true)
        #expect(vm.imminentRowID == nil)            // nothing highlighted as current/next
        #expect(!vm.featuredRows.isEmpty)           // rows still rendered (programmed)
    }

    @MainActor
    @Test func nextHighlightWhenScheduledSampleInsideWindow() async {
        let inside = Self.romeDate(2026, 6, 15, 6, 30)
        let service = ScheduledTrainBoardService(
            provider: SamplePadovaProvider(),
            fallback: { let m = MockTrainBoardService(); m.artificialDelay = .zero; return m }(),
            referenceDate: { inside }
        )
        let vm = StationBoardViewModel(service: service, station: .padova,
                                       allowsStationChange: false, now: { inside })
        await vm.refresh()
        #expect(vm.isScheduledSampleOutOfWindow == false)
        #expect(vm.imminentRowID != nil)            // within window → normal highlight
    }

    @MainActor
    @Test func mockHighlightUnaffectedByWindowLogic() async {
        let service = MockTrainBoardService(); service.artificialDelay = .zero
        let vm = StationBoardViewModel(service: service, station: .bolognaCentrale)
        await vm.refresh()
        #expect(vm.isScheduled == false)
        #expect(vm.scheduledWindow == nil)
        #expect(vm.isScheduledSampleOutOfWindow == false)
        #expect(vm.imminentRowID != nil)            // mock highlight unchanged
    }

    // MARK: - Viaggi (Trips) dashboard

    @MainActor
    @Test func mockTripsServiceLoadsDashboard() async throws {
        let service = MockTripsService(); service.artificialDelay = .zero
        let data = try await service.loadTrips()
        #expect(data.saved.count == 2)
        #expect(data.suggested != nil)
        #expect(data.recent.count == 3)
        #expect(data.saved.first?.direction == .homeToWork)
        #expect(data.saved.first?.origin == "Montegrotto Terme")
        #expect(data.saved.first?.status == .onTime)
        #expect(data.saved.last?.status == .delayed(minutes: 12))
        #expect(data.suggested?.destination == "Venezia Santa Lucia")
        #expect(data.suggested?.platform == "6")
    }

    @Test func savedJourneyDisplayDataFormatting() {
        let j = SavedJourney(
            id: "x", direction: .homeToWork,
            origin: "Montegrotto Terme", destination: "Padova",
            departure: Self.romeDate(2026, 6, 15, 7, 18),
            platform: "2", durationMinutes: 37, status: .onTime, isFavorite: true
        )
        let d = JourneyDisplayData.make(j)
        #expect(d.departureText == "07:18")
        #expect(d.durationText == "37 min")
        #expect(d.routeText == "Montegrotto Terme → Padova")
        #expect(d.platformDisplay == "2")
        #expect(d.accessibilityLabel.contains("Montegrotto Terme"))   // full name read out
        #expect(d.accessibilityLabel.contains("Padova"))
    }

    @Test func suggestedJourneyDisplayDataHasArrivalAndTrain() {
        let j = SuggestedJourney(
            id: "u", origin: "Padova", destination: "Venezia Santa Lucia",
            departure: Self.romeDate(2026, 6, 15, 17, 45),
            arrival: Self.romeDate(2026, 6, 15, 18, 13),
            category: "REG", trainNumber: "1722", platform: "6",
            durationMinutes: 28, status: .onTime
        )
        let d = JourneyDisplayData.make(j)
        #expect(d.departureText == "17:45")
        #expect(d.arrivalText == "18:13")
        #expect(d.trainText == "REG 1722")
        #expect(d.platformDisplay == "6")
    }

    @Test func recentJourneyDisplayDataIncludesPlatformInAccessibility() {
        let j = RecentJourney(
            id: "r", origin: "Bologna Centrale", destination: "Padova",
            departure: Self.romeDate(2026, 6, 15, 8, 32),
            category: "FR", trainNumber: "8602", durationMinutes: 62, platform: "5"
        )
        let d = JourneyDisplayData.make(j)
        #expect(d.departureText == "08:32")
        #expect(d.trainText == "FR 8602")
        #expect(d.accessibilityLabel.contains("FR 8602"))
    }

    @Test func journeyStatusCriticality() {
        #expect(JourneyStatus.onTime.isCritical == false)
        #expect(JourneyStatus.delayed(minutes: 3).isCritical == false)
        #expect(JourneyStatus.delayed(minutes: 12).isCritical == true)
        #expect(JourneyStatus.cancelled.isCritical == true)
    }

    @MainActor
    @Test func tripsViewModelLoadsAndFilters() async {
        let service = MockTripsService(); service.artificialDelay = .zero
        let vm = TripsViewModel(service: service)
        await vm.load()
        #expect(vm.hasData)
        #expect(vm.savedJourneys.count == 2)
        #expect(vm.recentJourneys.count == 3)
        #expect(vm.errorMessageKey == nil)

        // Today shows all sections.
        vm.selectFilter(.today)
        #expect(vm.showsSuggestedSection && vm.showsSavedSection && vm.showsRecentSection)
        // Saved shows only saved.
        vm.selectFilter(.saved)
        #expect(vm.showsSavedSection && !vm.showsSuggestedSection && !vm.showsRecentSection)
        // Recent shows only recent.
        vm.selectFilter(.recent)
        #expect(vm.showsRecentSection && !vm.showsSavedSection && !vm.showsSuggestedSection)
    }

    // MARK: - Cerca (Search)

    @MainActor
    @Test func cercaViewModelFilters() {
        let vm = CercaViewModel()
        // Idle: not searching, everything shown.
        #expect(vm.isSearching == false)
        #expect(vm.hasResults)
        #expect(vm.stations.contains("Padova"))

        // Case-insensitive query narrows across sections.
        vm.query = "venezia"
        #expect(vm.isSearching)
        #expect(vm.stations.contains("Venezia Santa Lucia"))
        #expect(vm.routes.contains("Padova → Venezia Santa Lucia"))
        #expect(vm.trains.isEmpty)

        // Train number query matches only trains.
        vm.query = "1722"
        #expect(vm.trains.contains("REG 1722"))
        #expect(vm.stations.isEmpty)
        #expect(vm.routes.isEmpty)

        // No match → no results.
        vm.query = "zzzz"
        #expect(!vm.hasResults)

        // Whitespace-only query is treated as idle.
        vm.query = "   "
        #expect(vm.isSearching == false)
        #expect(vm.hasResults)
    }

    // MARK: - Numeric text polish

    @Test func boardNumberDerivesRollingKeyFromDigits() {
        #expect(BoardNumber.value(from: "07:18") == 718)
        #expect(BoardNumber.value(from: "17:46") == 1746)
        #expect(BoardNumber.value(from: "+12 min") == 12)
        #expect(BoardNumber.value(from: "37 min") == 37)
        #expect(BoardNumber.value(from: "6") == 6)
        #expect(BoardNumber.value(from: "--") == 0)        // no digits → 0, no crash
    }

    @Test func recentJourneyTimesAreSingleLineHHmm() {
        let ref = Self.romeDate(2026, 6, 15, 12, 0)
        for journey in MockTripsService.sample(on: ref).recent {
            let t = JourneyDisplayData.make(journey).departureText
            #expect(t.count == 5)                          // "HH:mm" — fixed width
            #expect(t.contains(":"))
            #expect(!t.contains(" "))                       // single token (no wrap-inducing spaces)
            #expect(!t.contains("\n"))
        }
    }

    /// The alignment/numeric polish is view-layer only — the underlying display
    /// strings (time/platform/duration/delay) must stay exactly correct.
    @Test func viaggiDisplayStringsRemainCorrect() {
        let data = MockTripsService.sample(on: Self.romeDate(2026, 6, 15, 12, 0))

        let homeWork = JourneyDisplayData.make(data.saved[0])
        #expect(homeWork.departureText == "07:18")
        #expect(homeWork.platformDisplay == "2")
        #expect(homeWork.durationText == "37 min")

        let workHome = JourneyDisplayData.make(data.saved[1])
        #expect(workHome.departureText == "17:46")
        #expect(workHome.platformDisplay == "4")
        #expect(workHome.durationText == "39 min")
        #expect(data.saved[1].status == .delayed(minutes: 12))

        let useful = JourneyDisplayData.make(data.suggested!)
        #expect(useful.departureText == "17:45")
        #expect(useful.arrivalText == "18:13")
        #expect(useful.platformDisplay == "6")
        #expect(useful.durationText == "28 min")
    }

    // MARK: - Station title (reveal target = full name)

    /// The animated title reveal completes to `totalReal` characters, which equals
    /// the full station title. Guards the "stuck on first character" regression by
    /// pinning the title the reveal must reach.
    @Test func stationTitleResolvesToFullName() {
        let padova = StationNameFormatter.boardTitle(for: "Padova")
        #expect(padova.primary == "PADOVA")
        #expect(padova.secondary == "")
        #expect(padova.primary.count == 6)        // reveal must reach 6 → full "PADOVA", not "P"

        let bologna = StationNameFormatter.boardTitle(for: "Bologna Centrale")
        #expect(bologna.primary == "BOLOGNA")
        #expect(bologna.secondary == "CENTRALE")
    }

    // MARK: - Delay color policy

    @Test func delayVisualStateThresholds() {
        #expect(DelayVisualState.from(delayMinutes: nil, isCancelled: false) == nil)   // no badge
        #expect(DelayVisualState.from(delayMinutes: 0, isCancelled: false) == nil)     // no badge
        #expect(DelayVisualState.from(delayMinutes: 3, isCancelled: false) == .mild)
        #expect(DelayVisualState.from(delayMinutes: 7, isCancelled: false) == .medium)
        #expect(DelayVisualState.from(delayMinutes: 15, isCancelled: false) == .severe)
        #expect(DelayVisualState.from(delayMinutes: nil, isCancelled: true) == .cancelled)
        #expect(DelayVisualState.from(delayMinutes: 3, isCancelled: true) == .cancelled) // cancelled wins
    }

    // MARK: - Board refresh dedupe (duplicate-fetch hardening)

    private final class CountingBoardService: TrainBoardService, @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
        func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
            lock.lock(); _count += 1; lock.unlock()
            return StationBoardResponse(
                station: .padova, boardType: type, locale: nil, supportedLocales: [],
                rows: [], generatedAt: Date(), sourceUpdatedAt: nil, isStale: false, warningMessageKey: nil
            )
        }
    }

    @MainActor
    @Test func boardRefreshDedupesRapidDuplicatesButAllowsForceAndBoardChange() async {
        let service = CountingBoardService()
        let fixed = Self.romeDate(2026, 6, 16, 17, 0)
        let vm = StationBoardViewModel(service: service, station: .padova,
                                       allowsStationChange: false, now: { fixed })
        await vm.refresh()                  // first load
        await vm.refresh()                  // rapid duplicate (same board, same instant) → deduped
        #expect(service.count == 1)

        await vm.refresh(force: true)       // manual pull-to-refresh bypasses dedupe
        #expect(service.count == 2)

        vm.selectBoardType(.arrivals)       // board change → different key, not deduped
        await vm.refresh()
        #expect(service.count == 3)
    }

    // MARK: - Backend adapter Phase 1 (DTO → mapper → fixture service)

    /// Mirrors Binario1Tests/Fixtures/backend-padova-departures.sample.json (and the
    /// app resource) so DTO/mapper/service tests never touch the network.
    fileprivate static let backendFixtureJSON = """
    {
      "station": { "id": "padova", "name": "Padova", "sourcePlaceId": "2000" },
      "boardType": "departures",
      "source": {
        "kind": "rfiLive", "label": "Monitor RFI online",
        "updatedAt": "2026-06-17T10:49:00+02:00", "fetchedAt": "2026-06-17T10:50:12+02:00",
        "isFallback": false, "isStale": false
      },
      "rows": [
        { "id": "REG-16971-1049", "scheduledTime": "10:49", "category": "REG", "trainNumber": "16971", "destination": "Venezia Mestre", "platform": "2", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "RV-2774-1052", "scheduledTime": "10:52", "category": "RV", "trainNumber": "2774", "destination": "Venezia Santa Lucia", "platform": "2", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "AV-9805-1058", "scheduledTime": "10:58", "category": "AV", "trainNumber": "9805", "destination": "Napoli Centrale", "platform": "1", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "AV-9806-1104", "scheduledTime": "11:04", "category": "AV", "trainNumber": "9806", "destination": "Venezia Santa Lucia", "platform": "2", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "REG-5930-1110", "scheduledTime": "11:10", "category": "REG", "trainNumber": "5930", "destination": "Belluno", "platform": "7", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "RV-2280-1115", "scheduledTime": "11:15", "category": "RV", "trainNumber": "2280", "destination": "Bologna Centrale", "platform": "1", "delayMinutes": 0, "status": "onTime", "notes": [] },
        { "id": "IC-603-1120", "scheduledTime": "11:20", "category": "IC", "trainNumber": "603", "destination": "Roma Termini", "platform": "3", "delayMinutes": 5, "status": "delayed", "notes": [] },
        { "id": "AV-9412-1126", "scheduledTime": "11:26", "category": "AV", "trainNumber": "9412", "destination": "Milano Centrale", "platform": "4", "delayMinutes": 12, "status": "delayed", "notes": [] },
        { "id": "REG-5932-1130", "scheduledTime": "11:30", "category": "REG", "trainNumber": "5932", "destination": "Castelfranco Veneto", "platform": null, "delayMinutes": 0, "status": "cancelled", "notes": ["Treno cancellato"] }
      ],
      "diagnostics": { "sourceStatus": 200, "sourceBytes": 335041, "parsedRows": 9 }
    }
    """

    private struct StubBackendFetcher: BackendBoardFetching {
        let data: Data
        func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data { data }
    }

    @Test func backendFixtureDTODecodes() throws {
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: Data(Self.backendFixtureJSON.utf8))
        #expect(dto.station.id == "padova")
        #expect(dto.station.name == "Padova")
        #expect(dto.station.sourcePlaceId == "2000")
        #expect(dto.boardType == "departures")
        #expect(dto.source.kind == "rfiLive")
        #expect(dto.source.label == "Monitor RFI online")
        #expect(dto.source.isFallback == false)
        #expect(dto.rows.count == 9)
        #expect(dto.rows.first?.category == "REG")
        #expect(dto.rows.first?.trainNumber == "16971")
        #expect(dto.diagnostics?.parsedRows == 9)   // optional diagnostics decodes
    }

    @Test func backendDTODecodesWithoutDiagnostics() throws {
        // diagnostics is optional (production omits it) — decoding must still succeed.
        let json = #"{"station":{"id":"padova","name":"Padova","sourcePlaceId":null},"boardType":"departures","source":{"kind":"rfiLive","label":"Monitor RFI online"},"rows":[]}"#
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: Data(json.utf8))
        #expect(dto.diagnostics == nil)
        #expect(dto.station.sourcePlaceId == nil)
        #expect(dto.source.isFallback == nil)
    }

    @Test func backendMapperProducesNormalizedRows() throws {
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: Data(Self.backendFixtureJSON.utf8))
        let response = BackendBoardMapper.map(dto, referenceDate: Self.romeDate(2026, 6, 17, 10, 50))

        #expect(response.rows.count == 9)               // row count preserved
        #expect(response.station.id == "padova")
        #expect(response.boardType == .departures)
        #expect(response.sourceKind == .rfiLive)        // mapper maps source.kind (service overrides to .backendFixture)

        for r in response.rows {                        // categories stay compact, no leakage
            #expect(!r.category.contains("Categoria"))
            #expect(!r.category.contains("&#"))
            #expect(r.category.count <= 5)
        }

        let onTime = response.rows.first { $0.id == "REG-16971-1049" }
        #expect(onTime?.delayMinutes == nil)            // 0 delay → no delay badge
        #expect(onTime?.actualPlatform == "2")
        #expect(onTime?.status == .onTime)

        let d5 = response.rows.first { $0.id == "IC-603-1120" }
        #expect(d5?.delayMinutes == 5)
        #expect(DelayVisualState.from(delayMinutes: d5?.delayMinutes, isCancelled: false) == .medium)

        let d12 = response.rows.first { $0.id == "AV-9412-1126" }
        #expect(d12?.delayMinutes == 12)
        #expect(DelayVisualState.from(delayMinutes: d12?.delayMinutes, isCancelled: false) == .severe)

        let cancelled = response.rows.first { $0.status == .cancelled }
        #expect(cancelled != nil)
        #expect(cancelled?.platformDisplay == "--")     // missing platform → "--"
        #expect(cancelled?.delayMinutes == nil)         // cancelled → no delay
    }

    @Test func backendServiceLoadsFixtureWithoutNetwork() async throws {
        let stub = StubBackendFetcher(data: Data(Self.backendFixtureJSON.utf8))
        let service = BackendBoardService(fetcher: stub, fallback: MockTrainBoardService(),
                                          referenceDate: { Self.romeDate(2026, 6, 17, 10, 50) })
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.rows.count == 9)
        #expect(response.station.id == "padova")
        #expect(response.sourceKind == .backendFixture) // service labels it a fixture
        #expect(response.rows.allSatisfy { !$0.category.contains("Categoria") && !$0.category.contains("&#") })
    }

    // MARK: - Backend live fetcher (Phase 2B, URLSession + stubbed URLProtocol)

    @Test func backendURLBuilderMatchesContract() {
        let base = URL(string: "https://example.functions.supabase.co")!
        let url = URLSessionBackendBoardFetcher.makeURL(base: base, stationSlug: "padova", type: .departures, locale: "it")
        #expect(url?.absoluteString == "https://example.functions.supabase.co/board?stationSlug=padova&type=departures&locale=it")
    }

    @Test func backendFetcherReturnsDataOn200() async throws {
        let fetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-200.example")!),
            session: makeStubSession())
        let data = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        #expect(!data.isEmpty)
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: data)
        #expect(dto.station.id == "padova")
    }

    @Test func backendFetcherThrowsOnNon2xx() async {
        let fetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-502.example")!),
            session: makeStubSession())
        await #expect(throws: BackendFetchError.httpStatus(502)) {
            _ = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        }
    }

    @Test func backendFetcherThrowsOnEmptyBody() async {
        let fetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-empty.example")!),
            session: makeStubSession())
        await #expect(throws: BackendFetchError.emptyResponse) {
            _ = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        }
    }

    @Test func backendServiceMapsRemoteJSONStampedLive() async throws {
        let fetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-200.example")!),
            session: makeStubSession())
        let service = BackendBoardService(
            fetcher: fetcher, fallback: MockTrainBoardService(),
            referenceDate: { Self.romeDate(2026, 6, 17, 10, 50) },
            stampSourceKind: .backendLive, debugLogTag: "BackendLive")
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.rows.count == 9)
        #expect(response.sourceKind == .backendLive)   // came through the backend, stamped live
        #expect(response.rows.allSatisfy {
            !$0.category.contains("Categoria") && !$0.category.contains("&#") && $0.category.count <= 5
        })
        let d5 = response.rows.first { $0.id == "IC-603-1120" }
        #expect(d5?.delayMinutes == 5)
        #expect(d5?.status == .delayed)
    }

    @Test func backendEndpointConfigDetectsPlaceholder() {
        let placeholder = BackendEndpointConfig(baseURL: URL(string: "https://\(BackendEndpointConfig.placeholderHost).functions.supabase.co")!)
        #expect(placeholder.isConfigured == false)
        let real = BackendEndpointConfig(baseURL: URL(string: "https://abcd1234.functions.supabase.co")!)
        #expect(real.isConfigured == true)
    }

    @Test func appTokenResolutionPrefersBuildTimeThenEnvThenEmpty() {
        // 1) build-time Info.plist value wins over the scheme env var
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: "build-token", envValue: "env-token") == "build-token")
        // 2) falls back to the env var when the build-time value is absent/blank/placeholder/unresolved
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: nil, envValue: "env-token") == "env-token")
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: "   ", envValue: "env-token") == "env-token")
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: "$(BINARIO_BOARD_APP_TOKEN)", envValue: "env-token") == "env-token")
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: "paste-local-token-here", envValue: "env-token") == "env-token")
        // 3) empty when neither is configured
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: nil, envValue: nil) == "")
        #expect(BackendEndpointConfig.resolveAppToken(infoValue: "  ", envValue: "  ") == "")
    }

    // MARK: - App-token header (Hardening Phase 1)

    @Test func backendFetcherAttachesAppTokenWhenConfigured() async throws {
        var cfg = BackendEndpointConfig(baseURL: URL(string: "https://stub-echotoken.example")!)
        cfg.appToken = "tok-123"
        let fetcher = URLSessionBackendBoardFetcher(config: cfg, session: makeStubSession())
        let data = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        let echoed = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(echoed?["received"] == "tok-123")
    }

    @Test func backendFetcherOmitsTokenHeaderWhenEmpty() async throws {
        let cfg = BackendEndpointConfig(baseURL: URL(string: "https://stub-echotoken.example")!) // appToken defaults to ""
        let fetcher = URLSessionBackendBoardFetcher(config: cfg, session: makeStubSession())
        let data = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        let echoed = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(echoed?["received"] == "")   // no header attached → server sees nothing
    }

    @Test func backendFetcherThrowsTypedErrorOn401() async {
        let fetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-401.example")!),
            session: makeStubSession())
        await #expect(throws: BackendFetchError.httpStatus(401)) {
            _ = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .departures, locale: "it")
        }
    }

    @Test func backendServiceFallsBackToFixtureOn401() async throws {
        let liveFetcher = URLSessionBackendBoardFetcher(
            config: BackendEndpointConfig(baseURL: URL(string: "https://stub-401.example")!),
            session: makeStubSession())
        let fixtureFallback = BackendBoardService(
            fetcher: StubBackendFetcher(data: Data(Self.backendFixtureJSON.utf8)),
            fallback: MockTrainBoardService(),
            referenceDate: { Self.romeDate(2026, 6, 17, 10, 50) },
            stampSourceKind: .backendFixture)
        let service = BackendBoardService(
            fetcher: liveFetcher, fallback: fixtureFallback,
            referenceDate: { Self.romeDate(2026, 6, 17, 10, 50) },
            stampSourceKind: .backendLive, debugLogTag: "BackendLive")
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.rows.count == 9)                  // served by the fixture fallback
        #expect(response.sourceKind == .backendFixture)    // 401 → visible fixture fallback
    }

    // MARK: - Source label cleanup + personalized featured section

    @Test func backendSourceLabelsDropMonitorWord() {
        let app = Bundle(for: StationBoardViewModel.self)
        for loc in ["it", "en"] {
            let fixture = String(localized: "source.backendFixture", bundle: app, locale: Locale(identifier: loc))
            let live = String(localized: "source.backendLive", bundle: app, locale: Locale(identifier: loc))
            guard fixture != "source.backendFixture", live != "source.backendLive" else {
                print("[Test] backend source labels not resolvable in test bundle — skipping")
                return
            }
            #expect(fixture == "Backend fixture · RFI online")
            #expect(live == "Backend · RFI online")
            #expect(!fixture.contains("Monitor"))
            #expect(!live.contains("Monitor"))
            // The direct RFI-live label (DEBUG header) is de-"Monitor"ed too, so no
            // visible "Monitor RFI online" remains anywhere in the header path.
            let rfi = String(localized: "source.rfiLive", bundle: app, locale: Locale(identifier: loc))
            let rfiUpdated = String(localized: "source.rfiLiveUpdated", bundle: app, locale: Locale(identifier: loc))
            #expect(rfi == "RFI online")
            #expect(!rfi.contains("Monitor"))
            #expect(!rfiUpdated.contains("Monitor"))
        }
    }

    @Test func stationNameMatcherNormalizesCommonForms() {
        #expect(StationNameMatcher.matches("VENEZIA S.LUCIA", "Venezia Santa Lucia"))
        #expect(StationNameMatcher.matches("Venezia S. Lucia", "VENEZIA SANTA LUCIA"))
        #expect(StationNameMatcher.matches("Bologna C.LE", "Bologna Centrale"))
        #expect(StationNameMatcher.matches("Verona P.Nuova", "Verona Porta Nuova"))
        #expect(StationNameMatcher.matches("Padova", "padova"))
        // A single shared/generic token or a bare city prefix must NOT match different places.
        #expect(!StationNameMatcher.matches("Milano", "Milano Centrale"))
        #expect(!StationNameMatcher.matches("Centrale", "Milano Centrale"))
        #expect(!StationNameMatcher.matches("Venezia", "Venezia Mestre"))
        #expect(!StationNameMatcher.matches("Venezia Mestre", "Venezia Santa Lucia"))
        #expect(!StationNameMatcher.matches("Milano", "Torino"))
        #expect(!StationNameMatcher.matches(nil, "Padova"))
    }

    private struct FixedBoardService: TrainBoardService {
        let rows: [TrainBoardRow]
        func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
            StationBoardResponse(station: .padova, boardType: type, locale: nil, supportedLocales: [],
                                 rows: rows, generatedAt: Self.fixedDate, sourceUpdatedAt: nil,
                                 isStale: false, warningMessageKey: nil)
        }
        static let fixedDate = Binario1Tests.romeDate(2026, 6, 17, 18, 0)
    }

    private static func boardRow(_ id: String, _ destination: String, _ h: Int, _ m: Int,
                                 status: TrainStatus = .onTime, delay: Int? = nil) -> TrainBoardRow {
        let t = romeDate(2026, 6, 17, h, m)
        return TrainBoardRow(
            id: id, trainNumber: id, category: "AV", operatorName: nil, origin: nil,
            destination: destination, scheduledTime: t,
            expectedTime: delay.map { t.addingTimeInterval(Double($0) * 60) }, delayMinutes: delay,
            plannedPlatform: nil, actualPlatform: "1", status: status, notes: nil, lastUpdated: t)
    }

    private static func savedTo(_ destination: String, from origin: String = "Padova") -> SavedJourney {
        SavedJourney(id: "\(origin)->\(destination)", direction: .workToHome, origin: origin,
                     destination: destination, departure: romeDate(2026, 6, 17, 17, 46),
                     platform: nil, durationMinutes: 30, status: .onTime)
    }

    @MainActor
    @Test func personalizedFeaturedShowsMatchingSavedJourneyTrains() async {
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "VENEZIA S.LUCIA", 18, 10),
            Self.boardRow("r3", "Verona Porta Nuova", 18, 20),
            Self.boardRow("r4", "Venezia S. Lucia", 18, 30),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: [Self.savedTo("Venezia Santa Lucia")])
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == true)
        #expect(vm.featuredTitleKey == "section.yourNextTrains")
        #expect(vm.featuredRows.map(\.id) == ["r2", "r4"])   // only Venezia S. Lucia, scheduled order
        #expect(vm.imminentRowID == "r2")                    // soonest matching train highlighted
        #expect(vm.listRows.count == rows.count)             // full station board remains below
    }

    @MainActor
    @Test func featuredFallsBackToGenericWhenNoSavedJourneyMatches() async {
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "Milano Centrale", 18, 10),
            Self.boardRow("r3", "Verona Porta Nuova", 18, 20),
            Self.boardRow("r4", "Trieste Centrale", 18, 30),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: [Self.savedTo("Venezia Santa Lucia")])  // not on the board
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == false)
        #expect(vm.featuredTitleKey == "section.nextDepartures")
        #expect(vm.featuredRows.map(\.id) == ["r1", "r2", "r3"])   // generic top 3
        #expect(vm.listRows.map(\.id) == ["r3", "r4"])             // existing dropFirst(2) behavior
    }

    @MainActor
    @Test func personalizedFeaturedKeepsCancelledAndDelayedTrains() async {
        let rows = [
            Self.boardRow("c", "Venezia S.Lucia", 18, 5, status: .cancelled),
            Self.boardRow("d", "Venezia Santa Lucia", 18, 15, status: .delayed, delay: 35),
            Self.boardRow("o", "Bologna Centrale", 18, 25),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: [Self.savedTo("Venezia Santa Lucia")])
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == true)
        let ids = Set(vm.featuredRows.map(\.id))
        #expect(ids.contains("c"))    // cancelled match still shown
        #expect(ids.contains("d"))    // severe-delay match still shown
        #expect(!ids.contains("o"))   // non-matching destination excluded
    }

    // MARK: - Arrivals + board-type request (station registry / Arrivi)

    @Test func backendURLBuilderUsesBoardType() {
        let base = URL(string: "https://example.functions.supabase.co")!
        let dep = URLSessionBackendBoardFetcher.makeURL(base: base, stationSlug: "padova", type: .departures, locale: "it")
        let arr = URLSessionBackendBoardFetcher.makeURL(base: base, stationSlug: "padova", type: .arrivals, locale: "it")
        #expect(dep?.absoluteString == "https://example.functions.supabase.co/board?stationSlug=padova&type=departures&locale=it")
        #expect(arr?.absoluteString == "https://example.functions.supabase.co/board?stationSlug=padova&type=arrivals&locale=it")
    }

    @Test func backendDTODecodesArrivals() throws {
        let json = #"{"station":{"id":"padova","name":"Padova","sourcePlaceId":"2000"},"boardType":"arrivals","source":{"kind":"rfiLive","label":"RFI online"},"rows":[{"id":"AV-1-1010","scheduledTime":"10:10","category":"AV","trainNumber":"1","destination":"Reggio di Calabria Centrale","platform":"5","delayMinutes":0,"status":"onTime","notes":[]}]}"#
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: Data(json.utf8))
        #expect(dto.boardType == "arrivals")
        #expect(dto.rows.first?.destination == "Reggio di Calabria Centrale")
    }

    @Test func backendMapperMapsArrivalsPlaceToOrigin() throws {
        // For arrivals the contract's `destination` carries the ORIGIN/provenance.
        let json = #"{"station":{"id":"padova","name":"Padova","sourcePlaceId":"2000"},"boardType":"arrivals","source":{"kind":"rfiLive","label":"RFI online"},"rows":[{"id":"AV-1-1010","scheduledTime":"10:10","category":"AV","trainNumber":"1","destination":"Reggio di Calabria Centrale","platform":"5","delayMinutes":0,"status":"onTime","notes":[]},{"id":"REG-2-1012","scheduledTime":"10:12","category":"REG","trainNumber":"2","destination":"Venezia Santa Lucia","platform":"3","delayMinutes":7,"status":"delayed","notes":[]}]}"#
        let dto = try JSONDecoder().decode(BackendBoardDTO.self, from: Data(json.utf8))
        let response = BackendBoardMapper.map(dto, referenceDate: Self.romeDate(2026, 6, 17, 10, 0))
        #expect(response.boardType == .arrivals)
        let first = response.rows.first
        #expect(first?.origin == "Reggio di Calabria Centrale")   // place → origin for arrivals
        #expect(first?.destination == nil)
        #expect(first?.displayPlace(for: .arrivals) == "Reggio di Calabria Centrale")
        #expect(first?.category == "AV")
        let delayed = response.rows.first { $0.id == "REG-2-1012" }
        #expect(delayed?.delayMinutes == 7)
        #expect(delayed?.status == .delayed)
    }

    @Test func fixtureFetcherRejectsArrivals() async {
        // The bundled fixture is departures-only; arrivals must throw so the service
        // can fall back (never serve departures rows under the Arrivi board).
        let fetcher = FixtureBackendBoardFetcher()
        await #expect(throws: TrainBoardServiceError.self) {
            _ = try await fetcher.fetchBoardJSON(stationSlug: "padova", type: .arrivals, locale: "it")
        }
    }

    @MainActor
    @Test func arrivalsDoNotPersonalizeAndUseGenericTitle() async {
        let rows = [
            Self.boardRow("a1", "Venezia Santa Lucia", 18, 0),
            Self.boardRow("a2", "Bologna Centrale", 18, 10),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: [Self.savedTo("Venezia Santa Lucia")])  // would match on departures
        vm.selectBoardType(.arrivals)
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == false)             // personalization is departures-only for now
        #expect(vm.featuredTitleKey == "section.nextArrivals")
        #expect(vm.featuredRows.count == 2)                       // generic top rows
    }

    @Test func fullBoardTitleFormatKeysAreStationScoped() {
        // Full-board section title is station-scoped ("… da/ a %@").
        #expect(BoardType.departures.allSectionTitleFormatKey == "section.allDeparturesFrom")
        #expect(BoardType.arrivals.allSectionTitleFormatKey == "section.allArrivalsTo")
    }

    private final class RecordingBackendFetcher: BackendBoardFetching, @unchecked Sendable {
        private let lock = NSLock()
        private var _types: [BoardType] = []
        var types: [BoardType] { lock.lock(); defer { lock.unlock() }; return _types }
        let data: Data
        init(data: Data) { self.data = data }
        func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
            lock.lock(); _types.append(type); lock.unlock()
            return data
        }
    }

    private struct DepartureOnlyFetcher: BackendBoardFetching {
        let data: Data
        func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
            guard type == .departures else { throw TrainBoardServiceError.resourceMissing }  // like the bundled fixture
            return data
        }
    }

    @Test func backendServiceForwardsArrivalsToFetcher() async throws {
        let arrivalsJSON = #"{"station":{"id":"padova","name":"Padova","sourcePlaceId":"2000"},"boardType":"arrivals","source":{"kind":"rfiLive","label":"RFI online"},"rows":[{"id":"AV-1-1010","scheduledTime":"10:10","category":"AV","trainNumber":"1","destination":"Reggio di Calabria Centrale","platform":"5","delayMinutes":0,"status":"onTime","notes":[]}]}"#
        let fetcher = RecordingBackendFetcher(data: Data(arrivalsJSON.utf8))
        let service = BackendBoardService(fetcher: fetcher, fallback: MockTrainBoardService(),
                                          referenceDate: { Self.romeDate(2026, 6, 17, 10, 0) },
                                          stampSourceKind: .backendLive)
        let response = try await service.fetchBoard(stationId: "padova", type: .arrivals)
        #expect(fetcher.types == [.arrivals])                  // service forwards the board type
        #expect(response.boardType == .arrivals)
        #expect(response.sourceKind == .backendLive)
        #expect(response.rows.first?.origin == "Reggio di Calabria Centrale")
    }

    @Test func backendServiceFallsBackWhenFetcherRejectsArrivals() async throws {
        // Departures-only fetcher (like the bundled fixture) → arrivals throw → mock
        // fallback (never serve departures rows under the Arrivi board).
        let service = BackendBoardService(fetcher: DepartureOnlyFetcher(data: Data(Self.backendFixtureJSON.utf8)),
                                          fallback: MockTrainBoardService(),
                                          referenceDate: { Self.romeDate(2026, 6, 17, 10, 0) },
                                          stampSourceKind: .backendFixture)
        let response = try await service.fetchBoard(stationId: "padova", type: .arrivals)
        #expect(response.sourceKind == .mock)                  // fell back to mock, not the fixture
    }

    // MARK: - Saved journeys persistence (SavedJourneyStore) + Home wiring

    private func freshStore(_ suite: String) -> UserDefaultsSavedJourneyStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)   // isolate each test
        return UserDefaultsSavedJourneyStore(defaults: defaults)
    }

    @Test func savedStoreSaveLoadAddDeleteRoundtrip() {
        let store = freshStore("binario1.tests.roundtrip")
        #expect(store.load().isEmpty)
        let a = Self.savedTo("Venezia Santa Lucia")
        let b = Self.savedTo("Bologna Centrale")
        store.save([a, b])
        #expect(store.load().count == 2)
        store.add(a)                                       // upsert by id — no duplicate
        #expect(store.load().count == 2)
        let c = Self.savedTo("Milano Centrale")
        store.add(c)
        #expect(store.load().count == 3)
        store.delete(id: b.id)
        let ids = Set(store.load().map(\.id))
        #expect(ids.contains(a.id))
        #expect(ids.contains(c.id))
        #expect(!ids.contains(b.id))
    }

    @Test func savedStoreSeedsOnceAndRespectsDeletion() {
        let store = freshStore("binario1.tests.seed")
        store.seedIfNeeded(SavedJourneySeed.initial())
        #expect(!store.load().isEmpty)                     // seeded on first launch
        store.save([])                                     // user clears everything
        #expect(store.load().isEmpty)
        store.seedIfNeeded(SavedJourneySeed.initial())     // second launch must NOT re-seed
        #expect(store.load().isEmpty)
    }

    @Test func seededJourneysDoNotContainTheRemovedDemo() {
        // The old Padova → Venezia S. Lucia Home demo must not be real user data.
        let seeded = SavedJourneySeed.initial()
        #expect(!seeded.contains { $0.id == "home-demo-padova-venezia" })
        #expect(!seeded.contains { $0.origin == "Padova" && $0.destination == "Venezia Santa Lucia" })
    }

    @MainActor
    @Test func homeUsesPersistedSavedJourneysForPersonalization() async {
        let store = freshStore("binario1.tests.home-persisted")
        store.add(Self.savedTo("Venezia Santa Lucia"))     // persisted, NON-demo journey
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "VENEZIA S.LUCIA", 18, 10),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: store.load())
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == true)
        #expect(vm.featuredTitleKey == "section.yourNextTrains")
        #expect(vm.featuredRows.map(\.id) == ["r2"])
    }

    @MainActor
    @Test func homeFallsBackToGenericWhenNoPersistedJourneys() async {
        let store = freshStore("binario1.tests.home-empty")   // empty store
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "Venezia Santa Lucia", 18, 10),
            Self.boardRow("r3", "Verona Porta Nuova", 18, 20),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: store.load())   // []
        await vm.refresh()
        #expect(vm.usesPersonalizedFeatured == false)
        #expect(vm.featuredTitleKey == "section.nextDepartures")
    }

    @MainActor
    @Test func tripsViewModelDeleteRemovesJourneyAndItDoesNotReappear() async {
        let store = freshStore("binario1.tests.trips-delete")
        let service = MockTripsService(); service.artificialDelay = .zero
        let vm = TripsViewModel(service: service, savedStore: store)
        await vm.load()                                            // seeds sample saved journeys
        #expect(!vm.savedJourneys.isEmpty)
        let target = vm.savedJourneys[0].id
        vm.deleteSavedJourney(id: target)
        #expect(!vm.savedJourneys.contains { $0.id == target })    // Viaggi list updated
        #expect(!store.load().contains { $0.id == target })        // store updated
        await vm.load()                                            // reload
        #expect(!vm.savedJourneys.contains { $0.id == target })    // deleted journey does not reappear
    }

    @MainActor
    @Test func homeFallsBackAfterDeletingTheOnlyMatchingJourney() async {
        let store = freshStore("binario1.tests.home-delete")
        let saved = Self.savedTo("Venezia Santa Lucia")
        store.add(saved)
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "VENEZIA S.LUCIA", 18, 10),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: store.load(),
                                       savedJourneysProvider: { store.load() })
        await vm.refresh(force: true)
        #expect(vm.usesPersonalizedFeatured == true)               // matches while saved
        store.delete(id: saved.id)                                 // deleted in Viaggi (same store)
        await vm.refresh(force: true)                              // Home re-reads on refresh
        #expect(vm.usesPersonalizedFeatured == false)
        #expect(vm.featuredTitleKey == "section.nextDepartures")
    }

    // MARK: - Save journey from Cerca (Search)

    @MainActor
    @Test func cercaSaveAddsValidRouteToStore() {
        let store = freshStore("binario1.tests.cerca-save")
        let vm = CercaViewModel(savedStore: store)
        #expect(vm.saveRoute("Padova → Venezia Santa Lucia", now: Self.romeDate(2026, 6, 17, 10, 0)) == .saved)
        let saved = store.load()
        #expect(saved.count == 1)
        #expect(saved.first?.origin == "Padova")
        #expect(saved.first?.destination == "Venezia Santa Lucia")
        #expect(vm.isRouteSaved("Padova → Venezia Santa Lucia") == true)
    }

    @MainActor
    @Test func cercaSaveIsIdempotentNoDuplicates() {
        let store = freshStore("binario1.tests.cerca-dup")
        let vm = CercaViewModel(savedStore: store)
        #expect(vm.saveRoute("Padova → Venezia Santa Lucia") == .saved)
        #expect(vm.saveRoute("padova → VENEZIA santa lucia") == .alreadySaved)   // canonical dedup
        #expect(store.load().count == 1)
    }

    @MainActor
    @Test func cercaSaveRejectsInvalidPair() {
        let store = freshStore("binario1.tests.cerca-invalid")
        let vm = CercaViewModel(savedStore: store)
        #expect(vm.saveRoute("Padova") == .invalid)          // no separator
        #expect(vm.saveRoute("Padova → ") == .invalid)       // empty destination
        #expect(vm.canSaveRoute("Padova") == false)
        #expect(store.load().isEmpty)
    }

    @Test func seedDoesNotClobberExistingSavedJourneys() {
        // A journey saved (e.g. from Cerca) before Viaggi's first seed must survive.
        let store = freshStore("binario1.tests.seed-noclobber")
        let j = Self.savedTo("Venezia Santa Lucia")
        store.add(j)
        store.seedIfNeeded(SavedJourneySeed.initial())
        #expect(store.load().contains { $0.id == j.id })   // not overwritten by the seed
    }

    @MainActor
    @Test func savedFromCercaAppearsInTripsAfterReload() async {
        let store = freshStore("binario1.tests.cerca-trips")
        let cerca = CercaViewModel(savedStore: store)
        #expect(cerca.saveRoute("Padova → Venezia Santa Lucia") == .saved)
        let service = MockTripsService(); service.artificialDelay = .zero
        let trips = TripsViewModel(service: service, savedStore: store)
        await trips.load()
        #expect(trips.savedJourneys.contains { $0.origin == "Padova" && $0.destination == "Venezia Santa Lucia" })
    }

    @MainActor
    @Test func homePersonalizesFromCercaSavedJourney() async {
        let store = freshStore("binario1.tests.cerca-home")
        let cerca = CercaViewModel(savedStore: store)
        #expect(cerca.saveRoute("Padova → Venezia Santa Lucia") == .saved)
        let rows = [
            Self.boardRow("r1", "Bologna Centrale", 18, 0),
            Self.boardRow("r2", "VENEZIA S.LUCIA", 18, 10),
        ]
        let vm = StationBoardViewModel(service: FixedBoardService(rows: rows), station: .padova,
                                       allowsStationChange: false, now: { Self.romeDate(2026, 6, 17, 17, 0) },
                                       savedJourneys: store.load(), savedJourneysProvider: { store.load() })
        await vm.refresh(force: true)
        #expect(vm.usesPersonalizedFeatured == true)
        #expect(vm.featuredTitleKey == "section.yourNextTrains")
        #expect(vm.featuredRows.map(\.id) == ["r2"])
    }

#if DEBUG
    // MARK: - RFI live Padova spike (DEBUG-only)
    // Mirrors Binario1Tests/Fixtures/rfi-padova-departures.sample.html so parser
    // tests never need live network.

    private static let rfiPadovaFixtureHTML = """
    <!DOCTYPE html>
    <html lang="it">
    <head><meta charset="utf-8" /><title>Monitor Partenze - PADOVA</title></head>
    <body>
      <div id="nomestazione">PADOVA</div>
      <div id="aggiornamento">Aggiornato alle 17:12</div>
      <table id="monitor">
        <thead><tr><th>Vettore</th><th>Cat</th><th>Treno</th><th>Dest</th><th>Ora</th><th>Rit</th><th>Bin</th><th>Info</th></tr></thead>
        <tbody>
          <tr class="riga">
            <td><img src="/i/trenitalia.png" alt="Trenitalia" /></td>
            <td><img src="/i/REG.png" alt="Categoria Regionale" /></td>
            <td>5928</td><td>VENEZIA SANTA LUCIA</td><td>17:18</td><td>0</td><td>1</td><td></td>
          </tr>
          <tr class="riga">
            <td><img src="/i/trenitalia.png" alt="Trenitalia" /></td>
            <td><img src="/i/AV.png" alt="Categoria Alta Velocita&#39;" /></td>
            <td>9402</td><td>ROMA TERMINI</td><td>17:25</td><td>10</td><td>5</td><td>In stazione</td>
          </tr>
          <tr class="riga lampeggia">
            <td><img src="/i/italo.png" alt="Italo" /></td>
            <td><img src="/i/ITA.png" alt="Categoria Italo" /></td>
            <td>9902</td><td>MILANO CENTRALE</td><td>17:34</td><td>0</td><td></td><td></td>
          </tr>
          <tr class="riga">
            <td><img src="/i/trenitalia.png" alt="Trenitalia" /></td>
            <td><img src="/i/RV.png" alt="Categoria Regionale Veloce" /></td>
            <td>2774</td><td>BOLOGNA CENTRALE</td><td>17:41</td><td>Cancellato</td><td>3</td><td>Treno cancellato</td>
          </tr>
        </tbody>
      </table>
    </body>
    </html>
    """

    private struct StubMonitorFetcher: RFIMonitorFetching {
        var html: String? = nil
        var failing: Bool = false
        func fetchMonitor(placeId: String, arrivals: Bool) async throws -> RFIMonitorFetchResult {
            if failing { throw TrainBoardServiceError.resourceMissing }
            let h = html ?? ""
            return RFIMonitorFetchResult(
                html: h,
                url: RFIStationMonitorClient.monitorURL(placeId: placeId, arrivals: arrivals),
                statusCode: 200, contentType: "text/html", byteCount: h.utf8.count
            )
        }
    }

    /// Thread-safe capture box for the diagnostics recorder closure.
    private final class DiagBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: RFIStationMonitorDiagnostics?
        var value: RFIStationMonitorDiagnostics? { lock.lock(); defer { lock.unlock() }; return stored }
        func set(_ d: RFIStationMonitorDiagnostics) { lock.lock(); stored = d; lock.unlock() }
    }

    @Test func rfiMonitorURLBuildsPadovaDepartures() {
        let url = RFIStationMonitorClient.monitorURL(placeId: "2000", arrivals: false).absoluteString
        #expect(url.hasPrefix("https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor"))
        #expect(url.contains("arrivals=False"))
        #expect(url.contains("placeId=2000"))
    }

    @Test func rfiParserExtractsStationUpdatedAndRows() {
        let board = RFIStationMonitorParser.parse(Self.rfiPadovaFixtureHTML)
        #expect(board.stationName == "PADOVA")
        #expect(board.updatedAt == "17:12")
        #expect(board.rows.count >= 3)
    }

    @Test func rfiParserExtractsRowFields() {
        let board = RFIStationMonitorParser.parse(Self.rfiPadovaFixtureHTML)
        let venezia = board.rows.first { $0.trainNumber == "5928" }
        #expect(venezia?.destination == "VENEZIA SANTA LUCIA")
        #expect(venezia?.time == "17:18")
        #expect(venezia?.platform == "1")
        #expect(venezia?.category == "Categoria Regionale")   // parser keeps the raw (decoded) label
        // Missing platform stays missing (not fabricated).
        let italo = board.rows.first { $0.trainNumber == "9902" }
        #expect(italo?.platform == nil)
    }

    @Test func rfiDelayParsingNeverFakesDelay() {
        #expect(RFILiveMapper.delayMinutes(from: "0") == nil)
        #expect(RFILiveMapper.delayMinutes(from: "") == nil)
        #expect(RFILiveMapper.delayMinutes(from: nil) == nil)
        #expect(RFILiveMapper.delayMinutes(from: "Cancellato") == nil)
        #expect(RFILiveMapper.delayMinutes(from: "10") == 10)
    }

    @Test func rfiMapperBuildsValidRows() {
        let ref = Self.romeDate(2026, 6, 16, 17, 0)
        let response = RFILiveMapper.map(RFIStationMonitorParser.parse(Self.rfiPadovaFixtureHTML), referenceDate: ref)
        #expect(response.sourceKind == .rfiLive)
        #expect(response.isScheduled == false)
        #expect(response.scheduledWindow == nil)
        #expect(response.station.name == "Padova")
        #expect(response.rows.count == 4)

        let venezia = response.rows.first { $0.trainNumber == "5928" }
        #expect(venezia?.category == "REG")
        #expect(venezia?.destination == "VENEZIA SANTA LUCIA")
        #expect(venezia?.delayMinutes == nil)          // "0" → no fake delay
        #expect(venezia?.status == .onTime)
        #expect(venezia?.platformDisplay == "1")

        let italo = response.rows.first { $0.trainNumber == "9902" }
        #expect(italo?.platformDisplay == "--")        // missing platform handled safely
        #expect(italo?.status == .departing)

        let cancelled = response.rows.first { $0.trainNumber == "2774" }
        #expect(cancelled?.status == .cancelled)
        #expect(cancelled?.category == "RV")

        // Verbose "Categoria Alta Velocita&#39;" → compact "AV".
        let av = response.rows.first { $0.trainNumber == "9402" }
        #expect(av?.category == "AV")

        // No mapped category leaks the raw RFI label or HTML entities.
        for r in response.rows {
            #expect(!r.category.contains("Categoria"))
            #expect(!r.category.contains("&#"))
        }
    }

    @Test func rfiParserAndMapperHandleEmptyHTMLSafely() {
        let board = RFIStationMonitorParser.parse("")
        #expect(board.rows.isEmpty)
        #expect(board.stationName == nil)
        let response = RFILiveMapper.map(board, referenceDate: Self.romeDate(2026, 6, 16, 17, 0))
        #expect(response.rows.isEmpty)                  // no crash on empty input
    }

    @Test func rfiServiceMapsLiveBoardFromFetcher() async throws {
        let ref = Self.romeDate(2026, 6, 16, 17, 0)
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = RFILiveBoardService(
            fetcher: StubMonitorFetcher(html: Self.rfiPadovaFixtureHTML),
            fallback: mock,
            referenceDate: { ref },
            captureHTML: false
        )
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.sourceKind == .rfiLive)
        #expect(response.station.name == "Padova")
        #expect(response.rows.count >= 3)
    }

    @Test func rfiServiceFallsBackToMockOnFailure() async throws {
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = RFILiveBoardService(fetcher: StubMonitorFetcher(failing: true), fallback: mock, captureHTML: false)
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(!response.rows.isEmpty)                 // fell back to mock
        #expect(response.sourceKind != .rfiLive)
    }

    @Test func rfiDiagnosticsReportsLiveSuccess() async throws {
        let box = DiagBox()
        let ref = Self.romeDate(2026, 6, 16, 17, 0)
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = RFILiveBoardService(
            fetcher: StubMonitorFetcher(html: Self.rfiPadovaFixtureHTML),
            fallback: mock, referenceDate: { ref },
            captureHTML: false, recordDiagnostics: { box.set($0) }
        )
        let response = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(response.sourceKind == .rfiLive)
        #expect(box.value?.usedFallback == false)
        #expect(box.value?.renderedSource == "live")
        #expect(box.value?.parsedRowCount == 4)
        #expect((box.value?.receivedByteCount ?? 0) > 0)
        #expect(box.value?.statusCode == 200)
    }

    @Test func rfiDiagnosticsReportsEmptyParseFallback() async throws {
        let box = DiagBox()
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = RFILiveBoardService(
            fetcher: StubMonitorFetcher(html: "<html><body>no table here</body></html>"),
            fallback: mock, captureHTML: false, recordDiagnostics: { box.set($0) }
        )
        _ = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(box.value?.usedFallback == true)
        #expect(box.value?.renderedSource == "fallback-after-empty-parse")
        #expect(box.value?.parsedRowCount == 0)
        #expect((box.value?.receivedByteCount ?? 0) > 0)
    }

    @Test func rfiDiagnosticsReportsFetchErrorFallback() async throws {
        let box = DiagBox()
        let mock = MockTrainBoardService(); mock.artificialDelay = .zero
        let service = RFILiveBoardService(
            fetcher: StubMonitorFetcher(failing: true),
            fallback: mock, captureHTML: false, recordDiagnostics: { box.set($0) }
        )
        _ = try await service.fetchBoard(stationId: "padova", type: .departures)
        #expect(box.value?.usedFallback == true)
        #expect(box.value?.renderedSource == "fallback-after-fetch-error")
        #expect(box.value?.errorDescription != nil)
        #expect(box.value?.statusCode == nil)
    }

    @Test func rfiParserDecodesHTMLEntities() {
        let board = RFIStationMonitorParser.parse(Self.rfiPadovaFixtureHTML)
        let av = board.rows.first { $0.trainNumber == "9402" }
        #expect(av?.category?.contains("&#") == false)  // entity decoded by the parser
        #expect(av?.category?.contains("'") == true)    // &#39; → apostrophe
    }

    @Test func htmlEntityDecoderDecodesNumericAndNamed() {
        #expect(HTMLEntityDecoder.decode("Velocita&#39;") == "Velocita'")
        #expect(HTMLEntityDecoder.decode("Velocit&#224;") == "Velocità")
        #expect(HTMLEntityDecoder.decode("A&amp;B") == "A&B")
        #expect(HTMLEntityDecoder.decode("plain text") == "plain text")
    }

    @Test func rfiCategoryNormalizerMapsVerboseLabels() {
        #expect(RFITrainCategoryNormalizer.normalize("Categoria RV") == "RV")
        #expect(RFITrainCategoryNormalizer.normalize("CATEGORIA RV") == "RV")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Regionale") == "REG")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Regionale Veloce") == "RV")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Alta Velocita&#39;") == "AV")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Alta Velocità") == "AV")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Frecciarossa") == "FR")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Intercity") == "IC")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Intercity Notte") == "ICN")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Italo") == "ITA")
        #expect(RFITrainCategoryNormalizer.normalize("Categoria Qualcosa Di Molto Strano") == "UNK")
        #expect(RFITrainCategoryNormalizer.normalize(nil) == "UNK")
        #expect(RFITrainCategoryNormalizer.normalize("") == "UNK")
        #expect(RFITrainCategoryNormalizer.normalize("REG") == "REG")
    }

    /// Locator so `Bundle(for:)` resolves the test bundle for fixture files.
    private final class FixtureBundleLocator {}

    /// Runs against the REAL captured RFI HTML when present
    /// (Binario1Tests/Fixtures/rfi-padova-departures.real-sample.html). It is added
    /// manually from the device container; until then this test skips (no live
    /// network, never invents a fixture).
    @Test func rfiRealSampleParsesIfPresent() {
        guard let url = Bundle(for: FixtureBundleLocator.self)
                .url(forResource: "rfi-padova-departures.real-sample", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8), !html.isEmpty else {
            print("[Test] real RFI sample absent — add rfi-padova-departures.real-sample.html to activate")
            return
        }
        let board = RFIStationMonitorParser.parse(html)
        #expect(board.stationName?.uppercased().contains("PADOVA") == true)
        #expect(board.rows.count >= 20)

        let response = RFILiveMapper.map(board, referenceDate: Self.romeDate(2026, 6, 17, 10, 50))
        #expect(response.rows.count >= 20)
        for r in response.rows {
            #expect(!r.category.contains("Categoria"))   // verbose label stripped
            #expect(!r.category.contains("&#"))           // HTML entities decoded
            #expect(r.category.count <= 5)                // compact code (or UNK)
        }
    }
#endif
}

// MARK: - Stubbed URLProtocol for backend fetcher tests (no live network)

/// Stateless stub: the request HOST encodes the scenario, so parallel tests never
/// share mutable state. `stub-<n>` (n≠200) → HTTP n error JSON; `stub-empty` → 200
/// empty body; `stub-echotoken` → 200 `{"received":"<X-Binario-App-Token>"}`;
/// anything else (e.g. `stub-200`) → 200 + backend fixture JSON.
final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasPrefix("stub-") ?? false
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        guard let url = request.url else { client?.urlProtocolDidFinishLoading(self); return }
        let suffix = (url.host ?? "").hasPrefix("stub-") ? String((url.host ?? "").dropFirst("stub-".count)) : ""
        let (status, body): (Int, Data)
        switch suffix {
        case "empty":
            (status, body) = (200, Data())
        case "echotoken":
            let token = request.value(forHTTPHeaderField: "X-Binario-App-Token") ?? ""
            (status, body) = (200, Data("{\"received\":\"\(token)\"}".utf8))
        case let s where Int(s) != nil && Int(s) != 200:
            (status, body) = (Int(s)!, Data(#"{"error":{"code":"x"}}"#.utf8))
        default:
            (status, body) = (200, Data(Binario1Tests.backendFixtureJSON.utf8))
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !body.isEmpty { client?.urlProtocol(self, didLoad: body) }
        client?.urlProtocolDidFinishLoading(self)
    }
}

private func makeStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}
