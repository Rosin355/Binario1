//
//  BoardSourceMode.swift
//  Binario1
//
//  Selects which TrainBoardService backs the Home board. Kept simple and
//  reversible — flip `AppEnvironment.sourceMode` to switch.
//

import Foundation

enum BoardSourceMode {
    /// Bundled mock data (Bologna Centrale), times rebased to "now".
    case mock
    /// RFI "Quadro Orario" programmed timetable for Padova (id 1861), scheduled
    /// data only, with mandatory mock fallback if parsing/fetching fails.
    case scheduledPadova
    /// Reserved: a future remote source that always falls back to mock.
    case remoteWithMockFallback
    /// DEBUG-only spike: RFI live station monitor for Padova (live monitor
    /// `placeId` 2000), departures. Online source, mandatory mock fallback.
    /// Distinct from `.scheduledPadova` (PRM Quadro Orario, id 1861).
    case rfiLivePadova
    /// DEBUG-only: Phase 1 of the backend-adapter migration. Loads the bundled
    /// *normalized backend JSON fixture* for Padova through `BackendBoardService`
    /// (no live network). Renders the same Home board, labelled "Backend fixture".
    case backendFixturePadova
}
