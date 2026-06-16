//
//  RFILiveBoardService.swift
//  Binario1
//
//  DEBUG-ONLY real-data spike. App-facing `TrainBoardService` that reads the RFI
//  live station monitor for PADOVA (live monitor placeId 2000), parses it and maps
//  it into the existing `StationBoardResponse`. Departures only; arrivals and any
//  fetch/parse failure fall back to the mock service (mandatory). Never fabricates
//  delays or platforms.
//

#if DEBUG
import Foundation

// MARK: - Mapping (RFI monitor DTO → domain model)

enum RFILiveMapper {

    /// Normalize an RFI category label/code to a compact board code; unknown values
    /// are kept as-is (already a code) rather than invented.
    static func category(from raw: String?) -> String {
        guard let value = raw?.trimmingCharacters(in: .whitespaces).uppercased(), !value.isEmpty else { return "" }
        let map: [String: String] = [
            "REGIONALE": "REG", "REGIONALE VELOCE": "RV",
            "FRECCIAROSSA": "FR", "FRECCIARGENTO": "FA", "FRECCIABIANCA": "FB",
            "INTERCITY": "IC", "INTERCITY NOTTE": "ICN", "EUROCITY": "EC", "EURONIGHT": "EN",
            "ITALO": "ITA",
        ]
        return map[value] ?? value
    }

    /// A real, positive delay in minutes — or nil. "0", "", non-numeric → no delay
    /// (never a fake delay).
    static func delayMinutes(from raw: String?) -> Int? {
        guard let value = raw?.trimmingCharacters(in: .whitespaces),
              value.rangeOfCharacter(from: .decimalDigits) != nil,
              let minutes = Int(value.filter(\.isNumber)), minutes > 0 else { return nil }
        return minutes
    }

    static func isCancelled(_ row: RFIMonitorRow) -> Bool {
        let blob = [row.delay, row.info].compactMap { $0 }.joined(separator: " ").lowercased()
        return blob.contains("cancell") || blob.contains("soppress")
    }

    /// Parse "HH:MM" / "HH.MM" onto `reference`'s day in `timezone`.
    static func time(_ raw: String?, on reference: Date, timezone: TimeZone) -> Date? {
        guard let raw else { return nil }
        let parts = raw.replacingOccurrences(of: ".", with: ":").split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var c = cal.dateComponents([.year, .month, .day], from: reference)
        c.hour = h; c.minute = m; c.second = 0
        return cal.date(from: c)
    }

    static func map(_ board: RFIMonitorBoard,
                    referenceDate: Date = Date(),
                    timezone: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .current) -> StationBoardResponse {
        let rows: [TrainBoardRow] = board.rows.enumerated().compactMap { idx, r in
            guard let scheduled = time(r.time, on: referenceDate, timezone: timezone) else { return nil }
            let cancelled = isCancelled(r)
            let delay = cancelled ? nil : delayMinutes(from: r.delay)
            let platform = (r.platform?.isEmpty == false) ? r.platform : nil   // missing → nil → "--"
            let destination = (r.destination?.isEmpty == false)
                ? r.destination!
                : String(localized: "board.destinationUnavailable")
            let status: TrainStatus = cancelled ? .cancelled
                : (delay != nil ? .delayed : ((r.isDeparting ?? false) ? .departing : .onTime))
            return TrainBoardRow(
                id: "rfi-\(r.trainNumber ?? "?")-\(r.time ?? "")-\(idx)",
                trainNumber: r.trainNumber ?? "",
                category: category(from: r.category),
                operatorName: r.operatorName,
                origin: nil,
                destination: destination,
                scheduledTime: scheduled,
                expectedTime: delay.map { scheduled.addingTimeInterval(Double($0) * 60) },
                delayMinutes: delay,
                plannedPlatform: nil,
                actualPlatform: platform,           // live binario; never invented
                status: status,
                notes: r.info,
                lastUpdated: referenceDate
            )
        }

        let updated = time(board.updatedAt, on: referenceDate, timezone: timezone)
        return StationBoardResponse(
            station: .padova,                       // spike is Padova-locked
            boardType: .departures,
            locale: "it-IT",
            supportedLocales: ["it-IT", "en-US"],
            rows: rows,
            generatedAt: updated ?? referenceDate,
            sourceUpdatedAt: updated,
            isStale: false,
            warningMessageKey: nil,
            isScheduled: false,
            scheduledWindow: nil,
            sourceKind: .rfiLive
        )
    }
}

// MARK: - Service

final class RFILiveBoardService: TrainBoardService, @unchecked Sendable {
    private let fetcher: RFIMonitorFetching
    private let fallback: TrainBoardService
    private let referenceDate: @Sendable () -> Date

    /// RFI live monitor placeId for Padova (distinct from the PRM scheduled id 1861).
    private let padovaPlaceId = "2000"

    init(fetcher: RFIMonitorFetching = RFIStationMonitorClient(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() }) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.referenceDate = referenceDate
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        // Spike covers Padova DEPARTURES; arrivals fall back to mock.
        guard type == .departures else {
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
        do {
            let html = try await fetcher.fetchMonitorHTML(placeId: padovaPlaceId, arrivals: false)
            let board = RFIStationMonitorParser.parse(html)
            let response = RFILiveMapper.map(board, referenceDate: referenceDate())
            guard !response.rows.isEmpty else {
                print("[RFILive] parsed 0 rows → mock fallback")
                return try await fallback.fetchBoard(stationId: stationId, type: type)
            }
            return response
        } catch {
            print("[RFILive] fetch/parse failed: \(error) → mock fallback")
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
    }
}
#endif
