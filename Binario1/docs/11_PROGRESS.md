# 11 — Progress

Cronologia sintetica delle milestone. Tenere conciso.

## 2026-08-18 — FIX: `isDeparting` del parser RFI (Swift + backend), fixture rifatte da HTML reale

Stato: **corretto e verificato su entrambi i lati.** Chiude la regressione registrata
nell'Appendice A di [17_VIAGGIATRENO_SPIKE.md](17_VIAGGIATRENO_SPIKE.md). Nessun push
ancora: `9e27f14` tocca `supabase/**` e va in deploy automatico.

### Il segnale vero, misurato (non dedotto)
Su 3 download reali (Padova partenze, Roma Termini partenze, Padova arrivi — 40 righe
ciascuno) il tag di apertura `<tr>` ha **solo due valori**, `row yellowRow` e
`row greyRow`, 20 e 20: è **zebratura**, non porta informazione di board. Il segnale
"in partenza" è un `<img class="exlampeggio" alt="Si">` **dentro la cella
`RExLampeggio`** (colonna `<th id="HInArrivo">` = "In partenza"/"In Arrivo"); quando il
treno non è in partenza la cella è vuota e il `<td>` porta `aria-label="No"`.
Conteggi reali: **2/40** a Padova (8906, 8929), **2/40** a Roma (12657, 20245),
**0/40** sugli arrivi. Due icone alternate (`LampeggioGrey.png` / `LampeggioGold.png`)
= i due fotogrammi del lampeggio, entrambe con `alt="Si"` → il segnale è la presenza
dell'`<img>`, non il nome del file. **Segnale non ambiguo → `isDeparting` resta attivo**
(non c'era motivo di disattivarlo).

### Cosa era rotto
- `/lampeggi/i` sull'intero `<tr>`: la sottostringa è nell'**id/classe di quella cella**
  (`RExLampeggio` / `ExLampeggio_classtd`), quindi presente in **40/40** righe e in
  **0/40** tag di apertura. `isDeparting` è passato da sempre-falso a **sempre-vero**;
  con la precedenza `cancelled → delayed → departing → onTime`, **32 righe su 40**
  avrebbero mostrato "in partenza" invece di "in orario".
- `info = text(7)` leggeva proprio la cella `RExLampeggio` (vuota), non `RDettagli`
  (cella 8). Quindi `notes` era sempre vuoto **e** `isCancelledRow`, che ispeziona
  `delay + info`, non ha mai avuto un `info` reale da leggere.
- L'euristica `info contiene "stazione"` era doppiamente priva di base: leggeva la cella
  sbagliata e sulla pagina vera `IN STAZIONE` compare **solo nel banner avvisi**, fuori
  dalla tabella. **Rimossa.**

### Correzione (allineata Swift ↔ backend)
`isBoardingCell(cella 7)` = presenza di `<img>`; `detailsNote(cella 8)` = solo il blocco
`testoinfoaggiuntive` che segue il titolo **Informazioni**, mai l'itinerario "Fermate
successive" (~2 KB per riga). Stessa logica, stessi nomi, in
`Binario1/Services/RFIStationMonitorParser.swift` e `supabase/functions/board/rfi.ts`.

### Fixture: da inventate a reali
Le vecchie fixture erano scritte a mano e marcavano il treno in partenza con
`<tr class="riga lampeggia">`, forma **inesistente** nella pagina vera: verificavano
l'invenzione, non RFI. Sostituite con **estratti verbatim** di download reali
(2026-08-18): `rfi-padova-departures.sample.html` (4 righe) e
`rfi-roma-termini-departures.sample.html` (5 righe, con binari mancanti reali e il
numero treno alfanumerico `CB706`). Uniche modifiche: righe scartate e payload base64
dei loghi accorciati (il parser non legge `src`). Copia identica per il backend in
`rfi_fixtures.ts` (importata solo dai test, mai da `index.ts`). Policy in
[12_DECISIONS.md](12_DECISIONS.md).

### Verifiche rosso→verde
- **Backend**: 4 test rossi con il difetto reintrodotto → **29/29 verdi** col fix
  (`deno test`, `deno check` pulito). Erano 21 test.
- **iOS**: 3 test rossi con il difetto reintrodotto
  (`rfiDepartingComesOnlyFromTheBoardingColumn`, `rfiInfoComesFromTheInformazioniNote`,
  `rfiMapperBuildsValidRows`) → **125/125 verdi** col fix, 0 falliti, più i 10 UI test.
  **123 → 125**: nessun test perso, +2 nuovi test di regressione dedicati.

### Gap noto lasciato aperto di proposito (fuori mandato)
`updatedAt` **non viene catturato** dalla pagina reale: RFI scrive "aggiornato il
18/08/2026 alle ore 12:34:29" spezzato su più `<span>`, e il pattern non trova un
`HH:mm`. Il backend ricade quindi sul proprio `fetchedAt` — onesto, ma il timestamp
della sorgente si perde. **Non toccato** (nessuna modifica al contratto in questo
ticket); ora è **asserito nei test** su entrambi i lati perché resti visibile invece di
essere dato per funzionante.

### Non verificabile con dati reali
Nessun treno cancellato nei download: la cancellazione resta coperta **solo** dal
predicato (`isCancelled` / `isCancelledRow` su riga costruita in memoria), non da una
fixture. Dichiarato nei test e in [12_DECISIONS.md](12_DECISIONS.md).

### Vincoli rispettati
Guardrail Release/`.mock` e A3 intatti (nessuna modifica a `Binario1App.swift`,
`BackendEndpointConfig.swift`, xcconfig); A1/B1/B4/B3-lite e il fix della race non
toccati; nessuna modifica a `registry.ts`, `index.ts`, `hardening.ts`.

## 2026-08-18 — Spike ViaggiaTreno come fonte SECONDARIA (fallback tabellone)

Stato: **spike chiuso, nessun codice scritto.** Documento:
[17_VIAGGIATRENO_SPIKE.md](17_VIAGGIATRENO_SPIKE.md). App iOS, registry e path primario
RFI non toccati. 8 chiamate reali distanziate, confronto **appaiato** VT/RFI nello stesso
istante (Padova e Roma Termini, 18/08/2026 ore 12:34–12:39).

- **Raccomandazione: (b) piano B documentato, NON implementato.** VT risponde bene
  (JSON, 0,10–0,33 s contro 1,41–1,76 s di RFI) ma **non è la stessa board**.
- **Bloccanti**: VT **non contiene i treni Italo** (6 mancanti a Padova e 6 a Roma nella
  stessa finestra oraria); il **binario è assente in 12 righe su 25** a Padova e dove
  c'è **contraddice RFI 2 volte su 13** (è il *programmato*, non il confermato).
- `autocompletaStazione` funziona (`PADOVA|S02581`, `ROMA TERMINI|S08409`) ma **non con i
  nostri slug**: `roma-termini` → 200 con corpo vuoto. Utile come strumento **offline** di
  verifica incrociata quando si aggiungono stazioni, mai come dipendenza runtime.
- Casi limite: stazione inesistente → **200 + `[]`** (non 404: errore mascherato da board
  vuoto); data malformata → 400 non-JSON; `soluzioniViaggioNew` → **404 confermato**
  (B2 resta chiuso da questa strada); `circolante: false` **non** significa cancellato.
- `cancelled` **non verificato**: nessun treno soppresso nelle 81 righe del campione.

### Regressione trovata nel path primario RFI — NON corretta (fuori mandato)
Il fix di `5d8a7c2` / `9e27f14` cattura l'intero `<tr>` e testa `/lampeggi/i`, ma
nell'HTML RFI reale quella stringa è l'id di una **colonna presente in ogni riga**
(`<td id="RExLampeggio">`), non una classe della riga: **40/40 righe** contengono
`lampeggi`, **0/40** nel tag di apertura. `isDeparting` era sempre falso, ora è **sempre
vero** → oggi **32 righe su 40** mostrerebbero "in partenza" invece di "in orario" (le
reali sono **2**). Stesso difetto nei due port (`rfi.ts` e `RFIStationMonitorParser.swift`).
Il test deno passa perché la **fixture** usa `<tr class="riga lampeggia">`, forma che
l'HTML reale non ha. Inoltre `info` = `text(7)` legge la colonna `RExLampeggio`, non
`RDettagli` (cella 8). Segnale corretto: `<img>` dentro `RExLampeggio` (`aria-label="No"`
quando assente). **Da chiudere in un ticket dedicato PRIMA di pushare** i commit locali.

## 2026-08-12 — Spike GTFS: fattibilità di B2 (ricerca tratta A→B)

Stato: **spike chiuso, nessun codice scritto** (registrato a posteriori il 18/08/2026).
Documento: [16_GTFS_SPIKE.md](16_GTFS_SPIKE.md). Nessuna dipendenza aggiunta, app non
toccata, nessun dato GTFS committato.

- **Esito: B2 NON è realizzabile con dati aperti.** Verifica empirica su feed scaricati:
  Toscana (Padova assente) e Liguria (contiene AV, ma **0 trip** che tocchino sia Padova
  sia Roma Termini). I GTFS ferroviari italiani sono **regionali e frammentati per
  contratto di servizio**; nessun feed nazionale pubblico, nessun feed Veneto/Lazio.
- **Raccomandazione accolta: (c) rinviare B2.** Restiamo sulle fonti attuali, niente
  provider commerciale per ora. Da rifare (mezza giornata) al cambio orario di dicembre 2026.
- Nota: anche con i feed, il GTFS **non contiene binari né ritardi** — resterebbe uno
  strato orario con il live sopra.

## 2026-07-15 — Suite VERDE: risolti i 7 test rossi storici (2 bug distinti)

Stato: completata. **123/123 test passano** — prima volta senza rossi. I 7 fallimenti
"pre-esistenti" trascinati da mesi erano **due bug diversi**, uno nei test e uno nel
codice di produzione.

### Bug 1 — 6 test `StubURLProtocol` (difetto NEI TEST, non nel prodotto)
- `startLoading` ricavava lo scenario da `host.dropFirst("stub-".count)`, ottenendo
  `"502.example"` invece di `"502"` (il TLD restava attaccato). Nessun `case` matchava
  → **tutti gli scenari cadevano nel `default` 200 + fixture**: il 502/401/empty non
  lanciavano mai, e l'echo del token restituiva la fixture invece dell'header.
  I due test che "passavano" (`…ReturnsDataOn200`, `…MapsRemoteJSONStampedLive`) lo
  facevano **per caso**, perché il default era proprio il 200 che si aspettavano.
- Fix: lo scenario è il **primo label dell'host** dopo `stub-`
  (`host.dropFirst(5).split(separator: ".").first`). Il codice di produzione
  (`URLSessionBackendBoardFetcher`) era ed è corretto: gestiva già 401/502/empty.

### Bug 2 — `rfiMapperBuildsValidRows` (bug REALE nel parser)
- `RFIStationMonitorParser.rows` estraeva le righe con `"<tr[^>]*>(.*?)</tr>"`, il cui
  gruppo catturato è **solo il contenuto interno**: l'attributo `class` del `<tr>` non
  ne faceva parte. Ma RFI marca il treno in partenza con una **classe CSS lampeggiante
  sul `<tr>` stesso** → `isDeparting = row.contains("lampeggi")` era **codice morto**,
  sempre falso. Ogni riga ricadeva su `onTime`/`delayed`; l'unico `departing` possibile
  arrivava dall'info testuale "in stazione".
- Fix: catturare l'elemento intero `"(<tr[^>]*>.*?</tr>)"` (tag di apertura incluso).
  La guardia header (`<th`) e l'estrazione delle `<td>` restano invariate.
- **Il test aveva ragione da sempre**: la fixture contiene `<tr class="riga lampeggia">`
  per il treno 9902 e si aspettava `.departing`.

### Bug gemello nel BACKEND — CORRETTO (commit separato, innesca il deploy CI)
`supabase/functions/board/rfi.ts` è un port dello stesso parser e aveva **lo stesso
difetto** (`/<tr[^>]*>(.*?)<\/tr>/gis` + `/lampeggi/i.test(row)`): in **produzione**
nessuna riga veniva mai marcata `departing` per via della classe lampeggiante (l'unico
`departing` arrivava dall'info testuale "in stazione"). Stesso fix (cattura dell'intero
`<tr>`), in un **commit separato** perché un push su `supabase/**` fa deploy automatico.
- Nuovo test deno `blinking row class marks the train as departing`: fixture con
  `<tr class="riga lampeggia">` e **info vuota**, così la classe è l'unico segnale.
  **Verificato rosso→verde**: prima del fix 20 pass / 1 fail (AssertionError), dopo
  **21 pass / 0 fail**; `deno check` pulito. (Deno installato in locale per la verifica.)

### Test / build
- **123/123 verdi** (nessun test rosso residuo). Debug · build-for-testing · Release ·
  TestFlight tutte OK. Nessuna modifica ai guardrail: Release resta `.mock`.

## 2026-07-15 — BUG CRITICO risolto: righe di una stazione sotto l'header di un'altra

Stato: risolto, con test di regressione committati insieme al fix. Bug segnalato su
device: header "ROMA TERMINI · Backend · RFI online" ma righe di PADOVA.

### Causa (dimostrata con test di riproduzione, non ipotizzata)
Mancava l'invariante **"le righe mostrate provengono dalla stazione selezionata"**.
`refresh()` applicava qualunque risposta arrivasse. Due difetti sommati:
- **(a) Nessuna validazione d'identità**: `rows = response.rows` senza confrontare
  `response.station.id` con `station.id`.
- **(b) La risposta vecchia sopravviveva al cambio stazione**: `guard !isRefreshing`
  faceva **uscire subito** il `refresh(force:)` di `changeStation` se un auto-refresh
  (30s) di Padova era in volo → nessun fetch per Roma; poi la risposta Padova atterrava
  e riempiva `rows` sotto l'header Roma.
Escluse per evidenza: lo **slug inviato era corretto** (il backend rispondeva bene, e
l'header diceva "Backend", non "Backend fixture"); **nessuna cache** non chiavata
(`lastFetchKey` include `station.id`, cache backend `slug:type:locale`, URLCache per URL).

### Fix
- **Token di generazione** (`fetchGeneration`): incrementato da `changeStation`; una
  risposta che atterra con generazione o stazione diverse viene **scartata**.
- **`force` avvia davvero il fetch in parallelo**: `guard force || !isRefreshing` →
  la nuova stazione non si accoda più dietro una richiesta lenta. `isRefreshing` è ora
  un contatore di fetch in volo (`inFlightFetches`) e lo spinner resta finché almeno
  uno è attivo.
- **Validazione d'identità LIVE-ONLY**: se `response.station.id != station.id` →
  stato onesto, righe scartate. Attiva solo quando `liveServedStationIDs != nil`, così
  il **carosello demo mock** (che serve di proposito lo stesso dataset sotto stazioni
  diverse) continua a funzionare — verificato dai test esistenti.
- **Anche i `catch` ignorano gli esiti superati** (una failure vecchia non deve
  sporcare la nuova stazione).
- **Difesa in profondità**: `FixtureBackendBoardFetcher` ora **rifiuta slug diversi da
  `padova`** (prima ignorava lo slug) e il fixture service interno ha
  `fallbackStationID: padova` — chiude anche il path "URL non configurato → fixture per
  qualsiasi stazione".

### Test (committati col fix)
- `rowsFromAnotherStationAreNeverShown` — risposta con `station.id` estraneo → righe
  scartate + stato onesto. **Falliva prima del fix.**
- `inFlightFetchForPreviousStationCannotPaintNewStation` — fetch lento di Padova messo
  in pausa con un gate deterministico (actor), cambio a Roma, poi rilascio: la risposta
  vecchia **non** dipinge la nuova stazione. **Falliva prima del fix.**
- `fixtureFetcherRefusesForeignStationSlug` — la fixture Padova rifiuta altri slug.
- Carosello mock/demo verde: `unlockedStationCanChange`, `lockedStationStaysFixed`,
  `mockServiceLoadsBolognaDepartures`, `mockHighlightUnaffectedByWindowLogic`,
  `boardRefreshDedupesRapidDuplicatesButAllowsForceAndBoardChange`.

### Build / suite
- **123 test, 116 pass / 7 fail** — i 7 sono i **pre-esistenti** (StubURLProtocol +
  rfiMapper), non toccati. Debug/build-for-testing/Release/TestFlight OK.

### Nota
Il bug era osservabile perché Roma è ora selezionabile; con una sola stazione servita
non poteva manifestarsi. La classe di bug (risposta asincrona applicata a uno stato
cambiato) resta coperta dai due test di regressione.

## 2026-07-15 — Ticket B3-lite: cambio-stazione live Padova ↔ Roma Termini

Stato: **COMPLETATA E VERIFICATA END-TO-END (chiusa).** Deploy CI verde (workflow
`Deploy board function`, `deno test` inclusi). Verifiche dell'utente: `roma-termini`
→ **HTTP 200 con righe reali** (IC 511 → Salerno, `sourcePlaceId 2416`), `padova`
invariata, **401 senza token**; **su device** il cambio stazione mostra il tabellone
corretto per ciascuna stazione dopo il fix della race (vedi voce successiva).
Release `.mock`; guardrail A3 intatti; A1/B1/B4 non regrediti.

### Backend (`supabase/functions/board/registry.ts`)
- Aggiunta **Roma Termini** `slug "roma-termini"`, `rfiLivePlaceId "2416"`.
  **Verificato da me** sul monitor RFI pubblico: `Monitor?placeId=2416` → HTTP 200,
  `<title>Stazione di ROMA TERMINI</title>` (e 2000 → PADOVA). Nessun id indovinato.
- **`prmScheduledId` reso OPZIONALE** (`prmScheduledId?: string`) e **omesso** per Roma
  (non verificato). Verificato che **nessun code path live lo usa**: `index.ts` legge
  solo `rfiLivePlaceId`/`slug`/`displayName` (grep: solo commenti + test lo citano).
  Un'eventuale feature scheduled/PRM non va attivata per stazioni senza questo id.
- Fetch/parse **non toccati** (già generici). Test deno aggiornati: 2 stazioni verificate,
  Roma senza prmScheduledId, key ↔ slug allineati, bare "roma" → undefined (404).

### iOS
- **Fetch già parametrico**: `URLSessionBackendBoardFetcher` invia `stationSlug =
  station.id`. Il vincolo non era il fetch ma il picker bloccato + il fallback.
- **Allineamento slug (footgun)**: `Resources/stations.json` marca Padova e Roma Termini
  con `servedByLiveBoard: true`; i loro `id` ("padova", "roma-termini") **coincidono
  esatti** con le chiavi del registry (test lo asserisce → un drift fallisce in CI, non
  in produzione con un 404 silenzioso).
- **Stazioni servite derivate, non duplicate**: `StationCatalog.liveServed` filtra il
  flag del catalogo; `AppEnvironment.selectableStations` / `liveServedStationIDs` ne
  derivano. `allowsStationChange` in live = `selectableStations.count > 1`.
- **FOOTGUN CRITICO risolto**: prima, un fallimento su una stazione qualsiasi faceva
  fallback alla **fixture PADOVA** → si sarebbero viste righe di Padova sotto il nome
  di un'altra stazione. Ora `BackendBoardService` ha `fallbackStationID` (= Padova, la
  stazione che la fixture rappresenta): per altre stazioni lancia il nuovo
  **`BoardUnavailableError.stationNotServed`** invece di ricadere su dati altrui.
- **Stato onesto**: `StationBoardViewModel.isBoardUnavailableForStation` +
  `board.unavailableForStation` ("Tabellone non disponibile per questa stazione" /
  "Live board unavailable for this station"). Attivo se la stazione non è servita
  (nessun fetch tentato) o su `unknown_station`/404. **Mai** errore grezzo, **mai**
  righe di un'altra stazione: `changeStation` e lo stato onesto **azzerano `rows`**.
- **`changeStation`** cicla solo le stazioni selezionabili, ricarica (`force`) e
  confronta **per `id`** (bug trovato in corsa: l'uguaglianza di struct falliva perché
  la voce di catalogo porta metadati diversi dalla costante `Station.padova` → il
  cambio stazione sarebbe rimasto bloccato su Padova).

### Checkpoint — CHIUSO (verificato dopo il deploy CI)
- **`roma-termini` → HTTP 200 con righe REALI** (es. IC 511 → Salerno,
  `sourcePlaceId 2416`); **`padova` invariata**; **401 senza token**. Deploy eseguito
  dalla CI (`workflow_dispatch`, verde, `deno test` inclusi).
- **Su device**: cambiando stazione, Padova e Roma mostrano ciascuna il proprio
  tabellone (righe e nomi coerenti) — dopo il fix della race documentato sotto.
- *(Storico, prima del deploy: `roma-termini` rispondeva 404 `unknown_station` e l'app
  mostrava correttamente lo stato onesto, mai il tabellone di Padova.)*
- **Compatibilità parser per Roma verificata**: l'HTML di `placeId=2416` ha la stessa
  struttura di Padova (`<tbody>` con 40 `<tr>`) → il parser generico produrrà righe.
- **Stazione non servita (es. Firenze)**: `firenze-smn` → 404 `unknown_station` lato
  backend e, lato app, nessun fetch tentato → stato onesto. **Non** mostra Padova/Roma.

### Test
- Nuovi (deterministici, nessuna rete): catalogo deriva `liveServed` == {padova,
  roma-termini} (allineamento slug-registry); `changeStation` cicla le servite, invia
  lo slug giusto e mostra le righe di quella stazione (mai le precedenti); stazione non
  servita → stato onesto **senza fetch**; `BoardUnavailableError` → stato onesto, non
  `error.dataUnavailable`; `BackendBoardService` rifiuta il fallback di un'altra
  stazione ma lo usa per Padova; URL builder porta lo slug selezionato.
  Aggiornato il guardrail `sourceModeMatchesBuildConfiguration` (live ora consente il
  cambio, ma solo tra servite).
- **Suite: 120 test, 113 pass / 7 fail.** I 7 sono i **pre-esistenti** (StubURLProtocol +
  rfiMapper), NON toccati dal diff.
- **Test deno NON eseguiti**: Deno non è installato in questo ambiente (come da storico).
  Vanno eseguiti insieme al deploy.

### Build
- Debug OK · build-for-testing OK · **Release OK** (`.mock`, nessun cambio stazione live)
  · **TestFlight OK** (guardrail A3 intatti).

### Risks / next
- ~~Redeploy della Edge Function richiesto~~ → **FATTO** via CI (workflow
  `Deploy board function`, `deno test` eseguiti dalla pipeline). Roma è live.
- `prmScheduledId` di Roma resta ignoto: nessuna feature scheduled va attivata per Roma.
- Il catalogo iOS e il registry backend restano **due fonti da tenere allineate a mano**
  (il test asserisce gli id attesi; un vero single-source richiederebbe un endpoint
  `/stations`) — candidato per un B3-full.
- I 7 test rossi pre-esistenti restano fuori scope.

## 2026-07-15 — Ticket B1: catalogo stazioni reale + naming canonico in Cerca

Stato: completata (catalogo + ricerca entità + salvataggio canonico + alias). Sorgente
board invariata (Padova/partenze); Release resta `.mock`; A1/A3/B4 non regrediti.

### Problema risolto
- Cerca usava 7 stazioni mock hardcoded + testo libero. Un "Roma" digitato a mano NON
  matchava la riga board "ROMA TERMINI" (regola ≥2-token) → footgun: la tratta salvata
  non si agganciava al treno reale in Viaggi (B4).

### Cosa
- **Catalogo reale** `Resources/stations.json` (17 stazioni ITALIane reali). Schema
  `Station`. `providerCodes` compilati SOLO dove già verificati nel codice (Padova rfi
  1861, Bologna/Firenze/Milano PG/Venezia SL/Reggio) → `null` altrove (mai fabbricati).
  Nuovo campo opzionale `Station.boardAliases: [String]?` (Codable-tollerante).
- **`Services/StationCatalog.swift`**: protocollo + `DefaultStationCatalog` che decodifica
  il JSON dal bundle una volta e lo cache-a; `search` ranked (prefix > token-prefix >
  substring > città, fold diacritici, nessuna espansione abbreviazioni → "s" ≠ SANTA);
  `station(named:)` lookup canonico (displayName o alias). Fallback embedded (stazioni
  già note nel codice) se il JSON manca → mai catalogo vuoto.
- **Cerca usa il catalogo** (`CercaViewModel`): rimossi `mockStations/Routes/Trains`;
  `stations` ora sono ENTITÀ `Station`. Il form tratta risolve PARTENZA/DESTINAZIONE a
  stazioni del catalogo (suggerimenti tappabili) e **salva il displayName CANONICO**
  (es. "Roma Termini"), non il testo digitato. `canSaveCurrentRoute` richiede che
  entrambi i campi risolvano a una stazione → un bare "Roma" è bloccato finché non si
  sceglie "Roma Termini"/"Roma Tiburtina". `saveRoute(_:)` string resta (retro-compat)
  e canonicalizza i nomi noti.
- **Alias-aware matching** (`StationNameMatcher.matches(station:boardName:)`): confronta
  displayName + `boardAliases`, riusando `matches(_:_:)` → la **regola ≥2-token resta
  intatta** (Venezia Mestre ≠ Venezia Santa Lucia). Wired nel `SavedJourneyMatcher`
  condiviso via un `catalog` OPZIONALE (default nil = comportamento stringa attuale):
  RootTabView inietta LO STESSO catalogo in Home (`StationBoardViewModel`) e nel
  resolver B4 → coerenti e alias-aware insieme; i test senza catalogo restano invariati.
- Loc IT/EN: `search.route.pickStations`.

### Checkpoint (verificato sul board LIVE Padova)
- "roma" → **Roma Termini** + Roma Tiburtina come entità selezionabili (catalogo).
- Salvata **Padova → Roma Termini** (canonico), il resolver B4 aggancia la riga live
  "ROMA TERMINI" (oggi IC 594 @ 15:50; in altre fasce AV/FR) → treno reale + orario +
  ritardo. **Binario**: il board live non pubblica binari in questo momento (None su
  tutte le 40 righe) → card "--" ONESTO, comparirà quando RFI assegna.
- **Destinazione abbreviata**: il board live Padova usa forme piene ("ROMA TERMINI",
  "MILANO CENTRALE", "TORINO PORTA NUOVA") + "VENEZIA S.LUCIA" (che già matcha via
  S→SANTA). La forma più spinta "VENEZIA S.L." **matcha via `boardAliases`** (test),
  senza rompere il caso Mestre → nessun limite noto residuo per il board attuale.

### Test
- Nuovi (deterministici, catalogo in-memory, nessuna rete): decode con providerCodes
  null/alias assenti tollerati; catalogo bundlato carica; search "roma" ranking; lookup
  canonico + bare "Roma" non risolve; Cerca salva displayName canonico (case-insensitive);
  bare "Roma" bloccato finché non si sceglie l'entità; alias matcha "VENEZIA S.L."
  mantenendo ≥2-token (Mestre no); resolver B4 con catalogo aggancia la forma abbreviata
  (e SENZA catalogo no → documenta il limite stringa); Home spotlight alias-aware col
  catalogo. Riscritto `cercaViewModelFilters` (entità, niente routes/trains mock).
- **Suite: 114 test, 107 pass / 7 fail.** I 7 sono i **pre-esistenti** (StubURLProtocol +
  rfiMapper), NON toccati dal diff. Home/B4/save-Cerca esistenti verdi.

### Build
- Debug (app) OK; build-for-testing OK; Release OK (guardrail `.mock` intatto; catalogo
  bundlato anche in Release; in Release il board è mock Bologna → tratte Padova non
  servite → stato onesto B4).

### Risks / next
- `providerCodes` reali oltre Padova restano non verificati (null nel catalogo) — non
  usati dal fetch board oggi; attivazione stazioni live = lavoro futuro (registry).
- Station-mode è informativa (entità mostrate) perché il board live è solo Padova;
  selezione per-stazione utile con board multi-stazione (B3).
- I 7 test rossi pre-esistenti restano da sistemare in un task dedicato (fuori B1).

## 2026-07-15 — Ticket B4: prossimo treno REALE nelle tratte salvate (Viaggi)

Stato: completata (logica + UI + test). Nessun dato inventato: dato reale o stato
onesto. A1/A3 e i guardrail Release NON toccati.

### Problema risolto
- Le tratte salvate mostravano segnaposto: `departure` = ora del salvataggio,
  `platform` = nil, `durationMinutes` = 0, `status` = onTime hardcoded → "PROSSIMA
  PARTENZA 16:10" (spesso nel passato), "BINARIO ----", "DURATA 0 min". "Dalle tue
  abitudini" duplicava la stessa tratta col glitch minuti sul LED grande.

### Cosa
- **Helper condiviso** `Services/SavedJourneyMatcher.swift` (puro): estratto il
  predicate da `StationBoardViewModel.personalizedFeaturedRows` (origine = stazione
  servita, destinazione via `StationNameMatcher`). Home e Viaggi ora usano LO STESSO
  helper → non possono divergere. Home invariata (test spotlight verdi).
- **Resolver** `Services/NextTrainResolver.swift`: dato l'insieme dei viaggi salvati,
  fetcha UNA volta il board della stazione servita via `TrainBoardService.fetchBoard`
  (stazione **derivata** da `AppEnvironment.initialStation`, MAI hardcoded), e per ogni
  tratta la cui origine è servita prende la **prima riga futura** (`scheduledTime >=
  now`) che matcha la destinazione. Campi reali (orario/ritardo/binario/numero/stato).
- **Modelli**: `ResolvedNextTrain` (campi reali; niente durata/arrivo, che il board non
  fornisce), `NextTrainResolution { .resolved | .unavailable }`, display
  `Models/NextTrainDisplay.swift` (solo campi reali).
- **Stato onesto**: origine non servita (oggi solo Padova) o nessuna riga futura →
  `.unavailable` → card mostra "Prossimo treno non disponibile", MAI 0 min/----/save-time.
- **"Dalle tue abitudini"** ora è il **prossimo treno reale più imminente** tra le
  tratte risolte (LED grande con destinazione + numero + binario + ritardo reali); se
  nessuna risolve, la sezione è nascosta. Niente glitch minuti (valore completo o niente).
- **RECENTI nascosti** (`showsRecentSection == false`): scelta **meno ingannevole** —
  i recenti mock non devono sembrare cronologia reale finché non c'è storia vera. Il
  mock resta nel modello per un futuro riaggancio.
- **Colonna card salvata**: "Durata" (che sarebbe stata finta) → **"Treno"** (numero
  reale). Wiring: `TripsViewModel` inietta un `NextTrainResolving`; `RootTabView` passa
  `NextTrainResolver(service: AppEnvironment.makeTrainBoardService(), boardStation:
  AppEnvironment.initialStation)`. suggested/recent restano fuori dal dato reale.
- Loc IT/EN: `journey.nextTrain.unavailable`, `accessibility.journey.nextTrain`,
  `accessibility.journey.nextTrainUnavailable`.

### Checkpoint (verificato sul board LIVE Padova, non assunto)
- **Padova → Roma Termini** risolve a un AV reale: board live mostra AV 9435 → Roma
  Termini @ 18:56 **+5'** e AV 9437 @ 19:56 → orario/ritardo/numero reali. **Binario**:
  al momento il board live restituisce **0/40 righe con binario** (RFI non lo pubblica
  ancora per queste corse) → card mostra "--" ONESTO, mai inventato; comparirà quando
  RFI assegna il binario. Match richiede il nome pieno ("Roma Termini"): un bare "Roma"
  (1 token) NON matcha per la regola ≥2-token dello `StationNameMatcher` (condiviso).
- **Montegrotto → Padova**: origine non servita dal board Padova → stato onesto
  ("Prossimo treno non disponibile"), NON 0 min/----. (Test `…UnavailableWhenOriginNotServed`.)

### Test
- Nuovi (deterministici, clock Europe/Rome, `FixedBoardService`, nessuna rete):
  resolver risolve prima riga futura con campi reali; unavailable senza riga futura;
  unavailable se origine non servita; display usa l'orario del board non il save-time;
  habit = più imminente risolto; helper condiviso dà stessi risultati per Home e Viaggi.
  Aggiornati `tripsViewModelLoadsAndFilters` (recenti nascosti) e sostituito il vecchio
  test `nextHabitJourney`.
- **Suite: 106 test, 99 pass / 7 fail.** I 7 sono i **pre-esistenti** (StubURLProtocol +
  rfiMapper) NON legati a B4: il mio diff non tocca quei file. Zero regressioni nuove;
  Home spotlight verde.

### Build
- build-for-testing Debug OK; Release OK (guardrail `.mock` intatto: in Release il
  resolver gira contro il board mock Bologna → tratte Padova non servite → stato onesto).

### Risks / next
- Con board live senza binari, la card mostra "--" (onesto). Se si vuole il binario
  bisogna che la sorgente lo pubblichi (nulla da fare lato app).
- Multi-stazione (origine ≠ Padova che risolve davvero) è B1/B3: oggi correttamente
  stato onesto. Recenti reali = lavoro futuro (fonte cronologia).
- I 7 test rossi pre-esistenti restano da sistemare in un task dedicato (fuori B4).

## 2026-07-15 — TestFlight live Padova build (A1 Info reachable + A3 TESTFLIGHT source)

Stato: completata (codice + config Xcode + validazione live server-side). Build
commuter TestFlight per un tester Padova→Roma. Release App Store resta `.mock`.

### A1 — InfoView / disclaimer di affidabilità di nuovo raggiungibile
- Dopo il passaggio al tab **Cerca**, `InfoView` era orfana: il disclaimer
  `disclaimer.officialDisplays` non era raggiungibile da nessuna navigazione.
- **Fix**: pulsante info (ⓘ) nell'header Home (`StationBoardHeaderView`, accanto alla
  stella, gated su `onShowInfo` → non compare dove non passato, preview invariati) che
  presenta `InfoView` come **sheet**; `InfoView` ora ha un pulsante **Chiudi** (X) via
  `@Environment(\.dismiss)`. Nessun nuovo tab (resta Partenze/Viaggi/Cerca).
- Loc IT/EN in sync: `accessibility.info`, `action.close`.

### A3 — Sorgente `.backendLivePadova` nella config ARCHIVIO TestFlight
- **Nuova build configuration "TestFlight"** (famiglia Release) su progetto + 3 target;
  scheme `ArchiveAction` → `TestFlight` (Run/Test restano Debug). L'App Store si
  archivia solo cambiando a Release → `.mock` (guardrail intatto).
- **`AppEnvironment.sourceMode`**: nuovo ramo `#elseif TESTFLIGHT → .backendLivePadova`;
  `#else` (plain Release) resta `.mock`. Guard estesi a `#if DEBUG || TESTFLIGHT` per
  `.backendLivePadova` + factory `makeBackendLiveService`/`makeBackendFixtureService` e
  per `BackendEndpointConfig.debug`/token. `.rfiLivePadova`/`.backendFixturePadova`
  restano DEBUG-only.
- **Token baked-in**: nuovo `Config/Binario1.testflight.xcconfig` (committato, NESSUN
  secret) — `#include?` del gitignored `Binario1Secrets.local.xcconfig`, `INFOPLIST_FILE
  = Config/Binario1-Info.plist`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited)
  TESTFLIGHT`. Il token finisce nel binario via chiave Info.plist custom.

### Validazione (checkpoint: l'archivio TestFlight riceve dati LIVE, non fixture?)
- **Build**: Debug OK, Release OK, **TestFlight OK** (ramo live compila).
- **Token bakato**: Info.plist del prodotto **TestFlight** ha `BINARIO_BOARD_APP_TOKEN`
  len 64 hex, nessuna sostituzione irrisolta. **Release**: chiave **ASSENTE** (→ `.mock`).
- **Backend live (curl con token bakato, come farebbe l'app archiviata)**: **HTTP 200**,
  `source.kind=rfiLive`, **`isFallback=false`**, `isStale=false`, **40 righe** reali.
  Senza token → **HTTP 401** (path fixture). ⇒ Log runtime atteso su device:
  `[BackendLive] OK · rows=40 · source=rfiLive · fallback=false · stale=false`.
- Se il backend fosse giù o il token non fosse bakato (es. su clone senza il file
  `.local.xcconfig`) → 401 → **fallback visibile alla fixture**, mai dati inventati.

### Test
- Aggiornato guardrail `sourceModeMatchesBuildConfiguration` (era **già disallineato**:
  atteso `.scheduledPadova` in DEBUG mentre il codice è `.backendLivePadova`) + ramo
  `#elseif TESTFLIGHT`. Nuovo `infoAndCloseLabelsAreLocalized`. **Entrambi passano.**
- Esecuzione suite (prima volta effettiva in questo ambiente, CoreSimulator ha girato):
  **101 test, 94 pass / 7 fail**. I 7 sono **pre-esistenti e indipendenti** dalle
  modifiche A1/A3: 6 usano `StubURLProtocol` (il fetcher `URLSession` non viene
  intercettato in questo toolchain iOS 26) + `rfiMapperBuildsValidRows` (drift
  `.onTime`/`.departing`). Nessuno dei file coinvolti è nel diff.

### Sicurezza
- Nessun secret committato: il token vive solo in `Binario1Secrets.local.xcconfig`
  (gitignored) e nello scheme (in `xcshareddata/` gitignorato apposta). Il nuovo
  `Binario1.testflight.xcconfig` non contiene valori, solo `#include?`.

### Rischi / next step
- I 7 test rossi pre-esistenti (stub di rete + RFI mapper) andrebbero sistemati in un
  task dedicato (test-infra `StubURLProtocol` su iOS 26) — fuori scope A1/A3.
- Lo scheme (con `ArchiveAction=TestFlight`) è gitignored → il setting vive **solo su
  questa macchina**. Va bene per l'archivio locale del singolo tester; da rifare se si
  archivia altrove.
- Next: l'utente esegue **Archive** (config TestFlight) su device, verifica header
  `Backend · RFI online` + il log `[BackendLive] OK … fallback=false`, e trova l'AV/FR
  Padova→Roma con binario nel tabellone completo.

## 2026-07-01 — Wire Search modes and simplify Trips

Stato: completata (UI + VM). Niente backend/Supabase; Release resta `.mock`.

### Cerca
- Le tre card (Stazione / Tratta / Treno) ora sono **funzionali**: `SearchMode`
  (station/route/train) in `CercaViewModel`; toccare una card apre la modalità
  (con "Indietro" per tornare). Digitare senza scegliere una card mostra i risultati
  raggruppati (comportamento precedente).
- **Cerca tratta**: form `PARTENZA` / `DESTINAZIONE`, **Inverti tratta** (swap) e
  **Salva tratta** (attivo solo se entrambi i campi valorizzati). Salva via
  `SavedJourneyStore.add` (upsert, dedup con id canonicalizzato invariati); campi
  puliti dopo il salvataggio.
- **Cerca stazione**: elenco stazioni (ricerca) + nota che il tabellone live è per
  Padova (niente finto supporto per stazioni non verificate).
- **Cerca treno**: stato "in arrivo" (nessun lookup live, nessun endpoint nuovo).

### Viaggi (semplificazione)
- Rimosso il brand **"Binario 1"** dall'header; titolo **VIAGGI** ora usa lo stesso
  componente animato della Home (`DotMatrixStationTitleView`), con token d'animazione
  al (ri)ingresso del tab.
- Sezione "Prossimo viaggio utile" **riformulata in "DALLE TUE ABITUDINI"**: mostra il
  **prossimo viaggio probabile dai viaggi salvati** (orario locale, nessuna
  predizione/AI), nello stile della card grande apprezzata. Empty state:
  "Salva una tratta da Cerca per vederla qui."
- Rimosse le **quick actions** non funzionali e il "Vedi tutti" (no-op) da Recenti.

### Fix titolo tratte salvate
- Le tratte salvate da Cerca (`isCustomRoute`) mostrano la **rotta reale**
  ("Padova → Venezia S. Lucia") come titolo (icona bookmark), non l'alias
  "Casa → Lavoro"; accessibility usa la rotta reale. Gli alias ruolo restano per i
  viaggi commuter. `SavedJourney.isCustomRoute` è opzionale → dati già persistiti
  decodificano senza rotture.

### Test
- Selezione modalità Cerca; form tratta (campi/swap/validazione); tratta non valida
  non salvata; salva + dedup con `isCustomRoute`; tratta custom espone la rotta reale;
  habit Viaggi = prossimo salvato per orario; empty state senza salvati. Home invariata.

### Build / test
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun backend/Supabase; nessun secret; Release `.mock`.

## 2026-07-01 — Clarify Home station board UX

Stato: completata (solo copy/gerarchia UI). Niente backend/Supabase; Release `.mock`.

### Cosa
- **Header Home** comunica il contesto tabellone: eyebrow `STAZIONE`, titolo `Padova`,
  nuova riga descrittiva `header.boardDescriptor` = "Tabellone in tempo reale" /
  "Real-time board". (`header.stationContext` IT "STAZIONE DI" → "STAZIONE".)
- **Switch** `PARTENZE` / `ARRIVI` invariato (già chiaro).
- **Titolo board completo esplicito e station-scoped**: `TrainBoardListSectionView`
  ora mostra `TUTTE LE PARTENZE DA PADOVA` / `TUTTI GLI ARRIVI A PADOVA`
  (`section.allDeparturesFrom` "…da %@" / `section.allArrivalsTo` "…a %@", via
  `BoardType.allSectionTitleFormatKey` + `NSLocalizedString` + nome stazione;
  `BoardSectionHeader` accetta un `titleString` verbatim).
- **Hero = spotlight** (invariato): personalizzato `I TUOI PROSSIMI TRENI`, generico
  `PROSSIME PARTENZE` / `PROSSIMI ARRIVI`. Gerarchia: alto = spotlight utile, basso =
  tabellone completo di stazione.

### Modello mentale (copy)
- **Home = tabellone di stazione** (spotlight in alto + tabellone completo sotto).
- **Cerca = cerca/salva una tratta**. **Viaggi = archivio viaggi salvati**.

### Test
- `BoardType.allSectionTitleFormatKey` station-scoped (departures→…From, arrivals→…To);
  test titoli hero (`featuredTitleKey`) esistenti invariati.

### Build / test
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun backend/Supabase; nessun secret; Release `.mock`.

## 2026-07-01 — Add save journey action from Search

Stato: completata. Niente backend/Supabase; Release resta `.mock`.

### Cosa
- **Salva da Cerca**: le righe "Tratte" ("Origine → Destinazione") hanno un piccolo
  affordance bookmark. `CercaViewModel.saveRoute` fa parsing della coppia, costruisce
  un `SavedJourney` e fa `SavedJourneyStore.add` (upsert). Solo le righe tratta sono
  salvabili (stazioni/treni no).
- **Dedup**: id stabile `cerca:<canon origine>>​<canon destinazione>`
  (`StationNameMatcher.canonical`) → risalvare la stessa coppia = `.alreadySaved`,
  nessuna riga duplicata. Coppia non valida (senza `→` / destinazione vuota) →
  `.invalid`, non salvata (bottone assente se non parsabile).
- **Stato UI**: bottone "Salva" → "Salvato" (+ disabilitato) quando persistito;
  `refreshSavedState()` risincronizza al (ri)comparire del tab così una delete fatta
  in Viaggi riabilita il salvataggio.
- **Cross-feature**: stesso store (`UserDefaults.standard`) → dopo il salvataggio la
  tratta compare in Viaggi (al load) e la Home la usa al prossimo refresh (provider).
  Logica di matching Home invariata.
- Nuove chiavi loc: `action.saveJourney`, `search.save`, `search.saved` (IT/EN).

### Review (adversariale, multi-agent) — findings risolti
- **Critico**: `seedIfNeeded` sovrascriveva un viaggio salvato da Cerca prima del
  primo load di Viaggi (perdita dato). Fix: seed **solo se lo store è vuoto** (flag
  seeded impostato comunque una volta) → non clobbera i dati utente.
- **Minore**: cache `savedRouteIDs` stantia dopo delete cross-tab → risincronizzata
  in `saveRoute` e al `.task` di comparsa di Cerca (riabilita il salvataggio).
- **Minore (cosmetico, noto)**: i viaggi salvati da Cerca usano `direction .homeToWork`
  placeholder → la card Viaggi mostra il titolo ruolo "Casa → Lavoro" (la sotto-riga
  mostra comunque la tratta reale). Nessuna perdita dato; sistemarlo richiederebbe un
  flag/redesign della card → rimandato.

### Test
- Salvataggio valido aggiunge allo store; duplicato non crea righe (canonical dedup);
  coppia non valida non salvata; la tratta salvata compare in `TripsViewModel` dopo
  reload; la Home personalizza da un viaggio salvato via Cerca; il seed non clobbera
  dati esistenti.

### Build / test
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun backend/Supabase; nessun secret; Release `.mock`.

## 2026-07-01 — Add saved journey delete UI

Stato: completata. Niente backend/Supabase; Release resta `.mock`.

### Cosa
- **Delete in Viaggi**: le card salvate (`SavedJourneyCardView`) hanno ora un piccolo
  affordance cestino (`onRemove`) accanto alla stella + azione VoiceOver
  "Rimuovi viaggio salvato" (la card ignora i children a11y, quindi azione a livello
  card). Layout a card custom → niente swipe-to-delete List; approccio conservativo.
- **VM**: `TripsViewModel.deleteSavedJourney(id:)` → `store.delete` + ricarica
  `savedJourneys`. Suggested/recent (mock) restano separati dai salvati reali.
- **Empty state**: quando il filtro Oggi/Salvati è attivo ma non ci sono viaggi
  salvati, la sezione "Tratte salvate" mostra un piccolo pannello vuoto
  (`trips.saved.empty`), stile board.
- **Home riflette le cancellazioni al prossimo refresh/load**: `StationBoardViewModel`
  accetta un `savedJourneysProvider` e rilegge i viaggi salvati persistiti a ogni
  refresh; RootTabView passa `{ HomeSavedJourneys.current() }`. La logica di matching
  è invariata.
- **No re-seed dei cancellati**: `seedIfNeeded` resta una tantum (flag) → le
  cancellazioni utente non ritornano.
- Nuove chiavi loc: `action.removeSavedJourney`, `trips.saved.empty` (IT/EN).

### Test
- `TripsViewModel.deleteSavedJourney` rimuove dallo store e dalla lista; il viaggio
  cancellato non riappare dopo reload.
- Home torna alla sezione generica dopo aver cancellato l'unico viaggio corrispondente
  (via provider al refresh).
- Seed una tantum rispetta la cancellazione (test esistente).

### Build / test
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun backend/Supabase; nessun secret; Release `.mock`.

## 2026-07-01 — Persist saved journeys for personalized Home

Stato: completata. Niente backend/Supabase; Release resta `.mock`.

### Cosa
- **Modello persistibile**: `SavedJourney` (+ `JourneyStatus`, `JourneyDirection`) ora
  `Codable`.
- **Persistenza locale**: nuovo `Services/SavedJourneyStore.swift` — `SavedJourneyStoring`
  + `UserDefaultsSavedJourneyStore` (blob JSON in `UserDefaults`, chiave
  `binario1.savedJourneys.v1`) con `load/save/add(upsert)/delete` e `seedIfNeeded`
  (seed una tantum al primo avvio, flag `…seeded.v1`; NON riseminò dopo che l'utente
  svuota → le cancellazioni restano). `SavedJourneySeed.initial()` = i saved di
  `MockTripsService.sample` (Montegrotto↔Padova), ora dati reali persistiti.
- **Home legge il persistito**: `HomeSavedJourneys.current()` fa seed-once + `load()`
  dallo store. **Rimosso il demo Padova→Venezia S. Lucia** (non più dato utente).
- **Viaggi condivide lo store**: `TripsViewModel` carica i saved dallo store (suggested/
  recent restano mock) → Viaggi e Home usano la stessa sorgente persistita.
- **Comportamento Home invariato**: se un viaggio salvato matcha righe del board →
  "I TUOI PROSSIMI TRENI"; altrimenti "PROSSIME PARTENZE"; board completo sotto.
  Arrivi restano generici.

### Nota comportamentale (device)
- Con i soli seed reali (Montegrotto↔Padova) e board Padova, nessun match →
  la Home mostra "PROSSIME PARTENZE" (corretto: niente più demo artificiale). La
  personalizzazione si attiva quando un viaggio salvato reale ha come capolinea una
  destinazione presente sul tabellone.

### Test
- Store: save/load/add(upsert)/delete roundtrip; seed una tantum + rispetto delle
  cancellazioni; i seed NON contengono il demo rimosso.
- Home: usa i viaggi persistiti (personalizza con viaggio NON-demo); fallback generico
  se lo store è vuoto.

### Build / test
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun backend/Supabase toccato; nessun secret; Release `.mock`.

## 2026-06-23 — Validate installed DEBUG backend token configuration

Stato: **validato su iPhone reale.** Il token DEBUG build-time funziona anche aprendo
l'app installata dall'icona (non solo da Xcode).

### Evidenza (iPhone reale)
- Header mostra **`Backend · RFI online`** (NON `Backend fixture · RFI online`).
- Console: `[BackendLive] OK · rows=40 · source=rfiLive · fallback=false · stale=false`.
- Nessun fallback alla fixture; nessun dato stale-cache; righe backend live nel board;
  nessun log `[RFILive]` in modalità backend.

### Conferma fix
- **Causa**: le env var dello schema Xcode non sopravvivono al lancio dell'app
  installata dall'icona → nessun `X-Binario-App-Token` → 401 → fixture.
- **Fix**: token DEBUG iniettato a build-time via `.xcconfig` locale (gitignored) →
  chiave Info.plist custom, letto con precedenza build-time → env var → vuoto. Il file
  token resta gitignored; nessun secret committato. Release resta `.mock`.

## 2026-06-23 — Fix installed DEBUG app token configuration

Stato: completata. Niente token committato; Release invariato (`.mock`).

### Causa
- `BackendEndpointConfig.debug.appToken` leggeva SOLO
  `ProcessInfo.environment["BINARIO_BOARD_APP_TOKEN"]` → presente solo se l'app è
  lanciata da Xcode. Aprendo l'app installata dall'icona, nessuna env var → richiesta
  senza `X-Binario-App-Token` → 401 → fallback alla fixture (header
  "Backend fixture · RFI online", righe fixture).

### Fix (token build-time, gitignored)
- `Config/Binario1Secrets.local.xcconfig` (**gitignored**) definisce
  `BINARIO_BOARD_APP_TOKEN`; incluso via `#include?` da `Config/Binario1.debug.xcconfig`
  (committato), impostato come `baseConfigurationReference` del config **Debug** del
  target app. Esempio committato: `Config/Binario1Secrets.example.xcconfig` (placeholder).
- Il token è esposto all'app tramite una chiave Info.plist custom: partial
  `Config/Binario1-Info.plist` con `$(BINARIO_BOARD_APP_TOKEN)` (i custom `INFOPLIST_KEY_*`
  NON vengono iniettati per chiavi non-Apple → serve il file). Xcode fonde le chiavi
  generate sopra (verificato: plist DEBUG ha CFBundle* + token len 64).
- `resolveAppToken(infoValue:envValue:)`: precedenza **build-time Info.plist → env var
  Xcode → vuoto** (ignora placeholder e `$( )` non risolto). Così: lancio da Xcode OK,
  e app installata aperta da icona OK (token nel binario DEBUG).
- **Release**: nessun `baseConfigurationReference` → nessuna chiave token nel plist
  Release (verificato ASSENTE); resta `.mock`.
- Log: token assente → "app token not configured · using fixture fallback if backend
  returns 401"; HTTP 401 → "...status=401 · likely missing/invalid app token".

### Sicurezza
- Token reale solo in `Config/Binario1Secrets.local.xcconfig` (gitignored). Mai nei
  log/docs/commit. `git check-ignore` confermato.

### Build / test
- Build Debug+Release OK; plist DEBUG verificato (token len 64), plist Release verificato
  (token assente). Test target compila; aggiunti test `resolveAppToken` (build-time >
  env > vuoto; placeholder/`$( )` ignorati). Esecuzione unit test bloccata da
  CoreSimulator (ambiente).

## 2026-06-23 — Add backend arrivals and station registry foundation

Stato: completata. Nessuna stazione non verificata attivata; nessun cambio di
contratto dati (stesso JSON normalizzato per partenze/arrivi).

### Backend (Edge Function)
- **Station registry** estratto in `registry.ts`: unica stazione VERIFICATA Padova
  (`rfiLivePlaceId=2000`, `prmScheduledId=1861`, sistemi distinti, mai mischiati).
  TODO future (Bologna/Venezia/Montegrotto/Milano) solo con `rfiLivePlaceId` verificato.
- **Arrivi**: `/board?...&type=arrivals` → RFI `arrivals=True`; partenze → `arrivals=False`.
  `parseBoardType` (departures/arrivals, default departures, else 400). Risposta usa lo
  stesso contratto; `boardType` riflette il tipo richiesto. Per gli arrivi il campo
  `destination` contiene la PROVENIENZA (documentato; iOS lo mappa su `origin`).
- Parser/normalizzazione invariati (categorie compatte, niente `Categoria`/entità,
  binari/ritardi/stati sicuri). Cache key già per tipo.
- Validato live (curl): departures → boardType departures (40 righe, dest. Venezia/
  Bologna); arrivals → boardType arrivals (40 righe, provenienza es. Reggio Calabria);
  `type` non valido → 400.

### iOS
- `BackendBoardService` non forza più departures: partenze e arrivi passano al fetcher.
  `URLSessionBackendBoardFetcher` invia già `type` (Partenze→departures, Arrivi→arrivals).
  `FixtureBackendBoardFetcher` serve solo departures → per gli arrivi lancia → fallback.
- `BackendBoardMapper`: per `boardType=arrivals` mappa il luogo su `origin`
  (destinazione nil) così il board mostra la provenienza; departures invariato.
- **Hero personalizzata** resta SOLO per le partenze (guardia `boardType == .departures`);
  per gli arrivi titolo generico `PROSSIMI ARRIVI`. Personalizzazione arrivi rinviata.

### Test
- Backend (deno): registry risolve Padova (1 sola stazione); parseBoardType; URL
  departures `arrivals=False` / arrivals `arrivals=True`; helper puri (19/19 pass).
- iOS: URL builder per tipo; DTO decodifica `boardType=arrivals`; mapper arrivi →
  `origin`; fixture fetcher rifiuta arrivi; arrivi non personalizzano (titolo generico);
  test partenze personalizzate invariati.

### Review (adversariale, multi-agent) — findings risolti
- Arrivi non emettono più `departing` (euristica monitor partenze): in arrivi
  `isDeparting=false` → solo onTime/delayed/cancelled (verificato live).
- Fallback luogo mancante per arrivi usa `board.originUnavailable`
  ("Provenienza non disponibile"), non la stringa destinazione.
- Aggiunti test end-to-end `BackendBoardService` per arrivi (forward del tipo;
  fixture-only → fallback a mock).

### Build / sicurezza
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Nessun secret committato; Release resta `.mock`; Viaggi/Cerca invariati.

## 2026-06-23 — Personalize Home featured departures

Stato: completata (UI + logica MVP). Nessun cambio backend/contratto dati.

### Cosa
- **Pulizia label sorgente** (display/localization only): `source.backendFixture`
  ("Backend fixture · RFI online"), `source.backendLive` ("Backend · RFI online") e
  anche `source.rfiLive`/`source.rfiLiveUpdated` ("RFI online" / "RFI online ·
  aggiornato %@") — **nessun "Monitor RFI online" visibile nell'header** (IT+EN);
  commenti header aggiornati. Suffissi `· fallback` / `· dati cache`/`cached` invariati.
- **Featured personalizzata**: quando ci sono viaggi salvati (Viaggi) con righe del
  tabellone corrispondenti, la sezione in alto mostra **solo i treni dell'utente** con
  titolo **`I TUOI PROSSIMI TRENI`** (`section.yourNextTrains`). Match: stazione
  corrente = origine viaggio salvato + destinazione ~ destinazione viaggio (departures).
- **Fallback**: senza viaggi salvati o senza match → comportamento generico esistente
  (`PROSSIME PARTENZE`, top 3 imminenti). Nessun hero vuoto.
- **`TUTTE LE PARTENZE`** resta sotto come tabellone completo (board intero quando la
  featured è personalizzata; comportamento esistente in modalità generica).
- **Treni cancellati / molto in ritardo** restano visibili anche nella featured
  personalizzata (l'utente vuede vedere "il mio treno", problemi inclusi).

### Matching MVP (no route planner, no DB, no sync)
- `StationNameMatcher` (puro, testabile): canonicalizza (maiuscolo, fold accenti,
  punteggiatura → spazio, espansione abbreviazioni comuni: `S.` → SANTA, `C.LE` →
  CENTRALE, `P.NUOVA` → PORTA NUOVA), confronto per uguaglianza o sottoinsieme di token.
- Sorgente viaggi salvati per la Home: adapter `HomeSavedJourneys` (riusa i dati mock
  di Viaggi + 1 entry demo Padova→Venezia S.Lucia così la spotlight si attiva sul
  board Padova; Viaggi invariato). **Diventa reale quando i viaggi salvati saranno
  persistiti/condivisi.**

### Review (adversariale, multi-agent) — findings risolti
- Matcher: il match per sottoinsieme ora richiede ≥2 token condivisi → niente falsi
  positivi (Venezia ≠ Venezia Mestre; Centrale ≠ Milano Centrale).
- Spotlight ora dimostrabile end-to-end (entry demo); prima cadeva sempre in fallback
  coi soli dati mock di Viaggi.
- Pulizia label estesa a `source.rfiLive` + commenti header (niente "Monitor" residuo).

### Test (nessuna rete)
- Label backend fixture/live = "… · RFI online", niente "Monitor" (skip difensivo se
  la localizzazione non è risolvibile nel bundle di test).
- Matcher: forme comuni Venezia S.Lucia / C.LE / P.Nuova; Mestre ≠ Santa Lucia.
- Featured personalizzata: match → solo righe corrispondenti + titolo yourNextTrains +
  board completo sotto; no match → fallback generico + dropFirst(2); cancellato/ritardo
  personalizzati restano visibili.

### Build / sicurezza
- Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator —
  ambiente). Niente modifiche a backend/Supabase/contratto; Viaggi/Cerca invariati;
  Release resta `.mock`.

## 2026-06-22 — Real-station board comparison at Padova

Stato: **validazione visiva in stazione reale** del backend-live (campione osservato).
Non è una garanzia formale che tutti i dati RFI futuri coincidano sempre con i display
di stazione — serve comunque monitoraggio affidabilità + trasparenza sorgente.

### Contesto
- iPhone reale, app Binario1 con **header `Backend · Monitor RFI online`** (backend-live
  attivo, non fixture).
- Confronto visivo del tabellone app vs **tabellone fisico RFI** alla stazione di Padova.
- Le righe visibili sono risultate **coerenti** con il tabellone fisico per numero
  treno, destinazione, orario, ritardo/cancellazione e binario.

### Righe visibili coincidenti (campione)
- AV 9750 → Torino P. Nuova → 17:46 → +110' → bin. 3
- RV 3506 → Verona P. Nuova → 18:40 → +60' → bin. 3
- REG 17220 → Verona P. Nuova → 18:53 → +35' → bin. 1
- AV 9749 → Trieste C.le → 19:16 → +20' → bin. 5
- AV 8928 → Venezia S. Lucia → 19:27 → +10' → bin. 2
- AV 8993 → Udine → 19:34 → +20' → bin. 5
- RV 3508 → Verona P. Nuova → 19:40 → bin. 3
- REG 17107 → Rovigo → 19:41 → bin. 1
- AV 9480 → Trieste C.le → 19:42 → bin. 2
- REG 17146 → Verona P. Nuova → 19:53 → cancellato
- RV 3988 → Venezia S. Lucia → 19:53 → bin. 2
- AV 9437 → Roma Termini → 19:56 → bin. 1
- AV 9428 → Venezia S. Lucia → 20:06 → +20' → bin. 2

### Note di rendering
- Categorie compatte corrette: AV / RV / REG.
- Ritardi gravi mostrati chiaramente; treno cancellato come **`CANC`**; binari leggibili.
- Il display dell'app è risultato **più leggibile** del tabellone fisico per
  ritardi/cancellazioni.

### Esito
- Valida l'**allineamento pratico con la realtà di stazione per il campione osservato**.
- NON rimuove la necessità di monitoraggio dell'affidabilità e di trasparenza sulla
  sorgente (`Monitor RFI online`, non real-time garantito in assoluto).
- Docs-only; nessun codice app modificato; Release resta `.mock`.

## 2026-06-17 — Complete board app-token device validation

Stato: **path positivo confermato visivamente su iPhone reale.** Validazione
app-token completa (negativo + positivo su device; server tutti i path).

### Evidenza (screenshot iPhone reale)
- Header mostra **`Backend · Monitor RFI online`** (NON `Backend fixture`) → dati dal
  backend live, nessun fallback alla fixture visibile.
- Righe **backend live** renderizzate nel tabellone Partenze.
- Categorie compatte corrette: **AV / RV / REG**.
- Badge ritardo corretti (inclusi ritardi gravi); riga **treno cancellato → `CANC`**;
  valori binario corretti.
- **Console log non catturata** in questo pass (evidenza = screenshot UI). Riga attesa:
  `[BackendLive] OK · rows=N · source=rfiLive · fallback=false · stale=false`.

### Riepilogo validazione app-token
- **Path negativo** (già confermato su iPhone): nessun token → HTTP 401 → fallback
  visibile alla fixture, no crash.
- **Path positivo** (ora confermato su iPhone): token corretto → header
  `Backend · Monitor RFI online`, righe live, niente fixture. Server già validato via
  curl (no/errato → 401; corretto → 200, diagnostics omesse in production).

### Sicurezza / prossimo
- Nessun secret committato (token solo in env var schema Xcode + file gitignored
  `supabase/.env.board.local`). Release resta `.mock`. Viaggi/Cerca invariati.
- Prossima fase: station registry, supporto arrivi, cache condivisa/distribuita,
  policy di rollout in produzione.

## 2026-06-17 — Validate board app-token enforcement

Stato: **enforcement attivo; server validato (no/errato/corretto) + path negativo
confermato su iPhone reale.** Path positivo su iPhone (token corretto) **da fare**
dall'utente (nessun device in questo ambiente).

### Cosa
- **Secret Supabase configurati** sul progetto "Binario 1" (`hzwwvkuxqhmeicylyrsy`):
  `BINARIO_BOARD_APP_TOKEN` (token forte generato localmente) e
  `BINARIO_BOARD_ENV=production`. Funzione **rideployata**.
- **Validazione server (curl)**:
  - A) **nessun token → HTTP 401** (`unauthorized`).
  - B) **token errato → HTTP 401** (`unauthorized`).
  - C) **token corretto → HTTP 200**, board normalizzata, righe presenti,
    `source.kind=rfiLive`, `isFallback=false`, **`diagnostics` OMESSE**
    (`BINARIO_BOARD_ENV=production`).
- **iOS token locale (non committato)**: `BackendEndpointConfig.debug.appToken` ora
  legge l'env var `BINARIO_BOARD_APP_TOKEN` (impostata nello schema Xcode → vive in
  `xcuserdata/`, già gitignored). Token committato resta **vuoto**. `URLSessionBackendBoardFetcher`
  invia `X-Binario-App-Token` quando valorizzato; nessun header Authorization, nessuna
  anon/service_role key. `.gitignore` esteso (`*.local.swift`/`*.local.xcconfig`/`*.env.local`).
- **Token persistito localmente** per l'utente in `supabase/.env.board.local`
  (gitignored, `git check-ignore` confermato) — mai committato, mai stampato.

### Conseguenza (atteso)
- L'endpoint deployato ora **richiede il token**: l'app committata (token vuoto) e
  qualsiasi client senza token ricevono **401 → fallback visibile alla fixture**
  (`[BackendLive] FALLBACK · reason=fetch-error · error=…401…`). Per tornare live:
  impostare `BINARIO_BOARD_APP_TOKEN` (valore in `supabase/.env.board.local`) nello
  schema Xcode.

### Validazione iPhone
- **Path negativo — CONFERMATO su iPhone reale** (log utente):
  `[BackendLive] app token not configured` → `[BackendLive] HTTP ERROR · status=401`
  → `[BackendLive] FALLBACK · reason=fetch-error · using=fixture · error=httpStatus(401)`.
  Il backend rifiuta senza token, iOS riceve 401 e fa **fallback visibile alla
  fixture**, nessun crash.
- **Path positivo — server riconfermato** (curl con token corretto dal file
  gitignored): HTTP 200, 40 righe, `source.kind=rfiLive`, `isFallback=false`,
  `isStale=false`, **diagnostics omesse** (production), categorie compatte.
  **Su iPhone: PENDING (utente)** — impostare `BINARIO_BOARD_APP_TOKEN` (valore in
  `supabase/.env.board.local`) nello schema Xcode, eseguire `.backendLivePadova`,
  atteso `[BackendLive] OK · rows=N · source=rfiLive · fallback=false · stale=false`,
  header "Backend · Monitor RFI online", nessun `[RFILive]`.

### Build / sicurezza
- iOS Build Debug+Release OK; test target compila (esecuzione bloccata da CoreSimulator
  — ambiente). **Nessun secret committato** (token solo in file gitignored / env var).
  Release resta `.mock`. Viaggi/Cerca invariati.

## 2026-06-17 — Harden board backend access

Stato: completata (Hardening Phase 1). Codice live deployato; enforcement del token
attivabile impostando i secret server-side (non ancora attivi → spike resta aperto).

### Cosa
- **App token** `X-Binario-App-Token` nella Edge Function: legge
  `BINARIO_BOARD_APP_TOKEN` (env). Se configurato → token mancante/errato = **401**
  (`unauthorized`); se non configurato → consentito **solo in development** (warning),
  rifiutato in production. Confronto constant-time-ish; il token **non** è mai loggato
  né incluso negli errori.
- **Rate limit foundation** in-memory best-effort (60 req/min per client key) → **429**
  (`rate_limited`) con `Retry-After`/`X-RateLimit-Limit`/`X-RateLimit-Remaining`.
  Per-istanza, **non globale** → TODO limiter distribuito (Upstash/Redis o Supabase).
- **Diagnostics ridotte per ambiente**: `BINARIO_BOARD_ENV` (`development`/`production`,
  default development). In production il blocco `diagnostics` è **omesso**.
- **iOS**: `URLSessionBackendBoardFetcher` allega `X-Binario-App-Token` se
  `BackendEndpointConfig.appToken` è valorizzato; se vuoto logga
  `[BackendLive] app token not configured` e non allega header. 401 → errore tipizzato
  → `BackendBoardService` fallback alla fixture (header "Backend fixture"). Nessun
  token reale committato (placeholder vuoto, da impostare in locale).

### Validazione
- Backend: `deno check` pulito; `deno test` **16/16** (7 hardening + 9 parser).
  Handler locale: no token→401, token errato→401, token corretto→200 (diagnostics in
  dev), production+token→200 **senza diagnostics**, production+token assente→401.
  Funzione **rideployata**; live senza token → 200 (unconfigured+development),
  header rate-limit presenti.
- iOS: Build Debug+Release OK; test target compila (5 nuovi test token/401/fallback;
  esecuzione bloccata da CoreSimulator — ambiente).

### Secret Supabase richiesti (non nel repo)
- `BINARIO_BOARD_APP_TOKEN=<token>` · `BINARIO_BOARD_ENV=production`
  (`supabase secrets set …`, poi redeploy). Token speculare in
  `BackendEndpointConfig.appToken` lato app (in locale, non committato).

### Sicurezza / prossimo
- Nessun secret committato (solo project ref pubblico). Release resta `.mock`.
  Prossimo: rate limit distribuito, espansione station registry, arrivi,
  decisione di rollout produzione.

## 2026-06-17 — Validate backend live on iPhone

Stato: **VALIDATO end-to-end su iPhone reale.** Backend adapter provato:
iOS → Supabase Edge Function `/board` → RFI → JSON normalizzato → board.

### Validazione su device
- **Evidenza**: log console Xcode da iPhone reale (nessuno screenshot catturato):
  `[BackendLive] OK · rows=40 · source=rfiLive · fallback=false · stale=false`.
- **Conferma**: `.backendLivePadova` chiama con successo la Supabase `/board`; il
  backend ha restituito **40 righe live**; `fallback=false` (fixture NON usata);
  `stale=false` (nessun cache stale); **nessun log `[RFILive]`** → il parser RFI
  diretto on-device non gira in questa modalità.

### Contesto (già fatto in precedenza)
- **Function deployata**: `board` sul progetto Supabase "Binario 1"
  (`supabase functions deploy board --no-verify-jwt`). Endpoint:
  `https://hzwwvkuxqhmeicylyrsy.functions.supabase.co/board`.
- **Endpoint validato via curl**: `?stationSlug=padova&type=departures&locale=it`
  → 200 partenze reali (categorie compatte, niente `Categoria`/entità); 404 station
  sconosciuta; 400 `type=arrivals`.
- **iOS DEBUG**: `BackendEndpointConfig.debug` punta all'URL reale (project ref
  pubblico, non un secret; nessuna anon/service_role key, nessun header Authorization).

### Prossimo hardening (non ancora avviato)
- app token / auth · rate limiting · cache condivisa · espansione station registry
  · supporto arrivi · riduzione diagnostics · decisione di rollout in produzione.

### Sicurezza
- Nessun secret committato (solo il project ref pubblico). Release resta `.mock`.
  `.backendFixturePadova`/`.rfiLivePadova`/`.mock` invariati; Viaggi/Cerca invariati.
  Pass solo-doc: nessun codice modificato.

## 2026-06-17 — iOS backend live fetcher

Stato: completata (Phase 2B lato iOS). Prossima: **deploy della function + hardening
produzione (auth/rate limit/cache condivisa/registry stazioni reale)**.

### Cosa (niente UI ridisegnata; Viaggi/Cerca invariati)
- **Fetcher di rete**: nuovo `Services/URLSessionBackendBoardFetcher.swift`, conforme
  a `BackendBoardFetching`. Costruisce `<base>/board?stationSlug=…&type=…&locale=…`,
  fa `URLSession.data(from:)`, valida lo status HTTP 2xx, ritorna `Data` grezza
  (nessuna decodifica nel fetcher). Errori tipizzati `BackendFetchError`
  (`invalidURL`/`invalidResponse`/`httpStatus`/`emptyResponse`).
- **Config endpoint centralizzata**: nuovo `Services/BackendEndpointConfig.swift`
  (`baseURL`). DEBUG: `BackendEndpointConfig.debug` con host placeholder
  `project-ref-not-set` → `isConfigured == false` finché non si mette il project-ref
  reale (NON è un secret; nessuna anon/service_role key). Spike `verify_jwt = false`
  → nessun header Authorization.
- **Source mode** `.backendLivePadova` (DEBUG): iOS → Edge Function `/board` → RFI →
  JSON normalizzato. Default DEBUG. Mantenuti `.backendFixturePadova`, `.rfiLivePadova`,
  `.scheduledPadova`, `.mock`. Release resta `.mock`.
- **Factory**: `.backendLivePadova` usa `BackendBoardService(fetcher: URLSession…,
  fallback: <servizio fixture>, stampSourceKind: .backendLive, debugLogTag: "BackendLive")`.
  Se l'URL non è configurato → usa direttamente la fixture (log esplicito). Su errore
  di rete → fallback alla fixture **non silenzioso** (`[BackendLive] FALLBACK …`).
- **Header**: nuova `BoardSourceKind.backendLive` → "Backend · Monitor RFI online" /
  "Backend · RFI online monitor"; suffisso " · fallback" (source.isFallback) o
  " · dati cache"/"· cached" (source.isStale) in colore d'allerta. Distingue il dato
  che arriva dal backend dal dato RFI diretto.
- **Log DEBUG concisi**: `[BackendLive] OK · rows=N · source=rfiLive · fallback=… ·
  stale=…`, `[BackendLive] FALLBACK · reason=… · using=fixture`, `[BackendLive] HTTP
  ERROR · status=…`, `[BackendLive] FETCH ERROR · error=…` (nessun body JSON grande).

### Test (nessuna rete reale)
- URL builder = `/board?stationSlug=padova&type=departures&locale=it`.
- Fetcher: 200→Data, non-2xx→`httpStatus`, body vuoto→`emptyResponse` (via
  `StubURLProtocol` stateless, host-encoded).
- `BackendBoardService` mappa JSON remoto stubbato → `StationBoardResponse`
  (`sourceKind == .backendLive`, categorie compatte, ritardo/stato corretti).
- `BackendEndpointConfig.isConfigured` rileva il placeholder.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da CoreSimulator (ambiente). Release mock-only; nessun secret commesso.

## 2026-06-17 — Supabase board backend adapter spike

Stato: completata (Phase 2A, spike backend). Prossima: **fetcher di rete iOS verso
l'endpoint + hardening produzione (rate limit/auth/cache condivisa)**.

### Cosa (solo backend; nessuna modifica iOS UI/Viaggi/Cerca)
- **Edge Function `board`** (Deno/TypeScript) in `supabase/functions/board/`:
  `GET /board?stationSlug=padova&type=departures&locale=it`.
- **Padova partenze** supportate (registry minimo `STATIONS`: `rfiLivePlaceId=2000`,
  `prmScheduledId=1861`, sistemi distinti, mai mischiati).
- **Fetch RFI server-side** del monitor pubblico (placeId 2000, `arrivals=False`);
  cattura status/content-type/byte/fetchedAt/HTML.
- **Normalizzazione server-side** (`rfi.ts`, port del parser iOS DEBUG): categorie
  compatte (REG/RV/AV/FR/IC/EC/RJ/…), niente `Categoria`, niente entità HTML; binario
  assente → `--`; ritardo>0 → `delayed`; cancellato → `cancelled`; in partenza →
  `departing`; altrimenti `onTime`. Niente ritardi/binari inventati.
- **Risposta compatibile con `BackendBoardDTO` iOS** (`station`/`boardType`/`source`/
  `rows`/`diagnostics`).
- **Cache** in-memory (key `slug:type:locale`, TTL 30s); su errore RFI con cache
  calda → dati stale con `isFallback=true`/`isStale=true`; senza cache → `502`
  strutturato. Codici: 200/400/404/405/502. CORS permissivo + preflight `OPTIONS`
  (TODO restringere in prod).
- **Auth/JWT (spike)**: endpoint pubblico, `verify_jwt = false` in `config.toml`
  (deploy `supabase functions deploy board --no-verify-jwt`). Niente DB, niente
  service_role, niente secret nel repo (`supabase/.gitignore` esclude `.env`/`.temp`).
- **Test/validazione**: `rfi_test.ts` (Deno, puro, nessuna rete) su categorie/entità/
  ritardo/binario/stato + shape. Deno non installato in locale → check eseguibile con
  `deno test` / `deno check` quando disponibile.

## 2026-06-17 — Backend adapter iOS fixture phase

Stato: completata (Phase 1 lato iOS, solo fixture). Prossima: **Phase 2 — fetcher di
rete `URLSession` verso backend staging, RFI diretto come fallback dev**.

### Cosa (niente backend reale, niente rete, niente UI ridisegnata)
- **DTO backend**: nuovo `Services/BackendBoardDTO.swift` — decodifica il JSON
  normalizzato del contratto `GET /api/board` (`station`, `boardType`, `source`,
  `rows`, `diagnostics` opzionale). I DTO sono solo modello di trasporto: le view non
  li vedono mai.
- **Mapper**: nuovo `Services/BackendBoardMapper.swift` — DTO → `StationBoardResponse`.
  Regole sicure: niente ritardi/binari inventati; binario assente → `--`; ritardo
  0/assente → nessun badge; `cancelled` → stato cancellato senza ritardo; status
  ignoto → derivato dal ritardo. Categorie già compatte dal backend (REG/RV/AV/IC/…).
- **Service**: nuovo `Services/BackendBoardService.swift` — conforme a
  `TrainBoardService`, sorgente via `BackendBoardFetching`; in Phase 1 solo
  `FixtureBackendBoardFetcher` (JSON dal bundle, **nessuna rete**). Decodifica → mappa
  → marca `sourceKind = .backendFixture`; fallback obbligatorio al mock su
  errore/board vuota o per gli arrivi.
- **Fixture JSON normalizzato**: `Binario1/Resources/backend-padova-departures.sample.json`
  (risorsa app per il service DEBUG) + `Binario1Tests/Fixtures/backend-padova-departures.sample.json`
  (test). 9 partenze Padova realistiche (REG/RV/AV verso Venezia/Napoli/Belluno/
  Bologna, +5′, +12′, una cancellata). JSON normalizzato, niente `Categoria`, niente
  entità HTML, niente label sorgente nelle righe.
- **Source mode DEBUG**: aggiunto `.backendFixturePadova` (default DEBUG; header
  "Backend fixture · Monitor RFI online" / "Backend fixture · RFI online monitor",
  nuova `BoardSourceKind.backendFixture`). Mantenuti `.rfiLivePadova`,
  `.scheduledPadova`, `.mock` (flip in `AppEnvironment.sourceMode`). Release resta
  `.mock`.

### Test
- DTO: decodifica fixture (id/nome stazione, boardType, source kind/label, righe,
  diagnostics opzionali) + decodifica senza `diagnostics`.
- Mapper: 9 righe preservate, categorie compatte (no `Categoria`/`&#`), binario
  assente → `--`, 0/cancellata → nessun ritardo, 5′ → medium, 12′ → severe.
- Service: carica la fixture senza rete, `sourceKind == .backendFixture`.
- Nessun test usa rete o backend reale.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). UI/Viaggi/Cerca invariati; Release
  mock-only.

## 2026-06-17 — Prepare backend adapter architecture

Stato: completata (design + scaffold). Prossima milestone: **Phase 1 — `BackendBoardService`
+ DTO contro fixture JSON locale**.

### Cosa (niente backend, niente UI)
- **Doc architettura backend**: nuovo `docs/13_BACKEND_ADAPTER.md` con flusso
  `iOS → adapter backend → RFI → JSON normalizzato → iOS`, motivazioni (no scraping
  in produzione, fix parser server-side, meno rischio update app, cache/rate-limit,
  fallback futuri, JSON stabile), **contratto API** `GET /api/board`
  (`stationSlug`/`stationId`, `type`, `source`, `locale`) + esempio JSON che
  rispecchia il modello app, requisiti backend (cache 30–60s, rate-limit,
  stale-but-recent, `isFallback`/`isStale`, trasparenza sorgente), **piano di
  migrazione iOS** (Phase 1 DTO+`BackendBoardService` su fixture; Phase 2 backend in
  DEBUG con RFI diretto come fallback dev; Phase 3 produzione su backend, RFI HTML
  escluso da Release), e **station registry** (Padova: slug `padova`, displayName
  `Padova`, rfiLivePlaceId `2000`, prmScheduledId `1861`; live placeId ≠ id PRM, mai
  mischiarli).
- **Fixture reale**: NON aggiunta in questo pass — il file catturato vive nel
  container del device (`Documents/rfi-padova-live-latest.html`) e non è recuperabile
  da qui; per policy "non inventare fixture" non è stato fabbricato. Aggiunto un test
  `rfiRealSampleParsesIfPresent` che carica `rfi-padova-departures.real-sample.html`
  dal bundle di test e **salta** finché il file non è aggiunto (poi verifica
  PADOVA, ≥20 righe, categorie normalizzate senza `Categoria`/`&#`). La fixture
  rappresentativa esistente resta.

### Come aggiungere la fixture reale (manuale)
Xcode → Window > Devices and Simulators → iPhone → app Binario1 → Download Container
→ `AppData/Documents/rfi-padova-live-latest.html` → copiare in
`Binario1Tests/Fixtures/rfi-padova-departures.real-sample.html` (sanitizzare se serve).

### File
- Nuovo: `docs/13_BACKEND_ADAPTER.md`. Modificati: `Binario1Tests` (test reale gated),
  `docs/12_DECISIONS.md`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Nessuna rete nei test; UI/Viaggi/Cerca
  invariati; Release resta mock-only.

## 2026-06-16 — RFI live hardening and delay-column polish

Stato: completata. Prossima milestone: **verifica parser su HTML reale + fixture
sanitizzata**.

### 1. Doppio fetch RFI (investigato + risolto)
- **Causa**: `selectBoardType` chiamava `refresh()` E il cambio di `boardType`
  rilancia `.task(id:)` → due fetch al cambio Partenze/Arrivi; eventuali
  re-trigger del `.task` all'apertura non erano deduplicati. Il token animazione
  titolo **non** causava reload (alimenta solo il titolo header — confermato).
- **Fix**: `refresh(force:)` con **guard in-flight** (no overlap) + **dedupe per
  board** (stesso `station|boardType` entro `minAutoRefreshInterval` = 8s →
  skip); `selectBoardType` non fa più fetch (lo fa `.task(id:)`); pull-to-refresh
  usa `force: true`; il fetch annullato (superseded) non mostra errore.
- Risultato: apertura → 1 fetch; refresh manuale → 1 fetch; ritorno da
  Viaggi/Cerca → nessun fetch automatico; cambio board → 1 fetch.

### 2. Diagnostica DEBUG più pulita
- Log conciso: `[RFILive] LIVE OK · status=200 · rows=40 · bytes=… · contentType=… · fallback=false`,
  `[RFILive] FALLBACK · status=… · rows=0 · …`, `[RFILive] FETCH ERROR · fallback=true · error=…`.
- Riepilogo categorie: `[RFILive] categories: AV=12, RV=8, REG=15, …`.
- Log per-riga categoria dietro flag `RFILiveMapper.logsCategoryNormalizationDetails`
  (default `false`). Capture HTML grezzo in Documents invariato (path loggato).

### 3. Colonna ritardo compatta (UI)
- In "Tutte le partenze" la colonna ritardo ora è una `VStack`: etichetta piccola
  `Rit.` / `Del.` + badge ritardo sotto. Mostrata solo se c'è ritardo/cancellazione;
  colonna a larghezza fissa stabile quando vuota; nessuno shift della destinazione.

### 4. Logica colore ritardo semantica
- Nuovo `DelayVisualState` (mild/medium/severe/cancelled): 1–4' ambra, 5–9' arancio
  (`BoardColors.delayMedium`), 10'+ rosso-arancio, cancellato rosso, 0/nil → nessun
  badge. Rosso riservato ai problemi seri.

### File
- Modificati: `ViewModel/StationBoardViewModel.swift` (dedupe/force),
  `Views/StationBoardView.swift` (onSelect sync, refresh force),
  `Views/DelayBadgeView.swift` (`DelayVisualState`), `Views/TrainBoardRowView.swift`
  (colonna ritardo label+badge), `DesignSystem/BoardTheme.swift` (`delayMedium`),
  `Services/RFILiveBoardService.swift` (log + flag + summary), `Localizable.xcstrings`
  (`delay.short`), `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Aggiunti test soglie ritardo + dedupe.

## 2026-06-16 — RFI live diagnostics

Stato: completata (tooling DEBUG). Prossima milestone: **girare su iPhone reale e
salvare una fixture reale (sanitizzata) dal capture**.

### Cosa (solo DEBUG; nessun cambiamento di produzione)
- Nuova diagnostica `.rfiLivePadova`: niente più fallback silenzioso in DEBUG.
- `RFIStationMonitorDiagnostics` (url, status, content-type, byte ricevuti, righe
  parsate, fallback sì/no, `renderedSource`, errore, path HTML catturato) +
  `RFILiveDiagnosticsStore` (`@Observable`, singleton, solo DEBUG).
- Client: `fetchMonitor` ora restituisce `RFIMonitorFetchResult` (html + status +
  content-type + byteCount). Il service popola la diagnostica:
  - live → `usedFallback=false`, `renderedSource="live"`.
  - fetch ok ma 0 righe → `"fallback-after-empty-parse"`.
  - fetch fallito → `"fallback-after-fetch-error"`.
- **Capture HTML grezzo** (solo DEBUG) in Documents:
  `rfi-padova-live-latest.html` + `rfi-padova-live-YYYYMMDD-HHmmss.html`, path
  loggato in console. Mai in RELEASE, mai committato/caricato.
- **Banner DEBUG** sotto l'header (solo se `.rfiLivePadova`): es.
  `DEBUG RFI: 200 · 48 KB · 12 rows · live` / `… · 0 rows · fallback` /
  `DEBUG RFI: error · fallback` (rosso se fallback). Console logga URL, content-type,
  path capture, errore.
- Diagnostica iniettabile (`recordDiagnostics`) per test deterministici; di default
  scrive nello store osservato dalla UI.

### File
- Nuovi: `Services/RFILiveDiagnostics.swift`, `Views/RFILiveDiagnosticsBanner.swift`
  (entrambi `#if DEBUG`).
- Modificati: `Services/RFIStationMonitorClient.swift` (`RFIMonitorFetchResult`),
  `Services/RFILiveBoardService.swift` (diagnostica + capture), `Views/StationBoardView.swift`
  (banner DEBUG), `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release; in Release nessuna diagnostica/capture, tutto escluso).
- Test target: compila. Esecuzione unit test bloccata da instabilità CoreSimulator
  (ambiente). Test diagnostica via stub: live/empty/error, byteCount, rowCount.

### Prossimo
- Eseguire su iPhone reale; usare l'HTML catturato per verificare il parser e,
  se serve, salvarne una versione **sanitizzata** come fixture (mai auto-commit).

## 2026-06-16 — Normalize RFI train categories

Stato: completata. Prossima milestone: **verifica parser su HTML RFI reale**.

### Bug (su iPhone reale)
- Le categorie RFI arrivavano verbose: `Categoria RV`, `Categoria Alta
  Velocita&#39;`, ecc. → card con testo lungo, lista compatta troncata `CATE...`,
  entità HTML non decodificate (`&#39;`).

### Fix (solo parser/normalizzazione)
- Nuovo `HTMLEntityDecoder` (entità numeriche `&#39;`/`&#224;` + alcune named) e
  `RFITrainCategoryNormalizer`: decodifica entità → normalizza apostrofi/accenti →
  rimuove il prefisso `Categoria` → mappa alle sigle compatte
  (Regionale→REG, Regionale Veloce→RV, Alta Velocità/Velocita'→AV, Frecciarossa→FR,
  Frecciargento→FA, Frecciabianca→FB, Intercity→IC, Intercity Notte→ICN, Italo→ITA,
  Eurocity→EC, Euronight→EN). Sconosciute lunghe → `UNK` (mai stringhe lunghe).
- Il parser ora **decodifica le entità** in `clean` e negli `alt` immagine, così
  nessuna cella (categoria, destinazione…) espone `&#…`.
- `RFILiveMapper.category` delega al normalizzatore (+ log DEBUG `raw→normalized`).
- UI: aggiunto `lineLimit(1)` alla categoria della card "Prossime partenze"
  (la lista compatta aveva già `lineLimit(1)` + colonna fissa). Numero treno resta
  separato dalla categoria. Nessun redesign.

### Test
- Normalizzatore (tutti i casi: RV/REG/AV/FR/IC/ICN/ITA, sconosciuto→UNK,
  nil/empty→UNK), decoder HTML, e fixture RFI aggiornata con `Categoria …` +
  `&#39;`: asserzioni che nessuna `TrainBoardRow.category` contiene `Categoria` o
  `&#`, riga AV→`AV`, riga RV→`RV`. Niente rete.

### File
- Nuovo: `Services/RFITrainCategoryNormalizer.swift` (`#if DEBUG`).
- Modificati: `Services/RFIStationMonitorParser.swift` (decode entità),
  `Services/RFILiveBoardService.swift` (delega + log), `Views/FeaturedTrainRowView.swift`
  (`lineLimit(1)` categoria), `Binario1Tests` + fixture `rfi-padova-departures.sample.html`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente).

## 2026-06-16 — RFI live Padova spike

Stato: completata (spike tecnico). Prossima milestone: **verifica parser su HTML
RFI reale + valutazione affidabilità/legale**.

### Cosa
- Primo spike **dati reali**, **solo DEBUG**: adapter del monitor live RFI per
  **Padova partenze**. Endpoint
  `https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000`
  (live monitor `placeId=2000`, distinto dall'id PRM Quadro Orario 1861).
- Nuovo `BoardSourceMode.rfiLivePadova`. `AppEnvironment.sourceMode`:
  **DEBUG → `.rfiLivePadova`**, **RELEASE → `.mock`** (lo spike non diventa mai il
  default di produzione; i file RFI sono `#if DEBUG`).
- Layer service isolato (niente parsing nelle view/VM):
  - `RFIStationMonitorClient` — costruisce l'URL + fetch HTML (`RFIMonitorFetching`).
  - `RFIStationMonitorParser` — HTML → `RFIMonitorBoard`/`RFIMonitorRow` (stazione,
    aggiornato, righe positional `<td>`, tollerante a righe malformate).
  - `RFILiveBoardService` (`TrainBoardService`) + `RFILiveMapper` → `StationBoardResponse`
    (`sourceKind = .rfiLive`). Departures only; arrivi e qualsiasi errore →
    **fallback al mock** (obbligatorio).
- Mapping sicuro: binario mancante → `--`, ritardo mancante/"0" → nessun ritardo
  (mai finto), destinazione mancante → `Destinazione non disponibile`,
  cancellato/soppresso → `.cancelled`. Stazione bloccata su Padova.
- Header: `Monitor RFI online` / `RFI online monitor` (+ `· aggiornato HH:mm` se
  disponibile). Nessuna etichetta `Orario programmato` / `demo 06:00–06:59` in live.
- Refresh: solo manuale/path esistente (refresh ogni 30s del board già presente);
  nessun polling aggressivo/background/notifiche/Live Activities.
- Fixture `Binario1Tests/Fixtures/rfi-padova-departures.sample.html` + test unitari
  (URL, stazione `PADOVA`, aggiornato, ≥3 righe, numero/destinazione/ora/binario,
  ritardo non finto, mapper valido, cancellato, HTML vuoto sicuro, fallback al
  mock). I test non usano rete.

### Limiti noti
- **HTML RFI non è un contratto stabile**: i selettori del parser sono tarati su
  una fixture rappresentativa e vanno verificati sull'HTML live (obiettivo dello
  spike). Se non combacia → 0 righe → fallback al mock (UI stabile).
- Nessuna garanzia di produzione, nessun multi-stazione, niente arrivi live,
  niente AI/notifiche/Live Activities/persistenza.

### File
- Nuovi: `Services/RFIStationMonitorClient.swift`, `Services/RFIStationMonitorParser.swift`,
  `Services/RFILiveBoardService.swift` (tutti `#if DEBUG`),
  `Binario1Tests/Fixtures/rfi-padova-departures.sample.html`.
- Modificati: `Models/BoardSourceMode.swift`, `Models/StationBoardResponse.swift`
  (`BoardSourceKind`/`sourceKind`), `Binario1App.swift`,
  `ViewModel/StationBoardViewModel.swift`, `Views/StationBoardHeaderView.swift`,
  `Views/StationBoardView.swift`, `Localizable.xcstrings`, `Binario1Tests`.

### Build / test
- Build: OK (Debug e Release). Test target: compila. Esecuzione unit test bloccata
  da instabilità CoreSimulator (ambiente). Parser/mapper verificati su fixture.

## 2026-06-16 — Fix Partenze tab-entry title animation

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Bug
- Tornando su Partenze da un altro tab, il titolo stazione si **bloccava sul primo
  carattere** (es. solo `P` invece di `PADOVA`). Causa: il restart usava
  `.id(token)` (remount) + reveal **per-carattere** con `Task` staggerati; in
  `FlipCharacter.startFlip` la cancellazione durante il delay usciva **senza**
  impostare il glifo finale → i caratteri successivi restavano vuoti.

### Fix (solo lifecycle animazione; stile LED invariato)
- Riscritto `DotMatrixStationTitleView` con un **reveal deterministico**: un solo
  `.task(id:)` (token tab + nome stazione) guida un contatore `revealed`; ogni
  glifo si accende con un leggero flip 3D (asse `(x:0, y:1, z:0)`) quando il
  contatore lo supera. Il loop **finisce sempre** a `totalReal` e imposta il titolo
  pieno anche se cancellato → **mai parziale**.
- Rimosso `.id(token)` dal titolo in `StationBoardHeaderView`; il token è ora
  passato nel componente. Reduce Motion → titolo pieno immediato.
- Rendering LED invariato (Text ambra + texture punti + glow, font 34/22, colori).
- Nessun reload dati (il token tocca solo il `.task` del titolo); nessuna modifica
  a Viaggi/Cerca, scheduledPadova, righe/lista, ordine tab.

### File
- Riscritto: `Views/DotMatrixStationTitleView.swift`. Modificato:
  `Views/StationBoardHeaderView.swift` (no `.id`, passa token). `Binario1Tests`:
  `stationTitleResolvesToFullName`. `RootTabView`/`StationBoardView` invariati
  (il token già fluisce).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Determinismo del reveal verificato per
  costruzione (final state garantito) + build.

## 2026-06-16 — Viaggi pixel-fidelity polish

Stato: completata. Riferimento: `References/mockup-viaggi.png`. Prossima
milestone: **Smart Suggestions / App Intents**.

### Cosa (solo Viaggi; struttura, dati, Home/Partenze/Cerca invariati)
- **Densità verticale** avvicinata al mockup (lo schermo era troppo arioso):
  spaziatura tra sezioni 18→14, header sezione→contenuto 10→8, gap card salvate
  12→10.
- **Card salvate** più compatte: icona circolare 44→38, padding 14→13, spacing
  interno 13→11, griglia dettagli verticalSpacing 4→3. Gerarchia invariata
  (orario valore più forte, binario bilanciato).
- **Useful card** più densa (resta il centerpiece con bordo/glow ambra): spacing
  interni 12→10, padding 16→14.
- **Filtro** e **quick actions** leggermente più compatti (padding verticale 9→8
  e 11→10).
- Identità LED ambra, transizioni numeriche, orari Recenti su una riga: invariati.

### File
- Modificati: `Views/TripsView.swift`, `Views/SavedJourneyCardView.swift`,
  `Views/UsefulJourneyCardView.swift`, `Views/TripsFilterControl.swift`,
  `Views/TripsQuickActionsView.swift`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Fedeltà rifinita sul mockup in repo;
  niente screenshot perché il simulatore non si avvia in questa sessione.

## 2026-06-16 — Viaggi Visual Fidelity Pass

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo polish visivo Viaggi; struttura/dati invariati)
- Header: titolo LED `VIAGGI` più grande (42), sottotitolo su **una riga**
  (`lineLimit(1)` + scale) così `Aggiornato HH:mm ●` resta allineato.
- Filtro: pill selezionata con glow più pulito (raggio 5→3, opacità 0.5→0.4) e
  controllo leggermente più alto (padding 8→9), meno "over-glow".
- Useful card: destinazione leggermente più prominente (17→18).
- Quick actions: bordo più sottile (0.55) per un look railway-control premium.
- Nessuna nuova feature/colore; mock e Home/Partenze/Cerca invariati.

### File
- Modificati: `Views/TripsHeaderView.swift`, `Views/TripsFilterControl.swift`,
  `Views/UsefulJourneyCardView.swift`, `Views/TripsQuickActionsView.swift`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente). Nessun mockup Viaggi nel repo + simulatore
  non avviabile → fedeltà rifinita per costruzione sul mockup condiviso, non con
  screenshot.

## 2026-06-15 — Viaggi Numeric Alignment and Animation Polish

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- **Allineamento riga dettaglio card salvate**: la riga `PROSSIMA PARTENZA /
  BINARIO / DURATA / STATO` ora è una `Grid` a 4 colonne: etichette allineate in
  alto, valori allineati sulla stessa baseline (`GridRow(alignment:.firstTextBaseline)`).
  `07:18` resta il valore più grande; il binario è più piccolo (18 vs 22) e non
  domina; `37 min` e `In orario` sono sulla stessa riga visiva.
- **Animazione Partenze al rientro nel tab**: `RootTabView` traccia `selectedTab`
  (`AppTab`) con `TabView(selection:)` + `Tab(value:)`; al rientro su `.departures`
  incrementa `departuresAnimationToken`, passato a `StationBoardView` →
  `StationBoardHeaderView`, che applica `.id(token)` **solo al titolo** (non al
  board) per rieseguire il reveal. **Nessun reload dati** (la `.task` dipende da
  `boardType`, non dal token), scroll non resettato. **Reduce Motion**: `.id`
  costante → nessun restart/motion.
- **Transizioni numeriche testabili (DEBUG)**: nuova `NumericTransitionPreviewView`
  (solo `#if DEBUG`, non in produzione) con valori campione (time 07:18→07:22,
  platform 2→4→6, duration 37→42→51, delay 0→12→35) e bottone *Test numeric
  animation* che aggiorna i valori in `withAnimation(.snappy)` → i numeri rollano.
- Transizioni numeriche confermate solo su valori numerici dinamici (orari,
  binari, durata, ritardo); nomi/categorie/titolo restano statici. Reduce Motion
  rispettato ovunque.

### File
- Modificati: `Views/SavedJourneyCardView.swift` (Grid + baseline),
  `Views/StationBoardHeaderView.swift` + `Views/StationBoardView.swift`
  (`animationToken`), `Views/RootTabView.swift` (`AppTab` + selection + token).
- Nuovo (DEBUG): `Views/NumericTransitionPreviewView.swift`.
- `Binario1Tests`: stringhe display Viaggi corrette (time/binario/durata/ritardo).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice). Allineamento e no-wrap
  verificati a livello di layout (Grid + baseline, monospaced, lineLimit) e build.

## 2026-06-15 — Viaggi Numeric Text Polish

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- **Fix wrapping orari `Recenti`**: gli orari (`08:32`, `09:15`, `07:50`) andavano
  a capo (`08:3` / `2`) perché `LEDText` (dot) in una colonna stretta (52pt) si
  spezzava. Ora gli orari delle righe compatte usano `BoardNumberText` (Text
  affidabile, `monospacedDigit` + `lineLimit(1)` + `minimumScaleFactor`, colonna
  fissa 56pt, glow) → **sempre una riga**.
- **Helper numerico riusabile** (`Views/BoardNumberText.swift`):
  - `BoardNumber.value(from:)` — chiave roll dai digit di una stringa.
  - `BoardNumberText` — label numerica affidabile a una riga con transizione.
  - `.boardNumericTransition(_/value:)` — aggiunge `.contentTransition(.numericText(value:))`
    a un Text numerico esistente.
  - `LEDText.animatesNumeric` — transizione opzionale sui numeri LED (titolo
    `VIAGGI` resta statico).
  - Tutto **no-op con Reduce Motion** (valore finale senza rolling).
- **Applicato ai numeri Viaggi**: orari/binari/durata/ritardo (saved, useful,
  recent). Il **numero treno resta statico** (categoria+numero non è puro numerico).
  Dati mock statici → nessun roll ora; pronto per dati dinamici futuri.
- **Home/Partenze invariata**: l'helper è scoped a Viaggi (`PlatformBadgeView`/
  `DelayBadgeView`/righe board non toccati); estensione futura documentata.

### File
- Nuovo: `Views/BoardNumberText.swift`. Modificati: `Views/LEDText.swift`
  (`animatesNumeric` + `lineLimit(1)`), `Views/RecentJourneyRowView.swift`,
  `Views/SavedJourneyCardView.swift`, `Views/UsefulJourneyCardView.swift`,
  `Views/JourneyPlatformBadgeView.swift`, `Views/JourneyStatusBadgeView.swift`,
  `Binario1Tests` (chiave numerica + formato orari recenti).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice). Wrapping verificato a livello
  di layout (colonna fissa + monospaced + lineLimit) e build.

## 2026-06-15 — Restore approved Home LED title

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo area titolo Home)
- Ripristinata l'**animazione** del titolo stazione LED/dot-matrix già approvato
  (`DotMatrixStationTitleView`, flip 3D per carattere, asse `(x:0, y:1, z:0)`,
  stagger per indice, rispetta Reduce Motion).
- **Causa della regressione**: il renderer non era cambiato (è quello approvato:
  `Text` affidabile + griglia di punti LED mascherata + glow), ma il flip partiva
  solo `onChange` della stazione; con `.scheduledPadova` la stazione è bloccata su
  Padova → il flip non scattava mai → titolo "statico".
- **Fix**: il flip approvato ora parte anche come **reveal alla prima comparsa**
  (`onAppear`), riusando lo stesso meccanismo `startFlip` — nessun renderer nuovo,
  nessuna variante. Padova "accende" i caratteri a cascata; in mock il flip al
  cambio stazione resta.
- Nessuna modifica a: righe board, `.scheduledPadova`, label
  `Orario programmato · demo 06:00–06:59`, segmented Partenze/Arrivi, ticker,
  Viaggi, Cerca, navigazione.

### File
- Modificato: `Views/DotMatrixStationTitleView.swift` (solo `FlipCharacter.onAppear`).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Native Search Tab

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa
- Il terzo tab primario passa da **Info** a **Cerca**, usando il ruolo nativo
  SwiftUI `Tab(role: .search)`. Nuovo ordine tab: **Partenze · Viaggi · Cerca**.
- Nuova `CercaView` con `.searchable` nativo (dentro `NavigationStack`): da inattiva
  mostra tre voci categoria (Cerca stazione / tratta / treno); durante la ricerca
  mostra risultati **mock** raggruppati in Stazioni / Tratte / Treni, oppure
  `Nessun risultato`. `CercaViewModel` (`@Observable`) filtra un catalogo mock
  (case-insensitive). **Solo mock**: niente API, AI, notifiche, persistenza.
- `InfoView` **non rimossa**: resta nel codice per una futura area secondaria
  settings/about (non è più un tab primario).
- Localizzazione IT/EN: `tab.search`, `search.station/route/train`,
  `search.stations/routes/trains`, `search.noResults`, `search.prompt`.
- Partenze e Viaggi invariati.

### File
- Nuovi: `Views/CercaView.swift`, `ViewModel/CercaViewModel.swift`.
- Modificati: `Views/RootTabView.swift` (Info → Cerca `.search`),
  `Localizable.xcstrings`, `Binario1Tests` (filtro ricerca).
- `Views/InfoView.swift`: invariata, non più referenziata come tab.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Viaggi Visual Fidelity Pass

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents**.

### Cosa (solo UI Viaggi; Home/Partenze invariata)
- Refinement pixel-oriented del tab Viaggi sul mockup di riferimento. Dati e
  architettura invariati.
- **Header**: brand `Binario [1]` (cifra in box), titolo LED dot-matrix `VIAGGI`
  (nuovo primitivo riusabile `LEDText`), sottotitolo, **bottone cerca circolare**
  (placeholder, no logica Search) e `Aggiornato HH:mm ●` (mostrato solo dopo il
  caricamento).
- **Filtro**: pill selezionata con gradiente ambra brillante + testo scuro + glow,
  transizione animata (`matchedGeometryEffect`).
- **Ordine sezioni** allineato al mockup: Tratte salvate → Prossimo viaggio utile
  → Recenti → azioni rapide.
- **Card salvate**: icona circolare casa/lavoro, stella, titolo + rotta board
  UPPERCASE abbreviata, griglia a 4 colonne allineate (Partenza/Binario/Durata/
  Stato). **Stato**: pallino verde + `In orario` / pallino rosso + badge `+12 min`.
- **Prossimo viaggio utile**: orario LED grande + destinazione + `da ORIGINE`,
  griglia Durata/Treno/Arrivo con separatori, **binario LED grande** a destra,
  barra inferiore con pallino verde `In orario` + icona treno; bordo ambra bright.
- **Recenti**: righe compatte (ora LED, rotta board, `CAT NUM · durata`, binario,
  chevron) con `Vedi tutti ›` azionabile nell'header sezione.
- **Azioni rapide**: pill compatte orizzontali (icona + testo).
- **Tab bar**: icone tram/suitcase/info, aspetto scuro opaco + tint ambra.
- Nuovo colore `BoardColors.statusGreen` per lo stato "in orario".

### Verifica / fix
- Review multi-agente di fedeltà al mockup; applicati fix: stringhe `min`/`+N min`
  localizzate (`journey.duration.value`, `status.delay.short`), `Vedi tutti`
  azionabile + chevron + VoiceOver, header timestamp non finto, allineamento
  colonne, highlight bright sulla card centrale.

### File
- Nuovi: `Views/LEDText.swift`. Modificati: `Views/TripsHeaderView`,
  `TripsFilterControl`, `SavedJourneyCardView`, `UsefulJourneyCardView`,
  `RecentJourneyRowView`, `TripsQuickActionsView`, `JourneyStatusBadgeView`,
  `JourneyPlatformBadgeView`, `TripsView`, `RootTabView`,
  `NextDeparturesSectionView` (`BoardSectionHeader` + `trailingAction`, additivo),
  `Models/JourneyDisplayData` (rotta board), `ViewModel/TripsViewModel`
  (`lastUpdated`), `DesignSystem/BoardTheme` (verde), `Localizable.xcstrings`.

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata da
  instabilità CoreSimulator (ambiente, non codice).

## 2026-06-15 — Viaggi Tab MVP

Stato: completata. Prossima milestone: **Smart Suggestions / App Intents** (Viaggi
diventa la base per suggerimenti, App Intents e notifiche — non in questo MVP).

### Cosa
- Secondo tab **Viaggi** (dashboard commuter personale), accanto a **Partenze** e
  **Info**. Navigazione root a 3 tab (`RootTabView`, `TabView` con `Tab`), Viaggi
  in seconda posizione. Niente `Tab(role: .search)` (Search è milestone futura).
- `TripsView` data-driven: header (BINARIO1 / VIAGGI / sottotitolo + `+`), filtro
  segmentato (Oggi / Salvati / Recenti), sezione **Tratte salvate** (2 card),
  **Prossimo viaggio utile** (card centrale, binario molto leggibile), **Recenti**
  (3 righe compatte), e 3 **azioni rapide** placeholder (Nuovo viaggio / Segui
  treno / Avvisi).
- **Solo dati mock** (`MockTripsService`): nessuna API, nessuna persistenza,
  nessun dato live. Orari ancorati al giorno corrente (Europe/Rome).
- Riuso del design system esistente (`BoardColors`/`BoardFont`/`.ledGlow`,
  `PlatformBadgeView`, `BoardSectionHeader`, `BoardBackgroundView`, formatter):
  nessuna duplicazione di costanti di stile.
- Accessibilità: label VoiceOver complete per card salvate, card utile e righe
  recenti (nome stazione completo, orari, binario, durata, stato).
- Localizzazione IT/EN completa (tab, header, filtri, sezioni, azioni, label
  viaggio, accessibilità).

### File
- Nuovi modelli: `Models/Journey.swift` (`SavedJourney`, `SuggestedJourney`,
  `RecentJourney`, `JourneyStatus`, `JourneyDirection`, `TripsFilter`, `TripsData`),
  `Models/JourneyDisplayData.swift`.
- Nuovo service: `Services/TripsService.swift` (`TripsService`, `MockTripsService`).
- Nuovo view model: `ViewModel/TripsViewModel.swift` (`@Observable`).
- Nuove view: `Views/TripsView.swift`, `TripsHeaderView`, `TripsFilterControl`,
  `SavedJourneyCardView`, `UsefulJourneyCardView`, `RecentJourneyRowView`,
  `TripsQuickActionsView`, `JourneyStatusBadgeView`, `JourneyPlatformBadgeView`,
  `RootTabView`, `InfoView`.
- Modificati: `Binario1App.swift` (root → `RootTabView`),
  `Views/NextDeparturesSectionView.swift` (`BoardSectionHeader` + `trailingKey`
  opzionale, additivo), `Localizable.xcstrings`, `Binario1Tests`.
- Home / Partenze: **nessuna regressione** (solo aggiunta opzionale additiva al
  componente condiviso `BoardSectionHeader`).

### Build / test
- Build: OK (Debug). Test target: compila. Esecuzione unit test bloccata
  dall'instabilità CoreSimulator in questa sessione (problema d'ambiente, non di
  codice); i nuovi test Trips sono deterministici (clock fisso Europe/Rome).

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
