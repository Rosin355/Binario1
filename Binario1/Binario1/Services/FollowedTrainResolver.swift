//
//  FollowedTrainResolver.swift
//  Binario1
//
//  Decides, from a board read, what the Live Activity may say about the followed
//  train. Pure: no ActivityKit, no network — the tracker feeds it responses.
//
//  Identity is the THIRD axis after station and board type (C3): station slug +
//  departures + train number + programmed "HH:mm". Never the board row id, which
//  embeds the fetch date and changes across midnight.
//
//  Only a FRESH LIVE read can change what the lock screen says. Anything else —
//  no response, mock, fixture fallback, backend stale cache — is "we don't know",
//  and "we don't know" never becomes "no longer on the board".
//

import Foundation

enum FollowedTrainResolution: Equatable {
    /// A fresh live read lists exactly one row with this identity.
    case found(TrainBoardRow, readAt: Date)
    /// A fresh live read of the right board does not list the train.
    case noLongerOnBoard(readAt: Date)
    /// Nothing trustworthy to say: the activity keeps its last content and its
    /// staleDate tells the user it is aging.
    case unknown(UnknownReason)

    enum UnknownReason: Equatable {
        case noResponse
        case notLive
        case staleOrFallback
        case wrongStation
        case wrongBoardType
        /// More than one row carries the identity. We never pick one.
        case ambiguous
    }
}

enum FollowedTrainResolver {

    static func resolve(_ attributes: FollowedTrainAttributes,
                        in response: StationBoardResponse?) -> FollowedTrainResolution {
        guard let response else { return .unknown(.noResponse) }
        if let reason = untrustworthyReason(response, stationSlug: attributes.stationSlug) {
            return .unknown(reason)
        }
        let hits = response.rows.filter { matches($0, attributes) }
        let readAt = readAt(of: response)
        switch hits.count {
        case 1:  return .found(hits[0], readAt: readAt)
        case 0:  return .noLongerOnBoard(readAt: readAt)
        default: return .unknown(.ambiguous)
        }
    }

    /// Nil when the response is a fresh live read of `stationSlug`'s DEPARTURES.
    /// A Live Activity fed by mock or fixture data would be a lie on the lock
    /// screen: this is the data-level requirement that replaces a build flag.
    static func untrustworthyReason(_ response: StationBoardResponse,
                                    stationSlug: String) -> FollowedTrainResolution.UnknownReason? {
        guard response.sourceKind == .backendLive else { return .notLive }
        guard !response.isStale, !response.sourceIsFallback else { return .staleOrFallback }
        guard sameStation(response.station.id, stationSlug) else { return .wrongStation }
        guard response.boardType == .departures else { return .wrongBoardType }
        return nil
    }

    static func matches(_ row: TrainBoardRow, _ attributes: FollowedTrainAttributes) -> Bool {
        normalizedNumber(row.trainNumber) == normalizedNumber(attributes.trainNumber)
            && row.timeString() == attributes.scheduledTime
    }

    /// The backend's own read time (its fetch of RFI), not the device clock.
    static func readAt(of response: StationBoardResponse) -> Date {
        response.sourceUpdatedAt ?? response.generatedAt
    }

    /// Content for a row that a fresh read just listed.
    static func state(for row: TrainBoardRow, readAt: Date) -> FollowedTrainAttributes.ContentState {
        FollowedTrainAttributes.ContentState(
            tracking: .onBoard,
            delayMinutes: row.status.isCancelled ? nil : row.delayMinutes.flatMap { $0 > 0 ? $0 : nil },
            isCancelled: row.status.isCancelled,
            platform: row.hasPlatform ? row.platformDisplay : nil,
            readAtUnix: readAt.timeIntervalSince1970
        )
    }

    private static func normalizedNumber(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespaces)
    }

    private static func sameStation(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased()
            == b.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

/// What starting to follow a row needs: the fixed identity and the first content.
struct FollowedTrainTarget: Equatable {
    let attributes: FollowedTrainAttributes
    let initialState: FollowedTrainAttributes.ContentState
}

enum FollowedTrainEligibility {

    /// A target when `row` can honestly be followed from `response`, else nil.
    /// Same trust rules as an update, plus: departures only, a train number to key
    /// on, a train that is still to leave, and an identity unique on this board.
    static func target(for row: TrainBoardRow,
                       in response: StationBoardResponse,
                       now: Date) -> FollowedTrainTarget? {
        guard FollowedTrainResolver.untrustworthyReason(response, stationSlug: response.station.id) == nil else { return nil }
        let number = row.trainNumber.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty, number != "?" else { return nil }
        guard row.isUpcoming(now: now) else { return nil }

        let attributes = FollowedTrainAttributes(
            stationSlug: response.station.id,
            stationName: response.station.displayName,
            category: row.category,
            trainNumber: number,
            destination: BoardDestinationFormatter.display(row.displayPlace(for: .departures)),
            scheduledTime: row.timeString(),
            scheduledAtUnix: row.scheduledTime.timeIntervalSince1970
        )
        guard response.rows.filter({ FollowedTrainResolver.matches($0, attributes) }).count == 1 else { return nil }

        return FollowedTrainTarget(
            attributes: attributes,
            initialState: FollowedTrainResolver.state(for: row, readAt: FollowedTrainResolver.readAt(of: response))
        )
    }
}
