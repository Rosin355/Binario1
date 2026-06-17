# 12 — Decisions

Decisioni di prodotto/architettura non deducibili dal codice. Tenere conciso.

## Home screen

- **Brand `Binario1` rimosso dall'header**: si confondeva col numero di binario.
  L'header usa un contesto stazione: `STAZIONE DI` (IT) / `STATION` (EN).
- **Titolo stazione = LED/dot-matrix ANIMATO approvato** (`DotMatrixStationTitleView`):
  base `Text` sempre visibile + griglia di punti LED mascherata (additiva) + glow,
  stile LED ferroviario luminoso. **Animazione = flip 3D per carattere** (asse
  `(x:0, y:1, z:0)`, stagger `index*0.1`), eseguita sia come **reveal alla prima
  comparsa** sia al cambio stazione; Reduce Motion → aggiornamento istantaneo.
  - Glifi a punti LED (no box/celle per carattere); nome completo nelle
    accessibility label; resto della Home invariato.
  - Supera/scarta gli esperimenti rifiutati (split-flap, FlipBoard a celle,
    renderer Canvas/sampling che poteva risultare invisibile).
  - **Evitare regressioni nell'area header/titolo** quando si implementano
    feature non correlate: in `.scheduledPadova` la stazione è bloccata, quindi
    il flip deve comunque animarsi via reveal (il titolo non deve restare statico).
- **Affidabilità del renderer del titolo**: il titolo DEVE usare un'implementazione
  `Text`/SwiftUI sempre visibile come base, non un renderer complesso
  (ImageRenderer/Canvas/sampling) che può risultare vuoto/invisibile. Eventuale
  texture LED solo come overlay additivo e fail-safe sopra il testo.
- **Flip carattere consentito solo come transizione leggera**: al cambio
  stazione, flip 3D per carattere su base `Text` con asse `(x:0, y:1, z:0)` e
  stagger `index * 0.1`. Niente sistema a celle meccaniche/FlipBoard/split-flap,
  niente renderer complesso. Reduce Motion → aggiornamento istantaneo. Lo stato
  finale resta il titolo `Text` stabile e visibile.
  - Storico esperimenti (tutti rifiutati/superati): LED dot-matrix animato
    (scan+flip 3D) → split-flap → FlipBoard a slot fissi.
- **Flip 3D carattere-per-carattere solo come transizione** di cambio
  stazione / reveal, non come renderer permanente. Asse `(1,1,0)`, tilt sobrio
  90°→0; rispetta Reduce Motion (salta il flip). Stato finale = titolo LED.
- **Transizione titolo = macchina a stati esplicita** (`steady → out →
  flipping → settling → steady`) in un `Task` cancellabile: evita overlap
  vecchio/nuovo renderer LED e flip/LED simultanei, rende il cambio
  deterministico, coalesce i tap ripetuti e torna sempre a `steady`. Ogni
  stazione usa `.id(displayed)` per renderer freschi (no stato stale).
- **Righe board compatte = colonne a larghezza fissa + destinazione flessibile**:
  ora / categoria / numero / [destinazione flex] / ritardo / binario. Ora,
  ritardo e binario sempre allineati; il binario non esce mai dalla vista; la
  destinazione tronca con ellissi se serve.
- **Nomi stazione completi sempre disponibili** nel data model e nelle
  accessibility label; l'abbreviazione (`StationNameFormatter` /
  `BoardDestinationFormatter`) è solo per il display compatto del tabellone.
- **Carosello stazioni mock** dietro `Cambia`: solo per demo/test layout nomi
  lunghi; i dati del tabellone restano mock.

## Viaggi (Trips)

- **`Viaggi` è una dashboard commuter personale, NON un secondo tabellone**:
  risponde a "cosa conta per me come pendolare?" (tratte salvate, prossimo viaggio
  utile, recenti) — non a "cosa succede in stazione?". Più card-based della Home,
  ma stessa identità Binario1 (nero, ambra, texture/glow, badge binario/stato
  riusati).
- **Solo dati mock in questa milestone**: nessuna API, nessuna persistenza,
  nessun dato live. `TripsService`/`MockTripsService` dietro protocollo per
  sostituzione futura; formatting/accessibilità nel display layer
  (`JourneyDisplayData`), fuori dalle view.
- **Niente AI, notifiche, Live Activities, pagamenti o API reali** ora. `Viaggi`
  sarà la base per smart suggestions, App Intents e flussi di notifica in futuro.
- **Navigazione a 3 tab** (Partenze / Viaggi / Info), Viaggi secondo. Search
  rinviata (no `Tab(role: .search)` ora).
- **Riuso del design system**: `BoardSectionHeader` esteso in modo additivo
  (`trailingKey` opzionale per "Vedi tutti") invece di duplicare lo stile.

## Navigazione (tab)

- **Tre tab primari: Partenze · Viaggi · Cerca.** Il terzo tab è **Cerca**
  (ricerca), non Info, e usa il ruolo nativo `Tab(role: .search)`.
- **La ricerca è primaria** perché gli utenti spesso iniziano cercando una
  stazione, una tratta o un treno: merita un punto d'accesso di primo livello.
- **Info/About diventerà un'area secondaria** (settings/info) più avanti;
  `InfoView` resta nel codice ma non è più un tab primario.
- **Cerca è mock-only** in questa fase (catalogo locale, nessuna API/AI).
- **L'animazione intro di Partenze riparte al rientro nel tab**: `RootTabView`
  traccia il tab e incrementa un token su `.departures`; il token applica `.id`
  **solo al titolo** per rieseguire il reveal. NON ricaricare dati né resettare lo
  scroll; sotto Reduce Motion il restart è disattivato.

## Numeri dinamici (board)

- **I valori numerici dinamici usano `.contentTransition(.numericText(value:))`**
  (helper `BoardNumberText` / `.boardNumericTransition` / `LEDText.animatesNumeric`);
  il roll è **no-op con Reduce Motion**. Applicato ai numeri Viaggi (orari, binari,
  durata, ritardo).
- **Mai sui nomi/label non numeriche**: niente transizione numerica su nomi
  stazione/tratta, destinazioni, categorie treno (REG/RV/FR/ICN), titolo LED o
  label statiche.
- **Orari delle righe compatte sempre su una riga**: Text affidabile con
  `monospacedDigit` + `lineLimit(1)` + colonna a larghezza fissa (non il
  dot-renderer `LEDText`, che in colonne strette può andare a capo).
- Estensione futura ai numeri condivisi Home/Partenze (`PlatformBadgeView`,
  `DelayBadgeView`, orario riga) solo se non introduce regressioni di layout.

## Backend adapter — Phase 2B (iOS remote fetcher)

- **iOS consuma il JSON del backend tramite `BackendBoardService` + fetcher di rete**
  (`URLSessionBackendBoardFetcher`): l'app parla con l'adapter backend, **mai con RFI
  diretto** in questa modalità.
- **L'adapter RFI diretto resta emergency DEBUG-only** (`.rfiLivePadova`), fallback
  per sviluppo.
- **Backend live è validazione DEBUG** finché affidabilità / rate-limit / auth non
  sono irrobustiti; su errore o URL non configurato → fallback alla fixture, non
  silenzioso (log `[BackendLive] FALLBACK …`). Release resta `.mock`.
- **URL endpoint centralizzato** in `BackendEndpointConfig` (project-ref non è un
  secret); nessuna anon/service_role key nel repo.

## Backend adapter — Phase 2A (Supabase Edge Function `board`)

- **Il backend possiede il parsing/normalizzazione della sorgente**: la Edge Function
  `board` fa fetch dell'HTML RFI pubblico e restituisce JSON normalizzato compatibile
  con `BackendBoardDTO`; l'app non fa parsing di sorgenti in produzione.
- **Niente secret nel repo**: nessuna anon key, nessuna service_role, nessun `.env`
  reale; la function non accede al DB e non inizializza il client Supabase
  (`supabase/.gitignore` esclude `.env`/`.temp`).
- **L'adapter RFI diretto resta DEBUG-only su iOS** (fallback dev); la produzione
  consumerà l'endpoint backend.
- **Endpoint pubblico / senza JWT SOLO per lo spike** (`verify_jwt = false`,
  deploy `--no-verify-jwt`): è un endpoint di validazione, non la configurazione finale.
- **Prima di un rollout più ampio servono rate limiting / token applicativo / abuse
  protection** (e cache condivisa, diagnostics ridotte, CORS ristretto).

## Backend adapter — Phase 1 iOS (fixture)

- **L'iOS consuma JSON normalizzato del backend tramite DTO + mapper**
  (`BackendBoardDTO` → `BackendBoardMapper` → `StationBoardResponse`): le view non
  vedono mai i DTO, e il mapper applica le regole sicure dell'app (niente
  ritardi/binari finti, binario assente → `--`, 0/cancellata → nessun ritardo).
- **La modalità backend-fixture è il ponte prima dell'integrazione reale**:
  `BackendBoardService` con `FixtureBackendBoardFetcher` carica una fixture JSON dal
  bundle (nessuna rete). Source mode DEBUG `.backendFixturePadova`, etichettata in
  header come "Backend fixture · Monitor RFI online" per non far credere a una
  connessione live.
- **L'adapter RFI diretto resta DEBUG-only** e disponibile come fallback dev
  (`.rfiLivePadova`); non è più il default DEBUG.
- **La produzione userà poi `BackendBoardService` con un fetcher di rete** (Phase 2/3);
  il parsing HTML RFI resta escluso dal Release. Release resta `.mock`.

## Accesso dati reali (produzione)

- **In produzione i dati reali passano da un backend adapter**, non dallo scraping
  diretto in-app: `iOS → backend → RFI → JSON normalizzato → iOS` (vedi
  `docs/13_BACKEND_ADAPTER.md`).
- **Il parsing HTML RFI diretto resta DEBUG-only**; la produzione consuma **JSON
  normalizzato** dal backend.
- **Il backend gestisce parsing sorgente, normalizzazione, cache, rate-limit e
  fallback**; l'app resta stabile anche se il markup della sorgente cambia.
- **Mai inventare fixture**: la fixture reale si cattura dal device e si aggiunge a
  mano; i test girano su fixture, mai sulla rete.
- **`placeId` live RFI ≠ id PRM scheduled**: gli id stazione sono mappati
  centralmente (station registry), mai mischiati.

## Board live & ritardi

- **Il token animazione del titolo NON deve mai causare reload dati**: alimenta
  solo il titolo LED dell'header (reveal). Il fetch del board dipende solo da
  `.task(id: boardType)` e dal refresh manuale.
- **La validazione live DEBUG evita richieste duplicate silenziose**: `refresh`
  ha guard in-flight + dedupe per board (stesso `station|boardType` entro pochi
  secondi); `selectBoardType` non rifà il fetch (lo fa `.task(id:)`);
  pull-to-refresh è `force`.
- **Colonna ritardo board compatta = etichetta piccola (`Rit.`/`Del.`) + badge**,
  visibile solo con ritardo/cancellazione; colonna a larghezza fissa stabile.
- **Colori ritardo semantici per soglia** (`DelayVisualState`): 1–4' ambra, 5–9'
  arancio, 10'+ rosso-arancio, cancellato rosso; nessun colore unico arbitrario.
  Rosso riservato ai problemi seri.

## Sorgenti dati

- **I dati reali partono come adapter DEBUG isolato** (`RFILiveBoardService`,
  `.rfiLivePadova`, monitor RFI live placeId 2000): il monitor RFI è trattato come
  **sorgente online, non una garanzia assoluta**. La UI consuma solo
  `StationBoardResponse` normalizzato; il parsing HTML resta **isolato** nel layer
  service/parser (mai nelle view o nel view model). I test si basano su **fixture**,
  non sulla rete. RELEASE resta `.mock`: lo spike non spedisce finché affidabilità
  e architettura prodotto/legale non sono riviste.
- **Le label specifiche della sorgente vanno normalizzate prima dei modelli app**:
  il parser RFI decodifica le entità HTML e converte le categorie verbose
  (`Categoria Alta Velocita&#39;`) in **sigle compatte** (`AV`, `RV`, `REG`, `FR`,
  `IC`, `ITA`…) prima della mappatura. La UI non riceve **mai** stringhe categoria
  grezze; le sigle compatte sono il contratto di display a livello app.
- **In DEBUG il mode RFI non fa MAI fallback silenzioso**: ogni esito (live /
  fetch-ok-parse-vuoto / fetch-fallito) è registrato in `RFIStationMonitorDiagnostics`
  e mostrato (banner DEBUG + console). La validazione della sorgente live richiede
  il **capture dell'HTML grezzo** (Documents, solo DEBUG); l'HTML catturato può
  diventare una fixture **sanitizzata**, ma non viene mai committato automaticamente
  né caricato. Nessuna diagnostica/capture in RELEASE.
- **RFI "Quadro Orario" = solo orario PROGRAMMATO/scheduled**, mai presentato
  come verità live. Niente ritardi/cancellazioni/cambi binario real-time.
  Le righe scheduled hanno `status = .scheduled`, `delayMinutes`/`actualPlatform`/
  `expectedTime` = nil, solo `plannedPlatform`. Indicato in UI con
  `Orario programmato` / `Scheduled timetable` (no pallino "live").
- **Il layer real-time sarà separato** in futuro (non in questo spike).
- **Fallback al mock obbligatorio**: ogni sorgente (scheduled/remote) DEVE
  ricadere su `MockTrainBoardService` su errore di fetch/parse o risultato vuoto.
- **Parsing fuori dalle view**: sorgenti dietro `TrainBoardService` /
  `ScheduledTimetableProvider`; le view consumano solo modelli normalizzati.
- Spike corrente: solo Padova (RFI id `1861`), solo partenze, provider = sample
  bundled del Quadro Orario parsato (lo scraping HTML RFI reale è lavoro futuro).
- **Modalità scheduled single-station = nessun mismatch titolo/dati**: quando la
  sorgente è una singola stazione fissa (`.scheduledPadova` = Padova) la
  selezione stazione DEVE restare bloccata; titolo (`PADOVA`) e righe devono
  sempre coincidere. `AppEnvironment.allowsStationChange` governa il controllo
  `Cambia` (visibile ma disabilitato + hint VoiceOver `accessibility.stationLocked`)
  e `StationBoardViewModel.changeStation()` è un no-op se bloccato. `.mock` resta
  multi-stazione (carosello demo attivo); `.remoteWithMockFallback` è riservato a
  una futura sorgente remota multi-stazione.
- **`.scheduledPadova` = sorgente DEBUG/demo, mai default di produzione**:
  `AppEnvironment.sourceMode` è risolto per build (`#if DEBUG` → `.scheduledPadova`,
  `#else` → `.mock`). La produzione NON deve trattare l'orario programmato come
  verità ferroviaria in tempo reale; il demo scheduled resta confinato alle build
  di debug. RELEASE usa il mock.
- **Il sample scheduled espone la sua natura demo/finestra**: i dati di sample
  programmato portano `scheduledWindowStart/End` + `sourceKind = scheduledSample`
  (→ `StationBoardResponse.scheduledWindow`); la UI mostra la fascia
  (`… · demo 06:00–06:59`). Nessun pallino "live".
- **Il sample scheduled NON è board corrente/live**: fuori dalla propria finestra
  oraria non si evidenzia alcuna riga come "prossima/corrente" (`imminentRowID
  == nil`) e la sezione diventa `Partenze programmate` / `Programmed departures`.
  Le righe restano visibili come orario programmato, non come partenze imminenti.
- **Niente inferenza automatica "domani"**: senza supporto service-date esplicito,
  le righe del mattino non vengono spostate al giorno successivo.
