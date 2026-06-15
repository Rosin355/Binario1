//
//  TrainBoardService.swift
//  Binario1
//
//  Service protocol + backend DTOs + mapping to the domain model.
//  The app talks only to this abstraction; the MVP is backed by mock data.
//

import Foundation

protocol TrainBoardService: Sendable {
    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse
}

enum TrainBoardServiceError: Error {
    case resourceMissing
    case decodingFailed(underlying: Error)
}

// MARK: - DTOs (mirror the backend JSON contract — never used by views directly)

struct StationDTO: Decodable {
    let id: String
    let name: String
    let city: String?
    let displayName: String
    let countryCode: String
    let timezone: String
    let providerCodes: ProviderCodesDTO?
}

struct ProviderCodesDTO: Decodable {
    let rfi: String?
    let viaggiatreno: String?
}

struct BoardResponseDTO: Decodable {
    let station: StationDTO
    let boardType: String
    let locale: String?
    let supportedLocales: [String]?
    let rows: [TrainRowDTO]
    let generatedAt: String?
    let sourceUpdatedAt: String?
    let isStale: Bool?
    let warningMessageKey: String?
}

struct TrainRowDTO: Decodable {
    let id: String
    let trainNumber: String
    let category: String
    let operatorName: String?
    let origin: String?
    let destination: String?
    let scheduledTime: String
    let expectedTime: String?
    let delayMinutes: Int?
    let plannedPlatform: String?
    let actualPlatform: String?
    let status: String?
    let notes: String?
    let lastUpdated: String?
}

// MARK: - Mapping

enum TrainBoardMapper {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        return isoFormatter.date(from: string)
    }

    static func station(_ dto: StationDTO) -> Station {
        Station(
            id: dto.id,
            name: dto.name,
            city: dto.city,
            displayName: dto.displayName,
            countryCode: dto.countryCode,
            timezone: dto.timezone,
            providerCodes: dto.providerCodes.map {
                ProviderCodes(rfi: $0.rfi, viaggiatreno: $0.viaggiatreno)
            }
        )
    }

    static func status(_ raw: String?, delayMinutes: Int?) -> TrainStatus {
        if let raw, let parsed = TrainStatus(rawValue: raw) { return parsed }
        return (delayMinutes ?? 0) > 0 ? .delayed : .unknown
    }

    static func row(_ dto: TrainRowDTO, fallbackUpdated: Date) -> TrainBoardRow? {
        guard let scheduled = date(dto.scheduledTime) else { return nil }
        return TrainBoardRow(
            id: dto.id,
            trainNumber: dto.trainNumber,
            category: dto.category,
            operatorName: dto.operatorName,
            origin: dto.origin,
            destination: dto.destination,
            scheduledTime: scheduled,
            expectedTime: date(dto.expectedTime),
            delayMinutes: dto.delayMinutes,
            plannedPlatform: dto.plannedPlatform,
            actualPlatform: dto.actualPlatform,
            status: status(dto.status, delayMinutes: dto.delayMinutes),
            notes: dto.notes,
            lastUpdated: date(dto.lastUpdated) ?? fallbackUpdated
        )
    }

    static func response(_ dto: BoardResponseDTO) -> StationBoardResponse {
        let generated = date(dto.generatedAt) ?? Date()
        let rows = dto.rows.compactMap { row($0, fallbackUpdated: generated) }
        return StationBoardResponse(
            station: station(dto.station),
            boardType: BoardType(rawValue: dto.boardType) ?? .departures,
            locale: dto.locale,
            supportedLocales: dto.supportedLocales ?? ["it-IT", "en-US"],
            rows: rows,
            generatedAt: generated,
            sourceUpdatedAt: date(dto.sourceUpdatedAt),
            isStale: dto.isStale ?? false,
            warningMessageKey: dto.warningMessageKey
        )
    }
}
