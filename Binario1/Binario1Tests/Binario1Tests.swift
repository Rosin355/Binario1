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

    // MARK: - Scheduled timetable (Padova / RFI Quadro Orario spike)

    private static let sampleScheduledJSON = """
    {
      "stationId": "1861",
      "stationName": "Padova",
      "source": "RFI Quadro Orario",
      "hourRange": "06.00-06.59",
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
}
