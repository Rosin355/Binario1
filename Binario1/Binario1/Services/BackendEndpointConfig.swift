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

    /// Marker host used while no real deployment URL is set. When present we treat
    /// the config as *not configured* and fall back to the local fixture.
    static let placeholderHost = "project-ref-not-set"

    /// False while `baseURL` still points at the placeholder host.
    var isConfigured: Bool {
        !(baseURL.host?.contains(Self.placeholderHost) ?? true)
    }

    #if DEBUG
    /// DEBUG backend base URL for `.backendLivePadova`.
    ///
    /// To enable live backend mode: replace the placeholder host below with the
    /// deployed Supabase project ref (NOT a secret), e.g.
    /// `https://abcd1234.functions.supabase.co`. Until then `isConfigured` is false
    /// and `.backendLivePadova` gracefully falls back to the local backend fixture.
    static let debug = BackendEndpointConfig(
        baseURL: URL(string: "https://\(placeholderHost).functions.supabase.co")!
    )
    #endif
}
