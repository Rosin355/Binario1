//
//  BackendBoardMapper.swift
//  Binario1
//
//  Maps the normalized backend DTO (`BackendBoardDTO`) into the existing domain
//  `StationBoardResponse`. The backend already normalizes categories/status/
//  delay/platform, so this mapper only adapts shapes and applies the same safe
//  rules the app guarantees: never invent delays or platforms, missing platform →
//  "--", 0/absent delay → no delay badge, unknown status → safe fallback.
//

import Foundation

enum BackendBoardMapper {

    static func map(_ dto: BackendBoardDTO,
                    referenceDate: Date = Date(),
                    timezone: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .current) -> StationBoardResponse {

        let boardType = BoardType(rawValue: dto.boardType) ?? .departures

        let rows: [TrainBoardRow] = dto.rows.compactMap { r in
            guard let scheduled = time(r.scheduledTime, on: referenceDate, timezone: timezone) else { return nil }
            let status = mapStatus(r.status, delayMinutes: r.delayMinutes)
            let cancelled = (status == .cancelled)
            let delay = cancelled ? nil : positiveDelay(r.delayMinutes)      // never a fake delay
            let platform = (r.platform?.isEmpty == false) ? r.platform : nil // missing → nil → "--"
            let category = (r.category?.isEmpty == false) ? r.category! : "" // backend is already compact
            // The contract's `destination` field carries the destination for departures
            // and the ORIGIN/provenance for arrivals — map it to the matching domain
            // field so the board shows the right place per board type. The empty-place
            // fallback label matches the board type too.
            let unavailableKey: String.LocalizationValue = boardType == .arrivals
                ? "board.originUnavailable" : "board.destinationUnavailable"
            let place = (r.destination?.isEmpty == false)
                ? r.destination!
                : String(localized: unavailableKey)
            let origin = boardType == .arrivals ? place : nil
            let destination = boardType == .arrivals ? nil : place
            let notes = (r.notes?.isEmpty == false) ? r.notes!.joined(separator: " · ") : nil
            return TrainBoardRow(
                id: r.id,
                trainNumber: r.trainNumber ?? "",
                category: category,
                operatorName: nil,
                origin: origin,
                destination: destination,
                scheduledTime: scheduled,
                expectedTime: delay.map { scheduled.addingTimeInterval(Double($0) * 60) },
                delayMinutes: delay,
                plannedPlatform: nil,
                actualPlatform: platform,
                status: status,
                notes: notes,
                lastUpdated: referenceDate
            )
        }

        let station = Station(
            id: dto.station.id,
            name: dto.station.name,
            city: dto.station.name,
            displayName: dto.station.name,
            countryCode: "IT",
            timezone: timezone.identifier,
            providerCodes: ProviderCodes(rfi: dto.station.sourcePlaceId, viaggiatreno: nil)
        )

        let updated = isoDate(dto.source.updatedAt)
        let fetched = isoDate(dto.source.fetchedAt)

        return StationBoardResponse(
            station: station,
            boardType: boardType,
            locale: "it-IT",
            supportedLocales: ["it-IT", "en-US"],
            rows: rows,
            generatedAt: updated ?? fetched ?? referenceDate,
            sourceUpdatedAt: updated ?? fetched,
            isStale: dto.source.isStale ?? false,
            warningMessageKey: nil,
            isScheduled: false,
            scheduledWindow: nil,
            sourceKind: mapSourceKind(dto.source.kind),
            sourceIsFallback: dto.source.isFallback ?? false
        )
    }

    /// Map the backend status string to `TrainStatus`. Unknown/absent → derive from
    /// delay (positive → delayed, else onTime) rather than guessing.
    static func mapStatus(_ raw: String?, delayMinutes: Int?) -> TrainStatus {
        if let raw, let parsed = TrainStatus(rawValue: raw) { return parsed }
        return (delayMinutes ?? 0) > 0 ? .delayed : .onTime
    }

    /// Backend source `kind` → UI source label kind.
    static func mapSourceKind(_ raw: String) -> BoardSourceKind {
        switch raw {
        case "rfiLive":                return .rfiLive
        case "scheduled", "scheduledSample": return .scheduledSample
        default:                       return .mock
        }
    }

    private static func positiveDelay(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }

    private static func time(_ raw: String, on reference: Date, timezone: TimeZone) -> Date? {
        let parts = raw.replacingOccurrences(of: ".", with: ":").split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var c = cal.dateComponents([.year, .month, .day], from: reference)
        c.hour = h; c.minute = m; c.second = 0
        return cal.date(from: c)
    }

    private static func isoDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }
}
