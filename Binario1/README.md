# Binario1 MVP — Documentazione per Claude Code

Questo pacchetto contiene i documenti Markdown per iniziare lo sviluppo di **Binario1**, un MVP iOS SwiftUI ispirato ai tabelloni ferroviari italiani.

## Obiettivo

Creare una prima versione dell'app che mostri arrivi/partenze, orari, ritardi, binari e stato del treno con una UI molto fedele al tabellone fisico: nero opaco, testo LED arancione/ambra, griglia compatta e atmosfera industriale da stazione.

## Lingue MVP

Binario1 deve partire già con una base **bilingue italiano/inglese**:

- lingua principale: italiano (`it` / `it-IT`);
- lingua secondaria: inglese (`en` / `en-US`);
- UI localizzata con **String Catalog** (`Localizable.xcstrings`);
- nessuna stringa hardcoded nelle view;
- status, errori, empty state, disclaimer e accessibility labels tradotti;
- dati ferroviari tecnici normalizzati con enum/status key, poi trasformati in label localizzate lato client.

## Come usare questi file con Claude Code

1. Crea un nuovo progetto iOS SwiftUI chiamato `Binario1`.
2. Copia questi file nella root del repository.
3. Apri Claude Code nella cartella del progetto.
4. Inizia da `CLAUDE.md`.
5. Chiedi a Claude Code di implementare prima l'MVP con dati mock locali.
6. Integra subito la struttura di localizzazione IT/EN.
7. Solo dopo collega il backend/API contract definito nei documenti.

## Ordine consigliato di lettura

1. `CLAUDE.md`
2. `docs/00_PDR.md`
3. `docs/01_MVP_SCOPE.md`
4. `docs/02_ARCHITECTURE.md`
5. `docs/03_DATA_MODEL.md`
6. `docs/04_API_CONTRACT.md`
7. `docs/05_SWIFTUI_IMPLEMENTATION.md`
8. `docs/06_UI_DESIGN_SYSTEM.md`
9. `docs/07_BACKEND_ADAPTER_STRATEGY.md`
10. `docs/08_TESTING_AND_QUALITY.md`
11. `docs/09_CLAUDE_CODE_TASKS.md`
12. `docs/10_LOCALIZATION_IT_EN.md`

## Principio guida

Binario1 deve essere stabile anche quando la sorgente dati cambia. Per questo l'app iOS non deve dipendere direttamente da scraping, endpoint non documentati o parsing fragile. L'app deve parlare solo con un backend controllato dal progetto.

La UI deve sembrare un tabellone vero: non una semplice lista, non una dashboard moderna, ma una piccola stazione luminosa dentro l'iPhone.
