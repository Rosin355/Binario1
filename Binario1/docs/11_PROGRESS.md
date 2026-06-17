# 11 — Progress

Cronologia sintetica delle milestone. Tenere conciso.

## 2026-06-17 — Harden board backend access

Stato: completata (Hardening Phase 1). Codice live deployato; enforcement del token
attivabile impostando i secret server-side (non ancora attivi → spike resta aperto).

### Cosa
- **App token** `X-Binario-App-Token` nella Edge Function: legge
  `BINARIO_BOARD_APP_TOKEN` (env). Se configurato → token mancante/errato = **401**
  (`unauthorized`); se non configurato → consentito **solo in development** (warning),
  rifiutato in production. Confronto constant-time-ish; il token **non** è mai loggato
  né incluso negli errori.
- **Rate limit foundation** in-memory best-effort (60 req/min per client key) → **429**
  (`rate_limited`) con `Retry-After`/`X-RateLimit-Limit`/`X-RateLimit-Remaining`.
  Per-istanza, **non globale** → TODO limiter distribuito (Upstash/Redis o Supabase).
- **Diagnostics ridotte per ambiente**: `BINARIO_BOARD_ENV` (`development`/`production`,
  default development). In production il blocco `diagnostics` è **omesso**.
- **iOS**: `URLSessionBackendBoardFetcher` allega `X-Binario-App-Token` se
  `BackendEndpointConfig.appToken` è valorizzato; se vuoto logga
  `[BackendLive] app token not configured` e non allega header. 401 → errore tipizzato
  → `BackendBoardService` fallback alla fixture (header "Backend fixture"). Nessun
  token reale committato (placeholder vuoto, da impostare in locale).

### Validazione
- Backend: `deno check` pulito; `deno test` **16/16** (7 hardening + 9 parser).
  Handler locale: no token→401, token errato→401, token corretto→200 (diagnostics in
  dev), production+token→200 **senza diagnostics**, production+token assente→401.
  Funzione **rideployata**; live senza token → 200 (unconfigured+development),
  header rate-limit presenti.
- iOS: Build Debug+Release OK; test target compila (5 nuovi test token/401/fallback;
  esecuzione bloccata da CoreSimulator — ambiente).

### Secret Supabase richiesti (non nel repo)
- `BINARIO_BOARD_APP_TOKEN=<token>` · `BINARIO_BOARD_ENV=production`
  (`supabase secrets set …`, poi redeploy). Token speculare in
  `BackendEndpointConfig.appToken` lato app (in locale, non committato).

### Sicurezza / prossimo
- Nessun secret committato (solo project ref pubblico). Release resta `.mock`.
  Prossimo: rate limit distribuito, espansione station registry, arrivi,
  decisione di rollout produzione.

## 2026-06-17 — Validate backend live on iPhone

Stato: **VALIDATO end-to-end su iPhone reale.** Backend adapter provato:
iOS → Supabase Edge Function `/board` → RFI → JSON normalizzato → board.

### Validazione su device
- **Evidenza**: log console Xcode da iPhone reale (nessuno screenshot catturato):
  `[BackendLive] OK · rows=40 · source=rfiLive · fallback=false · stale=false`.
- **Conferma**: `.backendLivePadova` chiama con successo la Supabase `/board`; il
  backend ha restituito **40 righe live**; `fallback=false` (fixture NON usata);
  `stale=false` (nessun cache stale); **nessun log `[RFILive]`** → il parser RFI
  diretto on-device non gira in questa modalità.

### Contesto (già fatto in precedenza)
- **Function deployata**: `board` sul progetto Supabase "Binario 1"
  (`supabase functions deploy board --no-verify-jwt`). Endpoint:
  `https://hzwwvkuxqhmeicylyrsy.functions.supabase.co/board`.
- **Endpoint validato via curl**: `?stationSlug=padova&type=departures&locale=it`
  → 200 partenze reali (categorie compatte, niente `Categoria`/entità); 404 station
  sconosciuta; 400 `type=arrivals`.
- **iOS DEBUG**: `BackendEndpointConfig.debug` punta all'URL reale (project ref
  pubblico, non un secret; nessuna anon/service_role key, nessun header Authorization).

### Prossimo hardening (non ancora avviato)
- app token / auth · rate limiting · cache condivisa · espansione station registry
  · supporto arrivi · riduzione diagnostics · decisione di rollout in produzione.

### Sicurezza
- Nessun secret committato (solo il project ref pubblico). Release resta `.mock`.
  `.backendFixturePadova`/`.rfiLivePadova`/`.mock` invariati; Viaggi/Cerca invariati.
  Pass solo-doc: nessun codice modificato.

## 2026-06-17 — iOS backend live fetcher

Stato: completata (Phase 2B lato iOS). Prossima: **deploy della function + hardening
produzione (auth/rate limit/cache condivisa/registry stazioni reale)**.

### Cosa (niente UI ridisegnata; Viaggi/Cerca invariati)
- **Fetcher di rete**: nuovo `Services/URLSessionBackendBoardFetcher.swift`, conforme
  a `BackendBoardFetching`. Costruisce `<base>/board?stationSlug=…&type=…&locale=…`,
  fa `URLSession.data(from:)`, valida lo status HTTP 2xx, ritorna `Data` grezza
  (nessuna decodifica nel fetcher). Errori tipizzati `BackendFetchError`
  (`invalidURL`/`invalidResponse`/`httpStatus`/`emptyResponse`).
- **Config endpoint centralizzata**: nuovo `Services/BackendEndpointConfig.swift`
  (`baseURL`). DEBUG: `BackendEndpointConfig.debug` con host placeholder
  `project-ref-not-set` → `isConfigured == false` finché non si mette il project-ref
  reale (NON è un secret; nessuna anon/service_role key). Spike `verify_jwt = false`
  → nessun header Authorization.
- **Source mode** `.backendLivePadova` (DEBUG): iOS → Edge Function `/board` → RFI →
  JSON normalizzato. Default DEBUG. Mantenuti `.backendFixturePadova`, `.rfiLivePadova`,
  `.scheduledPadova`, `.mock`. Release resta `.mock`.
- **Factory**: `.backendLivePadova` usa `BackendBoardService(fetcher: URLSession…,
  fallback: <servizio fixture>, stampSourceKind: .backendLive, debugLogTag: "BackendLive")`.
  Se l'URL non è configurato → usa direttamente la fixture (log esplicito). Su errore
  di rete → fallback alla fixture **non silenzioso** (`[BackendLive] FALLBACK …`).
- **Header**: nuova `BoardSourceKind.backendLive` → "Backend · Monitor RFI online" /
  "Backend · RFI online monitor"; suffisso " · fallback" (source.isFallback) o
  " · dati cache"/"· cached" (source.isStale) in colore d'allerta. Distingue il dato
  che arriva dal backend dal dato RFI diretto.
- **Log DEBUG concisi**: `[BackendLive] OK · rows=N · source=rfiLive · fallback=… ·
  stale=…`, `[BackendLive] FALLBACK · reason=… · using=fixture`, `[BackendLive] HTTP
  ERROR · status=…`, `[BackendLive] FETCH ERROR · error=…` (nessun body JSON grande).

### Test (nessuna rete reale)
- URL builder = `/board?stationSlug=padova&type=departures&locale=it`.
- Fetcher: 200→Data, non-2xx→`httpStatus`, body vuoto→`emptyResponse` (via
  `StubURLProtocol` stateless, host-encoded).
- `BackendBoardService` mappa JSON remoto stubbato → `StationBoardResponse`
  (`sourceKind == .backendLive`, categorie compatte, ritardo/stato corretti).
- `BackendEndpointConfig.isConfigured` rileva il placeholder.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da CoreSimulator (ambiente). Release mock-only; nessun secret commesso.

## 2026-06-17 — Supabase board backend adapter spike

Stato: completata (Phase 2A, spike backend). Prossima: **fetcher di rete iOS verso
l'endpoint + hardening produzione (rate limit/auth/cache condivisa)**.

### Cosa (solo backend; nessuna modifica iOS UI/Viaggi/Cerca)
- **Edge Function `board`** (Deno/TypeScript) in `supabase/functions/board/`:
  `GET /board?stationSlug=padova&type=departures&locale=it`.
- **Padova partenze** supportate (registry minimo `STATIONS`: `rfiLivePlaceId=2000`,
  `prmScheduledId=1861`, sistemi distinti, mai mischiati).
- **Fetch RFI server-side** del monitor pubblico (placeId 2000, `arrivals=False`);
  cattura status/content-type/byte/fetchedAt/HTML.
- **Normalizzazione server-side** (`rfi.ts`, port del parser iOS DEBUG): categorie
  compatte (REG/RV/AV/FR/IC/EC/RJ/…), niente `Categoria`, niente entità HTML; binario
  assente → `--`; ritardo>0 → `delayed`; cancellato → `cancelled`; in partenza →
  `departing`; altrimenti `onTime`. Niente ritardi/binari inventati.
- **Risposta compatibile con `BackendBoardDTO` iOS** (`station`/`boardType`/`source`/
  `rows`/`diagnostics`).
- **Cache** in-memory (key `slug:type:locale`, TTL 30s); su errore RFI con cache
  calda → dati stale con `isFallback=true`/`isStale=true`; senza cache → `502`
  strutturato. Codici: 200/400/404/405/502. CORS permissivo + preflight `OPTIONS`
  (TODO restringere in prod).
- **Auth/JWT (spike)**: endpoint pubblico, `verify_jwt = false` in `config.toml`
  (deploy `supabase functions deploy board --no-verify-jwt`). Niente DB, niente
  service_role, niente secret nel repo (`supabase/.gitignore` esclude `.env`/`.temp`).
- **Test/validazione**: `rfi_test.ts` (Deno, puro, nessuna rete) su categorie/entità/
  ritardo/binario/stato + shape. Deno non installato in locale → check eseguibile con
  `deno test` / `deno check` quando disponibile.

## 2026-06-17 — Backend adapter iOS fixture phase

Stato: completata (Phase 1 lato iOS, solo fixture). Prossima: **Phase 2 — fetcher di
rete `URLSession` verso backend staging, RFI diretto come fallback dev**.

### Cosa (niente backend reale, niente rete, niente UI ridisegnata)
- **DTO backend**: nuovo `Services/BackendBoardDTO.swift` — decodifica il JSON
  normalizzato del contratto `GET /api/board` (`station`, `boardType`, `source`,
  `rows`, `diagnostics` opzionale). I DTO sono solo modello di trasporto: le view non
  li vedono mai.
- **Mapper**: nuovo `Services/BackendBoardMapper.swift` — DTO → `StationBoardResponse`.
  Regole sicure: niente ritardi/binari inventati; binario assente → `--`; ritardo
  0/assente → nessun badge; `cancelled` → stato cancellato senza ritardo; status
  ignoto → derivato dal ritardo. Categorie già compatte dal backend (REG/RV/AV/IC/…).
- **Service**: nuovo `Services/BackendBoardService.swift` — conforme a
  `TrainBoardService`, sorgente via `BackendBoardFetching`; in Phase 1 solo
  `FixtureBackendBoardFetcher` (JSON dal bundle, **nessuna rete**). Decodifica → mappa
  → marca `sourceKind = .backendFixture`; fallback obbligatorio al mock su
  errore/board vuota o per gli arrivi.
- **Fixture JSON normalizzato**: `Binario1/Resources/backend-padova-departures.sample.json`
  (risorsa app per il service DEBUG) + `Binario1Tests/Fixtures/backend-padova-departures.sample.json`
  (test). 9 partenze Padova realistiche (REG/RV/AV verso Venezia/Napoli/Belluno/
  Bologna, +5′, +12′, una cancellata). JSON normalizzato, niente `Categoria`, niente
  entità HTML, niente label sorgente nelle righe.
- **Source mode DEBUG**: aggiunto `.backendFixturePadova` (default DEBUG; header
  "Backend fixture · Monitor RFI online" / "Backend fixture · RFI online monitor",
  nuova `BoardSourceKind.backendFixture`). Mantenuti `.rfiLivePadova`,
  `.scheduledPadova`, `.mock` (flip in `AppEnvironment.sourceMode`). Release resta
  `.mock`.

### Test
- DTO: decodifica fixture (id/nome stazione, boardType, source kind/label, righe,
  diagnostics opzionali) + decodifica senza `diagnostics`.
- Mapper: 9 righe preservate, categorie compatte (no `Categoria`/`&#`), binario
  assente → `--`, 0/cancellata → nessun ritardo, 5′ → medium, 12′ → severe.
- Service: carica la fixture senza rete, `sourceKind == .backendFixture`.
- Nessun test usa rete o backend reale.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). UI/Viaggi/Cerca invariati; Release
  mock-only.

## 2026-06-17 — Prepare backend adapter architecture

Stato: completata (design + scaffold). Prossima milestone: **Phase 1 — `BackendBoardService`
+ DTO contro fixture JSON locale**.

### Cosa (niente backend, niente UI)
- **Doc architettura backend**: nuovo `docs/13_BACKEND_ADAPTER.md` con flusso
  `iOS → adapter backend → RFI → JSON normalizzato → iOS`, motivazioni (no scraping
  in produzione, fix parser server-side, meno rischio update app, cache/rate-limit,
  fallback futuri, JSON stabile), **contratto API** `GET /api/board`
  (`stationSlug`/`stationId`, `type`, `source`, `locale`) + esempio JSON che
  rispecchia il modello app, requisiti backend (cache 30–60s, rate-limit,
  stale-but-recent, `isFallback`/`isStale`, trasparenza sorgente), **piano di
  migrazione iOS** (Phase 1 DTO+`BackendBoardService` su fixture; Phase 2 backend in
  DEBUG con RFI diretto come fallback dev; Phase 3 produzione su backend, RFI HTML
  escluso da Release), e **station registry** (Padova: slug `padova`, displayName
  `Padova`, rfiLivePlaceId `2000`, prmScheduledId `1861`; live placeId ≠ id PRM, mai
  mischiarli).
- **Fixture reale**: NON aggiunta in questo pass — il file catturato vive nel
  container del device (`Documents/rfi-padova-live-latest.html`) e non è recuperabile
  da qui; per policy "non inventare fixture" non è stato fabbricato. Aggiunto un test
  `rfiRealSampleParsesIfPresent` che carica `rfi-padova-departures.real-sample.html`
  dal bundle di test e **salta** finché il file non è aggiunto (poi verifica
  PADOVA, ≥20 righe, categorie normalizzate senza `Categoria`/`&#`). La fixture
  rappresentativa esistente resta.

### Come aggiungere la fixture reale (manuale)
Xcode → Window > Devices and Simulators → iPhone → app Binario1 → Download Container
→ `AppData/Documents/rfi-padova-live-latest.html` → copiare in
`Binario1Tests/Fixtures/rfi-padova-departures.real-sample.html` (sanitizzare se serve).

### File
- Nuovo: `docs/13_BACKEND_ADAPTER.md`. Modificati: `Binario1Tests` (test reale gated),
  `docs/12_DECISIONS.md`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Nessuna rete nei test; UI/Viaggi/Cerca
  invariati; Release resta mock-only.

## 2026-06-16 — RFI live hardening and delay-column polish

Stato: completata. Prossima milestone: **verifica parser su HTML reale + fixture
sanitizzata**.

### 1. Doppio fetch RFI (investigato + risolto)
- **Causa**: `selectBoardType` chiamava `refresh()` E il cambio di `boardType`
  rilancia `.task(id:)` → due fetch al cambio Partenze/Arrivi; eventuali
  re-trigger del `.task` all'apertura non erano deduplicati. Il token animazione
  titolo **non** causava reload (alimenta solo il titolo header — confermato).
- **Fix**: `refresh(force:)` con **guard in-flight** (no overlap) + **dedupe per
  board** (stesso `station|boardType` entro `minAutoRefreshInterval` = 8s →
  skip); `selectBoardType` non fa più fetch (lo fa `.task(id:)`); pull-to-refresh
  usa `force: true`; il fetch annullato (superseded) non mostra errore.
- Risultato: apertura → 1 fetch; refresh manuale → 1 fetch; ritorno da
  Viaggi/Cerca → nessun fetch automatico; cambio board → 1 fetch.

### 2. Diagnostica DEBUG più pulita
- Log conciso: `[RFILive] LIVE OK · status=200 · rows=40 · bytes=… · contentType=… · fallback=false`,
  `[RFILive] FALLBACK · status=… · rows=0 · …`, `[RFILive] FETCH ERROR · fallback=true · error=…`.
- Riepilogo categorie: `[RFILive] categories: AV=12, RV=8, REG=15, …`.
- Log per-riga categoria dietro flag `RFILiveMapper.logsCategoryNormalizationDetails`
  (default `false`). Capture HTML grezzo in Documents invariato (path loggato).

### 3. Colonna ritardo compatta (UI)
- In "Tutte le partenze" la colonna ritardo ora è una `VStack`: etichetta piccola
  `Rit.` / `Del.` + badge ritardo sotto. Mostrata solo se c'è ritardo/cancellazione;
  colonna a larghezza fissa stabile quando vuota; nessuno shift della destinazione.

### 4. Logica colore ritardo semantica
- Nuovo `DelayVisualState` (mild/medium/severe/cancelled): 1–4' ambra, 5–9' arancio
  (`BoardColors.delayMedium`), 10'+ rosso-arancio, cancellato rosso, 0/nil → nessun
  badge. Rosso riservato ai problemi seri.

### File
- Modificati: `ViewModel/StationBoardViewModel.swift` (dedupe/force),
  `Views/StationBoardView.swift` (onSelect sync, refresh force),
  `Views/DelayBadgeView.swift` (`DelayVisualState`), `Views/TrainBoardRowView.swift`
  (colonna ritardo label+badge), `DesignSystem/BoardTheme.swift` (`delayMedium`),
  `Services/RFILiveBoardService.swift` (log + flag + summary), `Localizable.xcstrings`
  (`delay.short`), `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Aggiunti test soglie ritardo + dedupe.

## 2026-06-16 — RFI live diagnostics

Stato: completata (tooling DEBUG). Prossima milestone: **girare su iPhone reale e
salvare una fixture reale (sanitizzata) dal capture**.

### Cosa (solo DEBUG; nessun cambiamento di produzione)
- Nuova diagnostica `.rfiLivePadova`: niente più fallback silenzioso in DEBUG.
- `RFIStationMonitorDiagnostics` (url, status, content-type, byte ricevuti, righe
  parsate, fallback sì/no, `renderedSource`, errore, path HTML catturato) +
  `RFILiveDiagnosticsStore` (`@Observable`, singleton, solo DEBUG).
- Client: `fetchMonitor` ora restituisce `RFIMonitorFetchResult` (html + status +
  content-type + byteCount). Il service popola la diagnostica:
  - live → `usedFallback=false`, `renderedSource="live"`.
  - fetch ok ma 0 righe → `"fallback-after-empty-parse"`.
  - fetch fallito → `"fallback-after-fetch-error"`.
- **Capture HTML grezzo** (solo DEBUG) in Documents:
  `rfi-padova-live-latest.html` + `rfi-padova-live-YYYYMMDD-HHmmss.html`, path
  loggato in console. Mai in RELEASE, mai committato/caricato.
- **Banner DEBUG** sotto l'header (solo se `.rfiLivePadova`): es.
  `DEBUG RFI: 200 · 48 KB · 12 rows · live` / `… · 0 rows · fallback` /
  `DEBUG RFI: error · fallback` (rosso se fallback). Console logga URL, content-type,
  path capture, errore.
- Diagnostica iniettabile (`recordDiagnostics`) per test deterministici; di default
  scrive nello store osservato dalla UI.

### File
- Nuovi: `Services/RFILiveDiagnostics.swift`, `Views/RFILiveDiagnosticsBanner.swift`
  (entrambi `#if DEBUG`).
- Modificati: `Services/RFIStationMonitorClient.swift` (`RFIMonitorFetchResult`),
  `Services/RFILiveBoardService.swift` (diagnostica + capture), `Views/StationBoardView.swift`
  (banner DEBUG), `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release; in Release nessuna diagnostica/capture, tutto escluso).
- Test target: compila. Esecuzione unit test bloccata da instabilità CoreSimulator
  (ambiente). Test diagnostica via stub: live/empty/error, byteCount, rowCount.

### Prossimo
- Eseguire su iPhone reale; usare l'HTML catturato per verificare il parser e,
  se serve, salvarne una versione **sanitizzata** come fixture (mai auto-commit).

## 2026-06-16 — Normalize RFI train categories

Stato: completata. Prossima milestone: **verifica parser su HTML RFI reale**.

### Bug (su iPhone reale)
- Le categorie RFI arrivavano verbose: `Categoria RV`, `Categoria Alta
  Velocita&#39;`, ecc. → card con testo lungo, lista compatta troncata `CATE...`,
  entità HTML non decodificate (`&#39;`).

### Fix (solo parser/normalizzazione)
- Nuovo `HTMLEntityDecoder` (entità numeriche `&#39;`/`&#224;` + alcune named) e
  `RFITrainCategoryNormalizer`: decodifica entità → normalizza apostrofi/accenti →
  rimuove il prefisso `Categoria` → mappa alle sigle compatte
  (Regionale→REG, Regionale Veloce→RV, Alta Velocità/Velocita'→AV, Frecciarossa→FR,
  Frecciargento→FA, Frecciabianca→FB, Intercity→IC, Intercity Notte→ICN, Italo→ITA,
  Eurocity→EC, Euronight→EN). Sconosciute lunghe → `UNK` (mai stringhe lunghe).
- Il parser ora **decodifica le entità** in `clean` e negli `alt` immagine, così
  nessuna cella (categoria, destinazione…) espone `&#…`.
- `RFILiveMapper.category` delega al normalizzatore (+ log DEBUG `raw→normalized`).
- UI: aggiunto `lineLimit(1)` alla categoria della card "Prossime partenze"
  (la lista compatta aveva già `lineLimit(1)` + colonna fissa). Numero treno resta
  separato dalla categoria. Nessun redesign.

### Test
- Normalizzatore (tutti i casi: RV/REG/AV/FR/IC/ICN/ITA, sconosciuto→UNK,
  nil/empty→UNK), decoder HTML, e fixture RFI aggiornata con `Categoria …` +
  `&#39;`: asserzioni che nessuna `TrainBoardRow.category` contiene `Categoria` o
  `&#`, riga AV→`AV`, riga RV→`RV`. Niente rete.

### File
- Nuovo: `Services/RFITrainCategoryNormalizer.swift` (`#if DEBUG`).
- Modificati: `Services/RFIStationMonitorParser.swift` (decode entità),
  `Services/RFILiveBoardService.swift` (delega + log), `Views/FeaturedTrainRowView.swift`
  (`lineLimit(1)` categoria), `Binario1Tests` + fixture `rfi-padova-departures.sample.html`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente).

## 2026-06-16 — RFI live Padova spike

Stato: completata (spike tecnico). Prossima milestone: **verifica parser su HTML
RFI reale + valutazione affidabilità/legale**.

### Cosa
- Primo spike **dati reali**, **solo DEBUG**: adapter del monitor live RFI per
  **Padova partenze**. Endpoint
  `https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000`
  (live monitor `placeId=2000`, distinto dall'id PRM Quadro Orario 1861).
- Nuovo `BoardSourceMode.rfiLivePadova`. `AppEnvironment.sourceMode`:
  **DEBUG → `.rfiLivePadova`**, **RELEASE → `.mock`** (lo spike non diventa mai il
  default di produzione; i file RFI sono `#if DEBUG`).
- Layer service isolato (niente parsing nelle view/VM):
  - `RFIStationMonitorClient` — costruisce l'URL + fetch HTML (`RFIMonitorFetching`).
  - `RFIStationMonitorParser` — HTML → `RFIMonitorBoard`/`RFIMonitorRow` (stazione,
    aggiornato, righe positional `<td>`, tollerante a righe malformate).
  - `RFILiveBoardService` (`TrainBoardService`) + `RFILiveMapper` → `StationBoardResponse`
    (`sourceKind = .rfiLive`). Departures only; arrivi e qualsiasi errore →
    **fallback al mock** (obbligatorio).
- Mapping sicuro: binario mancante → `--`, ritardo mancante/"0" → nessun ritardo
  (mai finto), destinazione mancante → `Destinazione non disponibile`,
  cancellato/soppresso → `.cancelled`. Stazione bloccata su Padova.
- Header: `Monitor RFI online` / `RFI online monitor` (+ `· aggiornato HH:mm` se
  disponibile). Nessuna etichetta `Orario programmato` / `demo 06:00–06:59` in live.
- Refresh: solo manuale/path esistente (refresh ogni 30s del board già presente);
  nessun polling aggressivo/background/notifiche/Live Activities.
- Fixture `Binario1Tests/Fixtures/rfi-padova-departures.sample.html` + test unitari
  (URL, stazione `PADOVA`, aggiornato, ≥3 righe, numero/destinazione/ora/binario,
  ritardo non finto, mapper valido, cancellato, HTML vuoto sicuro, fallback al
  mock). I test non usano rete.

### Limiti noti
- **HTML RFI non è un contratto stabile**: i selettori del parser sono tarati su
  una fixture rappresentativa e vanno verificati sull'HTML live (obiettivo dello
  spike). Se non combacia → 0 righe → fallback al mock (UI stabile).
- Nessuna garanzia di produzione, nessun multi-stazione, niente arrivi live,
  niente AI/notifiche/Live Activities/persistenza.

### File
- Nuovi: `Services/RFIStationMonitorClient.swift`, `Services/RFIStationMonitorParser.swift`,
  `Services/RFILiveBoardService.swift` (tutti `#if DEBUG`),
  `Binario1Tests/Fixtures/rfi-padova-departures.sample.html`.
- Modificati: `Models/BoardSourceMode.swift`, `Models/StationBoardResponse.swift`
  (`BoardSourceKind`/`sourceKind`), `Binario1App.swift`,
  `ViewModel/StationBoardViewModel.swift`, `Views/StationBoardHeaderView.swift`,
  `Views/StationBoardView.swift`, `Localizable.xcstrings`, `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Parser/mapper verificati su fixture.

## 2026-06-16 — Fix Partenze tab-entry title animation

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Bug
- Tornando su Partenze da un altro tab, il titolo stazione si **bloccava sul primo
  carattere** (es. solo `P` invece di `PADOVA`). Causa: il restart usava
  `.id(token)` (remount) + reveal **per-carattere** con `Task` staggerati; in
  `FlipCharacter.startFlip` la cancellazione durante il delay usciva **senza**
  impostare il glifo finale → i caratteri successivi restavano vuoti.

### Fix (solo lifecycle animazione; stile LED invariato)
- Riscritto `DotMatrixStationTitleView` con un **reveal deterministico**: un solo
  `.task(id:)` (token tab + nome stazione) guida un contatore `revealed`; ogni
  glifo si accende con un leggero flip 3D (asse `(x:0, y:1, z:0)`) quando il
  contatore lo supera. Il loop **finisce sempre** a `totalReal` e imposta il titolo
  pieno anche se cancellato → **mai parziale**.
- Rimosso `.id(token)` dal titolo in `StationBoardHeaderView`; il token è ora
  passato nel componente. Reduce Motion → titolo pieno immediato.
- Rendering LED invariato (Text ambra + texture punti + glow, font 34/22, colori).
- Nessun reload dati (il token tocca solo il `.task` del titolo); nessuna modifica
  a Viaggi/Cerca, scheduledPadova, righe/lista, ordine tab.

### File
- Riscritto: `Views/DotMatrixStationTitleView.swift`. Modificato:
  `Views/StationBoardHeaderView.swift` (no `.id`, passa token). `Binario1Tests`:
  `stationTitleResolvesToFullName`. `RootTabView`/`StationBoardView` invariati
  (il token già fluisce).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Determinismo del reveal verificato per
  costruzione (final state garantito) + build.

## 2026-06-16 — Viaggi pixel-fidelity polish

Stato: completata. Riferimento: `References/mockup-viaggi.png`. Prossima
milestone: **Smart Suggestions / App Intents**.

### Cosa (solo Viaggi; struttura, dati, Home/Partenze/Cerca invariati)
- **Densità verticale** avvicinata al mockup (lo schermo era troppo arioso):
  spaziatura tra sezioni 18→14, header sezione→contenuto 10→8, gap card salvate
  12→10.
- **Card salvate** più compatte: icona circolare 44→38, padding 14→13, spacing
  interno 13→11, griglia dettagli verticalSpacing 4→3. Gerarchia invariata
  (orario valore più forte, binario bilanciato).
- **Useful card** più densa (resta il centerpiece con bordo/glow ambra): spacing
  interni 12→10, padding 16→14.
- **Filtro** e **quick actions** leggermente più compatti (padding verticale 9→8
  e 11→10).
- Identità LED ambra, transizioni numeriche, orari Recenti su una riga: invariati.

### File
- Modificati: `Views/TripsView.swift`, `Views/SavedJourneyCardView.swift`,
  `Views/UsefulJourneyCardView.swift`, `Views/TripsFilterControl.swift`,
  `Views/TripsQuickActionsView.swift`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Fedeltà rifinita sul mockup in repo;
  niente screenshot perché il simulatore non si avvia in questa sessione.

## 2026-06-16 — Viaggi Visual Fidelity Pass

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo polish visivo Viaggi; struttura/dati invariati)
- Header: titolo LED `VIAGGI` più grande (42), sottotitolo su **una riga**
  (`lineLimit(1)` + scale) così `Aggiornato HH:mm ●` resta allineato.
- Filtro: pill selezionata con glow più pulito (raggio 5→3, opacità 0.5→0.4) e
  controllo leggermente più alto (padding 8→9), meno "over-glow".
- Useful card: destinazione leggermente più prominente (17→18).
- Quick actions: bordo più sottile (0.55) per un look railway-control premium.
- Nessuna nuova feature/colore; mock e Home/Partenze/Cerca invariati.

### File
- Modificati: `Views/TripsHeaderView.swift`, `Views/TripsFilterControl.swift`,
  `Views/UsefulJourneyCardView.swift`, `Views/TripsQuickActionsView.swift`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Nessun mockup Viaggi nel repo + simulatore
  non avviabile → fedeltà rifinita per costruzione sul mockup condiviso, non con
  screenshot.

## 2026-06-15 — Viaggi Numeric Alignment and Animation Polish

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- **Allineamento riga dettaglio card salvate**: la riga `PROSSIMA PARTENZA /
  BINARIO / DURATA / STATO` ora è una `Grid` a 4 colonne: etichette allineate in
  alto, valori allineati sulla stessa baseline (`GridRow(alignment:.firstTextBaseline)`).
  `07:18` resta il valore più grande; il binario è più piccolo (18 vs 22) e non
  domina; `37 min` e `In orario` sono sulla stessa riga visiva.
- **Animazione Partenze al rientro nel tab**: `RootTabView` traccia `selectedTab`
  (`AppTab`) con `TabView(selection:)` + `Tab(value:)`; al rientro su `.departures`
  incrementa `departuresAnimationToken`, passato a `StationBoardView` →
  `StationBoardHeaderView`, che applica `.id(token)` **solo al titolo** (non al
  board) per rieseguire il reveal. **Nessun reload dati** (la `.task` dipende da
  `boardType`, non dal token), scroll non resettato. **Reduce Motion**: `.id`
  costante → nessun restart/motion.
- **Transizioni numeriche testabili (DEBUG)**: nuova `NumericTransitionPreviewView`
  (solo `#if DEBUG`, non in produzione) con valori campione (time 07:18→07:22,
  platform 2→4→6, duration 37→42→51, delay 0→12→35) e bottone *Test numeric
  animation* che aggiorna i valori in `withAnimation(.snappy)` → i numeri rollano.
- Transizioni numeriche confermate solo su valori numerici dinamici (orari,
  binari, durata, ritardo); nomi/categorie/titolo restano statici. Reduce Motion
  rispettato ovunque.

### File
- Modificati: `Views/SavedJourneyCardView.swift` (Grid + baseline),
  `Views/StationBoardHeaderView.swift` + `Views/StationBoardView.swift`
  (`animationToken`), `Views/RootTabView.swift` (`AppTab` + selection + token).
- Nuovo (DEBUG): `Views/NumericTransitionPreviewView.swift`.
- `Binario1Tests`: stringhe display Viaggi corrette (time/binario/durata/ritardo).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice). Allineamento e no-wrap
  verificati a livello di layout (Grid + baseline, monospaced, lineLimit) e build.

## 2026-06-15 — Viaggi Numeric Text Polish

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- **Fix wrapping orari `Recenti`**: gli orari (`08:32`, `09:15`, `07:50`) andavano
  a capo (`08:3` / `2`) perché `LEDText` (dot) in una colonna stretta (52pt) si
  spezzava. Ora gli orari delle righe compatte usano `BoardNumberText` (Text
  affidabile, `monospacedDigit` + `lineLimit(1)` + `minimumScaleFactor`, colonna
  fissa 56pt, glow) → **sempre una riga**.
- **Helper numerico riusabile** (`Views/BoardNumberText.swift`):
  - `BoardNumber.value(from:)` — chiave roll dai digit di una stringa.
  - `BoardNumberText` — label numerica affidabile a una riga con transizione.
  - `.boardNumericTransition(_/value:)` — aggiunge `.contentTransition(.numericText(value:))`
    a un Text numerico esistente.
  - `LEDText.animatesNumeric` — transizione opzionale sui numeri LED (titolo
    `VIAGGI` resta statico).
  - Tutto **no-op con Reduce Motion** (valore finale senza rolling).
- **Applicato ai numeri Viaggi**: orari/binari/durata/ritardo (saved, useful,
  recent). Il **numero treno resta statico** (categoria+numero non è puro numerico).
  Dati mock statici → nessun roll ora; pronto per dati dinamici futuri.
- **Home/Partenze invariata**: l'helper è scoped a Viaggi (`PlatformBadgeView`/
  `DelayBadgeView`/righe board non toccati); estensione futura documentata.

### File
- Nuovo: `Views/BoardNumberText.swift`. Modificati: `Views/LEDText.swift`
  (`animatesNumeric` + `lineLimit(1)`), `Views/RecentJourneyRowView.swift`,
  `Views/SavedJourneyCardView.swift`, `Views/UsefulJourneyCardView.swift`,
  `Views/JourneyPlatformBadgeView.swift`, `Views/JourneyStatusBadgeView.swift`,
  `Binario1Tests` (chiave numerica + formato orari recenti).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice). Wrapping verificato a livello
  di layout (colonna fissa + monospaced + lineLimit) e build.

## 2026-06-15 — Restore approved Home LED title

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo area titolo Home)
- Ripristinata l'**animazione** del titolo stazione LED/dot-matrix già approvato
  (`DotMatrixStationTitleView`, flip 3D per carattere, asse `(x:0, y:1, z:0)`,
  stagger per indice, rispetta Reduce Motion).
- **Causa della regressione**: il renderer non era cambiato (è quello approvato:
  `Text` affidabile + griglia di punti LED mascherata + glow), ma il flip partiva
  solo `onChange` della stazione; con `.scheduledPadova` la stazione è bloccata su
  Padova → il flip non scattava mai → titolo "statico".
- **Fix**: il flip approvato ora parte anche come **reveal alla prima comparsa**
  (`onAppear`), riusando lo stesso meccanismo `startFlip` — nessun renderer nuovo,
  nessuna variante. Padova "accende" i caratteri a cascata; in mock il flip al
  cambio stazione resta.
- Nessuna modifica a: righe board, `.scheduledPadova`, label
  `Orario programmato · demo 06:00–06:59`, segmented Partenze/Arrivi, ticker,
  Viaggi, Cerca, navigazione.

### File
- Modificato: `Views/DotMatrixStationTitleView.swift` (solo `FlipCharacter.onAppear`).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Native Search Tab

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- Il terzo tab primario passa da **Info** a **Cerca**, usando il ruolo nativo
  SwiftUI `Tab(role: .search)`. Nuovo ordine tab: **Partenze · Viaggi · Cerca**.
- Nuova `CercaView` con `.searchable` nativo (dentro `NavigationStack`): da inattiva
  mostra tre voci categoria (Cerca stazione / tratta / treno); durante la ricerca
  mostra risultati **mock** raggruppati in Stazioni / Tratte / Treni, oppure
  `Nessun risultato`. `CercaViewModel` (`@Observable`) filtra un catalogo mock
  (case-insensitive). **Solo mock**: niente API, AI, notifiche, persistenza.
- `InfoView` **non rimossa**: resta nel codice per una futura area secondaria
  settings/about (non è più un tab primario).
- Localizzazione IT/EN: `tab.search`, `search.station/route/train`,
  `search.stations/routes/trains`, `search.noResults`, `search.prompt`.
- Partenze e Viaggi invariati.

### File
- Nuovi: `Views/CercaView.swift`, `ViewModel/CercaViewModel.swift`.
- Modificati: `Views/RootTabView.swift` (Info → Cerca `.search`),
  `Localizable.xcstrings`, `Binario1Tests` (filtro ricerca).
- `Views/InfoView.swift`: invariata, non più referenziata come tab.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Viaggi Visual Fidelity Pass

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo UI Viaggi; Home/Partenze invariata)
- Refinement pixel-oriented del tab Viaggi sul mockup di riferimento. Dati e
  architettura invariati.
- **Header**: brand `Binario [1]` (cifra in box), titolo LED dot-matrix `VIAGGI`
  (nuovo primitivo riusabile `LEDText`), sottotitolo, **bottone cerca circolare**
  (placeholder, no logica Search) e `Aggiornato HH:mm ●` (mostrato solo dopo il
  caricamento).
- **Filtro**: pill selezionata con gradiente ambra brillante + testo scuro + glow,
  transizione animata (`matchedGeometryEffect`).
- **Ordine sezioni** allineato al mockup: Tratte salvate → Prossimo viaggio utile
  → Recenti → azioni rapide.
- **Card salvate**: icona circolare casa/lavoro, stella, titolo + rotta board
  UPPERCASE abbreviata, griglia a 4 colonne allineate (Partenza/Binario/Durata/
  Stato). **Stato**: pallino verde + `In orario` / pallino rosso + badge `+12 min`.
- **Prossimo viaggio utile**: orario LED grande + destinazione + `da ORIGINE`,
  griglia Durata/Treno/Arrivo con separatori, **binario LED grande** a destra,
  barra inferiore con pallino verde `In orario` + icona treno; bordo ambra bright.
- **Recenti**: righe compatte (ora LED, rotta board, `CAT NUM · durata`, binario,
  chevron) con `Vedi tutti ›` azionabile nell'header sezione.
- **Azioni rapide**: pill compatte orizzontali (icona + testo).
- **Tab bar**: icone tram/suitcase/info, aspetto scuro opaco + tint ambra.
- Nuovo colore `BoardColors.statusGreen` per lo stato "in orario".

### Verifica / fix
- Review multi-agente di fedeltà al mockup; applicati fix: stringhe `min`/`+N min`
  localizzate (`journey.duration.value`, `status.delay.short`), `Vedi tutti`
  azionabile + chevron + VoiceOver, header timestamp non finto, allineamento
  colonne, highlight bright sulla card centrale.

### File
- Nuovi: `Views/LEDText.swift`. Modificati: `Views/TripsHeaderView`,
  `TripsFilterControl`, `SavedJourneyCardView`, `UsefulJourneyCardView`,
  `RecentJourneyRowView`, `TripsQuickActionsView`, `JourneyStatusBadgeView`,
  `JourneyPlatformBadgeView`, `TripsView`, `RootTabView`,
  `NextDeparturesSectionView` (`BoardSectionHeader` + `trailingAction`, additivo),
  `Models/JourneyDisplayData` (rotta board), `ViewModel/TripsViewModel`
  (`lastUpdated`), `DesignSystem/BoardTheme` (verde), `Localizable.xcstrings`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Viaggi Tab MVP

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents** (Viaggi
diventa la base per suggerimenti, App Intents e notifiche — non in questo MVP).

### Cosa
- Secondo tab **Viaggi** (dashboard commuter personale), accanto a **Partenze** e
  **Info**. Navigazione root a 3 tab (`RootTabView`, `TabView` con `Tab`), Viaggi
  in seconda posizione. Niente `Tab(role: .search)` (Search è milestone futura).
- `TripsView` data-driven: header (BINARIO1 / VIAGGI / sottotitolo + `+`), filtro
  segmentato (Oggi / Salvati / Recenti), sezione **Tratte salvate** (2 card),
  **Prossimo viaggio utile** (card centrale, binario molto leggibile), **Recenti**
  (3 righe compatte), e 3 **azioni rapide** placeholder (Nuovo viaggio / Segui
  treno / Avvisi).
- **Solo dati mock** (`MockTripsService`): nessuna API, nessuna persistenza,
  nessun dato live. Orari ancorati al giorno corrente (Europe/Rome).
- Riuso del design system esistente (`BoardColors`/`BoardFont`/`.ledGlow`,
  `PlatformBadgeView`, `BoardSectionHeader`, `BoardBackgroundView`, formatter):
  nessuna duplicazione di costanti di stile.
- Accessibilità: label VoiceOver complete per card salvate, card utile e righe
  recenti (nome stazione completo, orari, binario, durata, stato).
- Localizzazione IT/EN completa (tab, header, filtri, sezioni, azioni, label
  viaggio, accessibilità).

### File
- Nuovi modelli: `Models/Journey.swift` (`SavedJourney`, `SuggestedJourney`,
  `RecentJourney`, `JourneyStatus`, `JourneyDirection`, `TripsFilter`, `TripsData`),
  `Models/JourneyDisplayData.swift`.
- Nuovo service: `Services/TripsService.swift` (`TripsService`, `MockTripsService`).
- Nuovo view model: `ViewModel/TripsViewModel.swift` (`@Observable`).
- Nuove view: `Views/TripsView.swift`, `TripsHeaderView`, `TripsFilterControl`,
  `SavedJourneyCardView`, `UsefulJourneyCardView`, `RecentJourneyRowView`,
  `TripsQuickActionsView`, `JourneyStatusBadgeView`, `JourneyPlatformBadgeView`,
  `RootTabView`, `InfoView`.
- Modificati: `Binario1App.swift` (root → `RootTabView`),
  `Views/NextDeparturesSectionView.swift` (`BoardSectionHeader` + `trailingKey`
  opzionale, additivo), `Localizable.xcstrings`, `Binario1Tests`.
- Home / Partenze: **nessuna regressione** (solo aggiunta opzionale additiva al
  componente condiviso `BoardSectionHeader`).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata
  dall'instabilità CoreSimulator in questa sessione (problema d'ambiente, non di
  codice); i nuovi test Trips sono deterministici (clock fisso Europe/Rome).

## 2026-06-15 — Scheduled Demo Time-Window Fix

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

- **Causa**: il demo `.scheduledPadova` carica il sample bundled
  `scheduled-padova-0600.sample.json` (fascia **06:00–06:59**). Alle 17:40
  mostrava comunque le partenze del mattino ed **evidenziava** Bassano del Grappa
  06:14 come "prossima partenza" → dato programmato presentato come corrente/live.
- **Fix** (solo dati scheduled/sample; `.mock` invariato):
  - Il sample espone metadati di finestra: `boardType`, `scheduledWindowStart`
    `06:00`, `scheduledWindowEnd` `06:59`, `sourceKind` `scheduledSample`
    → `StationBoardResponse.scheduledWindow` (`ScheduledSampleWindow`).
  - Header: `Orario programmato · demo 06:00–06:59` /
    `Scheduled timetable · demo 06:00–06:59` (nessun pallino live).
  - **Nessun highlight "prossima/corrente"** quando l'ora locale è fuori dalla
    finestra del sample: `imminentRowID == nil`; la sezione diventa
    `Partenze programmate` / `Programmed departures` (righe comunque mostrate).
  - **Niente rollover a domani**: le righe del mattino restano sul giorno di
    riferimento (nessuna inferenza "domani" senza service-date esplicita).
  - Invariati: stazione bloccata su Padova, `Cambia` disabilitato, nessun ritardo
    finto (`delayMinutes`/`actualPlatform`/`expectedTime` nil, `status .scheduled`).
  - `now` iniettabile nel view model per test deterministici della finestra.
- File: `Mock/scheduled-padova-0600.sample.json` (+ mirror `mock/`),
  `Services/ScheduledTrainBoardService.swift` (DTO + `sampleWindow`),
  `Models/StationBoardResponse.swift` (`ScheduledSampleWindow`),
  `ViewModel/StationBoardViewModel.swift`, `Views/StationBoardHeaderView.swift`,
  `Views/StationBoardView.swift`, `Views/NextDeparturesSectionView.swift`,
  `Localizable.xcstrings`, `Binario1Tests`.

## 2026-06-15 — Scheduled Padova = DEBUG-only Demo Mode

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

- `AppEnvironment.sourceMode` ora risolto per build:
  **DEBUG → `.scheduledPadova`** (demo orario programmato Padova),
  **RELEASE → `.mock`** (board Bologna mock). La sorgente demo non può così
  diventare il default di produzione.
- `.scheduledPadova` resta **solo orario programmato RFI "Quadro Orario", NON
  dati live**: niente ritardi/cancellazioni/cambi binario real-time; non va
  presentato come dato in tempo reale. Comportamento invariato: stazione bloccata
  su Padova, `Cambia` disabilitato/dimmato, `Orario programmato` / `Scheduled
  timetable`, nessun ritardo finto, nessun pallino "live".
- `.mock` invariato: carosello stazioni attivo, righe mock, nessun label
  scheduled (a meno che il mock non sia esplicitamente scheduled).
- File: `Binario1App.swift` (blocco `#if DEBUG`), `Binario1Tests` (test
  `sourceModeMatchesBuildConfiguration`). UI/layout, dati mock e sample scheduled
  invariati.

## 2026-06-15 — Padova Scheduled Timetable Spike

Stato: completata (spike). Prossima milestone: **Viaggi Tab MVP**.

### Cosa
- Sorgente **orario programmato** RFI "Quadro Orario" per **Padova** (RFI id
  `1861`), **solo partenze**, range `06.00–06.59`. **Solo dati programmati**:
  niente ritardi live, cancellazioni o cambi binario real-time.
- Architettura service-layer (nessun parsing nelle view):
  - `TrainBoardService` resta l'astrazione app-facing; `MockTrainBoardService` resta.
  - Nuovo `ScheduledTrainBoardService` con `ScheduledTimetableProvider`
    (default `BundledScheduledTimetableProvider` che decodifica un sample del
    Quadro Orario parsato) + `ScheduledTimetableMapper` → `StationBoardResponse`/
    `TrainBoardRow`. Un adapter RFI HTTP+HTML reale potrà sostituire il provider.
  - **Fallback al mock obbligatorio** su fetch/parse fallito o parse vuoto;
    arrivi → fallback (lo spike è solo partenze).
- Mapping: `scheduledTime` da orario programmato, `plannedPlatform` =
  binario programmato, `actualPlatform`/`delayMinutes`/`expectedTime` = nil,
  `status = .scheduled`, categoria inferita (REG/RV/FR/IC/ITA… altrimenti
  `UNKNOWN`), note = periodicità/avvisi. **Nessun ritardo finto.**
- UI: nessun redesign. La colonna ritardo resta vuota per le righe scheduled
  (il badge appare solo per delayed/cancelled). Header mostra
  `Orario programmato` / `Scheduled timetable` al posto di "Aggiornato ●".
- Config sorgente: `AppEnvironment.sourceMode` (`.mock` default,
  `.scheduledPadova`, `.remoteWithMockFallback`). Reversibile.
- **Coerenza single-station**: in `.scheduledPadova` la selezione stazione è
  **bloccata su Padova**. `Cambia` resta visibile ma **disabilitato** (icona
  lucchetto, dimmato, hint VoiceOver `accessibility.stationLocked`) e
  `StationBoardViewModel.changeStation()` è un **no-op** quando bloccato → titolo
  (`PADOVA`) e righe non possono mai divergere. In `.mock` il cambio stazione
  resta attivo (carosello demo). Governato da `AppEnvironment.allowsStationChange`.

### File
- Nuovi: `Models/BoardSourceMode.swift`, `Services/ScheduledTrainBoardService.swift`,
  `Mock/scheduled-padova-0600.sample.json`
- Modificati: `Models/StationBoardResponse.swift` (+`isScheduled`),
  `Models/Station.swift` (+`padova`), `Binario1App.swift` (source mode),
  `ViewModel/StationBoardViewModel.swift` (+`isScheduled`),
  `Views/StationBoardHeaderView.swift` + `StationBoardView.swift` (label),
  `Localizable.xcstrings` (`source.scheduled`), `Binario1Tests`.

### Limiti noti (spike)
- Solo Padova `1861`, solo partenze, una fascia oraria; provider = sample
  bundled (l'HTML scraping RFI reale è lavoro successivo). Nessun layer real-time.
- (Risolto) Il mismatch titolo/dati in `.scheduledPadova` — `Cambia` ora è
  bloccato su Padova (vedi "Coerenza single-station" sopra).

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde (inclusi i nuovi test scheduled).

## 2026-06-15 — Station Title Character Flip Polish

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

### Cambiato (solo titolo stazione)
- Mantenuto il titolo `Text`-based affidabile (sempre visibile, ambra + glow +
  texture punti additiva), ora reso **carattere-per-carattere**.
- Aggiunto un **flip 3D orizzontale leggero** al cambio stazione:
  `rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))`, stagger per
  indice `Double(index) * 0.1`, riga 2 dopo riga 1. Il vecchio glifo ruota
  edge-on, swap nascosto, il nuovo rientra (niente mirror, ghosting o titolo
  vuoto). **Reduce Motion → aggiornamento istantaneo, nessun flip.**
- Slot fissi (primario 9, secondario 12) riempiti con spazi → identità cella
  stabile per flip puliti; spazi = invisibili (nessun box). Tap ripetuti su
  `Cambia` coalescati (task per carattere, cancellabile).
- Niente FlipBoard/split-flap/Canvas-base/scan/auto-cycle.

### File
- Riscritto: `Views/DotMatrixStationTitleView.swift` (aggiunti `FlipLine` e
  `FlipCharacter` privati). Header e resto Home invariati.

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Nota: simulatore della sandbox instabile (screenshot/launch in crash); il
  titolo è `Text` puro → visibile per costruzione.

## 2026-06-15 — Station Title Visibility Fix

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

### Problema
- Dopo il revert al titolo statico, `BOLOGNA`/`CENTRALE` risultavano **invisibili**
  (header mostrava STAZIONE DI / Aggiornato / Cambia ma niente titolo).
- Causa: il renderer `StaticDotMatrixText` (ImageRenderer→sample→Canvas) non
  produceva punti sul device (array `dots` vuoto) mentre il `Text` nascosto di
  sizing riservava lo spazio → gap vuoto senza glifi.

### Fix
- Sostituito con un titolo **basato su `Text`** affidabile (sempre visibile):
  glifi ambra grassetto monospaced + glow leggero; texture a punti LED come
  overlay mascherato **puramente additivo** (se non disegna, il testo resta
  visibile). Nessuna animazione, niente FlipBoard/split-flap/scan.
- `StationNameFormatter` per le righe; nome completo nelle accessibility label;
  aggiornamento istantaneo al cambio stazione; nessun clipping.

### File
- Riscritto: `Views/DotMatrixStationTitleView.swift` (titolo `Text` affidabile)
- Rimosso: `Views/StaticDotMatrixText.swift` (renderer fragile che poteva sparire)
- Header e resto Home/Partenze invariati.

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Nota: il simulatore in questa sandbox è instabile (install/launch/screenshot in
  crash), quindi screenshot non catturabile qui; il titolo è però `Text` puro
  (foreground ambra opaco, frame non nullo) → non può risultare invisibile.

## 2026-06-15 — Static Station Title Revert

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

### Cambiato
- **FlipBoard title rifiutato** visivamente (celle meccaniche troppo "finte").
- Ripristinato un **titolo stazione dot-matrix statico** (LED ferroviario
  luminoso): due righe ambra, glow leggero, texture a punti, **nessuna
  animazione** (no flip, no scan, no celle/box per carattere).
- Aggiornamento del nome stazione **istantaneo** al cambio (nessun overlap
  vecchio/nuovo, nessun ghosting). Nessuna gestione speciale Reduce Motion
  (non c'è animazione).
- `StationNameFormatter` per i nomi: `BOLOGNA/CENTRALE`, `FIRENZE/S.M.N.`,
  `MILANO/P. GARIBALDI`, `REGGIO E./AV MEDIOP.`. Overscan verticale nel renderer
  → seconda riga mai tagliata. Accessibility = nome completo.

### File
- Nuovi: `Views/StaticDotMatrixText.swift`, `Views/DotMatrixStationTitleView.swift`
- Rimossi: `Views/FlipBoardCharacterCell.swift`, `Views/FlipBoardLineView.swift`,
  `Views/FlipBoardTitleView.swift`
- Modificato: `Views/StationBoardHeaderView.swift` (usa il titolo statico)
- Resto Home/Partenze invariato. Nessun residuo di animazione titolo / auto-cycle.

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Nota: il simulatore è risultato instabile in questa sessione (screenshot/launch
  in crash a intermittenza); il renderer statico è identico (tecnica
  rasterize+sample+dot a gradiente + overscan) a quello già verificato visivamente
  nei pass precedenti, senza l'animazione.

## 2026-06-15 — FlipBoard Title Experiment

Stato: **accettato** (chiaramente migliore). Branch `experiment/flipnumber-title-v2`.
Prossima milestone: **Viaggi Tab MVP**.

### Risultato
- Sostituito il titolo split-flap con un **flip board a slot fissi sempre
  visibili** (ispirato a FlipNumberView, scritto nativamente; nessun codice
  esterno/GPL copiato).
- Fix del problema chiave: i box cella ora esistono per l'intera larghezza riga
  e restano visibili anche **vuoti** (slot scuri da tabellone). Prima i box
  comparivano solo sui caratteri presenti → effetto finto. Es:
  `BOLOGNA _ _` con celle vuote visibili.
- Animazione FlipNumber-style: la cella (box + piega + bevel) resta ferma e
  visibile; **solo il glifo** fa il flip (leaf superiore vecchia si ripiega,
  leaf inferiore nuova scende). Niente ghosting, niente frame vuoti; stagger per
  indice, riga 2 dopo riga 1. Reduce Motion → swap diretto. Tap ripetuti
  coalescati (task per cella).
- Slot fissi: primario 9, secondario 12 (costanti, allineati, dimensionati per
  stare accanto a `Cambia`). Nomi lunghi via `StationNameFormatter`. Seconda riga
  mai tagliata.

### File
- Nuovi: `Views/FlipBoardCharacterCell.swift`, `Views/FlipBoardLineView.swift`,
  `Views/FlipBoardTitleView.swift`
- Rimossi: `Views/SplitFlapCharacterCell.swift`, `Views/SplitFlapLineView.swift`,
  `Views/SplitFlapBoardTitleView.swift` (sostituiti)
- Modificato: `Views/StationBoardHeaderView.swift` (usa il flip board)
- Resto Home/Partenze invariato.

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Verificato: celle vuote sempre visibili, nomi corti senza box mancanti, nomi
  lunghi allineati, nessun clipping riga 2, flip pulito (BOLOGNA→FIRENZE→MILANO
  senza ghosting/blank), resto schermo invariato.

## 2026-06-15 — Split-Flap Station Title

Stato: completata. Prossima milestone: **Viaggi Tab MVP**.

### Cambiato
- Titolo stazione passato da LED dot-matrix a **board split-flap** in stile
  tabellone ferroviario/aeroportuale anni '90: celle scure a larghezza fissa,
  piega centrale, testo ambra grassetto, flip meccanico carattere-per-carattere.
- Solo l'area titolo/sottotitolo è cambiata; resto della Home (header, segmented,
  prossime partenze, lista, badge, ticker, palette ambra/nero) invariato.
- Transizione cambio stazione **guidata per cella**: ogni cella è una piccola
  macchina a stati (idle → flip edge-on → swap → settle), con delay per indice;
  la riga secondaria parte dopo la primaria. Nessun overlap vecchio/nuovo, nessun
  frame vuoto, tap ripetuti su `Cambia` coalescati (cancel del task per cella).
- Reduce Motion: nessun flip, aggiornamento diretto al titolo finale.
- Nomi lunghi via `StationNameFormatter` in slot fissi (primario 9, secondario
  12) → sempre allineati: `BOLOGNA/CENTRALE`, `FIRENZE/S.M.N.`,
  `MILANO/P. GARIBALDI`, `REGGIO E./AV MEDIOP.`. Nessun clipping seconda riga.

### File
- Nuovi: `Views/SplitFlapCharacterCell.swift`, `Views/SplitFlapLineView.swift`,
  `Views/SplitFlapBoardTitleView.swift`
- Rimossi: `Views/AnimatedDotMatrixText.swift`, `Views/StationTitleLEDView.swift`,
  `Views/DotMatrixCharacterFlipText.swift` (renderer LED del titolo, non più usati)
- Modificato: `Views/StationBoardHeaderView.swift` (usa il titolo split-flap)

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Verificato: flip pulito (BOLOGNA→FIRENZE→… senza ghosting/overlap/blank),
  seconda riga non tagliata, nomi lunghi allineati, resto schermo invariato.

## 2026-06-15 — Station Title Animation Bugfix

Stato: completata. Prossima milestone: **Viaggi Tab**.

### Risolto
- **Glitch al cambio stazione**: il titolo LED ora usa una macchina a stati
  esplicita e cancellabile (`steady → out → flipping → settling → steady`) in
  `StationTitleLEDView`. Vecchio e nuovo titolo LED non si sovrappongono mai;
  flip e LED finale non sono mai entrambi a piena opacità (crossfade solo in
  `settling`). Niente ghosting/smear/frame vuoti.
- **Stato stale**: ogni stazione monta renderer freschi via `.id(displayed)`
  (nessun riuso di TimelineView/Canvas/ImageRenderer).
- **Tap ripetuti**: la transizione precedente viene cancellata e coalescata;
  lo stato finale torna sempre a `steady`.
- **Clipping seconda riga** (`CENTRALE`, `S.M.N.`, `AV MEDIOP.`): overscan
  verticale ampliato nel renderer (`AnimatedDotMatrixText`, include alone+glow);
  flip ridotto a tilt sobrio `(x:1,y:1,z:0)` 90°→0 (non più 180° somersault) per
  non proiettare oltre il frame. Nessun `.clipped()` sul titolo.

### File toccati
- `Views/StationTitleLEDView.swift` (macchina a stati)
- `Views/AnimatedDotMatrixText.swift` (overscan)
- `Views/DotMatrixCharacterFlipText.swift` (flip sobrio (1,1,0))
- `Views/StationBoardView.swift` (rimosso probe temporaneo)

### Build / test
- Build: OK. Unit test (`Binario1Tests`): verde.
- Verificato: cambio stazione pulito (BOLOGNA→FIRENZE senza ghosting),
  `S.M.N.` non tagliato, Reduce Motion, nessun auto-cycle di debug.

## 2026-06-15 — Home Screen Stabilization

Stato: completata. Prossima milestone: **Viaggi Tab**.

### Completato
- Header ridisegnato: rimosso il brand `Binario1` (confondibile col binario);
  ora `STAZIONE DI` + titolo LED `BOLOGNA` / `CENTRALE`, azione `Cambia`
  (cambio stazione), stella preferiti e `Aggiornato HH:mm` con LED di stato.
- Fix clipping di `CENTRALE`: overscan verticale nel renderer dot-matrix
  (`AnimatedDotMatrixText`), nessun alone LED tagliato.
- Transizione flip 3D carattere-per-carattere al cambio stazione
  (`DotMatrixCharacterFlipText` / `StationTitleLEDView`): BOLOGNA poi CENTRALE,
  poi ritorno al titolo LED. Rispetta Reduce Motion (crossfade).
- Robustezza testi lunghi: `StationNameFormatter` / `BoardDestinationFormatter`,
  colonne a larghezza fissa con destinazione flessibile; binario sempre visibile,
  nomi completi preservati nelle accessibility label.
- Carosello stazioni mock per testare nomi lunghi (Firenze S.M.N., Milano P.
  Garibaldi, Venezia S. Lucia, Reggio Emilia AV Mediopadana).

### File principali toccati
- `Views/StationBoardHeaderView.swift`, `Views/StationTitleLEDView.swift`
- `Views/AnimatedDotMatrixText.swift`, `Views/DotMatrixCharacterFlipText.swift` (nuovo)
- `Localization/BoardTextFitting.swift` (nuovo), `Models/Station.swift`
- `ViewModel/StationBoardViewModel.swift`, `Views/StationBoardView.swift`
- `Views/FeaturedTrainRowView.swift`, `Views/TrainBoardRowView.swift`
- `Localizable.xcstrings` (chiavi: header.stationContext, action.changeStation.short,
  accessibility.changeStation)

### Build / test
- Build: OK (nessun warning nelle view).
- Unit test (`Binario1Tests`): verde.
- Verificato IT/EN, Reduce Motion, nomi lunghi, `CENTRALE` non tagliato.

### Prossimo
- **Viaggi Tab** (non iniziare finché la home non è stabilizzata).
