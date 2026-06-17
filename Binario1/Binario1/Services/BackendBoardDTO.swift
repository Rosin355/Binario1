//
//  BackendBoardDTO.swift
//  Binario1
//
//  Decodable DTOs for the normalized board JSON returned by the future Binario1
//  backend adapter (see docs/13_BACKEND_ADAPTER.md, `GET /api/board`). These are
//  the *wire* model only — they are mapped into the domain `StationBoardResponse`
//  by `BackendBoardMapper`; views never see DTOs. Categories/status/delay/platform
//  are already normalized server-side, so the app does no source parsing.
//

import Foundation

struct BackendBoardDTO: Decodable, Equatable {
    let station: BackendStationDTO
    let boardType: String
    let source: BackendSourceDTO
    let rows: [BackendRowDTO]
    /// Development/debug-only payload — omitted (or reduced) in production responses.
    let diagnostics: BackendDiagnosticsDTO?
}

struct BackendStationDTO: Decodable, Equatable {
    let id: String
    let name: String
    /// Source-specific id (e.g. RFI live placeId). Optional — the app keys on `id`.
    let sourcePlaceId: String?
}

struct BackendSourceDTO: Decodable, Equatable {
    let kind: String            // "rfiLive" | "scheduled" | "mock"
    let label: String           // human source label, e.g. "Monitor RFI online"
    let updatedAt: String?      // ISO-8601, source freshness
    let fetchedAt: String?      // ISO-8601, when the backend fetched the source
    let isFallback: Bool?
    let isStale: Bool?
}

struct BackendRowDTO: Decodable, Equatable {
    let id: String
    let scheduledTime: String   // "HH:mm"
    let category: String?       // already compact: REG/RV/AV/FR/IC/… (never "Categoria …")
    let trainNumber: String?
    let destination: String?
    let platform: String?       // absent/empty → app renders "--"
    let delayMinutes: Int?      // real positive delay or 0/absent → no delay badge
    let status: String?         // onTime/delayed/cancelled/departing/…
    let notes: [String]?
}

struct BackendDiagnosticsDTO: Decodable, Equatable {
    let sourceStatus: Int?
    let sourceBytes: Int?
    let parsedRows: Int?
}
