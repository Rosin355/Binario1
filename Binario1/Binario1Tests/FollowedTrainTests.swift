//
//  FollowedTrainTests.swift
//  Binario1Tests
//
//  LA1 — the followed-train Live Activity. What is fixed here:
//   • identity is station + departures + number + programmed time, and it survives
//     the midnight change of the board row id;
//   • only a FRESH LIVE read can change the lock screen; mock, fixture fallback,
//     backend stale cache and errors are "we don't know" and never rewrite it;
//   • "not on the board any more" is never promoted to "departed";
//   • one display model, so every surface shows the same platform/delay;
//   • ContentState is the future push payload: its JSON keys are a contract.
//

import Testing
import Foundation
@testable import Binario1

@MainActor
struct FollowedTrainTests {

    // MARK: - Fixtures (built in memory; no network)

    private nonisolated static func romeDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private nonisolated static let readAt = romeDate(2026, 9, 28, 17, 58)

    private static func row(number: String = "17088", category: String = "REG",
                            at time: Date = romeDate(2026, 9, 28, 18, 6),
                            idDate: String = "2026-09-28",
                            delay: Int? = nil, platform: String? = "6",
                            status: TrainStatus = .onTime) -> TrainBoardRow {
        TrainBoardRow(
            id: "\(category)-\(number)-\(idDate)T\(FollowedTrainClock.string(from: time))",
            trainNumber: number, category: category, operatorName: nil,
            origin: nil, destination: "VENEZIA S.LUCIA",
            scheduledTime: time,
            expectedTime: delay.map { time.addingTimeInterval(Double($0) * 60) },
            delayMinutes: delay, plannedPlatform: nil, actualPlatform: platform,
            status: status, notes: nil, lastUpdated: readAt)
    }

    private static func response(_ rows: [TrainBoardRow],
                                 kind: BoardSourceKind = .backendLive,
                                 station: Station = .padova,
                                 type: BoardType = .departures,
                                 isStale: Bool = false,
                                 isFallback: Bool = false) -> StationBoardResponse {
        StationBoardResponse(
            station: station, boardType: type, locale: "it-IT", supportedLocales: ["it-IT", "en-US"],
            rows: rows, generatedAt: readAt, sourceUpdatedAt: readAt, isStale: isStale,
            warningMessageKey: nil, sourceKind: kind, sourceIsFallback: isFallback)
    }

    private nonisolated static let attributes = FollowedTrainAttributes(
        stationSlug: "padova", stationName: "PADOVA", category: "REG", trainNumber: "17088",
        destination: "VENEZIA S.LUCIA", scheduledTime: "18:06",
        scheduledAtUnix: romeDate(2026, 9, 28, 18, 6).timeIntervalSince1970)

    // MARK: - Resolver: identity (third axis)

    @Test func freshLiveReadFindsTheTrainAndCarriesTheBackendReadTime() {
        let resolution = FollowedTrainResolver.resolve(Self.attributes, in: Self.response([Self.row(delay: 4)]))
        guard case .found(let row, let readAt) = resolution else {
            Issue.record("expected .found, got \(resolution)"); return
        }
        #expect(row.delayMinutes == 4)
        #expect(readAt == Self.readAt)
    }

    @Test func identitySurvivesTheMidnightChangeOfTheRowId() {
        // The backend stamps row ids with the FETCH date: re-read after midnight, the
        // same 23:55 train carries a different id. The Live Activity key must not care.
        let late = Self.romeDate(2026, 9, 28, 23, 55)
        let attrs = FollowedTrainAttributes(
            stationSlug: "padova", stationName: "PADOVA", category: "REG", trainNumber: "17088",
            destination: "VENEZIA S.LUCIA", scheduledTime: "23:55", scheduledAtUnix: late.timeIntervalSince1970)
        let before = Self.row(at: late, idDate: "2026-09-28")
        let after = Self.row(at: late, idDate: "2026-09-29")
        #expect(before.id != after.id)
        #expect(FollowedTrainResolver.matches(before, attrs))
        #expect(FollowedTrainResolver.matches(after, attrs))
    }

    @Test func identityIgnoresDelayAndIsNotTheCategoryLabel() {
        // The programmed time never moves with a delay, and the category is a printed
        // label (B4 lesson): neither may break the match.
        #expect(FollowedTrainResolver.matches(Self.row(delay: 25), Self.attributes))
        #expect(FollowedTrainResolver.matches(Self.row(category: "RV"), Self.attributes))
        #expect(!FollowedTrainResolver.matches(Self.row(number: "17090"), Self.attributes))
        #expect(!FollowedTrainResolver.matches(Self.row(at: Self.romeDate(2026, 9, 28, 18, 7)), Self.attributes))
    }

    @Test func aFreshReadWithoutTheTrainIsNoLongerOnBoardNeverDeparted() {
        let resolution = FollowedTrainResolver.resolve(Self.attributes, in: Self.response([Self.row(number: "2222")]))
        #expect(resolution == .noLongerOnBoard(readAt: Self.readAt))
    }

    @Test func twoRowsWithTheSameIdentityAreAmbiguousNotAGuess() {
        let resolution = FollowedTrainResolver.resolve(Self.attributes, in: Self.response([Self.row(), Self.row(platform: "2")]))
        #expect(resolution == .unknown(.ambiguous))
    }

    @Test func onlyAFreshLiveReadOfTheRightBoardCanSpeak() {
        let rows = [Self.row()]
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: nil) == .unknown(.noResponse))
        // Release runs on .mock; DEBUG's backend-live falls back to the fixture on error.
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, kind: .mock)) == .unknown(.notLive))
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, kind: .backendFixture)) == .unknown(.notLive))
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, isStale: true)) == .unknown(.staleOrFallback))
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, isFallback: true)) == .unknown(.staleOrFallback))
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, station: .bolognaCentrale)) == .unknown(.wrongStation))
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response(rows, type: .arrivals)) == .unknown(.wrongBoardType))
        // …and an EMPTY untrusted read is still "unknown", never "no longer on board".
        #expect(FollowedTrainResolver.resolve(Self.attributes, in: Self.response([], kind: .backendFixture)) == .unknown(.notLive))
    }

    @Test func stateNeverInventsPlatformOrDelay() {
        let state = FollowedTrainResolver.state(for: Self.row(delay: nil, platform: nil), readAt: Self.readAt)
        #expect(state.platform == nil)
        #expect(state.delayMinutes == nil)
        let cancelled = FollowedTrainResolver.state(for: Self.row(delay: 10, status: .cancelled), readAt: Self.readAt)
        #expect(cancelled.isCancelled)
        #expect(cancelled.delayMinutes == nil)   // a cancellation is not a delay
    }

    // MARK: - Eligibility (C3: the requirement is on the DATA, not the build)

    @Test func onlyFreshLiveDepartureRowsCanBeFollowed() {
        let now = Self.romeDate(2026, 9, 28, 18, 0)
        let row = Self.row()
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row]), now: now) != nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row], kind: .mock), now: now) == nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row], kind: .backendFixture), now: now) == nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row], type: .arrivals), now: now) == nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row], isFallback: true), now: now) == nil)
        let noNumber = Self.row(number: "")
        #expect(FollowedTrainEligibility.target(for: noNumber, in: Self.response([noNumber]), now: now) == nil)
        let cancelled = Self.row(status: .cancelled)
        #expect(FollowedTrainEligibility.target(for: cancelled, in: Self.response([cancelled]), now: now) == nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row, Self.row(platform: "3")]), now: now) == nil)
        #expect(FollowedTrainEligibility.target(for: row, in: Self.response([row]), now: Self.romeDate(2026, 9, 28, 19, 0)) == nil)
    }

    @Test func targetKeysOnTheProgrammedTimeAndStartsFromTheReadValues() throws {
        let row = Self.row(delay: 7, platform: "7 OV")
        let target = try #require(FollowedTrainEligibility.target(for: row, in: Self.response([row]), now: Self.romeDate(2026, 9, 28, 18, 0)))
        #expect(target.attributes.scheduledTime == "18:06")
        #expect(target.attributes.stationSlug == "padova")
        #expect(target.initialState.platform == "7 OV")
        #expect(target.initialState.delayMinutes == 7)
        #expect(target.initialState.tracking == .onBoard)
        #expect(target.initialState.readAt == Self.readAt)
    }

    @Test func mockBoardOffersNothingToFollow() async {
        // Plain Release is .mock: a Live Activity fed by mock data would be a lie.
        let vm = StationBoardViewModel(service: MockTrainBoardService())
        await vm.refresh(force: true)
        #expect(!vm.rows.isEmpty)
        #expect(vm.rows.allSatisfy { vm.followTarget(for: $0) == nil })
    }

    @Test func liveBoardOffersFollowOnDeparturesOnlyAndDropsItWithTheSelection() async {
        let row = Self.row(at: Date().addingTimeInterval(20 * 60))
        let vm = StationBoardViewModel(service: StubBoardService(result: .success(Self.response([row]))),
                                       station: .padova)
        await vm.refresh(force: true)
        #expect(vm.followTarget(for: row) != nil)
        vm.selectBoardType(.arrivals)
        #expect(vm.followTarget(for: row) == nil)
    }

    // MARK: - Display: one source for every surface

    @Test func displayIsHonestAboutMissingValues() {
        var state = FollowedTrainResolver.state(for: Self.row(delay: nil, platform: nil), readAt: Self.readAt)
        var display = FollowedTrainDisplay(attributes: Self.attributes, state: state, isStale: false)
        #expect(display.platformText == "--")
        #expect(!display.hasPlatform)
        #expect(display.delay == nil)
        #expect(display.delayText == nil)
        state.platform = "  "
        display = FollowedTrainDisplay(attributes: Self.attributes, state: state, isStale: false)
        #expect(display.platformText == "--")
    }

    @Test func displayFlagsValuesThatAreNotConfirmedByAFreshRead() {
        let fresh = FollowedTrainResolver.state(for: Self.row(delay: 5), readAt: Self.readAt)
        let current = FollowedTrainDisplay(attributes: Self.attributes, state: fresh, isStale: false)
        #expect(current.valuesAreCurrent)
        #expect(current.timestamp == .read(clock: "17:58"))
        #expect(current.noLongerOnBoardScheduled == nil)

        let aged = FollowedTrainDisplay(attributes: Self.attributes, state: fresh, isStale: true)
        #expect(!aged.valuesAreCurrent)
        #expect(aged.timestamp == .stale(clock: "17:58"))
        #expect(aged.platformText == "6")   // last value kept, drawn as last-seen

        var gone = fresh
        gone.tracking = .noLongerOnBoard
        let goneDisplay = FollowedTrainDisplay(attributes: Self.attributes, state: gone, isStale: false)
        #expect(!goneDisplay.valuesAreCurrent)
        #expect(goneDisplay.noLongerOnBoardScheduled == "18:06")
        #expect(goneDisplay.delay == .minutes(5))   // the last seen delay stays visible
    }

    @Test func everySurfaceReadsTheSamePlatform() {
        // Rule 1: if the badge says 6, nothing else may say 2.
        let state = FollowedTrainResolver.state(for: Self.row(platform: "6"), readAt: Self.readAt)
        let display = FollowedTrainDisplay(attributes: Self.attributes, state: state, isStale: false)
        #expect(display.platformText == "6")
        #expect(display.accessibilityText.contains("6"))
        #expect(!display.accessibilityText.contains(" 2"))
    }

    // MARK: - ContentState is the future push payload

    @Test func contentStateJSONKeysAreAStableContract() throws {
        let state = FollowedTrainAttributes.ContentState(
            tracking: .onBoard, delayMinutes: 3, isCancelled: false, platform: "6",
            readAtUnix: 1_790_000_000)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        #expect(Set(object.keys) == ["tracking", "delayMinutes", "isCancelled", "platform", "readAtUnix"])
        #expect(object["readAtUnix"] as? Double == 1_790_000_000)   // seconds since 1970, not 2001
    }

    @Test func aBackendStylePayloadDecodes() throws {
        // What an LA2 sender would put in "content-state": plain keys, epoch seconds,
        // absent optionals meaning "no delay" / "no platform".
        let json = #"{"tracking":"noLongerOnBoard","isCancelled":false,"readAtUnix":1790000000}"#
        let state = try JSONDecoder().decode(FollowedTrainAttributes.ContentState.self, from: Data(json.utf8))
        #expect(state.tracking == .noLongerOnBoard)
        #expect(state.platform == nil)
        #expect(state.delayMinutes == nil)
        #expect(state.readAt == Date(timeIntervalSince1970: 1_790_000_000))
    }

    // MARK: - Tracker

    @Test func followStartsOneActivityReplacingThePrevious() async throws {
        let activities = FakeActivities()
        let tracker = FollowedTrainTracker(service: StubBoardService(result: .failure(URLError(.notConnectedToInternet))),
                                           activities: activities)
        let target = FollowedTrainTarget(attributes: Self.attributes,
                                         initialState: FollowedTrainResolver.state(for: Self.row(), readAt: Self.readAt))
        await tracker.follow(target)
        #expect(activities.endAllCalls == 1)
        #expect(activities.started?.attributes == Self.attributes)
        #expect(tracker.isFollowing(target))
        await tracker.stopFollowing()
        #expect(tracker.followed == nil)
        #expect(activities.started == nil)
    }

    @Test func disabledLiveActivitiesSurfaceAnErrorAndStartNothing() async {
        let activities = FakeActivities()
        activities.areActivitiesEnabled = false
        let tracker = FollowedTrainTracker(service: StubBoardService(result: .success(Self.response([]))),
                                           activities: activities)
        await tracker.follow(FollowedTrainTarget(attributes: Self.attributes,
                                                 initialState: FollowedTrainResolver.state(for: Self.row(), readAt: Self.readAt)))
        #expect(tracker.startErrorKey == "follow.error.disabled")
        #expect(activities.started == nil)
    }

    @Test func refreshAppliesAFreshReadAndIgnoresAnUntrustedOne() async {
        let now = Self.romeDate(2026, 9, 28, 18, 0)
        let service = StubBoardService(result: .success(Self.response([Self.row(delay: 8, platform: "4")])))
        let activities = FakeActivities()
        let tracker = FollowedTrainTracker(service: service, activities: activities, now: { now })
        await tracker.follow(FollowedTrainTarget(attributes: Self.attributes,
                                                 initialState: FollowedTrainResolver.state(for: Self.row(), readAt: Self.readAt)))

        await tracker.refreshOnce()
        #expect(activities.updates.last?.platform == "4")
        #expect(activities.updates.last?.delayMinutes == 8)

        // Error, fixture fallback, backend stale cache: no rewrite at all.
        for result: Result<StationBoardResponse, Error> in [
            .failure(URLError(.timedOut)),
            .success(Self.response([Self.row(platform: "9")], kind: .backendFixture)),
            .success(Self.response([], isStale: true)),
        ] {
            service.result = result
            let count = activities.updates.count
            await tracker.refreshOnce()
            #expect(activities.updates.count == count)
        }
    }

    @Test func refreshMarksNoLongerOnBoardKeepingTheLastSeenValues() async {
        let now = Self.romeDate(2026, 9, 28, 18, 0)
        let service = StubBoardService(result: .success(Self.response([Self.row(number: "9999")])))
        let activities = FakeActivities()
        let tracker = FollowedTrainTracker(service: service, activities: activities, now: { now })
        await tracker.follow(FollowedTrainTarget(attributes: Self.attributes,
                                                 initialState: FollowedTrainResolver.state(for: Self.row(delay: 5), readAt: Self.readAt)))
        await tracker.refreshOnce()
        let last = activities.updates.last
        #expect(last?.tracking == .noLongerOnBoard)
        #expect(last?.platform == "6")
        #expect(last?.delayMinutes == 5)
        #expect(tracker.followed != nil)   // not ended: it may be listed again
    }

    @Test func activityEndsOnlyWellAfterTheLastKnownExpectedDeparture() {
        let tracker = FollowedTrainTracker(service: StubBoardService(result: .success(Self.response([]))),
                                           activities: FakeActivities(),
                                           now: { Self.romeDate(2026, 9, 28, 18, 30) })
        var state = FollowedTrainResolver.state(for: Self.row(), readAt: Self.readAt)
        #expect(tracker.shouldEnd(Self.attributes, state))          // 18:06 + 15' < 18:30
        state.delayMinutes = 20
        #expect(!tracker.shouldEnd(Self.attributes, state))         // 18:26 + 15' > 18:30
    }

    @Test func aDismissedActivityStopsTheTracking() async {
        let service = StubBoardService(result: .success(Self.response([Self.row()])))
        let activities = FakeActivities()
        let tracker = FollowedTrainTracker(service: service, activities: activities,
                                           now: { Self.romeDate(2026, 9, 28, 18, 0) })
        await tracker.follow(FollowedTrainTarget(attributes: Self.attributes,
                                                 initialState: FollowedTrainResolver.state(for: Self.row(), readAt: Self.readAt)))
        activities.started = nil   // swiped away on the Lock Screen
        await tracker.refreshOnce()
        #expect(tracker.followed == nil)
        #expect(service.calls == 0)
    }

    // MARK: - Localization

    @Test func liveActivityStringsExistInItalianAndEnglish() throws {
        func keys(_ language: String) throws -> Set<String> {
            let path = try #require(Bundle.main.path(forResource: "LiveActivity", ofType: "strings",
                                                     inDirectory: nil, forLocalization: language))
            let dict = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
            return Set(dict.keys)
        }
        let it = try keys("it")
        #expect(!it.isEmpty)
        #expect(it == (try keys("en")))
    }
}

// MARK: - Test doubles

private final class StubBoardService: TrainBoardService, @unchecked Sendable {
    var result: Result<StationBoardResponse, Error>
    private(set) var calls = 0
    init(result: Result<StationBoardResponse, Error>) { self.result = result }
    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        calls += 1
        return try result.get()
    }
}

private final class FakeActivities: FollowedTrainActivityControlling {
    var areActivitiesEnabled = true
    var started: (attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState)?
    private(set) var updates: [FollowedTrainAttributes.ContentState] = []
    private(set) var endAllCalls = 0

    func current() -> (attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState)? { started }
    func start(_ attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState) throws {
        started = (attributes, state)
    }
    func update(_ state: FollowedTrainAttributes.ContentState) async {
        updates.append(state)
        if let s = started { started = (s.attributes, state) }
    }
    func endAll() async {
        endAllCalls += 1
        started = nil
    }
}
