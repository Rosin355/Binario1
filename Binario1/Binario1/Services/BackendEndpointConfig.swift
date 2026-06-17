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

    /// Local app token for the protected backend, resolved at runtime from the
    /// `BINARIO_BOARD_APP_TOKEN` environment variable. Set it in your Xcode scheme
    /// (Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables) —
    /// that lives in **gitignored user data**, so the real token is never committed.
    /// Empty when unset → no header is sent and `.backendLivePadova` falls back to
    /// the local fixture. The value MUST match the Supabase `BINARIO_BOARD_APP_TOKEN`
    /// secret. NEVER hardcode a real token here.
    ///
    /// (We deliberately use an env var rather than a gitignored `*.local.swift`: the
    /// Xcode project uses a synchronized file group, so a gitignored Swift file would
    /// be compiled on this machine but missing on a fresh clone, breaking the build.)
    private static var debugAppToken: String {
        ProcessInfo.processInfo.environment["BINARIO_BOARD_APP_TOKEN"] ?? ""
    }
    #endif
}
