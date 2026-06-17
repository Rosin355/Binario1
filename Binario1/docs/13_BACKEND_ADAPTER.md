# 13 — Backend Adapter Architecture

Status: **design only** — no backend implemented yet. This documents the target
production architecture for real train-board data, so the current DEBUG-only RFI
spike can later move behind a server adapter.

## Target architecture

```
iOS app  →  Binario1 backend adapter  →  RFI source  →  normalized JSON  →  iOS app
```

The iOS app never scrapes RFI directly in production. It calls the Binario1
backend, which fetches + parses the RFI monitor server-side and returns **stable,
normalized JSON** matching the app's existing domain model.

## Why a backend adapter

- **Don't scrape RFI from the production app.** HTML scraping in-app is brittle and
  hard to fix once shipped.
- **Centralize parser fixes server-side.** When RFI markup changes, fix the server
  — no App Store release required.
- **Reduce app-update risk.** The app consumes a versioned JSON contract, not HTML.
- **Caching + rate limiting.** The server caches briefly and shields RFI from
  per-client traffic.
- **Fallback sources later.** The server can add ViaggiaTreno / other sources behind
  the same contract without app changes.
- **Source transparency stays intact.** The contract carries a clear source label
  (`Monitor RFI online`) and `isFallback` / `isStale` flags.

## API contract (v1)

```
GET /api/board
```

Query params:

| param         | required | values / default                  |
|---------------|----------|------------------------------------|
| `stationSlug` | one of slug/id | e.g. `padova`                |
| `stationId`   | one of slug/id | central id (see registry)    |
| `type`        | yes      | `departures` \| `arrivals`         |
| `source`      | no       | `rfi` (default)                    |
| `locale`      | no       | `it` (default) \| `en`             |

Example:

```
GET /api/board?stationSlug=padova&type=departures&locale=it
```

### Response shape (mirrors the app model)

```json
{
  "station": {
    "id": "padova",
    "name": "Padova",
    "sourcePlaceId": "2000"
  },
  "boardType": "departures",
  "source": {
    "kind": "rfiLive",
    "label": "Monitor RFI online",
    "updatedAt": "2026-06-17T10:49:00+02:00",
    "fetchedAt": "2026-06-17T10:50:12+02:00",
    "isFallback": false,
    "isStale": false
  },
  "rows": [
    {
      "id": "REG-16971-2026-06-17T10:49",
      "scheduledTime": "10:49",
      "category": "REG",
      "trainNumber": "16971",
      "destination": "Venezia Mestre",
      "platform": "2",
      "delayMinutes": 0,
      "status": "onTime",
      "notes": []
    }
  ],
  "diagnostics": {
    "sourceStatus": 200,
    "sourceBytes": 335041,
    "parsedRows": 40
  }
}
```

### Field notes

- `source.kind`: `rfiLive` | `scheduled` | `mock` (maps to the app's `BoardSourceKind`).
- `source.label`: human source label shown in the header (never a guarantee of
  real-time precision).
- `status`: `onTime` | `delayed` | `cancelled` | `departing` | … (maps to `TrainStatus`).
- `delayMinutes`: real positive delay or `0`/absent — **never a fabricated delay**.
- `platform`: source value or absent → app renders `--`.
- `category`: already a **compact normalized code** (`AV`/`RV`/`REG`/`IC`/`ITA`/…),
  never a verbose `Categoria …` label and never HTML entities.
- `diagnostics`: **development/debug only**. Omitted (or reduced to a minimal
  `isFallback`/`isStale`) in production responses.

## Backend behavior requirements

- Fetch the RFI monitor HTML **server-side**.
- Parse HTML, normalize **categories**, **delay**, **platform**, **status**
  server-side (the rules currently in the DEBUG iOS spike move here).
- Return the stable JSON above.
- **Cache** results briefly (suggested **30–60s**) per `station|type`.
- **No aggressive polling**; **rate-limit** clients.
- On RFI fetch failure, return **stale-but-recent cached** data with `isStale=true`
  (and `isFallback=true` if served from an alternate/last-known source).
- Expose `isFallback` / `isStale` honestly; **never claim perfect real-time
  precision**.
- Preserve source transparency (`Monitor RFI online`).

## iOS migration plan

**Phase 1 — contract + DTO (no behavior change) — ✅ IMPLEMENTED (iOS, fixture-only)**
- Keep the current DEBUG direct-RFI adapter (`RFILiveBoardService`) available as a
  dev fallback (flip `AppEnvironment.sourceMode`).
- Added: `BackendBoardDTO` (wire model), `BackendBoardMapper` (DTO → `StationBoardResponse`),
  `BackendBoardService: TrainBoardService` with a `BackendBoardFetching` source and a
  `FixtureBackendBoardFetcher` (bundled JSON, **no network**).
- Added DEBUG source mode `.backendFixturePadova` (header label "Backend fixture ·
  Monitor RFI online") — the DEBUG default; RELEASE stays `.mock`.
- Fixture: `Binario1/Resources/backend-padova-departures.sample.json` (app, for the
  DEBUG service) + `Binario1Tests/Fixtures/backend-padova-departures.sample.json` (tests).
- Tested: DTO decode (incl. optional diagnostics), mapper normalization
  (categories compact, missing platform → `--`, 0/cancelled → no delay, 5'→medium,
  12'→severe), and the fixture service (loads + maps, `sourceKind == .backendFixture`,
  no network). **No live backend networking yet.**

**Phase 2A — backend endpoint (spike) — ✅ STARTED (server-side)**
- Supabase Edge Function `board` exists: `supabase/functions/board/`
  (`index.ts` handler + `rfi.ts` parser/normalization + `rfi_test.ts`).
- `GET /board?stationSlug=padova&type=departures&locale=it` — **Padova departures only**.
- Server-side RFI fetch (placeId 2000) + normalization → JSON matching `BackendBoardDTO`.
- In-memory 30s cache; stale-fallback on RFI failure; 200/400/404/405/502; permissive CORS.
- **Public / no-JWT for the spike** (`verify_jwt = false`); no DB, no secrets.
- **Pending:** iOS *remote* fetcher (a `URLSession` `BackendBoardFetching` pointing at
  the deployed function) — not built yet; iOS still uses the local fixture (Phase 1).
- **Pending (prod hardening):** rate limiting, app-level token/auth, abuse protection,
  shared cache, reduced/hidden diagnostics, restricted CORS, more stations + arrivals.
- Local run / deploy notes: `supabase/functions/board/README.md`.

**Phase 2 — backend in DEBUG**
- DEBUG uses `BackendBoardService` (pointing at staging/local).
- Keep the direct RFI adapter as an **emergency developer fallback only**.

**Phase 3 — production**
- Production app uses `BackendBoardService`.
- Direct RFI HTML parsing is **excluded from Release** (stays `#if DEBUG`).
- Mock remains available for tests/previews.

## Station registry plan

Stations must be **centrally mapped** — the RFI **live** `placeId` and the PRM
**scheduled** id are different systems and must **never** be mixed.

| slug                | displayName            | rfiLivePlaceId | prmScheduledId |
|---------------------|------------------------|----------------|----------------|
| `padova`            | Padova                 | `2000`         | `1861`         |

Future (placeholders, ids TBD): Bologna Centrale, Venezia Santa Lucia,
Montegrotto Terme, Milano Centrale.

Registry shape (future):

```
struct StationRegistryEntry {
    let slug: String
    let displayName: String
    let rfiLivePlaceId: String?   // RFI live monitor (Monitor?placeId=…)
    let prmScheduledId: String?   // PRM "Quadro Orario" (different system)
}
```

The backend owns the canonical registry; the app references stations by `slug`/`id`
only and never hardcodes a source-specific id outside the registry.
