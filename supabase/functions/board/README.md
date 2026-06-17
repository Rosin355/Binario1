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

## Hardening Phase 1

The function supports a **lightweight app token** + best-effort **rate limit** +
**diagnostics policy**, all driven by Supabase secrets (never committed):

| secret | values | effect |
|--------|--------|--------|
| `BINARIO_BOARD_APP_TOKEN` | any string | when set, requests must send `X-Binario-App-Token: <token>` or get `401` |
| `BINARIO_BOARD_ENV` | `development` \| `production` | `production` omits `diagnostics`; unset → `development` |

Behavior:
- **App token** (`X-Binario-App-Token`): if `BINARIO_BOARD_APP_TOKEN` is set, a
  missing/invalid token → `401 {"error":{"code":"unauthorized",…}}`. If unset, the
  request is allowed **only in development** (warning logged); in `production` an
  unset token is rejected. Token values are never logged or echoed. *This is
  abuse-reduction, not real auth — a token shipped in an app can be extracted.*
- **Rate limit:** best-effort in-memory, 60 req/min per approximate client key →
  `429 {"error":{"code":"rate_limited",…}}` with `Retry-After`, `X-RateLimit-Limit`,
  `X-RateLimit-Remaining`. **Per warm instance only — not globally reliable.**
  TODO(prod): shared/distributed limiter (Upstash/Redis or Supabase-backed).
- **Diagnostics:** included in `development`, omitted in `production`.

### Set the secrets (no values in the repo)

```bash
supabase secrets set BINARIO_BOARD_APP_TOKEN=<your-token> --project-ref <project-ref>
supabase secrets set BINARIO_BOARD_ENV=production --project-ref <project-ref>
# then redeploy:
supabase functions deploy board --no-verify-jwt --project-ref <project-ref>
```

With the GitHub ↔ Supabase integration, set these in **Supabase project secrets**
(dashboard), not in the repo. The matching token also goes in the iOS
`BackendEndpointConfig.appToken` (locally, not committed).

## Security notes

- No anon key, no `service_role` key, no `.env` with real secrets in the repo.
- No database access / no Supabase client init in this function.
- `verify_jwt = false` stays for now; the app token is code-level abuse reduction.
  Production still needs a distributed rate limiter + a rollout policy.
