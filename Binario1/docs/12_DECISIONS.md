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

## Viaggi salvati — persistenza locale

- **I viaggi salvati sono persistiti localmente** (`SavedJourneyStore`, JSON in
  `UserDefaults`) e sono la **fonte di verità unica** condivisa da Viaggi e dalla Home
  personalizzata. Niente backend/account/sync per ora.
- **Seed una tantum al primo avvio** (campioni realistici), poi dati reali
  editabili/cancellabili; le cancellazioni restano (nessun re-seed).
- **Rimosso il demo Padova→Venezia S. Lucia**: la personalizzazione della Home NON
  dipende più da un viaggio demo hardcoded — funziona con i viaggi salvati reali.
- **Persistenza locale semplice (UserDefaults/JSON)** scelta di proposito: leggera,
  nessuna dipendenza; si potrà evolvere (file store / sync) se servirà.
- **Gestione salvati in Viaggi = delete conservativo**: card custom → affordance
  cestino + azione VoiceOver (niente swipe-to-delete List), empty state minimale.
  La Home rilegge lo store al prossimo refresh (provider) → le cancellazioni si
  propagano senza toccare la logica di matching.
- **Salva da Cerca**: le tratte cercate si salvano nello stesso store (upsert con id
  canonicalizzato → niente duplicati). Il seed una-tantum **non sovrascrive** dati
  utente già presenti (un salvataggio da Cerca prima del primo load di Viaggi
  sopravvive). Direction placeholder `.homeToWork` per i salvataggi da Cerca (limite
  cosmetico noto: titolo card a ruoli, ma la tratta reale resta visibile).

## Ruoli dei 3 tab (funzionali)

- **Home = tabellone di stazione** (spotlight in alto + tabellone completo sotto).
- **Cerca = punto di ingresso ricerca** stazione / tratta / treno. Le card aprono le
  rispettive modalità (non sono decorative). "Cerca tratta" salva una tratta custom.
- **Viaggi = abitudini/tratte salvate dell'utente.** Il "viaggio utile" è riformulato
  come **abituale** ("Dalle tue abitudini"): il prossimo viaggio probabile ricavato dai
  soli viaggi salvati (orario locale), NON una predizione generica/AI.
- **Tratte custom** (salvate da Cerca) mostrano la rotta reale come titolo; gli alias
  "Casa → Lavoro" restano solo per viaggi commuter dedicati.

## Modello mentale a 3 tab (copy/gerarchia)

- **Home = tabellone di stazione.** L'header lo dichiara (STAZIONE · Padova ·
  "Tabellone in tempo reale"); in basso il **tabellone completo** con titolo esplicito
  station-scoped ("TUTTE LE PARTENZE DA PADOVA" / "TUTTI GLI ARRIVI A PADOVA").
- **Le righe personalizzate in alto sono solo uno spotlight** ("I tuoi prossimi treni"),
  non il significato principale dello schermo: gerarchia = alto spotlight utile, basso
  tabellone completo. Fallback generico "PROSSIME PARTENZE" / "PROSSIMI ARRIVI".
- **Cerca = ricerca/salvataggio di una tratta.** **Viaggi = archivio dei viaggi
  salvati.** I tre tab hanno ruoli distinti e non si sovrappongono.

## Home — featured personalizzata

- **La sezione in alto della Home dà priorità ai viaggi salvati dell'utente** quando
  possibile (titolo "I tuoi prossimi treni"): mostra "il mio treno", non solo il
  prossimo treno generico della stazione. È il vantaggio di Binario1 sul tabellone
  fisico — personalizza il primo sguardo.
- **Fallback generico** alle prossime partenze quando non ci sono viaggi salvati o
  match → nessun hero vuoto.
- **Il tabellone completo "Tutte le partenze" resta la fonte di verità** sotto la
  featured.
- **MVP**: matching per nome stazione canonicalizzato (no route planner), sorgente
  viaggi salvati mock (`HomeSavedJourneys`); diventa reale con la persistenza dei
  viaggi salvati. Nessun cambio di contratto dati/backend.

## Trasparenza sorgente dati (online)

- **Binario1 resta trasparente sul fatto che i dati arrivano da una sorgente online**
  (`Monitor RFI online`), non da un feed real-time garantito.
- **I dati backend RFI possono essere molto coerenti con i tabelloni fisici di stazione**
  — confronto visivo a Padova (2026-06-22) coerente sul campione osservato — ma l'app
  **non deve promettere precisione assoluta** né garantire che tutti i dati futuri
  coincidano sempre con i display di stazione. Mantenere monitoraggio affidabilità.

## Token DEBUG per app installata (build-time)

- **I token reali non si committano mai**: il token DEBUG vive solo in
  `Config/Binario1Secrets.local.xcconfig` (gitignored); committati solo l'esempio
  placeholder e la config base Debug.
- **Le build DEBUG installate hanno bisogno del token a build-time**, non solo della
  env var dello schema Xcode: la scheme env var c'è solo se l'app è lanciata da Xcode,
  non aprendo l'icona. Quindi il token è iniettato nel binario DEBUG via `.xcconfig` →
  chiave Info.plist custom; precedenza build-time → env var → vuoto.
- **Release non riceve token** (nessun baseConfigurationReference) e resta `.mock`.
- **Validato su iPhone reale (2026-06-23)**: app installata aperta da icona →
  `Backend · RFI online` + `[BackendLive] OK · rows=40 · …fallback=false · stale=false`,
  nessuna fixture. Conferma che le env var Xcode non bastano per l'app installata e
  che il token build-time (gitignored) è la soluzione. Nessun secret committato.

## Cambio-stazione live (B3-lite)

- **Il live serve più stazioni, ma solo quelle VERIFICATE nel registry** (oggi Padova
  2000 e Roma Termini 2416, entrambe confermate sul monitor RFI). `allowsStationChange`
  in live è vero solo se c'è più di una stazione servita; il picker cicla SOLO quelle.
- **`prmScheduledId` è opzionale nel registry**: il path live non lo usa mai (solo
  `rfiLivePlaceId`). Una stazione può essere live-attiva senza; una feature
  scheduled/PRM NON va attivata per stazioni che non lo hanno verificato.
- **Lo slug è il contratto tra app e backend**: `Station.id` (catalogo iOS) DEVE essere
  identico alla chiave del registry ("padova", "roma-termini"), altrimenti 404
  silenzioso. Un test asserisce l'insieme atteso così il drift esplode nei test.
- **L'elenco delle stazioni servite è derivato** dal flag `servedByLiveBoard` del
  catalogo, non duplicato in codice.
- **Mai la board di una stazione sotto il nome di un'altra**: il fallback fixture è
  vincolato alla stazione che rappresenta (`fallbackStationID`); per le altre si lancia
  `BoardUnavailableError` e la UI mostra lo **stato onesto** "Tabellone non disponibile
  per questa stazione". Cambio stazione e stato onesto **azzerano le righe** precedenti.
- **404 `unknown_station` è un caso previsto**, non un errore da mostrare grezzo.

## Catalogo stazioni & naming canonico (B1)

- **Le stazioni sono un catalogo reale** (`Resources/stations.json`, schema `Station`),
  non più liste mock. Cerca restituisce ENTITÀ `Station`; il form tratta risolve i campi
  a stazioni del catalogo e **salva il displayName CANONICO** (es. "Roma Termini"), così
  il resolver B4 / spotlight Home agganciano la riga board in modo affidabile. Un bare
  "Roma" NON è salvabile finché non si sceglie l'entità (footgun bloccato).
- **`providerCodes` non si fabbricano**: presenti solo dove già verificati nel codice
  (Padova rfi 1861, ecc.), `null` altrove. I nomi sono fatti pubblici; i codici no.
  Non usati dal fetch board oggi (solo metadati per un futuro registry live).
- **`boardAliases` opzionali** sulle stazioni per le forme abbreviate RFI ("Venezia
  S.L.", "Torino P.N."). `StationNameMatcher.matches(station:boardName:)` li considera
  RIUSANDO `matches(_:_:)` → la regola ≥2-token NON si indebolisce (Venezia Mestre ≠
  Venezia Santa Lucia). Gli alias possono solo AGGIUNGERE veri match.
- **Un solo catalogo condiviso**: iniettato (opzionale, default nil = match stringa) nel
  `SavedJourneyMatcher` usato SIA da Home SIA dal resolver B4 → restano coerenti e
  alias-aware insieme; i test/preview senza catalogo mantengono il comportamento stringa.
- **Ricerca senza espansione abbreviazioni**: il fold di ricerca è solo maiuscole +
  diacritici + punteggiatura (niente "s"→SANTA), a differenza di `StationNameMatcher.
  canonical` (che espande) usato per il match col board.

## Viaggi — prossimo treno reale (B4)

- **Dato reale o stato onesto, mai segnaposto**: le tratte salvate mostrano il prossimo
  treno REALE dal tabellone (orario/binario/ritardo/numero) risolto via
  `NextTrainResolver` attraverso `TrainBoardService`. Se non risolvibile (origine non
  servita dal board — oggi solo Padova — o nessuna riga futura che matcha) → "Prossimo
  treno non disponibile". Mai orari/binari/durate finti; l'ora-di-salvataggio NON è mai
  mostrata come partenza.
- **Un solo predicate di matching** (`SavedJourneyMatcher`, puro) condiviso da Home
  (spotlight) e Viaggi (resolver): estratto da `personalizedFeaturedRows` così le due
  feature non divergono. Origine = stazione servita dal board; destinazione via
  `StationNameMatcher` (regola ≥2-token → un bare "Roma" non matcha "Roma Termini").
- **Stazione servita derivata, non hardcoded**: il resolver riceve
  `AppEnvironment.initialStation` (Padova in DEBUG/TESTFLIGHT, mock altrove). Il board è
  single-station; tratte con origine diversa ricadono nello stato onesto (previsto).
- **Niente durata/arrivo inventati**: il board non fornisce l'arrivo, quindi la card
  reale mostra numero treno al posto della "durata" e nessun arrivo.
- **"Dalle tue abitudini" = prossimo treno reale più imminente** tra le tratte risolte
  (non una scelta per ora-del-giorno). Se nulla risolve, la sezione è nascosta.
- **Recenti nascosti finché non c'è cronologia reale**: mostrare recenti mock come se
  fossero storia vera è ingannevole; il mock resta nel modello per un futuro riaggancio.

## Sorgente TestFlight vs Release (guardrail a 3 rami)

- **La live NON è mai il default di Release App Store**: `AppEnvironment.sourceMode` è
  risolto a 3 rami — `#if DEBUG → .backendLivePadova`, `#elseif TESTFLIGHT →
  .backendLivePadova`, `#else (plain Release) → .mock`. Il flag `TESTFLIGHT` è definito
  SOLO da una **build configuration "TestFlight" dedicata** (famiglia Release); una
  Release senza flag non ha né live né token → `.mock`. Guard runtime `#if DEBUG ||
  TESTFLIGHT` attorno alle factory backend-live e a `BackendEndpointConfig.debug`.
- **Il token è bakato SOLO nelle config che devono chiamare il backend** (Debug e
  TestFlight) via `INFOPLIST_FILE = Config/Binario1-Info.plist` + `#include?` del
  gitignored `Binario1Secrets.local.xcconfig`. Release non ha `INFOPLIST_FILE` custom →
  nessuna chiave token nel plist (verificato ASSENTE). Senza token → 401 → fixture.
- **L'archivio TestFlight passa dalla config TestFlight, non da Release**: lo scheme
  `ArchiveAction` punta a `TestFlight`. Per l'App Store si archivia con Release (`.mock`).
- **Lo scheme resta gitignored** (`*.xcodeproj/xcshareddata/`): può portare env var col
  token; l'`ArchiveAction=TestFlight` quindi vive localmente, non nel repo.

## Station registry & board type (arrivi/partenze)

- **Gli id stazione devono essere VERIFICATI prima dell'attivazione**: una stazione
  entra nel registry solo con `rfiLivePlaceId` confermato sul monitor RFI live. Mai
  attivare id ipotizzati. `rfiLivePlaceId` ≠ `prmScheduledId` (sistemi diversi).
- **Il board type fluisce end-to-end** (iOS → backend): l'app invia
  `type=departures|arrivals`, il backend mappa su RFI `arrivals=False/True`.
- **Arrivi e partenze usano lo stesso contratto JSON normalizzato**; per gli arrivi il
  campo `destination` trasporta la provenienza (iOS lo mappa su `origin`).
- **La hero personalizzata vale prima per le partenze**; la personalizzazione degli
  arrivi è un'evoluzione successiva (per ora arrivi = vista generica).

## Backend adapter — Hardening Phase 1 (`board`)

- **`/board` non è più trattato come endpoint pubblico illimitato** per un rollout più
  ampio: supporta un **app token** (`X-Binario-App-Token`, env `BINARIO_BOARD_APP_TOKEN`)
  e un **rate limit** best-effort.
- **L'app token è una misura leggera di abuse-reduction, non sicurezza completa**: un
  token spedito in un'app mobile è estraibile → NON è user auth né equivalente a
  service_role. Per ora `verify_jwt = false`, validazione a livello di codice.
- **Diagnostics ridotte in produzione** via `BINARIO_BOARD_ENV` (niente
  `sourceBytes`/`sourceStatus` pubblici in production mode).
- **La produzione richiede ancora un rate limit distribuito e una policy di rollout**
  (il limiter in-memory è per-istanza, non globale). Nessun secret committato.
- **App-token validato end-to-end (2026-06-17)**: server no/errato → 401, corretto →
  200 con diagnostics omesse in production. Enforcement ora ATTIVO sul deploy. Path
  negativo confermato anche su iPhone reale (401 → fallback visibile alla fixture);
  path positivo **confermato su iPhone reale** (header `Backend · Monitor RFI online`,
  righe live, niente fixture). Backend-live protetto validato su device.
- **I token reali restano fuori da git**: env var nello schema Xcode (`xcuserdata/`,
  gitignored) lato iOS, secret Supabase lato server, copia locale in
  `supabase/.env.board.local` (gitignored). Mai committati, mai nei log/summary.

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
- **Validazione backend-live riuscita su iPhone reale** (2026-06-17, log
  `[BackendLive] OK · rows=40 · …`): il path dati reali in produzione deve passare
  dal **JSON normalizzato del backend**, non dal parsing RFI on-device.

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

## Fixture del parser RFI — solo HTML reale

- **Le fixture del parser RFI DEVONO essere HTML reale scaricato dal monitor**,
  non markup scritto a mano che "assomiglia" alla pagina. Motivo, non teorico: le
  fixture inventate marcavano il treno in partenza con `<tr class="riga lampeggia">`,
  una forma che la pagina vera **non ha**. Il test verificava quindi l'invenzione, non
  RFI: è passato mentre il parser era sbagliato, prima come codice morto
  (`isDeparting` sempre falso) e poi, dopo il "fix", sempre vero — 32 righe su 40
  sarebbero apparse "in partenza". Vedi [17_VIAGGIATRENO_SPIKE.md](17_VIAGGIATRENO_SPIKE.md)
  (Appendice A).
- **Canoniche**: `Binario1Tests/Fixtures/rfi-*.sample.html`, estratti **verbatim** di
  un download reale. Le uniche modifiche ammesse sono (1) righe scartate e (2) payload
  base64 dei loghi accorciati — il parser non legge mai `src`. Ogni fixture dichiara
  in testa data, `placeId` e cosa è stato tagliato.
- **Il backend ne tiene una copia** in `supabase/functions/board/rfi_fixtures.ts`
  (stringa TS, importata solo dai test, mai da `index.ts`): i due runtime non possono
  condividere un file. Deve restare **identica** alla copia iOS; si rigenerano
  entrambe da un download fresco, non si edita a mano.
- **Corollario**: se un comportamento non compare in nessun download reale, **non si
  inventa una fixture per coprirlo**. La cancellazione di un treno non è mai apparsa
  nei download: resta coperta al livello del predicato (`isCancelled` /
  `isCancelledRow` su una riga costruita in memoria), dichiarando che il campione
  reale non la conteneva.
- **Il segnale "in partenza" è una colonna, non una classe di riga**: è un `<img>`
  dentro la cella `RExLampeggio` (`alt="Si"`, icona `LampeggioGrey`/`LampeggioGold`
  — i due fotogrammi del lampeggio); quando il treno non è in partenza la cella è
  vuota e il `<td>` porta `aria-label="No"`. La classe del `<tr>` è **solo zebratura**
  (`row yellowRow` / `row greyRow`). Non cercare mai la sottostringa `lampeggi` nella
  riga: è contenuta nell'id/classe di quella cella, quindi è presente in **tutte**.
- **`info` è la nota "Informazioni"**, cioè il blocco `testoinfoaggiuntive` che segue
  il titolo `Informazioni` dentro la cella `RDettagli` — mai l'intera cella (che
  contiene anche l'itinerario "Fermate successive", ~2 KB) e mai la cella
  `RExLampeggio`. Valori reali: `CARROZZA 1 IN TESTA AL TRENO`, `VIA MONTEBELLUNA`,
  `NO-STOP`, `VIAGGIATORI DA … CON BUS SOSTITUTIVO ALLE ORE …`.
- **Niente euristiche testuali per lo stato**: l'euristica "info contiene *stazione*"
  è stata rimossa. Sulla pagina reale `IN STAZIONE` compare solo nel banner avvisi
  di stazione, **fuori dalla tabella**: usarla come segnale di partenza significava
  leggere un testo che non parla di quel treno.
