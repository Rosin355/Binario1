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

## Sorgenti dati

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
