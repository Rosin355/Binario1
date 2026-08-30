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

    /// True when `journey` departs from the station shown on the board.
    ///
    /// When a `catalog` is given, BOTH sides are resolved to catalog entities and
    /// compared by id — the mirror of what the destination side already did. This is
    /// what keeps an origin persisted under an older or colloquial spelling working
    /// ("Montegrotto Terme" → Terme Euganee-Abano-Montegrotto) now that the matcher is
    /// canonical equality: the tolerance comes from the entity's `searchAliases`, an
    /// explicit and reviewable list, instead of the old permissive subset rule which
    /// also matched genuinely different stations.
    ///
    /// Without a catalog — or when either side is not a catalog station — it falls
    /// back to the plain canonical name comparison.
    static func journeyDeparts(from stationName: String, journey: SavedJourney,
                               catalog: StationCatalog? = nil) -> Bool {
        if let catalog,
           let board = catalog.station(named: stationName),
           let origin = catalog.station(named: journey.origin) {
            return board.id == origin.id
        }
        return StationNameMatcher.matches(stationName, journey.origin)
    }

    /// The subset of `journeys` that depart from the given board station.
    static func journeysDeparting(from stationName: String, in journeys: [SavedJourney],
                                  catalog: StationCatalog? = nil) -> [SavedJourney] {
        journeys.filter { journeyDeparts(from: stationName, journey: $0, catalog: catalog) }
    }

    /// True when a DEPARTURES board row heads to the saved journey's destination.
    ///
    /// When a `catalog` is provided and the saved destination resolves to a catalog
    /// station, matching also considers that station's `boardAliases` (so an
    /// abbreviated board row like "VENEZIA S.L." matches a saved "Venezia Santa
    /// Lucia"). Without a catalog it's the plain canonical name match — identical to
    /// before, so Home/Viaggi keep the SAME shared behavior when no catalog is passed.
    static func row(_ row: TrainBoardRow, matchesDestinationOf journey: SavedJourney,
                    catalog: StationCatalog? = nil) -> Bool {
        if let catalog, let station = catalog.station(named: journey.destination) {
            return StationNameMatcher.matches(station: station, boardName: row.destination)
        }
        return StationNameMatcher.matches(row.destination, journey.destination)
    }

    /// Board rows (departures) matching ANY of the given saved journeys' destinations.
    static func rows(_ rows: [TrainBoardRow], matchingDestinationsOf journeys: [SavedJourney],
                     catalog: StationCatalog? = nil) -> [TrainBoardRow] {
        rows.filter { candidate in journeys.contains { row(candidate, matchesDestinationOf: $0, catalog: catalog) } }
    }
}
