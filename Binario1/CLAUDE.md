# CLAUDE.md — Istruzioni per Claude Code

## Ruolo

Agisci come senior iOS engineer specializzato in SwiftUI moderno, architetture testabili, localizzazione iOS e design system custom. Il progetto è un MVP iOS chiamato **Binario1**.

## Obiettivo del progetto

Costruire una app SwiftUI che simuli un tabellone ferroviario italiano per visualizzare arrivi/partenze, ritardi, binari e stato del treno. La UI deve sembrare un vero tabellone fisico da stazione, non una generica app trasporti.

## Branding

- Nome app: **Binario1**.
- Nome progetto Xcode: `Binario1`.
- Bundle display name: `Binario1`.
- Naming Swift consigliato: `Binario1App`, `Binario1Service`, `MockBinario1Service`, `RemoteBinario1Service`.
- Mantenere un tono essenziale, ferroviario, compatto, luminoso.

## Lingue MVP

Binario1 deve essere progettata da subito per **italiano e inglese**.

- Lingua principale: italiano.
- Lingua secondaria: inglese.
- Usare `Localizable.xcstrings`.
- Non inserire stringhe UI hardcoded nelle view.
- Tutte le label principali devono avere chiavi localizzate: `PARTENZE`, `ARRIVI`, `ORA`, `TRENO`, `DESTINAZIONE`, `PROVENIENZA`, `RITARDO`, `BINARIO`, errori, empty state, disclaimer, accessibility labels.
- Supportare un'impostazione app `AppLanguage.system / italian / english`, anche se nel primo MVP può bastare la lingua di sistema.
- Le API devono restituire status key stabili, non testi UI già pronti, quando possibile.

## Regole tecniche

- Usa SwiftUI moderno con `async/await`, `@Observable`, dependency injection e architettura feature-first.
- Target: iOS moderno compatibile con iOS 26 SDK, evitando API sperimentali non necessarie.
- Non usare Combine se non strettamente necessario.
- Non mettere logica di parsing dati ferroviari direttamente nell'app.
- L'app deve consumare un JSON normalizzato da un backend controllato dal progetto.
- Per l'MVP usa prima dati mock locali da `mock/board-response.sample.json`.
- Tutti i service devono essere testabili tramite protocollo.
- La UI deve funzionare bene su iPhone e iPad.
- Mantieni accessibilità minima: Dynamic Type ragionato, VoiceOver labels localizzate, contrasto alto.

## Vincoli UI

- Look fisico: tabellone nero, testo LED ambra/arancione, righe dense, griglia rigida.
- Evita card moderne, glassmorphism, sfondi colorati, gradients eccessivi o rounded UI generica.
- Deve sembrare “un tabellone ferroviario dentro l'iPhone”.
- Usa font monospaziato e micro-effetti: glow leggero, scanlines, dot-matrix/pixel feel.
- La localizzazione non deve rompere la griglia: usare label brevi e fallback compatti.

## Prima milestone — COMPLETATA (archivio)

> **Aggiornamento 2026-08-31.** I 12 punti qui sotto sono fatti. Due regole di questa
> pagina erano vere per la Milestone 1 e **non lo sono più**:
> "usa dati mock locali" e "non integrare API esterne" — l'app consuma il backend reale
> dal 2026-06, e il catalogo stazioni è nazionale (artefatto `rfi-stations.tsv`) dal
> B3-full. Restano invariati i vincoli che contano: **niente parsing di sorgenti
> ferroviarie nell'app** (è del backend), Release App Store su `.mock`, IT/EN in sync,
> nomi di stazione come DATI e non traduzioni.
>
> Per lo stato reale e il lavoro corrente: `docs/11_PROGRESS.md` (sezione "STATO ALLA
> FINE DELLA FASE") e `docs/12_DECISIONS.md`.

Implementato:

1. `StationBoardView`
2. `StationBoardViewModel`
3. `Binario1Service` protocol
4. `MockBinario1Service`
5. Modelli dati
6. UI tabellone arrivi/partenze
7. Refresh manuale e auto-refresh simulato
8. Stato loading/error/stale data
9. Ricerca stazione mock
10. Test base su view model e mapping JSON
11. Struttura bilingue IT/EN con String Catalog
12. Accessibilità localizzata per le righe del tabellone

## Comando iniziale consigliato

Leggi tutti i file nella cartella `docs/`, poi implementa la milestone 1 usando dati mock locali. Non integrare API esterne in questa fase. Crea subito le chiavi di localizzazione italiano/inglese.
