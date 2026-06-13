# 02 — Architettura tecnica

## Principio fondamentale

L'app iOS non deve conoscere la complessità delle sorgenti ferroviarie. Deve ricevere solo dati già normalizzati.

```text
SwiftUI App
   ↓
Feature Layer / ViewModel
   ↓
Domain Service Protocol
   ↓
RemoteBinario1Service oppure MockBinario1Service
   ↓
Backend proprietario JSON
   ↓
Adapter dati ferroviari + cache + fallback
```

## Architettura app iOS

Pattern consigliato: **Feature-first + MVVM leggero + Service protocol**.

```text
Binario1App/
├── App/
│   ├── Binario1App.swift
│   └── AppEnvironment.swift
├── Features/
│   ├── StationBoard/
│   │   ├── StationBoardView.swift
│   │   ├── StationBoardViewModel.swift
│   │   ├── StationBoardRowView.swift
│   │   └── TrainDetailView.swift
│   └── StationSearch/
│       ├── StationSearchView.swift
│       └── StationSearchViewModel.swift
├── Domain/
│   ├── Models/
│   │   ├── Binario1Row.swift
│   │   ├── Station.swift
│   │   ├── BoardType.swift
│   │   └── TrainStatus.swift
│   └── Services/
│       └── Binario1Service.swift
├── Data/
│   ├── DTO/
│   │   ├── BoardResponseDTO.swift
│   │   └── TrainRowDTO.swift
│   ├── Services/
│   │   ├── MockBinario1Service.swift
│   │   └── RemoteBinario1Service.swift
│   └── Mappers/
│       └── Binario1Mapper.swift
├── DesignSystem/
│   ├── BoardColors.swift
│   ├── BoardTypography.swift
│   ├── BoardEffects.swift
│   └── BoardLayout.swift
├── Localization/
│   ├── AppLanguage.swift
│   ├── LocalizationKeys.swift
│   └── LocalizedStatusFormatter.swift
└── Resources/
    ├── Localizable.xcstrings
    └── board-response.sample.json
```

## Layer

### App Layer

Contiene boot, environment e dependency injection.

Responsabilità:

- scegliere service mock o remote;
- configurare base URL;
- iniettare dipendenze nelle feature.

### Feature Layer

Contiene view e view model.

Responsabilità:

- stato UI;
- chiamate async al service;
- auto-refresh;
- mapping di stati loading/error/stale.

Non deve fare parsing HTML o conoscere endpoint esterni non normalizzati.

### Domain Layer

Contiene modelli puri e protocolli.

Responsabilità:

- rappresentare i concetti ferroviari;
- definire interfacce stabili;
- non dipendere da SwiftUI.

### Data Layer

Contiene DTO, decoding, remote service e mock service.

Responsabilità:

- decodificare JSON;
- fare request HTTP;
- mappare DTO in domain model;
- gestire errori di rete.

### Design System

Contiene colori, font, spacing, effetti.

Responsabilità:

- mantenere coerenza visiva;
- evitare duplicazione di valori;
- rendere semplice cambiare estetica.

### Localization Layer

Contiene la struttura bilingue italiano/inglese.

Responsabilità:

- centralizzare le chiavi localizzate;
- trasformare status tecnici in label leggibili;
- fornire accessibility labels localizzate;
- evitare stringhe hardcoded nelle view;
- mantenere label brevi compatibili con la griglia del tabellone.

File consigliati:

```text
Localization/
├── AppLanguage.swift
├── LocalizationKeys.swift
└── LocalizedStatusFormatter.swift
Resources/
└── Localizable.xcstrings
```

## Dependency Injection

Usare un `AppEnvironment` semplice.

```swift
struct AppEnvironment {
    let binario1Service: Binario1Service
    let languageProvider: AppLanguageProvider
}
```

Nel primo MVP può essere passato manualmente alle view.

## Stato ViewModel

Usare `@Observable`.

```swift
@Observable
final class StationBoardViewModel {
    var rows: [Binario1Row] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var selectedStation: Station
    var boardType: BoardType = .departures
}
```

## Auto-refresh

La view può avviare un task quando appare.

Regole:

- refresh immediato al primo load;
- refresh ogni 30 secondi;
- interrompere quando la view sparisce;
- evitare doppie chiamate simultanee;
- se fallisce, mantenere ultimi dati validi e mostrare warning.

## Backend previsto

L'endpoint finale deve essere simile a:

```text
GET /v1/stations/{stationId}/board?type=departures
GET /v1/stations/{stationId}/board?type=arrivals
```

La risposta deve essere normalizzata e stabile.

## Strategia cache

### Client

- Mantiene ultimi dati in memoria.
- Possibile persistenza leggera in futuro.
- Mostra `stale` dopo 3 minuti.

### Backend

- Cache breve 20–60 secondi.
- Fallback su ultimo dato valido.
- Normalizzazione errori.

## Error handling

Errori domain:

```swift
enum Binario1Error: Error, Equatable {
    case invalidStation
    case networkUnavailable
    case serverUnavailable
    case decodingFailed
    case staleData
    case unknown
}
```

UI copy:

Le stringhe non devono essere scritte direttamente nella view. Usare chiavi localizzate:

- `error.dataUnavailable` → IT: `Dati non disponibili. Riprova tra poco.` / EN: `Data unavailable. Try again shortly.`
- `warning.staleData` → IT: `Ultimo aggiornamento non recente.` / EN: `Last update is not recent.`
- `empty.noTrains` → IT: `Nessun treno trovato per questa stazione.` / EN: `No trains found for this station.`

## Note iOS 26

- Usare SwiftUI declarative UI.
- Usare Observation per modelli osservabili.
- Usare `async/await` per concorrenza.
- Evitare dipendenze obsolete non necessarie.
- Valutare standard components iOS dove servono, ma la board principale deve restare custom per preservare il look fisico.

## Riferimenti tecnici

- Apple SwiftUI Documentation: https://developer.apple.com/documentation/swiftui
- Apple Observation Documentation: https://developer.apple.com/documentation/Observation
- Apple iOS & iPadOS 26 Release Notes: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes
