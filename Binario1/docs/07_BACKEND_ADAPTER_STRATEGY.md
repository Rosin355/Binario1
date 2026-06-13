# 07 — Backend Adapter Strategy

## Scopo

Preparare l'architettura per dati live senza rendere fragile l'app iOS.

Il backend è il punto in cui, in futuro, si potranno integrare fonti dati autorizzate, feed pubblici, GTFS real-time se disponibili, API commerciali o adapter specifici.

## Perché non chiamare le fonti dalla app

- Le sorgenti possono cambiare formato.
- Alcuni endpoint possono non essere ufficiali o non documentati.
- Serve cache per evitare troppe chiamate.
- Serve fallback quando la fonte non risponde.
- Serve normalizzazione dei campi.
- Serve cambiare provider senza aggiornare l'app in App Store.

## Pattern backend

```text
HTTP Endpoint pubblico per app
   ↓
StationBoardController
   ↓
Binario1Provider interface
   ↓
ProviderAdapter RFI / ViaggiaTreno / GTFS / Commercial API
   ↓
Normalizer
   ↓
Cache
   ↓
JSON contract stabile
```

## Interfaccia provider

Pseudo TypeScript:

```ts
interface Binario1Provider {
  fetchBoard(input: FetchBoardInput): Promise<ProviderBoardResult>
}

type FetchBoardInput = {
  stationId: string
  providerStationCode: string
  type: 'departures' | 'arrivals'
  limit?: number
  locale?: 'it-IT' | 'en-US' | 'it' | 'en'
}
```

## Normalizer

Il normalizer converte dati grezzi in `BoardResponse`.

Per la localizzazione, il normalizer deve preferire codici stabili e chiavi (`status`, `warningMessageKey`) rispetto a testi già tradotti. Il client iOS userà `Localizable.xcstrings`.

Regole:

- date ISO 8601;
- ritardi in minuti interi;
- binario come stringa;
- status normalizzato;
- note brevi;
- provider metadata solo in `meta`, non nella UI principale;
- warning e status come key localizzabili;
- eventuale `warningMessage` localizzato solo come fallback.

## Cache

### Cache primaria

- TTL: 20–60 secondi.
- Key: `stationId:type`.

### Fallback cache

- Durata: fino a 5–10 minuti.
- Se fonte fallisce, restituire ultimo dato con `isStale: true`.

### Risposta stale

```json
{
  "isStale": true,
  "warningMessage": "Dati non recenti. Verifica i monitor ufficiali in stazione.",
  "warningMessageKey": "warning.staleData"
}
```

## Rate limiting

- Proteggere endpoint per IP/device.
- Limitare refresh troppo frequenti.
- Imporre minimo 20–30 secondi per stazione se necessario.

## Logging

Loggare:

- provider usato;
- tempo risposta;
- errori parsing;
- età cache;
- stazione richiesta;
- tipo board.

Non loggare dati personali non necessari.

## Monitoraggio

Metriche minime:

- percentuale successi provider;
- cache hit rate;
- error rate per stazione;
- tempo medio risposta;
- numero richieste per stazione.

## Possibili stack backend

### Supabase Edge Functions

Vantaggi:

- già coerente con stack moderno;
- facile deploy;
- possibile aggiunta DB/cache;
- buono per MVP.

### Node/Fastify

Vantaggi:

- pieno controllo;
- buon ecosistema;
- facile test adapter.

### Vapor Swift

Vantaggi:

- stesso linguaggio mentale dell'app iOS;
- type safety;
- interessante se vuoi restare full Swift.

## Localizzazione backend

Per il primo MVP il backend non deve essere obbligatorio, ma il contratto deve già prevedere:

- `locale` query parameter;
- `supportedLocales`;
- `messageKey` per errori;
- `warningMessageKey` per warning;
- status tecnici non tradotti.

Esempio: `status = delayed` diventa lato app `In ritardo` oppure `Delayed`.

## Consiglio MVP

Per ora non implementare backend. Preparare solo il contratto.

Quando la UI funziona:

1. creare endpoint mock remoto;
2. collegare app a endpoint mock;
3. implementare provider adapter;
4. aggiungere cache;
5. testare con poche stazioni;
6. valutare aspetti legali/licenze prima di pubblicare.

## Disclaimer prodotto

L'app deve sempre mostrare una nota:

> Dati informativi. In stazione fanno fede annunci e monitor ufficiali.
