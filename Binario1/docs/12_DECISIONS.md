# 12 — Decisions

Decisioni di prodotto/architettura non deducibili dal codice. Tenere conciso.

## Inquadramento di prodotto (vale per tutti i ticket)

- **Binario1 è un "consulto del tabellone di stazione", NON un trip planner.** Il gesto
  centrale è: l'utente cerca una stazione e ne consulta il tabellone. Ogni funzionalità
  va letta in questa chiave — se una feature ha senso solo per pianificare un viaggio,
  è fuori inquadramento.
- **B2 (journey planner) è RIMOSSO dallo scope, non rimandato.** Non va riproposto come
  "prossima milestone" né lasciato come TODO aperto nei documenti.
- Conseguenze pratiche già visibili nel codice: `Cerca` porta al tabellone della
  stazione scelta; `Viaggi` resta una dashboard di tratte salvate (scorciatoie verso il
  tabellone), non un motore di ricerca itinerari.

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

## I nomi RFI sono etichette di visualizzazione, non un sistema di tipi (B4)

> **La lezione più trasferibile di questa serie di ticket.** Vale oltre il caso che l'ha
> generata: ogni volta che abbiamo dedotto una **proprietà** da una **stringa** scritta da
> RFI, ci siamo sbagliati. Tre volte, in tre ticket diversi, su tre proprietà diverse.

| Ticket | La regola "ovvia" | Come si è rotta |
|---|---|---|
| **C4** | due nomi coincidono se uno è sottoinsieme di token dell'altro | 53 collisioni reali sull'elenco RFI, **8 su stazioni già spedite** (`VENEZIA MESTRE` contro le tre `GAZZERA`/`OLIMPIA`/`OSPEDALE`) |
| **B4** | il prefisso del nome dice **che cosa** è la voce (`PM `/`PC `/`BIVIO `/` PES` = punto operativo) | **10 voci su 21 erano stazioni passeggeri vere**, con tabellone e binario |
| **18** | la grafia stampata identifica la fermata | la **stessa** fermata ha grafie diverse su board diversi (`BATTAGLIA T.` da Padova, `BATTAGLIA TERME` da Terme Euganee) |

- **Il nome è ciò che RFI stampa, non ciò che la voce è.** RFI compone i nomi per farli
  stare in una colonna e per farsi capire da un operatore, non per farci fare parsing.
  Prefissi, abbreviazioni e troncamenti sono scelte tipografiche, e cambiano per contesto.
- **La regola pratica**: una proprietà si **verifica contro il comportamento della fonte**,
  poi si **congela in una lista esplicita**, e un **test la fissa**. Mai dedotta dalla
  stringa a runtime. Una lista di 11 voci verificate è più onesta di una regola di due
  righe che ne sbaglia 10.
- **Il costo di sbagliare non è simmetrico.** Dedurre da un nome produce errori
  *silenziosi*: nessuno si accorge che Caldiero manca dalla ricerca finché non è un
  pendolare di Caldiero a cercarla. Una lista sbagliata, invece, è visibile in review.

### Il caso B4, per esteso

- **La classificazione per prefisso di nome era SBAGLIATA e ha prodotto un bug in
  produzione.** `StationsArtifact.isOperationalPoint(name:)` marcava come punto operativo
  ogni voce con prefisso `PM `/`PC `/`BIVIO ` o suffisso ` PES`, escludendola **dalla
  ricerca e dal matching delle destinazioni**. Delle 21 selezionate, **10 sono stazioni
  passeggeri reali**: RFI serve loro un tabellone di partenze con righe e binario. Un
  pendolare di Caldiero non trovava la propria stazione, perché RFI la scrive
  `PC CALDIERO`. È l'opposto di ciò che il B3-full doveva ottenere.
- **La regola era giusta solo per `PM `** (11 su 12, l'eccezione è `PM ISPRA`) e **sbagliata
  per ogni singola voce** `PC ` (3/3), `BIVIO ` (1/1) e ` PES` (5/5).
- **Sostituita da una lista verificata di 11 id**, non da una regola migliore. La
  classificazione resta **nostra e nel codice** — l'artefatto TSV rimane una proiezione
  fedele della lista RFI, e `stations.json` resta metadata passeggeri curata. La firma è
  ora `isOperationalPoint(id:)`: prende un id, non un nome, perché la vecchia firma
  invitava proprio l'errore che sostituisce.
- **Criterio di verifica, valido in UNA SOLA DIREZIONE.** Sul monitor RFI di un `placeId`:
  pagina da ~5 KB con `DATI NON DISPONIBILI` e senza `<thead>`/`<tbody>` → punto operativo;
  tabellone con righe → **stazione passeggeri**.
  - **«ha un tabellone ⇒ è una stazione»**: solido. È su questo che poggiano i 10.
  - **«non ha tabellone ⇒ è un punto operativo»**: **NON valido**. Circa il **15% del
    catalogo** risponde `DATI NON DISPONIBILI` (linee sospese, servizio stagionale,
    stazioni che RFI non monitora in live) e un campione di quelle risulta fatto di
    stazioni passeggeri vere su ViaggiaTreno. **Mai aggiungere un id alla lista sulla sola
    assenza di tabellone**: nome e comportamento devono concordare.
  - L'ora del giorno non è un fattore confondente: RFI **riempie i tabelloni piccoli fino a
    un minimo di ~15 righe** sconfinando nel futuro, quindi un'ora tranquilla non svuota un
    tabellone reale (verificato su 15 stazioni piccole, 0 falsi allarmi).
- **Debito noto e dichiarato**: la lista può ancora MANCARE punti operativi dal nome
  ordinario. Non è misurabile col test sopra, e nessun segnale lessicale aiuta (nei 2414
  nomi non marcati non esiste **nessuna** occorrenza di `BIVIO`/`PM`/`PC`/`PES`). Servirebbe
  l'anagrafica ufficiale RFI delle *località di servizio*: spike accettato, non pianificato.
- **Il test fissa entrambi i lati** — gli 11 come insieme esatto, i 10 come cercabili per
  la query che un utente digita davvero ("caldiero") — più una **non-regressione**: gli
  insiemi "nome marcato" e "flag attivo" **devono differire**, perché la loro uguaglianza
  *è* il bug.

## Match fra nomi di stazione: uguaglianza canonica, mai sottoinsieme (C4)

- **Due nomi di stazione coincidono solo se le loro forme canoniche sono UGUALI.** La
  vecchia regola accettava anche il sottoinsieme di token (col vincolo ≥2 token). È
  stata rimossa: **aggiungere token significa stazione diversa**. `REGGIO EMILIA` non è
  `REGGIO EMILIA AV MEDIOPADANA`, `GENOVA PIAZZA PRINCIPE` non è la `SOTTERRANEA`,
  `BOLOGNA CENTRALE` non è `BOLOGNA C.LE/AV`, `NAPOLI AFRAGOLA` non è `NAPOLI AFRAGOLA
  PES`.
- **Il difetto era reale e già spedito, non teorico.** Sull'elenco autorevole RFI (2435
  voci, `PlaceId` del monitor, estratto il 2026-08-28) il subset test produceva **53
  coppie di collisione, 8 delle quali su stazioni già presenti nel catalogo delle 17** —
  fra cui `VENEZIA MESTRE` contro le tre `VENEZIA MESTRE GAZZERA / OLIMPIA / OSPEDALE`.
  Con l'uguaglianza canonica le collisioni sull'intero elenco sono **0**.
- **Il ponte fra la forma che il tabellone STAMPA e il nome ufficiale sono due cose
  esplicite**: l'espansione delle abbreviazioni dentro `canonical` (`C.LE` → CENTRALE,
  `P.NUOVA` → PORTA NUOVA) e i `boardAliases` dichiarati sulla stazione. **Non** un
  match permissivo. Verificato che il match delle destinazioni abbreviate non dipendeva
  affatto dal subset: `VENEZIA S.L.` passava già dall'alias, `BOLOGNA C.LE` già
  dall'espansione. Delle asserzioni del matcher già verdi, la regola stretta ne
  cambiava **una sola**: quella che fissava la collisione Abano.
- **Corollario**: la tabella di espansione è ora PORTANTE. Una forma stampata che non
  raggiunge il nome ufficiale non è più recuperata da un match approssimato: è un match
  mancato. Un test asserisce la copertura delle abbreviazioni su cui poggiano le
  stazioni servite, così ridurla rompe la suite invece di degradare in silenzio.
- **Token neutro per i santi**: `S. / SAN / SANT / SANTA / SANTO / SANTI / SS` → `S`.
  RFI scrive `S.` per entrambi i generi (231 nomi sullo snapshot del 2026-08-31); espanderlo in `SANTA`
  indovinava il genere e sbagliava sulla maggioranza maschile (`S.GIOVANNI` è *San*
  Giovanni), e soprattutto impediva ai 4 nomi scritti `SAN …` per esteso di agganciare
  la propria forma abbreviata. Non indovinare è meglio che indovinare male. Il token
  neutro rende visibili 2 collisioni che il codice prima non vedeva (`BIELLA S.PAOLO` e
  `S.PAOLO SOLBRITO` contro `SAN PAOLO`): sono reali, e la regola stretta le scioglie.
- **I punti operativi non sono capolinea.** Portano `operationalPoint: true` e sono esclusi
  **sia dal matching delle destinazioni sia dalla ricerca**, ma `station(named:)` continua
  a risolverli: un nome non perde mai la sua entità. Aprire il tabellone di un posto di
  movimento sarebbe una promessa non mantenuta; il flag lo impedisce alla radice.
  > **SUPERATO NEL MODO DI SELEZIONARLI (B4, 2026-09-01).** Qui si leggeva che le voci
  > `PM …`/`PC …`/`… PES`/`BIVIO …` — 21 nello snapshot del 2026-08-31 — *sono* i punti
  > operativi. **Non lo sono: 10 di quelle 21 sono stazioni passeggeri vere**, e escluderle
  > era un bug in produzione. Il flag e le sue conseguenze restano validi; a cambiare è
  > **come si stabilisce chi lo porta** — non più il prefisso del nome, ma una lista di 11
  > id verificati contro il monitor RFI. Vedi "I nomi RFI sono etichette di
  > visualizzazione, non un sistema di tipi (B4)".
- **La tolleranza sui nomi vecchi si sposta dove è ispezionabile.** Un'origine salvata
  sotto una grafia precedente ("Montegrotto Terme") continua ad agganciare, ma via
  `searchAliases` risolti dal catalogo — una lista esplicita e recensibile — invece che
  via una regola permissiva che agganciava anche stazioni diverse. Per questo
  `journeyDeparts` accetta ora un `catalog`, simmetrico al lato destinazione che lo
  aveva già.

## Catalogo nazionale: l'artefatto condiviso (B3-full)

- **Una sola fonte per iOS e backend: `rfi-stations.tsv`**, estratto dal `<select
  name="PlaceId">` di `iechub.rfi.it/ArriviPartenze/` — la lista autorevole di RFI, la
  stessa che pilota il monitor live. Due colonne: `placeId` e nome ufficiale. Nessun id
  indovinato, nessuna fonte alternativa. Si rigenera con
  `tools/generate-rfi-stations-tsv.mjs`, non si edita a mano.
- **L'artefatto è uno SNAPSHOT DATATO, non una verità perpetua.** Nulla garantisce che
  l'elenco di RFI sia stabile, quindi il conteggio non è una costante su cui appoggiarsi:
  l'header porta fonte e data. **Nessun test asserisce il conteggio**, si asseriscono
  proprietà (unicità, iniettività, àncore note). Un'asserzione sul numero non dimostra
  nulla mentre passa e si rompe a ogni variazione a monte.
  *(Nota di metodo: questa premessa NON va appoggiata a un cambiamento realmente
  avvenuto. L'unica variazione di conteggio osservata finora — 2434 vs 2435 — non era
  di RFI: era un difetto di estrazione, vedi sotto.)*
- **La duplicazione è una COPIA VERIFICATA, non due liste.** I due runtime non possono
  condividere un file, quindi il backend incorpora l'artefatto in
  `rfi_stations_tsv.ts`; `rfi_stations_tsv_test.ts` asserisce che le due copie sono
  **identiche byte a byte**, e senza `--allow-read` quel test FALLISCE invece di
  saltare (la CI passa il flag). Una copia non verificata è solo un secondo elenco che
  diverge in silenzio.
- **Normalizzazione TIPOGRAFICA soltanto**: dove RFI digita un backtick al posto
  dell'apostrofo (10 voci) diventa un apostrofo. **Mai la struttura**: spaziatura,
  trattini e slash restano come RFI li scrive (`CITTA' DI CASTELLO - ZONA INDUSTRIALE`
  conserva il trattino spaziato, `BOLOGNA C.LE/AV` il suo slash). Toccare la struttura
  significherebbe inventare nomi. Effetto collaterale utile: senza backtick l'artefatto
  è incorporabile *raw* in un template literal, e il generatore lo verifica.
- **Il conteggio 2434 vs 2435 non era deriva di RFI: era un estrattore cieco.**
  L'opzione di MILANO CENTRALE porta `selected="selected"` PRIMA di `value`, quindi un
  pattern ancorato su `<option value=` la perdeva — una stazione fra le più grandi
  d'Italia, sparita senza errore. Il generatore ora confronta le righe estratte con i
  tag `<option>` presenti e **fallisce** se non coincidono. La lezione è generale: la
  perdita silenziosa di dati va resa rumorosa, non spiegata come variazione a monte.

## Grafia dei nomi: maiuscolo verbatim RFI (B3-full)

- **`displayName` è il nome ufficiale RFI, verbatim e MAIUSCOLO** ("VENEZIA S.LUCIA",
  "TERME EUGANEE-ABANO-MONTEGROTTO"). Con 17 voci il Title Case si curava a mano; con
  l'elenco nazionale andrebbe **generato**, e generarlo significa inventare una grafia
  che RFI non ha mai scritto: 233 nomi portano particelle (DI/DEL/DELLA/DA/IN/SUL) che
  vanno minuscole, 232 abbreviazioni puntate (`S.LUCIA`, `C.LE`), 47 un apostrofo dove
  l'italiano vuole un accento (`MONDOVI'`). Il maiuscolo non decide nessuna di queste
  domande, ed è anche la resa del tabellone fisico.
- **Conseguenza accettata**: ricerca e tratte salvate mostrano il maiuscolo. Il match
  non ne risente — `canonical` maiuscolizza comunque, quindi un nome persistito in
  grafia precedente continua a risolvere.
- **`Station.id` = slug del nome ufficiale**, regola unica e senza casi speciali
  (minuscolo, ogni sequenza di non-alfanumerici → un trattino). Riproduce senza
  eccezioni i quattro slug scritti a mano prima della copertura nazionale. Due id
  disallineati sono stati **rinominati in place**, non duplicati: `firenze-smn` →
  `firenze-santa-maria-novella`, `reggio-emilia-av` → `reggio-emilia-av-mediopadana`
  (nessuna persistenza contiene id di stazione: le tratte salvate memorizzano i nomi).
- **`stations.json` non è più il catalogo: è un OVERLAY curato.** Porta solo ciò che la
  lista RFI non ha — città, `providerCodes` verificati, `boardAliases`,
  `searchAliases`. Non può rinominare né introdurre una stazione; un id non presente
  nell'artefatto è un errore, e un test lo dichiara.

## Registry backend: da lista statica a Map dall'artefatto (B3-full)

- **Il registry è costruito dall'artefatto embedded e indicizzato in una `Map` all'init**
  (opzione 2). La lista letterale mantenuta a mano è stata **sostituita**, non estesa.
- **Una collisione di slug fa fallire l'init**, non viene assorbita: una `Map`
  terrebbe l'ultimo scrittore e una stazione sparirebbe dal registry senza errore.
  Sullo snapshot attuale la regola è iniettiva (nessuna collisione), e un test lo
  asserisce come proprietà più il caso sintetico che la violerebbe.
- **`servedByLiveBoard` è derivato dalla presenza nel registry.** Poiché registry e
  catalogo nascono dallo stesso artefatto, la copertura è **totale**: ogni stazione del
  catalogo è servita.
- **A copertura totale il guardrail va tenuto vivo con una stazione NON SERVITA
  SINTETICA.** Prima del B3-full ogni slug fuori dai 3 registrati era una stazione non
  servita reale, e l'invariante si testava da sé; ora non esiste più un caso reale. Il
  test usa un registry-fixture che omette deliberatamente una voce. **L'invariante non
  è stata indebolita: è stato sostituito il soggetto**, perché l'unica alternativa era
  smettere di testarla proprio quando la superficie si allarga a tutta Italia.
- **I 21 punti operativi restano nel registry** (RFI serve davvero quei placeId: il
  campione mostra righe reali su `BIVIO D'AURISINA`, `PC CALDIERO`…). L'irraggiungibilità
  è imposta da iOS, che li esclude da ricerca e da matching destinazioni.

## Titolo stazione: il wrap spezza anche sul trattino (B3-full)

- **La riga primaria del titolo si spezza sul TRATTINO oltre che sullo spazio.** RFI ha
  nomi che sono un unico composto trattinato senza spazi
  (`MARCELLINA-VERBICARO-ORSOMARSO`, 30 caratteri): con la rottura solo sullo spazio
  finivano interi sulla riga primaria come **una sola parola**, che non aveva nulla su
  cui andare a capo e poteva solo rimpicciolire. Sull'artefatto le righe primarie oltre
  soglia passano **da 49 a 0**.
- **I separatori dentro una riga sono preservati verbatim**; si perde solo quello sul
  punto di rottura. Altrimenti `ABANO-MONTEGROTTO` verrebbe reso `ABANO MONTEGROTTO` —
  un nome diverso da quello ufficiale, anche senza alcun a capo.
- **Una riga primaria non può restare una particella isolata**: `SAN` sopra `PAOLO` si
  legge come troncamento, non come a capo. Quando la primaria finirebbe su una
  particella di testa, assorbe la parte successiva. Sullo snapshot i casi reali sono 5
  (`SAN PAOLO`, `SAN GOTTARDO`, `SAN POLO MATESE`, `SAN FAUSTINO-CASIGLIANO`,
  `SU CANALE`).

## Selezione stazione: chiusi i due debiti del C3 (B3-full)

- **`changeStation()` e `selectableStations` sono RIMOSSI.** Erano irraggiungibili
  dalla UI dal C3 (il carosello è sparito dal prodotto) e sopravvivevano solo come
  soggetto del test di regressione del fix race. Quel test è stato **riscritto su
  `selectStation(_:)`**, che percorre lo stesso `invalidateSelection()`: la protezione è
  ri-puntata, non persa.
- **`AppEnvironment.allowsStationChange` non è più `selectableStations.count > 1`.** Con
  la copertura nazionale quella condizione è banalmente vera, ed è peggio che stantia:
  una condizione che non può più essere falsa nasconde ciò che doveva proteggere. Ora
  dichiara ciò che conta davvero — se la sorgente è multi-stazione.

## Validazione a due assi: stazione E modalità (C3)

- **Le righe mostrate devono sempre appartenere sia alla STAZIONE sia alla MODALITÀ
  dichiarate dall'header.** Il fix race copriva solo l'asse stazione; l'asse modalità
  mancava, e una risposta di partenze in volo finiva sotto l'header ARRIVI (stessi
  orari, stessi binari, colonna provenienza vuota perché le righe di partenza non hanno
  `origin`).
- **Il cambio di modalità invalida come il cambio di stazione**: stesso
  `invalidateSelection()` — bump del token di generazione e `rows = []`. Le righe di un
  tabellone non devono mai sopravvivere al passaggio all'altro, nemmeno per un frame.
- **Il collasso dei fetch duplicati avviene per chiave `stazione|tipo`**, mai su "un
  fetch qualsiasi in volo". Un guard globale sull'in-flight inghiottiva la richiesta
  arrivi quando l'utente toccava ARRIVI mentre un altro fetch era in corso: l'unica
  richiesta emessa restava quella di partenze. Un doppio scatto del `.task` continua a
  collassare; una richiesta genuinamente diversa parte sempre.
- **Al mismatch di payload si espone `error.dataUnavailable`, NON
  `markBoardUnavailable`**: la stazione È servita, è il payload a essere sbagliato.
  Dire "tabellone non disponibile per questa stazione" sarebbe una diagnosi falsa;
  l'errore dati è onesto e porta con sé il pulsante Riprova.
- Corollario di metodo: un bug di questa famiglia va **riprodotto con un test rosso**
  prima di correggerlo. Qui la riproduzione ha smentito la causa ipotizzata (vedi
  `11_PROGRESS.md`, C3): il difetto esisteva anche **senza** cambio stazione, quindi
  ricostruire il view model non lo avrebbe risolto.

## Selezione stazione: una via sola (C3)

- **Il carosello di "Cambia" è RIMOSSO.** Con il catalogo servito destinato a crescere a
  centinaia di stazioni nel B3-full, ciclare tra le stazioni servite è inutilizzabile.
- **"Cambia" apre lo sheet di ricerca stazione**, non un push: il tab Partenze non ha un
  NavigationStack e un push porterebbe il chevron indietro. La selezione **sostituisce**
  la stazione restando nel tab. È la differenza voluta con l'ingresso da Cerca, dove il
  push col back è corretto e resta com'è.
- **Una sola implementazione della ricerca**: `CercaView` in modalità picker
  (`onSelectStation`), non una seconda lista. Le due porte d'ingresso non possono
  divergere.
- **`selectStation(_:)` è l'unico ingresso** per cambiare stazione; `changeStation()` vi
  delega. Quest'ultimo è **orfano dalla UI** e sopravvive solo come soggetto del test di
  regressione del fix race — insieme a `selectableStations`. Rimuoverli, e sciogliere
  `AppEnvironment.allowsStationChange` (ancora legato a `selectableStations.count > 1`,
  concettualmente stantio col picker), è **cleanup previsto dentro il B3-full**.
- Il board aperto da Cerca resta bloccato (`allowsStationChange: false`): il picker non
  può spostarne la stazione.

## Policy di naming del catalogo stazioni (C2 — da applicare in blocco nel B3-full)

- **Il nome ufficiale RFI è la fonte di verità** per `name` / `displayName`. Niente nomi
  inventati, commerciali o d'uso comune nel catalogo. Il nome ufficiale è quello che
  compare nella lista `PlaceId` del monitor RFI e nel `<title>Stazione di …</title>`.
  Esempio C2: la stazione di Montegrotto si chiama **"Terme Euganee-Abano-Montegrotto"**;
  "Montegrotto Terme" NON esiste come stazione RFI. Secondo caso applicato (C4): il nome
  ufficiale è **"Venezia S.Lucia"** (placeId 3009), non "Venezia Santa Lucia" che era una
  forma nostra; id rinominato in `venezia-s-lucia`, forma comune scesa a `searchAlias`.
  Delle 17 voci del catalogo è **l'unica** che divergeva dal nome ufficiale RFI.
- **`searchAliases`** = i nomi che l'UTENTE cerca (comuni, storici, colloquiali). Sono
  solo per la ricerca e per la risoluzione canonica: un alias entra nel ranking **con lo
  stesso rango del nome ufficiale**, e `station(named:)` li accetta, così un nome
  persistito sotto una grafia precedente continua a risolvere all'entity. Non compaiono
  mai in UI: ciò che si mostra e si salva resta il nome ufficiale.
- **`boardAliases`** = le forme **brevi che RFI stampa nella colonna destinazione**
  ("TERME EUGANEE", "VENEZIA S.L."). Servono al match della destinazione, non alla
  ricerca. Non mescolare i due campi: hanno contratti diversi.
- **Un solo id per stazione**, uguale allo slug del registry backend. Alla promozione di
  una stazione si RINOMINA l'id esistente, non si aggiunge un doppione. Verificare prima
  che nessuna persistenza contenga id di stazione (oggi: nessuna — le tratte salvate
  memorizzano i *nomi*, non gli id).
- **Debito di disambiguazione**: quando un alias porta a una stazione perché la stazione
  "giusta" non è ancora in catalogo, va annotato nel JSON (`_note`, chiave ignorata dal
  decoder) e rimosso prima di aggiungere la stazione concorrente. Caso vivo: `Abano` /
  `Abano Terme` puntano oggi alla 2829 perché la RFI 364 "ABANO TERME" non è in catalogo.

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
