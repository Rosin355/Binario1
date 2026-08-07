//
//  Station.swift
//  Binario1
//

import Foundation

struct ProviderCodes: Codable, Equatable, Hashable {
    let rfi: String?
    let viaggiatreno: String?
}

struct Station: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let city: String?
    let displayName: String
    let countryCode: String
    let timezone: String
    let providerCodes: ProviderCodes?
    /// Optional abbreviated forms a live RFI board may use for THIS station's name
    /// (e.g. "Venezia S.L.", "Torino P.N.") that `StationNameMatcher.canonical` can't
    /// derive on its own. Used to line up a saved journey with an abbreviated board
    /// row WITHOUT weakening the ≥2-token rule. Optional → decodes as nil when absent;
    /// never fabricated (only well-known display abbreviations).
    var boardAliases: [String]? = nil
    /// True when this station is SERVED by the live board backend, i.e. its `id` is a
    /// slug present in the backend registry (`supabase/functions/board/registry.ts`)
    /// with a VERIFIED rfiLivePlaceId. The app derives the live station picker from
    /// this flag instead of duplicating the list in code. Absent/false → the station
    /// exists in the catalog for search/naming, but a live fetch must NOT be attempted
    /// (honest "board unavailable" state instead).
    ///
    /// FOOTGUN: `id` MUST equal the backend registry slug exactly ("padova",
    /// "roma-termini") — a mismatch yields 404 unknown_station.
    var servedByLiveBoard: Bool? = nil
}

extension Station {
    /// Whether the live board backend serves this station (see `servedByLiveBoard`).
    var isServedByLiveBoard: Bool { servedByLiveBoard == true }
}

extension Station {
    nonisolated static let bolognaCentrale = Station(
        id: "bologna-centrale",
        name: "Bologna Centrale",
        city: "Bologna",
        displayName: "Bologna Centrale",
        countryCode: "IT",
        timezone: "Europe/Rome",
        providerCodes: ProviderCodes(rfi: "BO_C", viaggiatreno: "S05043")
    )

    nonisolated static let firenzeSMN = Station(
        id: "firenze-smn", name: "Firenze Santa Maria Novella", city: "Firenze",
        displayName: "Firenze Santa Maria Novella", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "FI_SMN", viaggiatreno: "S06421")
    )

    nonisolated static let milanoPortaGaribaldi = Station(
        id: "milano-porta-garibaldi", name: "Milano Porta Garibaldi", city: "Milano",
        displayName: "Milano Porta Garibaldi", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "MI_PG", viaggiatreno: "S01645")
    )

    nonisolated static let veneziaSantaLucia = Station(
        id: "venezia-santa-lucia", name: "Venezia Santa Lucia", city: "Venezia",
        displayName: "Venezia Santa Lucia", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "VE_SL", viaggiatreno: "S02593")
    )

    nonisolated static let reggioEmiliaAV = Station(
        id: "reggio-emilia-av", name: "Reggio Emilia AV Mediopadana", city: "Reggio Emilia",
        displayName: "Reggio Emilia AV Mediopadana", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "RE_AV", viaggiatreno: "S05311")
    )

    /// Padova — used by the RFI Quadro Orario scheduled-timetable spike.
    /// `providerCodes.rfi` carries the RFI Quadro Orario station id (1861).
    nonisolated static let padova = Station(
        id: "padova", name: "Padova", city: "Padova",
        displayName: "Padova", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "1861", viaggiatreno: "S02430")
    )

    /// Mock station carousel used by the home "Cambia" action (and to exercise
    /// long-name layout). The board data itself stays mock.
    nonisolated static let demoStations: [Station] = [
        .bolognaCentrale, .firenzeSMN, .milanoPortaGaribaldi, .veneziaSantaLucia, .reggioEmiliaAV,
    ]
}
