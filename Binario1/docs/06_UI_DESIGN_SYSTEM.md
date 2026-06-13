# 06 — UI Design System

## Direzione visiva

L'app deve sembrare un tabellone ferroviario fisico italiano fotografato dentro un iPhone.

Parole chiave:

- nero opaco;
- LED arancione/ambra;
- griglia industriale;
- dot matrix;
- righe dense;
- binario evidente;
- atmosfera notturna da stazione;
- niente UI generica da travel app.

## Colori

```swift
enum BoardColors {
    static let background = Color(red: 0.015, green: 0.014, blue: 0.012)
    static let panel = Color(red: 0.03, green: 0.028, blue: 0.024)
    static let amber = Color(red: 1.0, green: 0.43, blue: 0.06)
    static let amberDim = Color(red: 0.72, green: 0.26, blue: 0.03)
    static let amberBright = Color(red: 1.0, green: 0.62, blue: 0.18)
    static let gridLine = Color(red: 0.18, green: 0.10, blue: 0.04)
    static let warning = Color(red: 1.0, green: 0.34, blue: 0.05)
}
```

## Typography

Usare font monospaziato.

```swift
enum BoardTypography {
    static let header = Font.system(size: 22, weight: .bold, design: .monospaced)
    static let column = Font.system(size: 11, weight: .semibold, design: .monospaced)
    static let row = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let rowSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let platform = Font.system(size: 16, weight: .bold, design: .monospaced)
}
```

## Header

Il top deve ricordare una cornice metallica.

Elementi:

- `PARTENZE` / `ARRIVI` in italiano oppure `DEPARTURES` / `ARRIVALS` in inglese;
- nome stazione;
- ultimo aggiornamento;
- piccolo stato dati.

Le label inglesi possono essere più lunghe: prevedere truncation controllata o font leggermente ridotto nel titolo.

Esempio italiano:

```text
PARTENZE                              FIRENZE S. M. NOVELLA
AGG. 15:31:22                         DATI LIVE / MOCK
```

Esempio inglese:

```text
DEPARTURES                            FIRENZE S. M. NOVELLA
UPD. 15:31:22                         LIVE / MOCK DATA
```

## Colonne

Italiano:

```text
ORA    TRENO       DESTINAZIONE                 RIT   BIN
```

Inglese:

```text
TIME   TRAIN       DESTINATION                  DEL   PLT
```

Per arrivi:

```text
ORA/TIME  TRENO/TRAIN  PROVENIENZA/ORIGIN  RIT/DEL  BIN/PLT
```

Allineamento:

- ora: sinistra;
- treno: sinistra;
- destinazione: sinistra;
- ritardo: destra o centro;
- binario: centro/destra.

## Row states

### Puntuale

- Amber normale.
- Ritardo `--`.

### In ritardo

- Ritardo più luminoso.
- Piccola animazione pulse opzionale.

### Cancellato

- Testo compatto `CANC` nella colonna ritardo o stato, valido sia in italiano che in inglese per mantenere il look tabellone.
- Opacità leggermente più bassa.
- Note visibili se presenti.

### Binario cambiato

- Binario luminoso.
- Nota `BIN VAR` in italiano o `PLT CHG` in inglese, sempre compatta.

## Effetto LED

MVP semplice:

```swift
Text(value)
    .foregroundStyle(BoardColors.amber)
    .shadow(color: BoardColors.amber.opacity(0.45), radius: 3, x: 0, y: 0)
```

Futuro:

- Custom dot matrix renderer.
- Shader leggero.
- Canvas-based LED text.

## Scanlines

Overlay sottile:

```swift
struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let lineHeight: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.12)))
                    y += lineHeight
                }
            }
        }
        .allowsHitTesting(false)
    }
}
```

## Motion

Animazioni leggere, quasi impercettibili:

- pulse su ritardo;
- flicker minimo casuale;
- transizione row opacity quando refresh;
- nessun movimento teatrale.

La sensazione deve essere quella di una macchina pubblica, non di una landing page.

## iPad

Su iPad:

- board centrata con max width;
- più righe visibili;
- font leggermente più grande;
- possibile sidebar stazioni in futuro.

## Localizzazione e griglia

La traduzione non deve deformare il tabellone. Usare label brevi:

| Concetto | Italiano | English |
|---|---|---|
| Partenze | PARTENZE | DEPARTURES |
| Arrivi | ARRIVI | ARRIVALS |
| Ora | ORA | TIME |
| Treno | TRENO | TRAIN |
| Destinazione | DESTINAZIONE | DESTINATION |
| Provenienza | PROVENIENZA | ORIGIN |
| Ritardo | RIT | DEL |
| Binario | BIN | PLT |
| Aggiornato | AGG. | UPD. |

## Cose da evitare

- Card con corner radius grandi.
- Glassmorphism sulla board.
- Gradienti viola/blu moderni.
- Icone colorate.
- Mappe nella prima schermata.
- Troppe CTA.
- Bottoni da app commerciale.

## Prompt UI interno

> Recreate a real Italian railway station departure board inside SwiftUI. Dark black industrial panel, amber LED dot-matrix typography, compact rows, strict grid, physical board feeling, platform numbers on the right, delays highlighted in the same amber style. Avoid modern cards or generic travel app UI.
