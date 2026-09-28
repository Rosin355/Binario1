//
//  FollowedTrainTracker.swift
//  Binario1
//
//  Keeps the ONE followed train's Live Activity in step with the board — locally.
//  LA1 has no push: the app re-reads the board every minute while it is in the
//  foreground, and nothing updates once it is not. That is not hidden: every update
//  carries a staleDate, and past it the extension says "non aggiornato" on its own.
//
//  Outcomes of a read (see FollowedTrainResolver):
//   • found            → fresh values, tracking = onBoard
//   • noLongerOnBoard  → last-seen values kept, tracking = noLongerOnBoard
//   • unknown          → NO update: the content ages visibly, it is never rewritten
//                        from data we do not trust
//

import ActivityKit
import Foundation
import Observation

/// The ActivityKit surface the tracker needs, behind a protocol so the tracker's
/// decisions are testable without a device.
protocol FollowedTrainActivityControlling {
    var areActivitiesEnabled: Bool { get }
    /// The live activity, if one is running (at most one: following replaces).
    func current() -> (attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState)?
    func start(_ attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState) throws
    func update(_ state: FollowedTrainAttributes.ContentState) async
    func endAll() async
}

@Observable
@MainActor
final class FollowedTrainTracker {

    /// The followed train, nil when nothing is followed.
    private(set) var followed: FollowedTrainAttributes?
    /// Localization key of the last failure to start, for the UI.
    private(set) var startErrorKey: String?

    private var lastState: FollowedTrainAttributes.ContentState?
    private let service: TrainBoardService
    private let activities: FollowedTrainActivityControlling
    private let now: () -> Date

    init(service: TrainBoardService,
         activities: FollowedTrainActivityControlling,
         now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.activities = activities
        self.now = now
    }

    func isFollowing(_ target: FollowedTrainTarget) -> Bool {
        guard let followed else { return false }
        return followed.stationSlug == target.attributes.stationSlug
            && followed.trainNumber == target.attributes.trainNumber
            && followed.scheduledTime == target.attributes.scheduledTime
    }

    /// Re-attach to an activity that survived an app relaunch — or notice that the
    /// user dismissed it from the lock screen.
    func restore() {
        if let current = activities.current() {
            followed = current.attributes
            lastState = current.state
        } else {
            followed = nil
            lastState = nil
        }
    }

    /// Follow `target`, replacing any train followed before (one at a time).
    func follow(_ target: FollowedTrainTarget) async {
        startErrorKey = nil
        guard activities.areActivitiesEnabled else {
            startErrorKey = "follow.error.disabled"
            return
        }
        await activities.endAll()
        followed = nil
        lastState = nil
        do {
            try activities.start(target.attributes, state: target.initialState)
            followed = target.attributes
            lastState = target.initialState
        } catch {
            startErrorKey = "follow.error.startFailed"
        }
    }

    func stopFollowing() async {
        await activities.endAll()
        followed = nil
        lastState = nil
    }

    /// One read of the followed train's board, then the matching update (or none).
    func refreshOnce() async {
        restore()
        guard let attributes = followed, let last = lastState else { return }

        if shouldEnd(attributes, last) {
            await stopFollowing()
            return
        }

        let response = try? await service.fetchBoard(stationId: attributes.stationSlug, type: .departures)
        // The user may have stopped or replaced the train while the read was in flight.
        guard followed == attributes else { return }

        switch FollowedTrainResolver.resolve(attributes, in: response) {
        case .found(let row, let readAt):
            await apply(FollowedTrainResolver.state(for: row, readAt: readAt))
        case .noLongerOnBoard(let readAt):
            var next = last
            next.tracking = .noLongerOnBoard
            next.readAtUnix = readAt.timeIntervalSince1970
            await apply(next)
        case .unknown:
            break   // no rewrite: the staleDate already set tells the truth
        }
    }

    /// Foreground loop. Cancelled by the caller when the scene leaves `.active`.
    func runWhileActive() async {
        while !Task.isCancelled {
            await refreshOnce()
            try? await Task.sleep(for: .seconds(FollowedTrainPolicy.refreshInterval))
        }
    }

    /// Ended once the last known expected departure (programmed + last seen delay)
    /// is well past. Never on "no longer on the board" alone: a train RFI drops for
    /// a moment and lists again must still be followed.
    func shouldEnd(_ attributes: FollowedTrainAttributes, _ state: FollowedTrainAttributes.ContentState) -> Bool {
        let delay = TimeInterval((state.delayMinutes ?? 0) * 60)
        let expected = Date(timeIntervalSince1970: attributes.scheduledAtUnix + delay)
        return now() > expected.addingTimeInterval(FollowedTrainPolicy.endAfterDeparture)
    }

    private func apply(_ state: FollowedTrainAttributes.ContentState) async {
        lastState = state
        await activities.update(state)
    }
}

/// Real ActivityKit implementation.
struct LiveFollowedTrainActivities: FollowedTrainActivityControlling {

    var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func current() -> (attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState)? {
        guard let activity = Activity<FollowedTrainAttributes>.activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) else { return nil }
        return (activity.attributes, activity.content.state)
    }

    func start(_ attributes: FollowedTrainAttributes, state: FollowedTrainAttributes.ContentState) throws {
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: FollowedTrainPolicy.staleDate(for: state)),
            pushType: nil   // LA1: local updates only; push is LA2
        )
    }

    func update(_ state: FollowedTrainAttributes.ContentState) async {
        for activity in Activity<FollowedTrainAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: FollowedTrainPolicy.staleDate(for: state)))
        }
    }

    func endAll() async {
        for activity in Activity<FollowedTrainAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
