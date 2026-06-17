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

    /// Verbose per-row category logs are noisy; off by default (flip to debug a
    /// specific normalization). The aggregate summary is logged once per fetch.
    static let logsCategoryNormalizationDetails = false

    /// Compact board code from a verbose RFI category label, via the dedicated
    /// normalizer (decodes entities, strips "Categoria", maps to codes, else "UNK").
    static func category(from raw: String?) -> String {
        let code = RFITrainCategoryNormalizer.normalize(raw)
        if logsCategoryNormalizationDetails, let raw, raw != code {
            print("[RFILive] category raw=\"\(raw)\" normalized=\"\(code)\"")
        }
        return code
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
    private let captureHTML: Bool
    private let recordDiagnostics: @Sendable (RFIStationMonitorDiagnostics) -> Void

    /// RFI live monitor placeId for Padova (distinct from the PRM scheduled id 1861).
    private let padovaPlaceId = "2000"

    init(fetcher: RFIMonitorFetching = RFIStationMonitorClient(),
         fallback: TrainBoardService = MockTrainBoardService(),
         referenceDate: @escaping @Sendable () -> Date = { Date() },
         captureHTML: Bool = true,
         recordDiagnostics: (@Sendable (RFIStationMonitorDiagnostics) -> Void)? = nil) {
        self.fetcher = fetcher
        self.fallback = fallback
        self.referenceDate = referenceDate
        self.captureHTML = captureHTML
        self.recordDiagnostics = recordDiagnostics ?? { diagnostics in
            Task { @MainActor in RFILiveDiagnosticsStore.shared.record(diagnostics) }
        }
    }

    func fetchBoard(stationId: String, type: BoardType) async throws -> StationBoardResponse {
        // Spike covers Padova DEPARTURES; arrivals fall back to mock.
        guard type == .departures else {
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
        let url = RFIStationMonitorClient.monitorURL(placeId: padovaPlaceId, arrivals: false)
        do {
            let result = try await fetcher.fetchMonitor(placeId: padovaPlaceId, arrivals: false)
            let capturedPath = captureHTML ? RFIRawHTMLCapture.save(result.html) : nil
            let board = RFIStationMonitorParser.parse(result.html)
            let response = RFILiveMapper.map(board, referenceDate: referenceDate())

            let status = result.statusCode.map(String.init) ?? "?"
            if response.rows.isEmpty {
                record(url: result.url, status: result.statusCode, contentType: result.contentType,
                       bytes: result.byteCount, rows: 0, usedFallback: true,
                       source: "fallback-after-empty-parse", error: nil, path: capturedPath)
                print("[RFILive] FALLBACK · status=\(status) · rows=0 · bytes=\(result.byteCount) · fallback=true")
                return try await fallback.fetchBoard(stationId: stationId, type: type)
            }

            record(url: result.url, status: result.statusCode, contentType: result.contentType,
                   bytes: result.byteCount, rows: response.rows.count, usedFallback: false,
                   source: "live", error: nil, path: capturedPath)
            print("[RFILive] LIVE OK · status=\(status) · rows=\(response.rows.count) · bytes=\(result.byteCount) · contentType=\(result.contentType ?? "?") · fallback=false")
            print("[RFILive] categories: \(Self.categorySummary(response.rows))")
            return response
        } catch {
            record(url: url, status: nil, contentType: nil, bytes: 0, rows: 0, usedFallback: true,
                   source: "fallback-after-fetch-error", error: "\(error)", path: nil)
            print("[RFILive] FETCH ERROR · fallback=true · error=\(error)")
            return try await fallback.fetchBoard(stationId: stationId, type: type)
        }
    }

    /// Aggregate "AV=12, RV=8, …" summary for the concise DEBUG log.
    private static func categorySummary(_ rows: [TrainBoardRow]) -> String {
        Dictionary(grouping: rows, by: { $0.category })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }

    private func record(url: URL, status: Int?, contentType: String?, bytes: Int, rows: Int,
                        usedFallback: Bool, source: String, error: String?, path: String?) {
        recordDiagnostics(RFIStationMonitorDiagnostics(
            url: url, statusCode: status, contentType: contentType, receivedByteCount: bytes,
            parsedRowCount: rows, usedFallback: usedFallback, renderedSource: source,
            errorDescription: error, capturedHTMLPath: path, capturedAt: Date()
        ))
    }
}
#endif
