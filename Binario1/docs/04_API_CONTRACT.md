# 04 — API Contract Backend → iOS

## Obiettivo

Definire un contratto stabile tra app iOS e backend proprietario. L'app non deve dipendere direttamente da sorgenti ferroviarie terze o non documentate.

## Base URL

Ambienti consigliati:

```text
DEV      https://dev-api.binario1.local
STAGING  https://staging-api.binario1.app
PROD     https://api.binario1.app
```

Nel MVP locale usare mock JSON, non serve backend reale.

## Endpoint

### Get station board

```http
GET /v1/stations/{stationId}/board?type=departures&locale=it-IT
GET /v1/stations/{stationId}/board?type=arrivals&locale=en-US
```

`locale` è opzionale. L'app deve funzionare anche senza testi localizzati dal backend, perché le label principali vengono tradotte lato iOS.

### Query parameters

| Parametro | Tipo | Required | Note |
|---|---|---:|---|
| `type` | `departures` / `arrivals` | sì | Tipo tabellone |
| `limit` | integer | no | Default 50 |
| `locale` | string | no | Default `it-IT`; supportare `it-IT`, `it`, `en-US`, `en` |

## Response success

```json
{
  "station": {
    "id": "firenze-smn",
    "name": "Firenze Santa Maria Novella",
    "city": "Firenze",
    "displayName": "FIRENZE S. M. NOVELLA",
    "countryCode": "IT",
    "timezone": "Europe/Rome",
    "providerCodes": {
      "rfi": "FI_SMN",
      "viaggiatreno": "S08409"
    }
  },
  "boardType": "departures",
  "locale": "it-IT",
  "supportedLocales": ["it-IT", "en-US"],
  "rows": [],
  "generatedAt": "2026-06-13T15:30:00+02:00",
  "sourceUpdatedAt": "2026-06-13T15:29:40+02:00",
  "isStale": false,
  "warningMessage": null,
  "warningMessageKey": null
}
```

## Train row JSON

```json
{
  "id": "REG-17120-2026-06-13-firenze-smn",
  "trainNumber": "17120",
  "category": "REG",
  "operatorName": "Trenitalia",
  "origin": null,
  "destination": "Prato Centrale",
  "scheduledTime": "2026-06-13T15:36:00+02:00",
  "expectedTime": "2026-06-13T15:41:00+02:00",
  "delayMinutes": 5,
  "plannedPlatform": "2",
  "actualPlatform": "2",
  "status": "delayed",
  "notes": "",
  "lastUpdated": "2026-06-13T15:29:40+02:00"
}
```

## Localizzazione nel contratto

Regola consigliata: il backend invia **codici e chiavi**, non testi UI indispensabili. Il client iOS decide la lingua usando `Localizable.xcstrings`.

Campi consigliati:

```json
{
  "locale": "it-IT",
  "supportedLocales": ["it-IT", "en-US"],
  "warningMessageKey": "warning.officialDisplays",
  "status": "delayed"
}
```

Il backend può inviare anche `warningMessage`, ma l'app deve preferire `warningMessageKey` quando disponibile.

## Error response

```json
{
  "error": {
    "code": "SOURCE_UNAVAILABLE",
    "message": "Dati temporaneamente non disponibili",
    "messageKey": "error.sourceUnavailable",
    "retryAfterSeconds": 30
  }
}
```

## Error codes

| Code | Significato | UI fallback |
|---|---|---|
| `INVALID_STATION` | Stazione inesistente | Mostra errore e torna alla ricerca |
| `SOURCE_UNAVAILABLE` | Fonte dati non raggiungibile | Mantieni cache se presente |
| `RATE_LIMITED` | Troppe richieste | Mostra retry |
| `DECODING_ERROR` | Backend non riesce a normalizzare | Mostra errore generico |
| `NO_DATA` | Nessun treno disponibile | Empty state |

## Caching headers consigliati

```http
Cache-Control: public, max-age=30, stale-while-revalidate=120
ETag: "station-board-firenze-smn-departures-..."
```

## Regole backend

- Accettare `locale` come query parameter, ma non rendere il client dipendente da testi backend.
- Normalizzare tutte le date in ISO 8601.
- Non inviare HTML al client.
- Non inviare campi ambigui senza fallback.
- Inviare sempre `generatedAt`.
- Inviare `sourceUpdatedAt` quando disponibile.
- Inviare status e warning tramite key stabili quando possibile.
- Se il dato è vecchio ma usabile, `isStale: true`.
- Se la sorgente fallisce, rispondere con ultimo dato valido quando possibile.

## Compatibilità futura

Il contratto può essere esteso con:

```json
{
  "meta": {
    "provider": "rfi",
    "confidence": "high",
    "dataAgeSeconds": 25
  }
}
```

L'app deve ignorare i campi sconosciuti.

## Sicurezza

- Il backend può avere chiavi o logiche private.
- L'app non deve contenere segreti.
- Considerare rate limit per IP/device.
- Considerare user-agent identificativo lato backend.

## Nota per Claude Code

Implementa `RemoteBinario1Service` in modo che legga questo contratto. Tuttavia, nella prima milestone usa solo `MockBinario1Service`.
