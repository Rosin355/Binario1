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
}
