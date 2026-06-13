# 05 — SwiftUI Implementation Guide

## Obiettivo

Guidare l'implementazione SwiftUI dell'MVP con sintassi moderna, stato chiaro e UI coerente con un tabellone ferroviario fisico.

## App entry

```swift
@main
struct Binario1App: App {
    private let environment = AppEnvironment.mock

    var body: some Scene {
        WindowGroup {
            StationBoardView(
                viewModel: StationBoardViewModel(
                    service: environment.binario1Service,
                    initialStation: .mockFirenzeSMN
                )
            )
        }
    }
}
```

## ViewModel

```swift
import Observation
import Foundation

@Observable
final class StationBoardViewModel {
    var rows: [Binario1Row] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var boardType: BoardType = .departures
    var selectedStation: Station
    var isStale = false

    private let service: Binario1Service
    private var isRefreshing = false

    init(service: Binario1Service, initialStation: Station) {
        self.service = service
        self.selectedStation = initialStation
    }

    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = rows.isEmpty
        errorMessage = nil

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let response = try await service.fetchBoard(
                stationId: selectedStation.id,
                type: boardType
            )
            rows = response.rows
            lastUpdated = response.generatedAt
            isStale = response.isStale
        } catch {
            errorMessage = "error.dataUnavailable"
            isStale = true
        }
    }

    @MainActor
    func selectBoardType(_ type: BoardType) async {
        guard boardType != type else { return }
        boardType = type
        await refresh()
    }
}
```

## Service protocol

```swift
protocol Binario1Service: Sendable {
    func fetchBoard(stationId: String, type: BoardType) async throws -> BoardResponse
}
```

## Auto refresh nella View

```swift
.task(id: viewModel.boardType) {
    await viewModel.refresh()

    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(30))
        await viewModel.refresh()
    }
}
```

## Localizzazione SwiftUI

Usare `LocalizedStringKey` o `LocalizedStringResource`, evitando stringhe hardcoded.

Esempio:

```swift
extension BoardType {
    var titleKey: LocalizedStringKey {
        switch self {
        case .departures: "board.departures"
        case .arrivals: "board.arrivals"
        }
    }
}
```

Per gli errori, il ViewModel può salvare una key (`String`) e la view può renderla con `Text(LocalizedStringKey(errorKey))`.

## Layout principale

```swift
struct StationBoardView: View {
    @State var viewModel: StationBoardViewModel

    var body: some View {
        ZStack {
            BoardColors.background.ignoresSafeArea()

            VStack(spacing: 12) {
                BoardHeaderView(
                    titleKey: viewModel.boardType.titleKey,
                    stationName: viewModel.selectedStation.displayName,
                    lastUpdated: viewModel.lastUpdated,
                    isStale: viewModel.isStale
                )

                BoardTypePicker(
                    selected: viewModel.boardType,
                    onSelect: { type in
                        Task { await viewModel.selectBoardType(type) }
                    }
                )

                BoardColumnHeaderView()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.rows) { row in
                            StationBoardRowView(row: row)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(BoardEffects.scanlines)
        }
    }
}
```

## Row layout

Usare griglia rigida. Evitare layout casuali.

Colonne consigliate iPhone:

```text
ORA/TIME  54 pt
TRENO/TRAIN 78 pt
DEST/TO   flexible
RIT/DELAY 48 pt
BIN/PLAT  44 pt
```

Su iPad si può aumentare lo spazio destinazione.

## Font

Preferire:

```swift
.monospaced(.body)()
```

oppure:

```swift
.font(.system(size: 14, weight: .medium, design: .monospaced))
```

## Effetti

MVP:

- Glow leggero con shadow arancione.
- Opacità variabile minima tra righe.
- Scanline overlay sottile.
- Background nero non completamente piatto.

Evitare effetti pesanti che peggiorano performance.

## Accessibilità

Ogni row deve avere label localizzata.

Italiano:

```text
Treno regionale 17120 per Prato Centrale, ore 15:36, ritardo 5 minuti, binario 2.
```

English:

```text
Regional train 17120 to Prato Centrale, 15:36, 5 minutes late, platform 2.
```

## Preview

Creare preview con dati mock in entrambe le lingue quando possibile.

```swift
#Preview("Departure Board IT") {
    StationBoardView(
        viewModel: StationBoardViewModel(
            service: MockBinario1Service(),
            initialStation: .mockFirenzeSMN
        )
    )
}
```

## Testabilità

- ViewModel testabile senza SwiftUI.
- Service mock configurabile per success/failure.
- Mapper testabile con JSON sample.

## Nota importante

Non implementare chiamate a sorgenti ferroviarie reali nella app iOS durante l'MVP. La prima versione deve essere pulita come un binario appena posato: UI, modelli, stato e mock data.
