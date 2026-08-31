# 01 — MVP Scope

> **STATO AL 2026-08-31 (chiusura B3-full).** Questo documento è stato scritto prima
> della Milestone 1 e descriveva un MVP a dati mock. Buona parte è **superata dai
> fatti**: il backend reale è in produzione da giugno 2026 e il catalogo stazioni è
> nazionale da agosto. Le sezioni sotto sono state riallineate; dove una voce è stata
> superata lo dice esplicitamente invece di essere cancellata, così resta leggibile
> perché era in quella lista.
>
> La fonte di verità sulle decisioni è `12_DECISIONS.md`; la cronologia è
> `11_PROGRESS.md`. In caso di conflitto, vincono quelli — questo documento è il più
> vecchio dei tre.

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

### Ricerca stazione — ~~mock~~ **catalogo reale nazionale** ✅

- ~~Lista stazioni mock.~~ **Fatto, e superato**: catalogo nazionale (2435 voci)
  dall'artefatto condiviso `rfi-stations.tsv`, nomi ufficiali RFI (B1, poi B3-full).
- Search field minimale. ✅
- Selezione stazione. ✅ — apre il tabellone della stazione scelta.
- ~~Persistenza ultima stazione selezionata con `AppStorage`.~~ **Non fatto, e non più
  previsto in questa forma**: la stazione iniziale è derivata dalla sorgente
  (`AppEnvironment.initialStation`). Se serve un "ricordati l'ultima stazione", è una
  feature da decidere, non un residuo da completare.

### Dettaglio treno base — **NON implementato**

Mai costruito. Non è un debito nascosto: è una feature mai iniziata, da ridecidere
alla luce del posizionamento (un tabellone fisico non ha un "dettaglio treno"). Se
resta in scope, va rispecificata.

Al tap su una riga, mostrerebbe sheet o navigation detail con:

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

~~Usare `mock/board-response.sample.json` come fonte iniziale.~~ **Superato**: i mock
restano solo come sorgente di Release App Store e per i test/preview. La sorgente reale
è il backend.

## Funzionalità OUT of scope

Ancora fuori scope:

- Login.
- Biglietti.
- Pagamenti.
- Push notification reali.
- Geofencing.
- Language switch avanzato con onboarding dedicato.
- **Scraping lato app** — e resta un vincolo di architettura, non una preferenza: il
  parsing della sorgente appartiene al backend.
- **Ricerca tratta A→B / journey planning (B2)** — **rimosso dallo scope**, non
  rinviato (`12_DECISIONS.md`). Aggiunto qui perché la sua assenza va dichiarata.

Non più fuori scope (superate dai fatti):

- ~~Backend reale.~~ **In produzione da 2026-06**: Edge Function `board` su Supabase,
  con app token e rate limit. È oggi la sorgente dati dell'app.
- ~~Widget.~~ ~~Live Activities.~~ **Prossimo blocco di lavoro**: mockup M1 approvati,
  4 correzioni M1-fix pendenti. (`00_PDR.md` li elenca ancora fra i non-obiettivi: è la
  contraddizione da sanare nella revisione del PRD.)
- ~~Pubblicazione App Store.~~ Non ancora fatta, ma non più esclusa per principio: la
  build Release è configurata (`.mock`, senza token) proprio per poterci arrivare.

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
