//
//  SavedJourneyMatcher.swift
//  Binario1
//
//  Pure, shared matching between a user's saved journey and a live/mock board.
//  Extracted from `StationBoardViewModel.personalizedFeaturedRows` so the Home
//  spotlight AND the Viaggi next-train resolver (`NextTrainResolver`) use the exact
//  SAME predicate and can never diverge. Not a route planner — it only delegates
//  free-text name comparison to `StationNameMatcher`.
//

import Foundation

enum SavedJourneyMatcher {

    /// True when `journey` departs from the station shown on the board: the board
    /// station name matches the journey's origin (via `StationNameMatcher`).
    static func journeyDeparts(from stationName: String, journey: SavedJourney) -> Bool {
        StationNameMatcher.matches(stationName, journey.origin)
    }

    /// The subset of `journeys` that depart from the given board station.
    static func journeysDeparting(from stationName: String, in journeys: [SavedJourney]) -> [SavedJourney] {
        journeys.filter { journeyDeparts(from: stationName, journey: $0) }
    }

    /// True when a DEPARTURES board row heads to the saved journey's destination.
    static func row(_ row: TrainBoardRow, matchesDestinationOf journey: SavedJourney) -> Bool {
        StationNameMatcher.matches(row.destination, journey.destination)
    }

    /// Board rows (departures) matching ANY of the given saved journeys' destinations.
    static func rows(_ rows: [TrainBoardRow], matchingDestinationsOf journeys: [SavedJourney]) -> [TrainBoardRow] {
        rows.filter { candidate in journeys.contains { row(candidate, matchesDestinationOf: $0) } }
    }
}
