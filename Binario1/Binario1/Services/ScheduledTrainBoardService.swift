//
//  ScheduledTrainBoardService.swift
//  Binario1
//
//  Scheduled-timetable source spike, using the RFI "Quadro Orario" (programmed
//  timetable) for Padova (RFI station id 1861) as a SCHEDULED departures source.
//
//  IMPORTANT: this is programmed/scheduled data, NOT live data. It carries the
//  programmed platform but NO real delays, cancellations or real-time platform
//  changes. Scheduled rows are mapped with status `.scheduled`, `delayMinutes`
//  nil and `actualPlatform` nil so the board never fakes live punctuality.
//
//  Parsing is decoupled behind `ScheduledTimetableProvider`. For this controlled
//  spike the provider decodes a bundled sample of the parsed Quadro Orario
//  (`scheduled-padova-0600.sample.json`). A real RFI HTTP+HTML adapter can
//  replace the provider later without touching the app. Any fetch/parse failure
//  falls back to the mock service (mandatory).
//

import Foundation

// MARK: - DTOs (mirror the parsed RFI Quadro Orario "Partenze" rows)

struct ScheduledTimetableDTO: Decodable {
    let stationId: String
    let stationName: String
    let source: String?
    let hourRange: String?
    let departures: [ScheduledDepartureDTO]
}

struct ScheduledDepartureDTO: Decodable {
    let time: String                // "06.05" / "06:05"
    let category: String?           // RFI label/code; may be missing
    let trainNumber: String
    let destination: String
    let plannedPlatform: String?    // programmed platform; may be missing
    let operatorName: String?
    let periodicity: String?
    let notes: String?
}

// MARK: - Provider (swap for a real RFI HTTP+HTML adapter later)

protocol ScheduledTimetableProvider: Sendable {
    func load(stationId: String) async throws -> ScheduledTimetableDTO
}

/// Loads the bundled parsed-Quadro-Orario sample.
struct BundledScheduledTimetableProvider: ScheduledTimetableProvider {
    var resourceName: String = "scheduled-padova-0600.sample"
    var bundle: Bundle = .main

    func load(stationId: String) async throws -> ScheduledTimetableDTO {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw TrainBoardServiceError.resourceMissing
        }
        do {
            return try JSONDecoder().decode(ScheduledTimetableDTO.self, from: data)
        } catch {
            throw TrainBoardServiceError.decodingFailed(underlying: error)
        }
    }
}

// MARK: - Mapping to app models

enum ScheduledTimetableMapper {

    private static let knownCategories: Set<String> = [
        "REG", "RV", "FR", "FA", "FB", "IC", "ICN", "EC", "EN", "ITA", "RGV", "AV", "ES", "BUS",
    ]

    /// Infer a compact category code from an RFI label/icon hint. Unknown → "UNKNOWN".
    static func category(from raw: String?) -> String {
        guard let value = raw?.trimmingCharacters(in: .whitespaces).uppercased(), !value.isEmpty else {
            return "UNKNOWN"
        }
        if knownCategories.contains(value) { return value }
        switch value {
        case "REGIONALE":          return "REG"
        case "REGIONALE VELOCE":   return "RV"
        case "FRECCIAROSSA":       return "FR"
        case "FRECCIARGENTO":      return "FA"
        case "FRECCIABIANCA":      return "FB"
        case "INTERCITY":          return "IC"
        case "INTERCITY NOTTE":    return "ICN"
        case "EUROCITY":           return "EC"
        case "EURONIGHT":          return "EN"
        case "ITALO":              return "ITA"
        default:                   return "UNKNOWN"
        }
    }

    /// Parse "HH.MM" / "HH:MM" into a Date on `reference`'s day, in `timezone`.
    static func time(_ raw: String, on reference: Date, timezone: TimeZone) -> Date? {
        let parts = raw.replacingOccurrences(of: ".", with: ":").split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var comps = cal.dateComponents([.year, .month, .day], from: reference)
        comps.hour = h; comps.minute = m; comps.second = 0
        return cal.date(from: comps)
    }

    static func map(_ dto: ScheduledTimetableDTO,
                    referenceDate: Date = Date(),
                    timezone: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .current) -> StationBoardResponse {
        let rows: [TrainBoardRow] = dto.departures.compactMap { dep in
            guard let scheduled = time(dep.time, on: referenceDate, timezone: timezone) else { return nil }
            let note = [dep.periodicity, dep.notes]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return TrainBoardRow(
                id: "\(dto.stationId)-\(dep.trainNumber)-\(dep.time)",
                trainNumber: dep.trainNumber,
                category: category(from: dep.category),
                operatorName: dep.operatorName,
                origin: nil,
                destination: dep.destination,
                scheduledTime: scheduled,
                expectedTime: nil,          // scheduled only — no live expected time
                delayMinutes: nil,          // never fake a delay
                plannedPlatform: dep.plannedPlatform,
                actualPlatform: nil,        // not live
                status: .scheduled,
                notes: note.isEmpty ? nil : note,
                lastUpdated: referenceDate
            )
        }

        let station = Station(
            id: "padova",
            name: dto.stationName,
            city: dto.stationName,
            displayName: dto.stationName,
            countryCode: "IT",
            timezone: timezone.identifier,
            providerCodes: ProviderCodes(rfi: dto.stationId, viaggiatreno: nil)
        )

        return StationBoardResponse(
            station: station,
            boardType: .departures,
            locale: "it-IT",
            supportedLocales: ["it-IT", "en-US"],
            rows: rows,
            generatedAt: referenceDate,
            sourceUpdatedAt: nil,
            isStale: false,
            warningMessageKey: nil,
            isScheduled: true
        )
    }
}

// MARK: - Service

/// App-facing scheduled departures source for Padova, with mandatory mock fallback.
final class ScheduledTrainBoardService: TrainBoardService, @unchecked Sendable {
    private let provider: ScheduledTimetableProvider
    private let fallback: TrainBoardService
    private let referenceDate: @Sendable () -> Date

    init(provider: ScheduledTimetableProvider = BundledScheduledTimetableProvider(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() }) {
        self.provider = provider
        self.fallback = fallback
        self.referenceDate = referenceDate
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        // The scheduled spike covers Padova DEPARTURES only; arrivals fall back to mock.
        guard type == .departures else {
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
        do {
            let dto = try await provider.load(stationId: stationId)
            let response = ScheduledTimetableMapper.map(dto, referenceDate: referenceDate())
            guard !response.rows.isEmpty else {
                return try await fallback.fetchBoard(stationId: stationId, type: type)
            }
            return response
        } catch {
            // Parsing / fetching failed → mock fallback (mandatory).
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
    }
}
