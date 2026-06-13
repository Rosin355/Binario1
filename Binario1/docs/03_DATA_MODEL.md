# 03 — Data Model

## Obiettivo

Definire un modello dati stabile per l'app iOS, separato dai DTO ricevuti dal backend. Il modello deve essere abbastanza ricco da rappresentare un tabellone ferroviario reale, ma abbastanza semplice da sostenere l'MVP.

## Domain models

### BoardType

```swift
enum BoardType: String, Codable, CaseIterable, Identifiable {
    case departures
    case arrivals

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .departures: "board.departures"
        case .arrivals: "board.arrivals"
        }
    }
}
```

### TrainStatus

```swift
enum TrainStatus: String, Codable, Equatable {
    case scheduled
    case onTime
    case delayed
    case cancelled
    case departing
    case departed
    case arriving
    case arrived
    case platformChanged
    case unknown
}
```

### Station

```swift
struct Station: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let city: String?
    let displayName: String
    let countryCode: String
    let timezone: String
    let providerCodes: ProviderCodes?
}

struct ProviderCodes: Codable, Equatable, Hashable {
    let rfi: String?
    let viaggiatreno: String?
}
```

### Binario1Row

```swift
struct Binario1Row: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let trainNumber: String
    let category: String
    let operatorName: String?

    let origin: String?
    let destination: String?
    let displayPlace: String

    let scheduledTime: Date
    let expectedTime: Date?
    let delayMinutes: Int?

    let plannedPlatform: String?
    let actualPlatform: String?
    let platformDisplay: String

    let status: TrainStatus
    let notes: String?
    let lastUpdated: Date
}
```

### BoardResponse

```swift
struct BoardResponse: Codable, Equatable {
    let station: Station
    let boardType: BoardType
    let rows: [Binario1Row]
    let generatedAt: Date
    let sourceUpdatedAt: Date?
    let isStale: Bool
    let warningMessage: String?
}
```

## Modelli per localizzazione

Il modello dati deve restare neutro: non salvare direttamente label UI localizzate dentro `Binario1Row`. Le view devono usare chiavi o formatter localizzati.

### AppLanguage

```swift
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case italian = "it"
    case english = "en"

    var id: String { rawValue }
}
```

### LocalizedStatusFormatter

```swift
struct LocalizedStatusFormatter {
    func label(for status: TrainStatus) -> LocalizedStringResource {
        switch status {
        case .scheduled: "status.scheduled"
        case .onTime: "status.onTime"
        case .delayed: "status.delayed"
        case .cancelled: "status.cancelled"
        case .departing: "status.departing"
        case .departed: "status.departed"
        case .arriving: "status.arriving"
        case .arrived: "status.arrived"
        case .platformChanged: "status.platformChanged"
        case .unknown: "status.unknown"
        }
    }
}
```

### Regola importante

- `status` resta un enum tecnico.
- `delayMinutes` resta un numero.
- `platformDisplay` resta un valore compatto.
- La traduzione avviene solo a livello UI/formatter.

## DTO remoti

I DTO devono rispecchiare il JSON backend e non devono essere usati direttamente nelle view.

```swift
struct BoardResponseDTO: Decodable {
    let station: StationDTO
    let boardType: String
    let rows: [TrainRowDTO]
    let generatedAt: String
    let sourceUpdatedAt: String?
    let isStale: Bool?
    let warningMessage: String?
}
```

```swift
struct TrainRowDTO: Decodable {
    let id: String
    let trainNumber: String
    let category: String
    let operatorName: String?
    let origin: String?
    let destination: String?
    let scheduledTime: String
    let expectedTime: String?
    let delayMinutes: Int?
    let plannedPlatform: String?
    let actualPlatform: String?
    let status: String?
    let notes: String?
    let lastUpdated: String?
}
```

## Regole di mapping

### displayPlace

- Se `boardType == departures`, usare `destination`.
- Se `boardType == arrivals`, usare `origin`.
- Se mancante, mostrare `--`.

### platformDisplay

- Preferire `actualPlatform`.
- Altrimenti usare `plannedPlatform`.
- Se entrambi mancanti, `--`.

### delayMinutes

- `nil`: informazione non disponibile.
- `0`: puntuale.
- maggiore di `0`: ritardo.
- minore di `0`: anticipo, non prioritario nel MVP ma supportato.

### status fallback

Se lo status non è riconosciuto:

```swift
.status = delayMinutes ?? 0 > 0 ? .delayed : .unknown
```

## Formattazione UI

La formattazione visiva deve essere compatta in entrambe le lingue. Il tabellone non deve allargarsi troppo in inglese.

### Ora

Formato compatto:

```text
HH:mm
```

### Ritardo

```text
--      se nil o 0 / if nil or 0
+5      se 5 minuti / if 5 minutes late
+25     se 25 minuti / if 25 minutes late
CANC    se cancellato / if cancelled, compact board style
```

Label estesa per VoiceOver:

- IT: `ritardo 5 minuti`;
- EN: `5 minutes late`.

### Treno

```text
FR 9421
REG 17120
IC 597
```

## Date

- Backend invia ISO 8601.
- Client decodifica con `ISO8601DateFormatter` o decoder configurato.
- Timezone MVP: Europe/Rome.

## Esempio row normalizzata

```json
{
  "id": "FR-9421-2026-06-13-FirenzeSMN",
  "trainNumber": "9421",
  "category": "FR",
  "operatorName": "Trenitalia",
  "origin": "Venezia S. Lucia",
  "destination": "Roma Termini",
  "scheduledTime": "2026-06-13T15:42:00+02:00",
  "expectedTime": "2026-06-13T15:49:00+02:00",
  "delayMinutes": 7,
  "plannedPlatform": "5",
  "actualPlatform": "6",
  "status": "platformChanged",
  "notes": "Binario variato",
  "lastUpdated": "2026-06-13T15:31:00+02:00"
}
```
