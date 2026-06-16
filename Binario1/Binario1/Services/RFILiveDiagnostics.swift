//
//  RFILiveDiagnostics.swift
//  Binario1
//
//  DEBUG-ONLY validation tooling for the RFI live spike. Lets a developer see, on
//  device or in the console, whether the board is rendering LIVE rows or fell back
//  to mock — never a silent fallback. Excluded from RELEASE entirely.
//

#if DEBUG
import Foundation
import Observation

struct RFIStationMonitorDiagnostics: Equatable {
    let url: URL
    let statusCode: Int?
    let contentType: String?
    let receivedByteCount: Int
    let parsedRowCount: Int
    let usedFallback: Bool
    let renderedSource: String      // "live" | "fallback-after-empty-parse" | "fallback-after-fetch-error"
    let errorDescription: String?
    let capturedHTMLPath: String?
    let capturedAt: Date

    /// Compact one-line status for the DEBUG banner, e.g. "200 · 48 KB · 12 rows · live".
    var compactSummary: String {
        guard let statusCode else { return "error · fallback" }
        return "\(statusCode) · \(receivedByteCount / 1024) KB · \(parsedRowCount) rows · \(usedFallback ? "fallback" : "live")"
    }
}

/// Observable holder for the most recent RFI diagnostics, read by the Home DEBUG
/// banner. Singleton because the live service is created behind `TrainBoardService`.
@Observable
@MainActor
final class RFILiveDiagnosticsStore {
    static let shared = RFILiveDiagnosticsStore()
    private init() {}
    private(set) var latest: RFIStationMonitorDiagnostics?
    func record(_ diagnostics: RFIStationMonitorDiagnostics) { latest = diagnostics }
}

/// Saves the raw RFI HTML to the app Documents directory for inspection / turning
/// into a sanitized fixture. DEBUG only — never auto-committed, never uploaded.
enum RFIRawHTMLCapture {
    static func save(_ html: String) -> String? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = html.data(using: .utf8) else { return nil }
        let latest = docs.appendingPathComponent("rfi-padova-live-latest.html")
        let stamped = docs.appendingPathComponent("rfi-padova-live-\(timestamp()).html")
        do {
            try data.write(to: latest)
            try? data.write(to: stamped)
            print("[RFILive] captured HTML (\(data.count) bytes) → \(latest.path)")
            return latest.path
        } catch {
            print("[RFILive] HTML capture failed: \(error)")
            return nil
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
#endif
