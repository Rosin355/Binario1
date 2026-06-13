# 09 — Task Breakdown per Claude Code

## Come lavorare

Procedere a piccoli passi. Dopo ogni task, compilare e verificare.

## Task 1 — Setup progetto

**Prompt per Claude Code**

```text
Read the documentation in /docs and set up the initial SwiftUI project structure for Binario1 using a feature-first architecture. Create App, Features, Domain, Data, DesignSystem, Localization and Resources folders. Do not implement external APIs yet.
```

**Output atteso**

- Cartelle create.
- App entry pulita.
- Environment mock.
- Resources folder with Localizable.xcstrings placeholder.

## Task 2 — Domain models

```text
Implement the domain models described in docs/03_DATA_MODEL.md: BoardType, TrainStatus, Station, ProviderCodes, Binario1Row, BoardResponse and AppLanguage. Keep them Codable, Equatable and Hashable where appropriate.
```

**Output atteso**

- Modelli compilanti.
- Mock station static helper.

## Task 3 — Mock JSON + DTO

```text
Add the mock JSON file from mock/board-response.sample.json to the app bundle. Implement DTOs and a mapper from DTO to domain models. Add unit tests for decoding and mapping.
```

**Output atteso**

- DTO.
- Mapper.
- Test decode JSON.

## Task 4 — Service protocol + Mock service

```text
Create Binario1Service protocol and MockBinario1Service. The mock service should load board-response.sample.json from the bundle and return BoardResponse asynchronously with a small artificial delay.
```

**Output atteso**

- Protocollo.
- Mock service.
- Error handling base.

## Task 5 — StationBoardViewModel

```text
Implement StationBoardViewModel using @Observable, async/await and the service protocol. Include refresh, board type switching, loading, error, lastUpdated and stale state. Prevent simultaneous refresh calls.
```

**Output atteso**

- ViewModel testabile.
- Test success/failure.

## Task 6 — Localization IT/EN

```text
Create Localizable.xcstrings with Italian and English translations for all MVP UI strings: board titles, column headers, status labels, errors, empty states, stale warnings, disclaimer, accessibility row templates and station search labels. Create a small LocalizationKeys or formatter layer so SwiftUI views do not contain hardcoded user-facing strings.
```

**Output atteso**

- String Catalog IT/EN.
- `AppLanguage` model.
- `LocalizedStatusFormatter`.
- Board labels working in Italian and English.

## Task 7 — Design System

```text
Implement BoardColors, BoardTypography, BoardLayout and BoardEffects using the UI rules in docs/06_UI_DESIGN_SYSTEM.md. Keep the style faithful to a physical Italian railway board.
```

**Output atteso**

- Colori.
- Font.
- Scanline overlay.
- Glow text modifier.

## Task 8 — Main board UI

```text
Build StationBoardView, BoardHeaderView, BoardTypePicker, BoardColumnHeaderView and StationBoardRowView. Use a black industrial board style with amber monospaced LED text, strict columns and dense rows. Avoid modern cards and generic travel UI. Use localized strings for all user-facing labels.
```

**Output atteso**

- Schermata principale.
- Scroll righe.
- Header.
- Toggle arrivi/partenze.

## Task 9 — Refresh behavior

```text
Add manual refresh and auto-refresh every 30 seconds while StationBoardView is visible. Show last update time and stale warning if data is older than 3 minutes.
```

**Output atteso**

- `.refreshable`.
- `.task` loop controllato.
- Warning stale.

## Task 10 — Station search mock

```text
Create a simple StationSearchView with a mock list of Italian stations. Allow selecting a station and persisting the last selected station with AppStorage. Localize search placeholder, empty state and navigation title in Italian and English.
```

**Output atteso**

- Search view.
- Mock stations.
- Persistenza base.

## Task 11 — Train detail

```text
Add a train detail screen opened from a board row. Show train category, number, destination/origin, scheduled time, expected time, delay, platform, status and notes with the same board aesthetic.
```

**Output atteso**

- Dettaglio treno.
- Navigation o sheet.

## Task 12 — Remote service scaffold

```text
Create RemoteBinario1Service that follows docs/04_API_CONTRACT.md, but do not use it by default. Keep base URL configurable and add robust decoding/error handling. Include locale query parameter support.
```

**Output atteso**

- Service remoto pronto.
- Non attivo di default.

## Task 13 — Polish finale MVP

```text
Polish the board UI: spacing, dense rows, amber glow, scanlines, platform emphasis, delay highlight and accessibility labels. The result must feel like a real physical station board, not a modern travel dashboard.
```

**Output atteso**

- UI coerente.
- Accessibilità minima.
- Preview aggiornate.

## Prompt unico per iniziare

```text
Read CLAUDE.md and all files in docs/. Implement Milestone 1 of Binario1: a SwiftUI iOS app with a realistic Italian railway station board UI, mock data, domain models, service protocol, @Observable view model, manual refresh, auto-refresh, loading/error/stale states, IT/EN localization with Localizable.xcstrings, localized accessibility labels and strict amber-on-black board design. Do not integrate external railway APIs yet.
```
