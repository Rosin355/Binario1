# `board` Edge Function — Binario1 backend adapter (Phase 2A spike)

Server-side adapter:

```
iOS app → board() → RFI public monitor HTML → normalized JSON → iOS app
```

- **Endpoint:** `GET /board?stationSlug=padova&type=departures&locale=it`
- **Scope (spike):** Padova **departures** only, public/no-JWT, **no DB, no secrets**.
- **Source:** `https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000`
  - `rfiLivePlaceId = 2000` (live monitor) — **distinct** from `prmScheduledId = 1861` (PRM schedule). Never mix.
- **Response:** JSON compatible with the iOS `BackendBoardDTO` (see `docs/13_BACKEND_ADAPTER.md`).
- **Cache:** in-memory, key `stationSlug:type:locale`, TTL 30s. On RFI failure with a
  warm cache → returns stale data with `source.isFallback = true`, `isStale = true`.
  On failure with no cache → structured `502`.
- **Diagnostics:** included for the dev spike (`sourceStatus`, `sourceBytes`, `parsedRows`, …).
  **TODO(prod): reduce or hide.**
- **CORS:** permissive (`*`) for development. **TODO(prod): restrict Allow-Origin.**

## Status codes

| code | meaning |
|------|---------|
| 200  | success |
| 400  | missing `stationSlug`, unsupported `type`, or unsupported `locale` |
| 404  | unknown station |
| 405  | method not allowed (only `GET`/`OPTIONS`) |
| 502  | RFI fetch/parse failure with no cached fallback |

## Local run

```bash
# from repo root (where supabase/ lives)
supabase start                 # optional: only if you want the full local stack
supabase functions serve board --no-verify-jwt
# then:
curl "http://localhost:54321/functions/v1/board?stationSlug=padova&type=departures&locale=it"
```

## Unit tests (no network)

```bash
cd supabase/functions/board
deno test            # runs rfi_test.ts (pure parser/normalization, never calls live RFI)
deno check index.ts  # type-check
```

## Deploy (note only — do NOT run unless authenticated)

If the project is wired to the **Supabase ↔ GitHub integration**, committing this
function lets the connected workflow deploy it.

Otherwise, deploy via CLI (the spike is public, so JWT verification is off):

```bash
supabase functions deploy board --no-verify-jwt
```

Deployed call placeholder (no real project ref committed):

```
https://<project-ref>.functions.supabase.co/board?stationSlug=padova&type=departures&locale=it
```

## Security notes

- No anon key, no `service_role` key, no `.env` with real secrets in the repo.
- No database access / no Supabase client init in this function.
- Public/no-JWT is **only** for this validation spike. Production must add
  rate limiting, an app-level token, and abuse protection first.
