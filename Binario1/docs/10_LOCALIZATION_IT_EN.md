# 10 — Localizzazione IT/EN per Binario1

## Obiettivo

Binario1 deve essere pronta fin dal primo MVP per funzionare in italiano e inglese. La localizzazione non deve essere una vernice finale: deve stare nelle fondamenta, come una rotaia parallela alla UI.

## Lingue supportate

| Lingua | Codice breve | Locale consigliato | Uso |
|---|---|---|---|
| Italiano | `it` | `it-IT` | Lingua principale |
| English | `en` | `en-US` | Lingua secondaria MVP |

## Strategia iOS consigliata

Usare **String Catalog**:

```text
Resources/
└── Localizable.xcstrings
```

Regole:

- nessuna stringa UI hardcoded nelle view;
- usare chiavi stabili e leggibili;
- mantenere label brevi per il tabellone;
- lasciare i nomi ufficiali delle stazioni così come arrivano dal dato;
- tradurre status, errori, warning, disclaimer, empty state e accessibility label.

## Chiavi principali

| Key | Italiano | English |
|---|---|---|
| `app.name` | Binario1 | Binario1 |
| `board.departures` | PARTENZE | DEPARTURES |
| `board.arrivals` | ARRIVI | ARRIVALS |
| `column.time` | ORA | TIME |
| `column.train` | TRENO | TRAIN |
| `column.destination` | DESTINAZIONE | DESTINATION |
| `column.origin` | PROVENIENZA | ORIGIN |
| `column.delay` | RIT | DEL |
| `column.platform` | BIN | PLT |
| `label.updatedShort` | AGG. | UPD. |
| `label.mockData` | DATI MOCK | MOCK DATA |
| `label.liveData` | DATI LIVE | LIVE DATA |
| `status.scheduled` | Programmato | Scheduled |
| `status.onTime` | Puntuale | On time |
| `status.delayed` | In ritardo | Delayed |
| `status.cancelled` | Cancellato | Cancelled |
| `status.departing` | In partenza | Departing |
| `status.departed` | Partito | Departed |
| `status.arriving` | In arrivo | Arriving |
| `status.arrived` | Arrivato | Arrived |
| `status.platformChanged` | Binario variato | Platform changed |
| `status.unknown` | Stato non disponibile | Status unavailable |
| `error.dataUnavailable` | Dati non disponibili. Riprova tra poco. | Data unavailable. Try again shortly. |
| `warning.staleData` | Ultimo aggiornamento non recente. | Last update is not recent. |
| `empty.noTrains` | Nessun treno trovato per questa stazione. | No trains found for this station. |
| `disclaimer.officialDisplays` | Le informazioni possono subire variazioni. In stazione fare sempre riferimento agli annunci e ai monitor ufficiali. | Information may change. At the station, always refer to official announcements and displays. |
| `search.station.placeholder` | Cerca stazione | Search station |
| `search.station.title` | Scegli stazione | Choose station |
| `detail.train.title` | Dettaglio treno | Train details |

## Pattern SwiftUI

### BoardType

```swift
import SwiftUI

enum BoardType: String, Codable, CaseIterable, Identifiable {
    case departures
    case arrivals

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .departures: "board.departures"
        case .arrivals: "board.arrivals"
        }
    }
}
```

### Status formatter

```swift
import SwiftUI

struct LocalizedStatusFormatter {
    func key(for status: TrainStatus) -> LocalizedStringKey {
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

### Error rendering

```swift
if let errorKey = viewModel.errorMessageKey {
    Text(LocalizedStringKey(errorKey))
}
```

## Language setting opzionale

Per il primo MVP è sufficiente seguire la lingua di sistema. Però l'architettura può già prevedere:

```swift
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case italian = "it"
    case english = "en"

    var id: String { rawValue }
}
```

In futuro si potrà aggiungere un'impostazione interna:

- `Sistema` / `System`;
- `Italiano` / `Italian`;
- `English` / `English`.

## Accessibilità localizzata

Le righe del tabellone devono essere dense visivamente, ma chiare con VoiceOver.

Template italiano:

```text
Treno %@ %@ per %@, partenza prevista alle %@, %@, binario %@.
```

Template inglese:

```text
%@ train %@ to %@, scheduled departure at %@, %@, platform %@.
```

Per arrivi sostituire `per/to` con `da/from`.

## Note su nomi ferroviari

Non tradurre forzatamente:

- nomi stazioni;
- categorie treno (`FR`, `REG`, `IC`, `RV`, `ITALO`);
- numeri treno;
- binari.

Esempio corretto:

- IT: `FR 9421 ROMA TERMINI BIN 7`
- EN: `FR 9421 ROMA TERMINI PLT 7`

## Checklist localizzazione MVP

- [ ] `Localizable.xcstrings` creato.
- [ ] Lingue `it` e `en` aggiunte al progetto.
- [ ] Header board localizzato.
- [ ] Colonne localizzate.
- [ ] Stati treno localizzati.
- [ ] Errori e warning localizzati.
- [ ] Disclaimer localizzato.
- [ ] Search station localizzata.
- [ ] Train detail localizzato.
- [ ] VoiceOver label localizzate.
- [ ] Preview/test manuale in italiano.
- [ ] Preview/test manuale in inglese.
