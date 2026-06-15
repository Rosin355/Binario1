# 11 — Progress

Cronologia sintetica delle milestone. Tenere conciso.

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
