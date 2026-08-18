# 17 — Spike ViaggiaTreno come fonte SECONDARIA (fallback del tabellone)

**Tipo**: spike di verifica, non un ticket di prodotto. Nessun adapter implementato,
nessuna dipendenza aggiunta, app iOS / registry / path primario RFI non toccati.
**Data**: 2026-08-18. Tutte le chiamate sono state eseguite tra le **12:34 e le 12:39
ora di Roma** dello stesso giorno.
**Contesto**: la decisione "restiamo sulle fonti attuali, niente provider commerciale"
è documentata in [16_GTFS_SPIKE.md](16_GTFS_SPIKE.md) (raccomandazione finale). Il
confronto sistematico tra fonti vive in un **documento di decisione esterno, non ancora
nel repo**; questo spike non lo sostituisce e non ne anticipa il contenuto.

## Domanda

> Lo scraping del monitor RFI resta la fonte **primaria**. ViaggiaTreno (VT) può fare da
> **salvagente**: quando l'HTML di RFI cambia o non risponde, il backend serve dati VT
> reali invece di cadere sul fixture?

**Risposta: NO come fallback automatico.** VT risponde bene ed è tecnicamente più
robusto (JSON), ma **non contiene i treni Italo** e **il binario è assente in circa metà
delle righe**. Un fallback VT non mostrerebbe "gli stessi dati da un'altra porta":
mostrerebbe un **tabellone diverso e incompleto**, senza che l'utente lo sappia.
Raccomandazione: **(b) piano B documentato, non implementato**. Dettaglio in fondo.

> **Fuori scope ma bloccante — leggere l'appendice.** Durante il confronto ho trovato una
> **regressione reale nel path primario RFI**, introdotta dai commit locali non ancora
> pushati. Non l'ho corretta (fuori mandato). Vedi [Appendice A](#appendice-a).

## Metodo

Chiamate reali, poche e distanziate, **appaiate**: per ogni stazione ho interrogato VT e
il monitor RFI **nello stesso momento** (stessa invocazione, pochi secondi di distanza),
così il confronto sul binario è fatto sullo stesso istante di realtà e non su due
fotografie diverse. Il monitor RFI è stato letto con lo **stesso `User-Agent` e lo stesso
parser posizionale** di `supabase/functions/board/rfi.ts`, riprodotto in Python: nessuna
modifica al codice di produzione.

Endpoint base (confermato):
`http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/<metodo>/<parametri>`

## 1. Gli endpoint partenze/arrivi rispondono in modo affidabile?

**Sì, e sono nettamente più veloci di RFI.** 8 chiamate, nessun errore, nessun timeout.

| Chiamata | HTTP | Latenza | Content-Type | Byte | Righe |
|---|---|---|---|---|---|
| `autocompletaStazione/padova` | 200 | 0,157 s | `text/plain` | 42 | 2 |
| `autocompletaStazione/roma ter` | 200 | 0,100 s | `text/plain` | 20 | 1 |
| `partenze/S02581/<data>` (Padova) | 200 | 0,334 s | `application/json` | 61.114 | 25 |
| `partenze/S08409/<data>` (Roma T.) | 200 | 0,298 s | `application/json` | 80.431 | 32 |
| `arrivi/S02581/<data>` (Padova) | 200 | 0,331 s | `application/json` | 59.547 | 24 |
| RFI `Monitor?placeId=2000` (confronto) | 200 | 1,412 s | `text/html` | 346.830 | 40 |
| RFI `Monitor?placeId=2416` (confronto) | 200 | 1,760 s | `text/html` | 318.584 | 40 |

**Latenza VT 0,10–0,33 s contro 1,41–1,76 s di RFI** (4–5× più veloce, e ~5× meno byte).
Il parametro data va passato nel formato JS `Tue Aug 18 2026 12:34:28 GMT+0200`,
URL-encoded. Ogni riga JSON ha **74 campi**.

Campione reale (partenze Padova, 12:34, prime righe):

```
12:22 REG  3513  VENEZIA S.LUCIA     binProg=2  binEff=null ritardo=8   nonPartito=true
12:31 EC   41    VENEZIA S.LUCIA     binProg=null binEff=null ritardo=-13
12:46 REG  16414 TREVISO CENTRALE    binProg=9  binEff=9    ritardo=0
12:46 (vuoto) 9732 MILANO CENTRALE   binProg=null binEff=null ritardo=0
```

**Nota HTTPS**: `https://www.viaggiatreno.it/...` risponde **301 con `Location:` in
`http://`** — l'API in pratica è **solo HTTP in chiaro**. Lato Edge Function è
server-to-server (nessun problema ATS iOS), ma resta una fonte non autenticata e
alterabile in transito: un fallback su HTTP semplice è una fonte meno fidata di RFI
(HTTPS).

## 2. Il BINARIO: il punto decisivo

**È il punto su cui il fallback fallisce.** Confronto appaiato, stesso istante.

### Padova (RFI pubblica il binario su **40/40** righe)

Su 25 treni VT, tutti presenti anche su RFI:

| Esito | Righe |
|---|---|
| Binario VT **uguale** a RFI | **11** |
| Binario VT **diverso** da RFI | **2** |
| Binario VT **assente** (entrambi i campi `null`) | **12** |

- VT espone un binario in **13/25 righe (52%)**; nelle altre 12 non ha nulla da mostrare.
- Dove lo espone, **2 volte su 13 contraddice RFI**:
  - treno **3513** → VT `binarioProgrammatoPartenza = 2`, **RFI = 5**
  - treno **3994** → VT `binarioProgrammatoPartenza = 5`, **RFI = 2**
- `binarioEffettivoPartenzaDescrizione` è valorizzato in **1 riga su 25**. Le altre
  hanno solo il **programmato**, che è esattamente il dato che cambia all'ultimo minuto.

### Roma Termini (RFI pubblica il binario su **5/40** righe)

Comportamento opposto e istruttivo: a Roma **RFI tace deliberatamente** finché il binario
non è confermato. Dove RFI pubblica: **3 uguali, 0 diversi, 1 VT-vuoto**. In compenso VT
espone un **binario programmato su 12 righe dove RFI non mostra nulla**.

Questo non è un vantaggio: è la stessa divergenza vista a Padova, dal lato opposto. VT
serve il *programmato*, RFI serve il *confermato*. Su una stazione di testa come Roma
Termini il programmato cambia spesso — mostrarlo come se fosse il binario reale
violerebbe la regola "mai dati inventati", in una forma peggiore del `--`.

**Conclusione del punto 2**: il binario VT è **incompleto (52% a Padova) e semanticamente
diverso** (programmato vs effettivo). Un fallback che serve quel campo con la stessa
etichetta del primario mostra un binario sbagliato a una riga su sette, e nessun binario
a una su due.

## 2-bis. Copertura: VT non contiene Italo

Scoperta non prevista dal brief e più grave del binario.

**Padova, stessa finestra oraria (12:22 → 14:10)**: RFI ha **6 treni che VT non ha**.
Tutti e 6 hanno `alt="ITALO"` nella colonna vettore del monitor RFI:
`8906, 8929, 8908, 8913, 8981, 8984`. In VT: **zero treni Italo**.

**Roma Termini, finestra VT (fino alle 14:15)**: **7 treni assenti da VT** — 6 Italo
(`8905, 8947, 8134, 8907, 9923, 9940`) + `CB706` (Trenitalia, numero alfanumerico).

ViaggiaTreno è il sistema **di Trenitalia**: espone il proprio parco treni, non il
tabellone di stazione. RFI, che gestisce l'infrastruttura, li vede tutti. Su Roma Termini
un fallback VT **cancellerebbe silenziosamente ~15% delle partenze**, incluse quelle di
un intero operatore.

Nella direzione opposta: 3 treni sono in VT ma non su RFI (Roma) — `9519` e `553` con
`inStazione: true` (già al binario/appena partiti, RFI li ha tolti) e `4620` con
`circolante: false`. Non è un guadagno: è rumore di coda.

## 3. `autocompletaStazione` risolve Padova e Roma Termini?

**Sì, ma NON con i nostri slug.** Risposta `text/plain`, righe `NOME|CODICE`.

| Query | Risposta |
|---|---|
| `padova` | `PADOVA\|S02581` + `PADOVA CAMPO MARTE\|S02650` |
| `roma ter` | `ROMA TERMINI\|S08409` |
| `roma` | 424 byte, **9 stazioni**, `ROMA TERMINI\|S08409` prima ma seguita da ANAGNINA, AURELIA, BALDUINA, … |
| **`roma-termini`** (nostro slug) | **HTTP 200 con corpo VUOTO (0 byte)** |

Punti di attenzione:
- **Il nostro slug non è una query valida**: il trattino non viene normalizzato. Servirebbe
  `slug → "roma termini"` prima di interrogare. Mappatura non gratuita.
- La risposta è **ambigua per costruzione** (prefix match): `padova` restituisce 2
  risultati, `roma` ne restituisce 9. Serve una regola di match esatto sul nome, non
  "prendi la prima riga".
- Il codice VT (`S02581`, `S08409`) è un **terzo sistema di id**, diverso sia da
  `rfiLivePlaceId` (2000 / 2416) sia da `prmScheduledId`. Il registry oggi documenta
  esplicitamente il rischio di mescolare sistemi di id: aggiungerne un terzo va fatto con
  lo stesso rigore (campo separato, verificato uno per uno, mai dedotto).

**Vale però la pena registrarlo**: i codici VT **coincidono con quelli visti nei feed
GTFS** dello spike 16 (`830002581` Padova, `830008409`/`S08409_1` Roma Termini). È un
riscontro incrociato utile e gratuito — vedi la raccomandazione.

## 4. Mappatura VT → `BoardResponse`

Contratto di riferimento: `interface BoardResponse` in `supabase/functions/board/index.ts`.

| Campo `BoardResponse` | Campo VT | Mappabile | Note |
|---|---|---|---|
| `station.id` (slug) | — | ❌ | Resta nostro; VT non lo conosce. |
| `station.name` | da `autocompletaStazione` | ⚠️ | Nome VT in maiuscolo, diverso dal `displayName` del registry. |
| `station.sourcePlaceId` | codice `S+5` | ⚠️ | **Terzo sistema di id**: richiede campo dedicato, non riusare `rfiLivePlaceId`. |
| `boardType` | endpoint `partenze` / `arrivi` | ✅ | Endpoint separati, simmetrici. |
| `source.kind` | — | ⚠️ | Servirebbe un valore nuovo (`"viaggiatrenoLive"`): oggi è `"rfiLive"` fisso e l'app lo legge. |
| `source.updatedAt` | — | ❌ | **VT non espone un "aggiornato alle"**. RFI sì. Si potrebbe usare solo `fetchedAt`. |
| `rows[].scheduledTime` | `orarioPartenza` / `orarioArrivo` | ✅ | Epoch ms → `HH:mm` in `Europe/Rome`. Più solido della stringa RFI. |
| `rows[].trainNumber` | `numeroTreno` | ✅ | Numerico in VT, stringa nel contratto. Attenzione: RFI ha numeri **alfanumerici** (`CB706`). |
| `rows[].destination` | `destinazione` / `origine` | ✅ | Maiuscolo, stessa forma di RFI. Per `arrivi` il campo utile è `origine`. |
| `rows[].category` | `categoriaDescrizione` | ⚠️ | `categoria` è **vuoto per tutte le Frecce** (6/25 Padova, 11/32 Roma). `categoriaDescrizione` funziona ma arriva con **spazio iniziale** (`" FR"`). **Perdita di fedeltà**: il treno 8311, che RFI marca `FRECCIARGENTO`, in VT è `" FR"` → il nostro `FA` diventerebbe `FR`. |
| `rows[].platform` | `binarioEffettivo…` ?? `binarioProgrammato…` | ❌ | **Vedi punto 2.** Assente nel 48% delle righe a Padova; semantica diversa (programmato vs confermato). |
| `rows[].delayMinutes` | `ritardo` | ⚠️ | **VT restituisce anche valori negativi** (anticipo: `-13`, `-16`, `-8`). Il contratto vuole `number` con `0 = nessun ritardo`: i negativi vanno azzerati come già fa `normalizeDelay`. Inoltre `ritardo: 0` su un treno lontano significa "non ancora noto", non "in orario". |
| `rows[].status` | derivato | ⚠️ | `inStazione: true` → `departing` (segnale **pulito**, molto meglio dell'euristica HTML). `cancelled`: **non verificabile** — vedi punto 5. |
| `rows[].notes` | `subTitle` | ❌ | `subTitle` era `null` su tutte le 81 righe raccolte. Nessuna sorgente di note. |
| `rows[].id` | derivato | ✅ | Stessa formula `categoria-numero-dataThh:mm`. |

**Lacune non colmabili**: `platform` (parziale e divergente), `source.updatedAt`
(assente), `notes` (assente), fedeltà di `category` (FA→FR), e la **copertura Italo**.

**Cosa VT fa meglio di RFI**: orari come epoch (niente parsing di stringhe), `inStazione`
come flag esplicito invece di una classe CSS, e un formato che non si rompe se cambia il
layout del sito. Sono vantaggi reali, ma su campi che oggi **non sono il problema**.

## 5. Casi limite

| Caso | Comportamento osservato | Come lo riconosciamo |
|---|---|---|
| **Stazione inesistente** (`partenze/S99999/…`) | **HTTP 200 + `[]`** (2 byte) — **non** 404 | ⚠️ **Indistinguibile da "nessun treno".** Un typo nel codice produce un tabellone vuoto silenzioso. Va trattato come errore, non come board vuoto. |
| **Codice malformato** (`partenze/XYZ/…`) | **HTTP 200 + `[]`** | Stesso problema. |
| **Data malformata** | **HTTP 400**, `text/html;charset=ISO-8859-1`, corpo `Error ` | Unico errore esplicito. **Il corpo non è JSON**: un `res.json()` cieco esploderebbe. |
| **HTTP 204** | **Non osservato** in nessuna delle 5 prove. Il caso "vuoto" si presenta come 200 + `[]`. | Non posso confermare che 204 esista su questi endpoint. |
| **`soluzioniViaggioNew`** | **HTTP 404**, `text/html`, corpo `Error ` | **Confermato dismesso.** B2 resta chiuso da questa strada, come già stabilito. |
| **Treni cancellati / parziali** | **NON VERIFICATO**: nelle 81 righe raccolte `provvedimento` era **0 ovunque** e `riprogrammazione` **`"N"` ovunque**. Nessun treno soppresso nel campione. | ❗ La mappatura di `cancelled` è **la lacuna più pericolosa** e resta **non dimostrata**. |
| **`circolante: false`** | Presente su **13/25** righe a Padova e **24/32** a Roma — su treni perfettamente regolari | ❗ **NON significa cancellato.** Sembra indicare "non ancora in circolazione/tracciato". Mapparlo su `cancelled` renderebbe soppressa metà del tabellone. Trappola documentata. |
| **`ritardo` negativo** | `-13`, `-16`, `-8` osservati | Anticipo. Da azzerare, mai mostrato. |
| **`ritardo: 0` su treno futuro** | Frequentissimo (14/25 a Padova) | Ambiguo: "in orario" o "non ancora noto". RFI in questi casi lascia la cella **vuota**, che è più onesto. |

## Rischi noti

1. **Copertura non equivalente (Italo assente)** — il rischio principale. Un fallback
   automatico degraderebbe il tabellone in modo **invisibile all'utente**, che vedrebbe
   una board plausibile ma mancante di un operatore intero.
2. **Binario assente o divergente** — il campo che dà il nome all'app.
3. **Errori mascherati da 200 + `[]`** — un id sbagliato non fallisce: svuota.
4. **`cancelled` non mappabile con prove** — mostrare "in orario" un treno soppresso è il
   peggior fallimento possibile per questa app.
5. **API non contrattualizzata e in chiaro (HTTP)** — nessuna garanzia di stabilità né
   SLA; VT è un backend interno di Trenitalia, non un'API pubblica versionata. Lo stesso
   rischio "può cambiare senza preavviso" che abbiamo su RFI, con in più il downgrade a
   HTTP.
6. **Due semantiche sotto la stessa etichetta** — se la board a volte è RFI e a volte VT,
   "Binario 2" significa due cose diverse a seconda del giorno. Un fallback andrebbe
   comunque **dichiarato in UI**, non solo nel campo `isFallback`.

## Raccomandazione

### **(b) Tenerlo come piano B documentato, NON implementarlo ora.**

Motivazione: VT è tecnicamente in salute (veloce, JSON, stabile in queste prove) ma **non
è la stessa board**. Le due proprietà che il fallback dovrebbe preservare — *tutti i treni
della stazione* e *il binario* — sono proprio quelle che perde: **zero treni Italo**, e
binario assente in **12 righe su 25** a Padova. Implementarlo oggi produrrebbe un
salvagente che, nel momento in cui serve, mostra dati reali ma **incompleti e in parte
contraddittori**, senza che nessuno se ne accorga.

Non è nemmeno chiaro che sia meglio del comportamento attuale: oggi, quando RFI cade, il
backend serve **cache stale marcata `isStale`** (`staleFallback`) e solo in ultima istanza
un 502 strutturato. Una cache di 30 secondi fa marcata come vecchia è più onesta di una
board VT fresca ma monca.

Scartare (a) e (c):
- **(a) fallback automatico — scartata ora.** Diventa interessante **solo se** VT
  aggiunge Italo (verificabile in 5 minuti rifacendo il confronto) **oppure** se
  accettiamo esplicitamente un fallback dichiarato in UI come "dati parziali, solo
  Trenitalia, binario non garantito". È una decisione di prodotto, non tecnica.
- **(c) scartare — no.** Sarebbe uno spreco: due sottoprodotti sono utili subito.

### Due cose da portarsi a casa comunque, senza implementare l'adapter

1. **`autocompletaStazione` come strumento offline per il registry.** Risolve
   nome → codice ed è **incrociabile con i codici GTFS** già visti nello spike 16
   (`S02581`/`830002581`, `S08409`/`830008409`). Non risolve il nostro problema (il
   registry ha bisogno di `rfiLivePlaceId`, un id RFI, che VT **non** espone), ma è una
   **seconda conferma indipendente** che stiamo parlando della stazione giusta quando ne
   attiveremo di nuove. Uso da riga di comando in fase di aggiunta stazione, **mai come
   dipendenza runtime**.
2. **`inStazione` come modello del segnale "in partenza".** VT lo espone come booleano
   pulito. È il confronto che ha fatto emergere la regressione in appendice.

### Condizioni per riaprire

Rifare questo spike (mezza giornata) se: VT inizia a esporre Italo; oppure RFI cambia
HTML in modo non tamponabile e serve *qualsiasi* fonte reale; oppure il prodotto accetta
un fallback dichiaratamente parziale.

---

## Appendice A — Regressione trovata nel path primario RFI (fuori scope, non corretta)

Emersa confrontando il tabellone RFI reale con VT. **Non l'ho corretta**: il mandato di
questo spike esclude il path primario. La riporto perché è **nei commit locali non ancora
pushati**, e uno di quelli tocca `supabase/**` → **al push fa deploy automatico**.

### Cosa succede

Il fix dei commit `5d8a7c2` (Swift) e `9e27f14` (backend) fa catturare l'intero
`<tr …>…</tr>` e poi testa `/lampeggi/i` sull'elemento. Ma nell'HTML RFI di oggi la
stringa **non compare mai come classe della riga**: compare come **id/classe di una
colonna presente in OGNI riga**:

```html
<tr id="3513" name="treno" class="row yellowRow">     ← nessun "lampeggi" qui
  …
  <td id="RExLampeggio" class="ExLampeggio_classtd" aria-label="No" …>   ← qui, sempre
```

Conteggio sull'HTML scaricato (Padova, 12:34):

| Misura | Valore |
|---|---|
| Righe dati | 40 |
| Righe il cui **`<tr>` intero** contiene `lampeggi` | **40 / 40** |
| Righe il cui **tag di apertura `<tr>`** contiene `lampeggi` | **0 / 40** |
| Righe realmente "in partenza" (`<img>` nella cella `RExLampeggio`) | **2 / 40** (treni 8906, 8929) |
| Occorrenze totali di `Lampeggio` nel documento | 82 |

### Effetto

`isDeparting` era **sempre falso** prima del fix (codice morto, come diagnosticato) ed è
**sempre vero** dopo. Poiché `normalizeStatus` valuta `cancelled → delayed → departing →
onTime`, **ogni riga senza ritardo diventa `departing`**: nel campione di oggi **32 righe
su 40 mostrerebbero "in partenza"** invece di "in orario". La verità è 2.

Il difetto è **identico nei due port**: `supabase/functions/board/rfi.ts` (riga con
`/lampeggi/i.test(row)`) e `Binario1/Binario1/Services/RFIStationMonitorParser.swift:79`
(`row.localizedCaseInsensitiveContains("lampeggi")`).

Il test deno `blinking row class marks the train as departing` passa perché la **fixture**
contiene `<tr class="riga lampeggia">` — una forma che l'HTML reale di RFI **non ha**.
La fixture non riproduce la struttura `RExLampeggio` osservata oggi.

### Secondo difetto, stessa area

`info` è letto da `text(7)`, cioè proprio la cella **`RExLampeggio`** (la colonna "In
partenza"), non dalla cella dei dettagli. Struttura reale delle 9 celle:

```
[0] RVettore  [1] RCategoria  [2] RTreno  [3] RStazione  [4] ROrario
[5] RRitardo  [6] RBinario    [7] RExLampeggio           [8] RDettagli
```

Quindi `notes` riceve il contenuto della colonna "in partenza" (vuoto o un'immagine), e
il ramo `info.contains("stazione")` è a sua volta codice morto.

### Segnale corretto (per chi implementerà il fix)

"In partenza" = presenza di un `<img>` nella cella `RExLampeggio`; l'assenza è marcata
`aria-label="No"`. Verificato: 2/40 righe, coerenti con i due treni in partenza al minuto
della lettura.

**Nessuna modifica applicata.** Va aperto un ticket a sé, con una fixture rigenerata
dall'HTML reale, **prima** di pushare i commit locali.

## Riproducibilità

```bash
# Codice stazione (attenzione: il nostro slug con trattino NON funziona)
curl -s "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/autocompletaStazione/padova"
curl -s "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/autocompletaStazione/roma%20ter"

# Partenze (formato data JS, URL-encoded)
D=$(TZ=Europe/Rome LC_ALL=C date "+%a %b %d %Y %H:%M:%S GMT%z")
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$D")
curl -s "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/partenze/S02581/$ENC"

# Confronto appaiato: stesso istante sul monitor RFI
curl -s "https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000"

# Casi limite
curl -s -o /dev/null -w "%{http_code}\n" ".../partenze/S99999/$ENC"        # 200 + []
curl -s -o /dev/null -w "%{http_code}\n" ".../partenze/S02581/non-una-data" # 400
curl -s -o /dev/null -w "%{http_code}\n" ".../soluzioniViaggioNew/S02581/S08409/2026-08-18T13:00:00" # 404
```

Le risposte grezze vivono in una cartella scratch fuori dal repo: **nessun payload VT o
HTML RFI è stato committato**, nessuna credenziale usata.

## Limiti di questo spike

- **Una sola finestra temporale** (12:34–12:39 di martedì 18/08/2026), 2 stazioni. Il
  comportamento del binario può variare per ora del giorno e giorno della settimana; la
  differenza Padova/Roma mostra già che **varia per stazione**.
- **Nessun treno cancellato nel campione**: la mappatura di `cancelled` resta la lacuna
  non dimostrata. Andrebbe ricontrollata durante uno sciopero o un guasto.
- Non ho testato `arrivi` su Roma Termini, né `andamentoTreno` / `cercaNumeroTreno`
  (fuori dalla domanda del fallback di stazione).
- Non ho valutato rate limit o comportamento sotto carico: 8 chiamate totali, deliberatamente
  poche. Un fallback in produzione andrebbe verificato anche su quello.
- Nessuna verifica dei **termini d'uso** di ViaggiaTreno: prima di dipenderne in
  produzione andrebbe chiarito, come già rilevato per i feed GTFS nello spike 16.
