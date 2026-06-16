//
//  RFIStationMonitorClient.swift
//  Binario1
//
//  DEBUG-ONLY real-data spike. Builds the RFI live station-monitor URL and fetches
//  the raw HTML. No SwiftUI, no parsing here — just networking. Injected behind
//  `RFIMonitorFetching` so the service/tests can stub it without live network.
//
//  Endpoint pattern:
//  https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000
//

#if DEBUG
import Foundation

/// HTML plus the response metadata the diagnostics layer needs.
struct RFIMonitorFetchResult: Sendable {
    let html: String
    let url: URL
    let statusCode: Int?
    let contentType: String?
    let byteCount: Int
}

/// Abstraction over "fetch the RFI monitor" so it can be stubbed in tests.
protocol RFIMonitorFetching: Sendable {
    func fetchMonitor(placeId: String, arrivals: Bool) async throws -> RFIMonitorFetchResult
}

final class RFIStationMonitorClient: RFIMonitorFetching, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Builds the live monitor URL. `arrivals` maps to the .NET-style `True`/`False`.
    static func monitorURL(placeId: String, arrivals: Bool) -> URL {
        var components = URLComponents(string: "https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor")!
        components.queryItems = [
            URLQueryItem(name: "arrivals", value: arrivals ? "True" : "False"),
            URLQueryItem(name: "placeId", value: placeId),
        ]
        return components.url!
    }

    func fetchMonitor(placeId: String, arrivals: Bool) async throws -> RFIMonitorFetchResult {
        let url = Self.monitorURL(placeId: placeId, arrivals: arrivals)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; Binario1 spike)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TrainBoardServiceError.resourceMissing
        }
        // RFI pages are usually UTF-8; fall back to Latin-1 for stray bytes.
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        guard !html.isEmpty else { throw TrainBoardServiceError.resourceMissing }
        return RFIMonitorFetchResult(
            html: html,
            url: url,
            statusCode: http.statusCode,
            contentType: http.value(forHTTPHeaderField: "Content-Type"),
            byteCount: data.count
        )
    }
}
#endif
