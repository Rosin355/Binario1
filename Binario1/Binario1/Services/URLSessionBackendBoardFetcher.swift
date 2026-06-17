//
//  URLSessionBackendBoardFetcher.swift
//  Binario1
//
//  `BackendBoardFetching` over the network: calls the Binario1 backend adapter
//  (`GET /board?stationSlug=…&type=…&locale=…`) and returns the raw JSON `Data`.
//  It does NOT decode the DTO — decoding/mapping stays in `BackendBoardService`.
//  The app talks to the backend adapter, never directly to RFI in this mode.
//

import Foundation

enum BackendFetchError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
}

struct URLSessionBackendBoardFetcher: BackendBoardFetching {
    let config: BackendEndpointConfig
    let session: URLSession

    init(config: BackendEndpointConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Build `<base>/board?stationSlug=…&type=…&locale=…` (query order is stable).
    static func makeURL(base: URL, stationSlug: String, type: BoardType, locale: String) -> URL? {
        guard var comps = URLComponents(url: base.appendingPathComponent("board"),
                                        resolvingAgainstBaseURL: false) else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "stationSlug", value: stationSlug),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "locale", value: locale),
        ]
        return comps.url
    }

    func fetchBoardJSON(stationSlug: String, type: BoardType, locale: String) async throws -> Data {
        guard let url = Self.makeURL(base: config.baseURL, stationSlug: stationSlug, type: type, locale: locale) else {
            throw BackendFetchError.invalidURL
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw BackendFetchError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                #if DEBUG
                print("[BackendLive] HTTP ERROR · status=\(http.statusCode)")
                #endif
                throw BackendFetchError.httpStatus(http.statusCode)
            }
            guard !data.isEmpty else {
                throw BackendFetchError.emptyResponse
            }
            return data
        } catch let error as BackendFetchError {
            throw error
        } catch {
            #if DEBUG
            print("[BackendLive] FETCH ERROR · error=\(error.localizedDescription)")
            #endif
            throw error
        }
    }
}
