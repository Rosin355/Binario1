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
    var city: String?
    let displayName: String
    let countryCode: String
    let timezone: String
    var providerCodes: ProviderCodes?
    /// Optional abbreviated forms a live RFI board may use for THIS station's name
    /// (e.g. "Venezia S.L.", "Torino P.N.") that `StationNameMatcher.canonical` can't
    /// derive on its own. Used to line up a saved journey with an abbreviated board
    /// row WITHOUT weakening the ≥2-token rule. Optional → decodes as nil when absent;
    /// never fabricated (only well-known display abbreviations).
    var boardAliases: [String]? = nil
    /// Alternative names a USER may search for — common, historical or colloquial
    /// forms that are NOT the official RFI name (e.g. "Montegrotto" for
    /// "Terme Euganee-Abano-Montegrotto"). Search-only, and also accepted by the
    /// catalog's canonical lookup so a name persisted under an older spelling still
    /// resolves to this entity. Distinct from `boardAliases`, which are the SHORT
    /// forms an RFI board prints in the destination column. Optional → decodes as nil
    /// when absent; never fabricated.
    var searchAliases: [String]? = nil
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
    /// True when this entry is an OPERATIONAL POINT, not a passenger station: RFI's
    /// list carries "PM …" (posto di movimento), "PC …" (posto di comunicazione),
    /// "… PES" and a "BIVIO …" among its entries (21 of them in the 2026-08-31
    /// snapshot). They exist so a name still
    /// resolves to an entity, but a passenger never boards there.
    ///
    /// Consequences, both deliberate: excluded from board-destination matching
    /// (`StationNameMatcher.matches(station:boardName:)` returns false — an
    /// operational point is never a printed terminus, so "NAPOLI AFRAGOLA PES" can
    /// never answer for a row reading "NAPOLI AFRAGOLA"), and excluded from search
    /// results (opening a board for one would promise a timetable that does not
    /// exist). Absent/false → an ordinary passenger station.
    ///
    /// JSON key: `operationalPoint`. C4 introduces the flag; POPULATING it for the
    /// 21 real entries belongs to B3-full, with the national catalog.
    var operationalPoint: Bool? = nil
}

extension Station {
    /// Whether the live board backend serves this station (see `servedByLiveBoard`).
    var isServedByLiveBoard: Bool { servedByLiveBoard == true }
    /// Whether this entry is an operational point, not a passenger station
    /// (see `operationalPoint`).
    var isOperationalPoint: Bool { operationalPoint == true }
}

extension Station {
    // Names below are RFI's OFFICIAL names, verbatim and UPPERCASE, matching the
    // shared artifact (`rfi-stations.tsv`). Ids are the registry slug the artifact
    // derives from that name — the same string the backend keys its registry by.
    // See the naming policy in docs/12_DECISIONS.md.

    nonisolated static let bolognaCentrale = Station(
        id: "bologna-centrale",
        name: "BOLOGNA CENTRALE",
        city: "Bologna",
        displayName: "BOLOGNA CENTRALE",
        countryCode: "IT",
        timezone: "Europe/Rome",
        providerCodes: ProviderCodes(rfi: "BO_C", viaggiatreno: "S05043")
    )

    /// id realigned to the registry slug in B3-full (was "firenze-smn", which the slug
    /// rule does not produce from the official name).
    nonisolated static let firenzeSMN = Station(
        id: "firenze-santa-maria-novella", name: "FIRENZE SANTA MARIA NOVELLA", city: "Firenze",
        displayName: "FIRENZE SANTA MARIA NOVELLA", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "FI_SMN", viaggiatreno: "S06421")
    )

    nonisolated static let milanoPortaGaribaldi = Station(
        id: "milano-porta-garibaldi", name: "MILANO PORTA GARIBALDI", city: "Milano",
        displayName: "MILANO PORTA GARIBALDI", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "MI_PG", viaggiatreno: "S01645")
    )

    /// OFFICIAL RFI name (placeId 3009 → "VENEZIA S.LUCIA"). "Venezia Santa Lucia" is
    /// the common form and lives on as a `searchAlias` in the catalog — see the naming
    /// policy in docs/12_DECISIONS.md. Renamed in place (one id per station, never a
    /// duplicate entity).
    nonisolated static let veneziaSLucia = Station(
        id: "venezia-s-lucia", name: "VENEZIA S.LUCIA", city: "Venezia",
        displayName: "VENEZIA S.LUCIA", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "VE_SL", viaggiatreno: "S02593")
    )

    /// id realigned to the registry slug in B3-full (was "reggio-emilia-av").
    nonisolated static let reggioEmiliaAV = Station(
        id: "reggio-emilia-av-mediopadana", name: "REGGIO EMILIA AV MEDIOPADANA", city: "Reggio Emilia",
        displayName: "REGGIO EMILIA AV MEDIOPADANA", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "RE_AV", viaggiatreno: "S05311")
    )

    /// Padova — used by the RFI Quadro Orario scheduled-timetable spike.
    /// `providerCodes.rfi` carries the RFI Quadro Orario station id (1861).
    nonisolated static let padova = Station(
        id: "padova", name: "PADOVA", city: "Padova",
        displayName: "PADOVA", countryCode: "IT",
        timezone: "Europe/Rome", providerCodes: ProviderCodes(rfi: "1861", viaggiatreno: "S02430")
    )

    /// Mock station carousel used by the home "Cambia" action (and to exercise
    /// long-name layout). The board data itself stays mock.
    nonisolated static let demoStations: [Station] = [
        .bolognaCentrale, .firenzeSMN, .milanoPortaGaribaldi, .veneziaSLucia, .reggioEmiliaAV,
    ]
}
