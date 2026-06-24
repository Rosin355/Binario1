//
//  BackendEndpointConfig.swift
//  Binario1
//
//  Centralized base URL for the Binario1 backend adapter (Supabase Edge Function
//  `board`). The project-ref URL is NOT a secret, but is kept in one place. No anon
//  / service_role keys here — the spike endpoint runs with `verify_jwt = false`, so
//  no Authorization header is needed.
//

import Foundation

struct BackendEndpointConfig {
    /// Base URL of the deployed function, e.g.
    /// `https://<project-ref>.functions.supabase.co` (the fetcher appends `/board`).
    let baseURL: URL

    /// Lightweight app token sent as the `X-Binario-App-Token` header (abuse
    /// reduction only — NOT a secret-grade credential, NOT user auth). Empty means
    /// "not configured": the fetcher attaches no header and logs a notice. Do NOT
    /// commit a real token value here; set it locally before testing the protected
    /// backend (and `supabase secrets set BINARIO_BOARD_APP_TOKEN=…` server-side).
    var appToken: String = ""

    /// Marker host used while no real deployment URL is set. When present we treat
    /// the config as *not configured* and fall back to the local fixture.
    static let placeholderHost = "project-ref-not-set"

    /// False while `baseURL` still points at the placeholder host.
    var isConfigured: Bool {
        !(baseURL.host?.contains(Self.placeholderHost) ?? true)
    }

    /// App-token precedence: a build-time Info.plist value (baked into the DEBUG
    /// binary via Config/*.xcconfig — survives a Home-screen launch) → the Xcode Run
    /// scheme env var (only present when launched by Xcode) → empty. Ignores an
    /// unresolved `$(…)` substitution and the committed example placeholder.
    static func resolveAppToken(infoValue: String?, envValue: String?) -> String {
        if let v = infoValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !v.isEmpty, v != "paste-local-token-here", !v.contains("$(") {
            return v
        }
        if let e = envValue?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            return e
        }
        return ""
    }

    #if DEBUG
    /// DEBUG backend base URL for `.backendLivePadova` — the deployed Supabase
    /// Edge Function `board` for the "Binario 1" project.
    ///
    /// The project ref is **public, not a secret** (it appears in every function
    /// URL); no anon/service_role key and no Authorization header are used (the
    /// spike runs `verify_jwt = false`). If the endpoint is ever unreachable,
    /// `.backendLivePadova` falls back to the local backend fixture (not silently —
    /// see the `[BackendLive] FALLBACK …` logs). To point at a different deployment,
    /// change the host below (or reset it to the placeholder to force fixture mode).
    static let debug = BackendEndpointConfig(
        baseURL: URL(string: "https://hzwwvkuxqhmeicylyrsy.functions.supabase.co")!,
        appToken: debugAppToken
    )

    /// Local app token for the protected backend (see `resolveAppToken`): a
    /// **build-time** value from the gitignored `Config/Binario1Secrets.local.xcconfig`
    /// (baked into the DEBUG binary via the custom Info.plist key — survives a
    /// Home-screen launch of the installed app), else the Xcode Run scheme env var
    /// (only when launched by Xcode), else empty (→ fixture fallback). MUST match the
    /// Supabase `BINARIO_BOARD_APP_TOKEN` secret. NEVER hardcode a real token here.
    private static var debugAppToken: String {
        resolveAppToken(
            infoValue: Bundle.main.object(forInfoDictionaryKey: "BINARIO_BOARD_APP_TOKEN") as? String,
            envValue: ProcessInfo.processInfo.environment["BINARIO_BOARD_APP_TOKEN"]
        )
    }
    #endif
}
