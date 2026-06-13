# 01 — MVP Scope

## Scopo della prima versione

La prima versione deve dimostrare tre cose:

1. La UI tabellone è forte, riconoscibile e credibile.
2. L'architettura è pronta per dati reali senza riscrittura.
3. L'esperienza utente risponde subito a orario, ritardo e binario.

## Funzionalità IN scope

### Home / Station Board

- Header con nome stazione.
- Toggle `Partenze / Arrivi`.
- Lista righe tabellone.
- Timestamp ultimo aggiornamento.
- Indicatore dati obsoleti.
- Refresh manuale.
- Auto-refresh ogni 30 secondi.

### Ricerca stazione mock

- Lista stazioni mock.
- Search field minimale.
- Selezione stazione.
- Persistenza ultima stazione selezionata con `AppStorage`.

### Dettaglio treno base

Al tap su una riga, mostra sheet o navigation detail con:

- categoria + numero;
- origine/destinazione;
- orario programmato;
- orario stimato;
- ritardo;
- binario previsto/confermato;
- stato;
- note;
- fermate mock opzionali.

### Localizzazione IT/EN

- String Catalog con chiavi per italiano e inglese.
- Label del tabellone localizzate.
- Errori, warning e disclaimer localizzati.
- Accessibility labels localizzate.
- Nessuna stringa hardcoded nelle view.

### Stato dati

Gestire:

- loading;
- error;
- stale;
- empty;
- offline/cache.

### Dati mock

Usare `mock/board-response.sample.json` come fonte iniziale.

## Funzionalità OUT of scope

- Login.
- Biglietti.
- Pagamenti.
- Push notification reali.
- Geofencing.
- Widget.
- Live Activities.
- Backend reale.
- Language switch avanzato con onboarding dedicato.
- Scraping lato app.
- Pubblicazione App Store.

## User stories MVP

### US-01 — Vedere partenze

Come viaggiatore voglio aprire l'app e vedere subito le partenze della stazione selezionata, così posso capire quale treno prendere.

**Acceptance criteria**

- La schermata mostra almeno 10 righe mock.
- Ogni riga ha ora, treno, destinazione, ritardo e binario.
- I dati sono leggibili in massimo 3 secondi.

### US-02 — Passare ad arrivi

Come utente voglio passare da partenze ad arrivi, così posso controllare quando arriva un treno.

**Acceptance criteria**

- Toggle chiaro `PARTENZE / ARRIVI`.
- Cambio dati senza crash.
- Stato loading breve o transizione morbida.

### US-03 — Vedere ritardi

Come pendolare voglio vedere subito se un treno è in ritardo.

**Acceptance criteria**

- Ritardo `+5`, `+10`, `+25` evidenziato visivamente.
- Se il treno è puntuale, mostra `--` o `0` in modo coerente.
- Se cancellato, lo stato è evidente.

### US-04 — Vedere binario

Come viaggiatore voglio vedere il binario confermato.

**Acceptance criteria**

- Il binario è nella colonna destra.
- Se non disponibile, mostra `--`.
- Se cambia, la row può animare leggermente il valore.

### US-05 — Lingua inglese

Come viaggiatore non italiano voglio poter usare l'app in inglese, così posso leggere arrivi, partenze, ritardi e binari senza conoscere l'italiano.

**Acceptance criteria**

- Le colonne principali appaiono in inglese se il sistema è impostato in inglese.
- Errori, empty state, warning stale e disclaimer sono tradotti.
- La griglia resta leggibile anche con label inglesi.
- Le stazioni mantengono il nome ufficiale.

### US-06 — Dati obsoleti

Come utente voglio sapere se i dati non sono aggiornati.

**Acceptance criteria**

- Mostra `Aggiornato alle HH:mm:ss`.
- Se il dato supera 3 minuti, mostra warning discreto.

## Priorità

### P0

- UI tabellone.
- Dati mock.
- Modelli dati.
- ViewModel.
- Service protocol.
- Loading/error/stale.
- Localizzazione IT/EN base.

### P1

- Ricerca stazione.
- Dettaglio treno.
- Persistenza ultima stazione.
- Test base.

### P2

- Animazioni LED.
- Effetto scanline.
- Dot-matrix custom rendering.
- iPad layout.

## Definition of Done MVP

- Compila senza warning critici.
- Tutte le schermate principali usano dati mock.
- Nessuna dipendenza da API esterne.
- Il tabellone è visivamente coerente con la reference.
- ViewModel testabile.
- JSON mock decodificato correttamente.
- App utilizzabile su iPhone e iPad simulator.
- String Catalog italiano/inglese presente e usato dalle schermate MVP.
