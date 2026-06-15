# 12 — Decisions

Decisioni di prodotto/architettura non deducibili dal codice. Tenere conciso.

## Home screen

- **Brand `Binario1` rimosso dall'header**: si confondeva col numero di binario.
  L'header usa un contesto stazione: `STAZIONE DI` (IT) / `STATION` (EN).
- **Titolo stazione = dot-matrix STATICO** (`DotMatrixStationTitleView` /
  `StaticDotMatrixText`), stile LED ferroviario luminoso. **Nessuna animazione
  del titolo per ora.** Sostituisce gli esperimenti animati (LED scan,
  split-flap, FlipBoard a slot fissi), tutti rimossi.
  - Rationale: più pulito, premium e leggibile; meno "finto" delle celle
    meccaniche; nessun rischio di glitch/ghosting/overlap di rendering.
  - Glifi composti da punti LED a gradiente (no box per carattere, no celle),
    glow leggero, overscan verticale → seconda riga mai tagliata. Aggiornamento
    istantaneo al cambio stazione; nome completo nelle accessibility label.
  - Un'eventuale animazione del titolo sarà riconsiderata in futuro solo dopo
    che il design statico è perfetto.
  - Resto della Home invariato, stile Binario1 esistente.
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
