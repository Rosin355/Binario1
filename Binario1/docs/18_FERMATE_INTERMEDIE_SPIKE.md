# 18 — Spike: dati sulle fermate intermedie dei treni

**Tipo**: spike di esplorazione, non un ticket di prodotto. Nessun codice di prodotto
toccato, nessun servizio nuovo, nessuna UI, nessuna dipendenza aggiunta. Il parser usato
per misurare è throwaway, in una cartella scratch fuori dal repo.
**Data**: 2026-09-01. Tutte le chiamate fra le **14:53 e le 15:05 ora di Roma**.
**Fuori scope, rispettato**: nessuna ricerca di soluzioni A→B. B2 resta rimosso dallo
scope (`12_DECISIONS.md`, "Inquadramento di prodotto"). Dove una fonte offriva anche le
soluzioni, quella parte è stata ignorata.

## Domanda

> Il tabellone mostra il CAPOLINEA. Da Padova non possiamo rispondere a "qual è il
> prossimo treno per Montegrotto", perché nessuna riga dice Montegrotto. Esiste una fonte
> che, data una riga di tabellone già esistente, ne elenchi le fermate — così da poter
> filtrare?

**Risposta breve: sì, e la fonte è il monitor RFI stesso — il dato è già dentro l'HTML
che scarichiamo oggi, a costo zero.** Ma il filtro **non regge come funzione universale**
sulle 2435 stazioni del catalogo: i nomi delle fermate sono stampati in forme abbreviate
che **non si agganciano al catalogo per uguaglianza canonica nel 33,7% dei casi**, e la
forma **cambia a seconda del tabellone da cui la si legge**. Raccomandazione dettagliata
in fondo: **si fa, ma solo a copertura dichiarata per stazione verificata**, e con
"non lo so" come stato di default — mai "non ferma".

> **Nota sul riferimento del brief.** `15_DATA_SOURCE_DECISION.md` **non esiste**, né nel
> repo né nella storia git (mancano sia il 14 sia il 15). La premessa però regge: lo
> smantellamento dell'endpoint soluzioni è verificato e documentato in
> [17_VIAGGIATRENO_SPIKE.md](17_VIAGGIATRENO_SPIKE.md) — `soluzioniViaggioNew` → HTTP 404.
> Lo spike 17 dice che il confronto sistematico fra fonti vive in "un documento di
> decisione esterno, non ancora nel repo": è probabilmente quello.

## Metodo

Misure su HTML e JSON reali, scaricati oggi. Il lettore di righe riproduce **la logica
posizionale di `supabase/functions/board/rfi.ts`** (celle `<td>` per indice, non per nome
di classe); la funzione di confronto fra nomi riproduce **`StationNameMatcher.canonical`**
di `Binario1/Binario1/Models/StationNameMatcher.swift`, espansioni e token neutro `S`
inclusi. Nessuno dei due è stato modificato: sono stati *riprodotti* per poter misurare
senza toccare il prodotto.

Board scaricati (partenze **e** arrivi per i primi tre):

| Stazione | placeId | Righe partenze | Righe arrivi |
|---|---|---|---|
| PADOVA | 2000 | 40 | 40 |
| ROMA TERMINI | 2416 | 40 | 40 |
| TERME EUGANEE-ABANO-MONTEGROTTO | 2829 | 17 | 16 |
| ABANO TERME | 364 | 15 | — |
| MONSELICE | 1776 | 27 | — |

Egress verificato aperto su entrambe le fonti prima di iniziare.

---

# Strada C — il monitor RFI stesso

**Non era un'ipotesi da verificare: il dato è già nel repo.** In `rfi_fixtures.ts`
(HTML reale del 2026-08-18) la cella 8 `RDettagli` contiene, sotto il titolo *Fermate
successive*:

```html
<div class="titoloInfoAggiuntive">Fermate successive</div>
<div class="testoinfoaggiuntive">
    FERMA A:ABANO T. (12:48) - TERME EUGANEE (12:53) - BATTAGLIA T. (12:57) -
    MONSELICE (13:03) - S.ELENA-ESTE (13:15) - STANGHELLA (13:21) - ROVIGO (13:33)
</div>
```

`rfi.ts:233` già lo nomina — per **scartarlo di proposito**: `detailsNote` legge solo il
blocco *Informazioni*, "never the 'Fermate successive' stop list". Il dato passa da anni
sotto il parser e viene buttato via.

Il bottone `apriFermateSuccessive('…')` chiama una funzione JS su un `<div>` **già inline
nella pagina**: nessuna chiamata di rete aggiuntiva, nessun endpoint di dettaglio.

## C1 — Copertura: totale sulle partenze, nulla sugli arrivi

| Board | Righe | Con lista fermate | % |
|---|---|---|---|
| Padova **partenze** | 40 | **40** | **100%** |
| Roma Termini **partenze** | 40 | **40** | **100%** |
| Terme Euganee **partenze** | 17 | **17** | **100%** |
| Padova **arrivi** | 40 | **0** | **0%** |
| Roma Termini **arrivi** | 40 | **0** | **0%** |
| Terme Euganee **arrivi** | 16 | **0** | **0%** |

Spaccato per categoria e vettore (97 righe di partenza):

| Categoria | Righe | Con fermate | | Vettore | Righe | Con fermate |
|---|---|---|---|---|---|---|
| REG | 31 | 100% | | TRENITALIA | 54 | 100% |
| ALTA VELOCITA' | 31 | 100% | | FRECCIAROSSA | 19 | 100% |
| RV | 17 | 100% | | **ITALO** | **11** | **100%** |
| INTERCITY | 6 | 100% | | INTERCITY | 6 | 100% |
| ARL (Leonardo Express) | 5 | 100% | | LEONARDO EXPRESS | 5 | 100% |
| REGIONALE VELOCE | 5 | 100% | | TRENORD | 1 | 100% |
| EC / RJ | 2 | 100% | | FRECCIARGENTO | 1 | 100% |

**Funziona per i regionali esattamente come per la lunga percorrenza**, ed espone anche i
treni **Italo** — la lacuna che nello spike 17 aveva ucciso ViaggiaTreno come fallback.
RFI gestisce l'infrastruttura e li vede tutti. Zero righe con blocco presente ma lista
vuota.

**Sugli arrivi il blocco non esiste in nessuna forma.** Non è il percorso residuo, non è
"fermate precedenti": la cella è **vuota** e porta `aria-label="Nessuna"`.

```html
<td id="RDettagli" aria-label="Nessuna" headers="HDettagli" scope="row" class="…"></td>
```

Zero occorrenze di `FERMA A`, `Fermate successive`, `Fermate precedenti` o
`ApriFermateSuccessive` in tutta la pagina degli arrivi. → **Come chiesto, lo dico
esplicito: il filtro per fermata si può fare SOLO sul lato partenze.** Sul tabellone
arrivi non c'è niente da filtrare.

## C2 — Chiave di join: non serve

Il blocco è **dentro lo stesso `<tr>`** della riga. Non c'è nessuna chiave da costruire,
nessun id di stazione di origine da procurarsi, nessun rischio di associare la lista al
treno sbagliato. Verificato comunque su tutte e 97 le righe:

| Verifica | Esito |
|---|---|
| `title="Treno NNNN"` del popup == cella 2 (numero treno) | **97/97, 0 discordanze** |
| `<tr id="NNNN">` == cella 2 | **97/97, 0 discordanze** |

È la differenza strutturale con la strada A, dove la chiave di join **è** il problema.

## C3 — Costo per tabellone: zero

**0 chiamate aggiuntive per arricchire 40 righe.** Il testo delle fermate pesa
**6.064 byte su 336.689** a Padova (1,80% della pagina) e 6.929 su 319.418 a Roma Termini
(2,17%). Lo stiamo già scaricando e già scartando.

Il parse completo della pagina, blocco fermate incluso, misura **7,1 ms** (Padova) e
**6,8 ms** (Roma Termini) in Python. Il costo marginale dell'estrazione è rumore rispetto
a **1,3–2,4 s** di fetch RFI.

## C4 — Gli orari sono PROGRAMMATI, non aggiornati col ritardo

**È la misura più importante dopo la C7, e l'esito cambia cosa possiamo mostrare.**

Tre fetch della stessa stazione (14:53, 14:59, 15:02) confrontati riga per riga:

| Confronto | Treni comuni | Ritardo cambiato | Lista fermate cambiata |
|---|---|---|---|
| Padova T1→T2 | 37 | **1** (treno 8418: `''` → `5`) | **0** |
| Padova T1→T3 | 37 | 1 (treno 8418) | **0** |
| Roma Termini T1→T3 | 37 | **1** (treno 9588: `''` → `5`) | **0** |

Il treno **8418** ha preso 5 minuti di ritardo fra le 14:53 e le 14:59: la sua lista
fermate è rimasta **identica carattere per carattere**. Idem per il **9588** a Roma
Termini, su un'altra stazione e un'altra riga. Su **0 treni su 37**, in nessuna finestra,
un orario di passaggio si è mosso.

**Conseguenza vincolante**: gli orari dentro `FERMA A` sono l'**orario ufficiale
programmato**. Presentarli come "arrivo previsto" su un treno in ritardo sarebbe
fabbricazione — il treno 8418 arriverà 5 minuti dopo quello che il blocco dichiara, e il
blocco non lo dice. Sono utilizzabili solo come *orario da orario ufficiale*, e il
ritardo della riga va mostrato accanto, mai sommato da noi.

**Semantica dell'orario: è l'ARRIVO alla fermata, non la partenza.** Verificato su due
treni con doppia lettura:

| Treno | Da Terme Euganee la lista dice | Il board di Padova dice |
|---|---|---|
| 17084 | `PADOVA (16:19)` | partenza **16:21** |
| 3980 | `PADOVA (15:51)` | partenza **15:53** |

Due minuti di sosta in entrambi i casi. Per la domanda "a che ora arrivo a Montegrotto"
questo è il dato giusto — ma va etichettato arrivo, non partenza.

**TTL che reggerebbe**: la *lista* delle fermate è stabile (0 variazioni in 9 minuti su
111 osservazioni riga-per-riga) e potrebbe essere cachata a lungo; ma essendo dentro la
stessa pagina del board non c'è nulla da cachare separatamente — **il TTL resta quello
del board (30 s)** e la domanda è priva di oggetto. Il valore della misura è un altro:
dice che gli orari **non sono live**, quindi non vanno spacciati per tali.

## C5 — Affidabilità

È **lo stesso rischio che già corriamo**, non uno nuovo: stessa pagina, stesso fetch,
stesso parser. Non aggiunge una fonte, aggiunge una cella.

Con un'aggravante da mettere per iscritto: le celle della tabella (`RBinario`, `ROrario`)
sono struttura portante della pagina; il blocco fermate vive dentro un **`<div>` di popup**
(`FermateSuccessivePopupStyle`), che è ornamento. RFI può ridisegnare il popup senza
toccare la tabella. La struttura è però risultata **identica su tutte e 5 le stazioni**
scaricate, comprese due piccole (Abano 15 righe, Terme Euganee 17).

**Difetto di encoding trovato**: RFI scrive l'apostrofo **quadruplo-escapato**.

```
S.DONA&#39;&#39;&#39;&#39; DI PIAVE   →  dopo unescape:  S.DONA'''' DI PIAVE
```

Il nome vero è `S.DONA' DI PIAVE`. Chi legge il blocco deve collassare gli apostrofi
ripetuti o quel nome non aggancerà mai nulla. Non è un caso isolato di battitura: è come
la pagina serve quel campo.

## C6 — Legale

**Nessuna fonte nuova**: è la stessa pagina RFI che l'app già consulta, sulla quale la
verifica è già stata fatta. Per completezza, i termini citabili:

- Termini e condizioni RFI: <https://www.rfi.it/it/misc/termini-e-condizioni.html>
  > "I contenuti del Sito non possono, né totalmente né in parte, essere riprodotti,
  > trasferiti, caricati, pubblicati o distribuiti in qualsiasi modo senza il preventivo
  > consenso espresso di RFI S.p.A."

  con l'eccezione per uso personale:
  > "È in ogni caso consentito agli utenti stampare o salvare su propri supporti singole
  > parti o estratti del Sito, purché ciò sia finalizzato a utilizzi di natura
  > strettamente personale e non commerciale."

- `iechub.rfi.it/robots.txt` → **HTTP 404**: nessuna direttiva robots, in nessun senso.

Il quadro **non cambia** rispetto a oggi: leggere il blocco fermate non estende la
superficie legale, perché non estende la superficie di fetch. Se la lettura del monitor è
accettabile, la lettura di una cella in più della stessa pagina lo è allo stesso titolo.

## C7 — Risoluzione dei nomi: la misura che decide

688 occorrenze di fermata su 3 board di partenza → **291 nomi distinti**, confrontati per
**uguaglianza canonica** (regola C4, mai sottoinsieme) contro le **2435 voci** di
`rfi-stations.tsv`.

| Esito | Nomi distinti | % | Occorrenze | % |
|---|---|---|---|---|
| Risolvono a **1** stazione | 193 | **66,3%** | 480 | 69,8% |
| **Non** risolvono (0) | 98 | **33,7%** | 208 | 30,2% |
| **Ambigui** (>1) | **0** | **0,0%** | 0 | 0,0% |

**Zero ambigui per uguaglianza canonica**: la regola stretta di C4 non produce mai una
risposta sbagliata. Quando aggancia, aggancia bene. Il problema è quanto spesso non
aggancia.

### I 98 falliti, per pattern

| Pattern | Nomi | Occ. | Esempi | Risolvibile con una regola? |
|---|---|---|---|---|
| **A. Stazione estera** | 12 | 12 | `ZURICH HB`, `MUENCHEN HBF`, `INNSBRUCK HBF`, `LUGANO` | **Mai.** Non sono nel catalogo nazionale e non possono esserci. |
| **B. Sottoinsieme stretto** | 18 | 33 | `TERME EUGANEE`, `DESENZANO`, `COLLEFERRO`, `MACCARESE` | Solo violando C4. Vedi sotto. |
| **C. Abbreviazione puntata** | 39 | 88 | `ABANO T.`, `CIVITAVECC.`, `PRIVERNO FOS.`, `REGGIO E. AV MP.` | **No**: il punto tronca a lunghezze arbitrarie, senza dizionario. |
| **D. Troncamento a 16 char** | 10 | 15 | `MARINA DI CERVET`, `BUSCHE LENTIAI M`, `GAZZO DI BIGAREL` | **No**: parola tagliata a metà. |
| **E. Contrazione / sigla** | 19 | 60 | `VE MESTRE` (x18), `FIRENZE SMN` (x9), `MS.BIAGIO-TERR.M` | **No**: `VE`→`VENEZIA` è un dizionario, non una regola. |

Il troncamento a larghezza fissa esiste: **288 dei 291 nomi sono ≤ 16 caratteri**, con un
picco netto a 16 e sole 3 eccezioni (`TRIESTE AEROPORTO` 17, `REGGIO CALABRIA C.LE` 20,
e il `S.DONA'` quadruplo-escapato). Ma non spiega il grosso: la maggioranza dei falliti è
**abbreviata**, non tagliata.

### Gli AMBIGUI sotto una regola permissiva — il caso peggiore, e si verifica

Come chiesto, riportati a parte: un nome che risolve a **più** stazioni non è utilizzabile,
ed è peggio di uno che non risolve affatto, perché una regola permissiva sceglierebbe
comunque una risposta.

Se si abbandonasse l'uguaglianza canonica per un **match di prefisso**, sui 98 falliti:

| Regola | 0 match | 1 match | **>1 match (AMBIGUO)** |
|---|---|---|---|
| Prefisso di token | 80 | 17 | **1** |
| Prefisso di stringa | 46 | 50 | **2** |

I due casi reali:

```
MARINO       → MARINO DEL TRONTO-FOLIGNANO | MARINO LAZIALE
VENEZIA M.   → VENEZIA MESTRE | VENEZIA MESTRE GAZZERA
                | VENEZIA MESTRE OLIMPIA | VENEZIA MESTRE OSPEDALE
```

`VENEZIA M.` è stampato **7 volte** nei board scaricati ed è prefisso di **quattro**
stazioni. È **esattamente la famiglia di collisione** che la decisione C4 cita come
motivo per aver rimosso la regola del sottoinsieme (`12_DECISIONS.md`: "fra cui VENEZIA
MESTRE contro le tre VENEZIA MESTRE GAZZERA / OLIMPIA / OSPEDALE"). Adottare un prefisso
per far funzionare le fermate **resusciterebbe il bug che C4 ha ucciso**, in un punto
dove sbagliare significa dire a un utente che il suo treno ferma dove non ferma.

### La forma stampata CAMBIA a seconda del tabellone

Questa è la scoperta che rende il problema strutturale, non contabile. All'interno di una
singola pagina la forma è stabile (0 stazioni su 92 con due forme). **Fra pagine diverse,
no.** Lo stesso treno, le stesse fermate, letto da board diversi:

```
treno 17084, da PADOVA:
  BUSA DI VIGONZA(16:29) - … - VE MESTRE(16:56) - V.PORTO MARGHERA(17:01) - VENEZIA S.LUCIA(17:09)
treno 17084, da TERME EUGANEE:
  BUSA DI VIG.(16:29)    - … - VENEZIA M.(16:56) - VE PORTO MARGHER(17:01) - VENEZIA S.L.(17:09)
```

Quattro stazioni su sette cambiano grafia. E su quattro board della stessa direttrice:

```
treno 17019, da PADOVA          →  BATTAGLIA T.
treno 17019, da ABANO TERME     →  BATTAGLIA T.
treno 17019, da TERME EUGANEE   →  BATTAGLIA TERME
```

Ho provato l'ipotesi "budget di lunghezza della stringa" e **non regge**: il caso 17084 va
nella direzione giusta (lista più lunga → forme più corte), il caso 17019 nella direzione
opposta. **La regola che sceglie la forma non l'ho determinata.** Il fatto misurato resta,
ed è quello che conta: **il nome stampato non è un identificatore stabile della stazione.**

### Ponte incrociato: 92 coppie stampato→ufficiale ricavate automaticamente

Allineando le liste RFI con `andamentoTreno` di ViaggiaTreno (stesso treno, stesso numero
di fermate, **stessi orari al minuto**) ho ottenuto la traduzione per **32 treni allineati
su 33**, cioè **92 stazioni distinte**. Estratto:

| Stampato da RFI | Ufficiale (da VT) | Occ. |
|---|---|---|
| `VE MESTRE` | VENEZIA MESTRE | 13 |
| `TERME EUGANEE` | TERME EUGANEE-ABANO-MONTEGROTTO | 4 |
| `VERONA P.VESCOVO` | VERONA PORTA VESCOVO | 4 |
| `S.GIORGIO D.PERT` | S.GIORGIO DELLE PERTICHE | 3 |
| `V.PORTO MARGHERA` | VENEZIA PORTO MARGHERA | 3 |
| `FIRENZE SMN` | FIRENZE SANTA MARIA NOVELLA | 2 |
| `PEDEROBBA CAV.P.` | PEDEROBBA CAVASO POSSAGNO | 2 |
| `S.DONA'''' DI PIAVE` | S.DONA' DI PIAVE-JESOLO | 1 |

**Questo è un sottoprodotto utilizzabile**: la tabella di traduzione si può *generare*,
non si deve scrivere a mano stazione per stazione. Torna nella raccomandazione.

Una sola voce non ha un ufficiale in catalogo: **`CALDIERO`**. La stazione passeggeri
Caldiero (linea Verona–Vicenza) esiste, i treni ci fermano, VT la chiama `CALDIERO` — ma
nel catalogo RFI compare **solo come `PC CALDIERO`** (`placeId` 802), che oggi è
classificato punto operativo e quindi escluso dal matching.

> **Non è un buco del catalogo: è un difetto della classificazione, e non è isolato.**
> Approfondito dopo la prima stesura: il monitor di `PC CALDIERO` serve **15 righe reali
> di partenza con binario**, ed è una stazione passeggeri a tutti gli effetti. Verificati
> tutti e 21 i punti operativi: **9 sono falsi positivi**. Dettaglio e criterio di
> verifica nel prerequisito **P3** della raccomandazione.

### Il catalogo attuale non basta — misurato

Le 17 stazioni di `stations.json` confrontate con le forme davvero stampate nei 5 board:

| Esito | Stazioni |
|---|---|
| Aggancia una forma stampata | 11 |
| **Nessun aggancio** | **6** — venezia-mestre, firenze-santa-maria-novella, milano-porta-garibaldi, torino-porta-susa, reggio-emilia-av-mediopadana, genova-piazza-principe |

Casi concreti, con i `boardAliases` che già esistono:

| Stazione | Alias presenti | Forma stampata | Aggancia? |
|---|---|---|---|
| Firenze S.M.Novella | `Firenze S.M.N.`, `Firenze S. M. Novella` | `FIRENZE SMN` | **NO** (`FIRENZE S M N` ≠ `FIRENZE SMN`) |
| Torino Porta Susa | `Torino P.S.` | `TORINO P. SUSA` | **NO** |
| Genova Piazza Principe | `Genova P.Principe` | `GENOVA PRINCIPE` | **NO** |
| Venezia Mestre | — | `VE MESTRE` / `VENEZIA M.` | **NO** (13+7 occorrenze) |
| Terme Euganee-Abano-Montegrotto | `Terme Euganee` | `TERME EUGANEE` | **SÌ** |

La ragione è strutturale e va registrata: **i `boardAliases` esistenti sono stati costruiti
per le DESTINAZIONI**, cioè per i capolinea, che RFI stampa in forma lunga in una colonna
larga. Le **fermate intermedie sono stampate in forme più corte e diverse**. Sono due
vocabolari, non uno. Riusare `boardAliases` per le fermate produrrebbe mancati agganci
silenziosi.

---

# Strada A — ViaggiaTreno `andamentoTreno`

## A2 — Chiave di join: il problema previsto dal brief, confermato

`andamentoTreno` vuole `<codOrigine>/<numeroTreno>/<epochPartenza>`. **Il codice della
stazione di ORIGINE del treno non è sul tabellone RFI**: il tabellone dice il capolinea di
arrivo, non da dove il treno è partito. Va procurato con una chiamata in più.

`cercaNumeroTrenoTrenoAutocomplete/<numero>` lo ricava dal solo numero:

```
17019  →  17019 - VENEZIA S.LUCIA - 01/09/26|17019-S02593-1788213600000
12679  →  12679 - ROMA TERMINI    - 01/09/26|12679-S08409-1788213600000
```

L'epoch è la **mezzanotte del giorno**, quindi derivabile; il codice origine **no**.
L'endpoint restituisce **una sola riga**: se un numero fosse condiviso da due treni nello
stesso giorno, non c'è modo di accorgersene — restituisce una risposta plausibile e
sbagliata, senza segnalarlo. Su 34 treni il join è però risultato solido:

| Verifica sul board Padova | Esito |
|---|---|
| Treni risolti che contengono davvero PADOVA nelle fermate | **33 / 34** |
| Orario VT a Padova ≠ orario del board | **0** |
| Fallimento | treno **36** (→ ZURICH HB): VT risolve un treno 36 che non passa da Padova |

## A1 — Copertura: perde Italo per intero

40 righe del board Padova passate all'autocomplete:

| Esito | Righe |
|---|---|
| Risolti | **34 / 40** (85%) |
| **Risposta vuota** | **6 / 40** |

I 6 vuoti sono **esattamente i 6 treni Italo** del board (`8986, 8914, 8919, 8988, 8916,
8923`). Verificati altri 5 Italo da Roma Termini: **tutti vuoti**. **0 su 11 treni Italo
noti a ViaggiaTreno**, contro 11 su 11 su RFI. Conferma indipendente dello spike 17, ora
sul caso d'uso delle fermate.

## A3 — Costo per tabellone: insostenibile

**74 chiamate per arricchire 40 righe** (34 autocomplete + 34 andamento + 6 andate a
vuoto), misurate in **39 s** in sequenza con pacing di 0,4 s. Non esiste una chiamata per
stazione né per linea che restituisca le fermate di tutte le righe: `andamentoTreno` è
**per singolo treno**, per costruzione. Come chiesto, lo dico chiaro: **non c'è una via
per-stazione, e 74 chiamate per tabellone non sono sostenibili.**

## A4 — Latenza

Molto buona per chiamata: **0,05–0,15 s**, contro 1,3–2,4 s di RFI. Il problema non è la
singola chiamata, è il loro numero. Parallelizzando si potrebbe scendere, ma si tratterebbe
di 74 richieste per apertura di tabellone verso un servizio non contrattualizzato.

## A7 — Il suo unico vero vantaggio: i nomi sono ufficiali

`andamentoTreno` restituisce i nomi **per esteso e ufficiali**:

```
TERME EUGANEE-ABANO-MONTEGROTTO     VENEZIA MESTRE     VENEZIA PORTO MARGHERA
```

**118 nomi distinti, 105 risolvono a 1 stazione (89,0%)**. I 13 falliti sono stazioni
**Ferrovie Nord Milano** (`MILANO CADORNA`, `SARONNO`, `VARESE NORD`, `MALNATE`, …) —
infrastruttura di un altro gestore, legittimamente assenti dal catalogo RFI — più
`CALDIERO`, lo stesso buco di catalogo già visto.

È l'immagine speculare di RFI: **VT risolve i nomi e perde i treni; RFI ha tutti i treni e
non risolve i nomi.**

## A5 / A6 — Affidabilità e legale

Affidabilità: invariata rispetto allo spike 17 — API non contrattualizzata, **solo HTTP in
chiaro**, errori mascherati da `200 + []`.

**Legale: qui VT sta peggio di RFI, ed è un fatto nuovo rilevante.**
Termini: <http://www.viaggiatreno.it/monitorpuntualita/it/iconmedialab/trenitalia/viaggiatreno/view/popups/popupNoteLegaliIndiciPunt.html>

> "I contenuti del Servizio Internet non possono, né totalmente né in parte, essere
> copiati, riprodotti, trasferiti, caricati, pubblicati o distribuiti in qualsiasi modo
> senza il preventivo consenso scritto della società Trenitalia S.p.A."

e, esplicitamente:

> "È vietato il cd. deep linking ossia l'utilizzo, su siti di soggetti terzi, di parti del
> Servizio Internet o, comunque, il collegamento diretto alle pagine senza passare per la
> home page del Servizio Internet."

Chiamare `andamentoTreno` da un backend **è** collegamento diretto a una pagina del
servizio senza passare dalla home. I termini aggiungono che i dati "non rivestono carattere
di ufficialità". `robots.txt` di viaggiatreno.it vieta solo `AhrefsBot`, ma non sana la
clausola sul deep linking.

RFI vieta la ridistribuzione e ammette l'uso personale; VT vieta la ridistribuzione **e in
più** il deep linking. **Dipendere da VT è una posizione legale peggiore di quella che
abbiamo già**, non uguale.

---

# Strada B — GTFS

Time-box rispettato: nessun feed riscaricato, verificato solo ciò che lo spike 16 aveva
lasciato aperto.

**Cosa cambia col catalogo nazionale: niente, per questo problema.** Il catalogo è un
elenco di **stazioni** (nome ufficiale + `placeId`), non di **orari**. Dà l'anagrafica
contro cui risolvere un nome — ed è infatti ciò che ho usato per la misura C7 — ma non
contiene `stop_times`, quindi non dice dove ferma un treno. Le due conclusioni dello spike
16 (nessun feed Veneto/Lazio ferroviario, nessun feed nazionale scaricabile) **restano in
piedi**.

**Un aggiornamento, però, c'è, e vale registrarlo.** Il NAP nazionale — che lo spike 16
aveva marcato "non verificato" — oggi espone a catalogo un dataset nazionale:

| Campo | Valore |
|---|---|
| Nome | **OAP Trenitalia - NeTEx Livello 1** |
| Descrizione | "Dati relativi alla programmazione dei servizi di trasporto ferroviario Trenitalia, conformi allo standard NeTEx L1" |
| Titolare / Editore | Trenitalia (`redazioneintreno@trenitalia.it`) |
| Formato | **NeTEx**, non GTFS |
| Copertura geografica | **IT** (nazionale) |
| Registrato il | 2026-01-07 |
| Aggiornamento | fino a mensile |
| Catalogo | <https://www.cciss.it/nap/mmtis/public/catalog/Dataset> |

**Ma non è scaricabile**: la voce è un record di *metadati* e non ha alcun *Asset*
associato (ricerca su `…/catalog/Asset` per "Trenitalia" → nessun risultato). Non c'è URL
di download pubblico.

Quindi: per questo spike **resta chiusa** — è NeTEx e non GTFS, è solo Trenitalia (niente
Italo), è programmazione e non live, e comunque non si scarica. Ma è un cambiamento reale
rispetto ad agosto e **cambia cosa andrebbe ricontrollato** alla prossima riapertura: non
più "esiste un feed nazionale?" (esiste, a catalogo) ma "come si ottiene l'accesso?".

---

# Confronto

| Misura | **C — RFI (cella dettagli)** | **A — ViaggiaTreno** | **B — GTFS** |
|---|---|---|---|
| Copertura REG/RV | **100%** | 100% | n/d |
| Copertura Italo | **100% (11/11)** | **0% (0/11)** | 0% |
| Copertura arrivi | **0%** | 100% | n/d |
| Chiave di join | **nessuna necessaria** | serve codice origine, non sul board | numero treno, fragile |
| Costo per 40 righe | **0 chiamate** | **74 chiamate / 39 s** | ingest offline |
| Latenza marginale | **~0 ms** (7 ms di parse) | 0,05–0,15 s × 74 | n/d |
| Orari | programmati (misurato) | programmati **+ effettivi** | programmati |
| Risoluzione nomi | **66,3%** | **89,0%** | ufficiali |
| Ambiguità | **0** | 0 | 0 |
| Affidabilità | rischio già corso, +popup | non contrattualizzata, HTTP | feed a scadenza |
| Legale | invariato | **peggiore** (deep linking vietato) | CC-BY (dove esiste) |

---

# Raccomandazione

## Premessa: la scoperta strutturale — il vocabolario è per COPPIA, non per stazione

Va letta prima di tutto il resto, perché è ciò che determina la forma della soluzione.

**La stessa fermata è stampata con grafie diverse su board diversi, e la regola che
sceglie la grafia non è derivabile.** Non è un dettaglio di parsing: cambia l'unità del
vocabolario.

```
treno 17019, fermata BATTAGLIA TERME:
   letto dal board di PADOVA          →  BATTAGLIA T.
   letto dal board di ABANO TERME     →  BATTAGLIA T.
   letto dal board di TERME EUGANEE   →  BATTAGLIA TERME

treno 17084, quattro fermate su sette cambiano grafia fra PADOVA e TERME EUGANEE:
   BUSA DI VIGONZA / VE MESTRE  / V.PORTO MARGHERA / VENEZIA S.LUCIA   (da Padova)
   BUSA DI VIG.    / VENEZIA M. / VE PORTO MARGHER / VENEZIA S.L.      (da Terme Euganee)
```

Conseguenza operativa: **la chiave del vocabolario è la coppia `(stazione osservata,
fermata)`, non la fermata.** Un alias non è "Terme Euganee si stampa `TERME EUGANEE`": è
"sul board di Padova, Terme Euganee si stampa `TERME EUGANEE`". Sapere come una fermata è
scritta su un board **non dice** come è scritta su un altro, e non esiste una regola che
permetta di dedurlo — ho provato l'ipotesi del budget di lunghezza e cade su un
controesempio (vedi C7).

Da qui discende il resto, e va detto con chiarezza: **la copertura dichiarata non è una
precauzione prudenziale, è l'unica forma corretta della funzione.** Non stiamo scegliendo
di essere cauti su un vocabolario che in teoria potrebbe essere completo: stiamo prendendo
atto che **un vocabolario completo non è costruibile per deduzione**, perché ogni nuova
stazione osservata è un insieme nuovo di grafie da rilevare empiricamente. Attivare la
funzione su una stazione significa **aver osservato quel board**, non aver aggiunto una
riga a una tabella.

Corollario sul costo: il vocabolario cresce come *(stazioni attivate × fermate raggiungibili
da ciascuna)*, non come *(stazioni)*. È la ragione per cui il punto 3 qui sotto — generarlo
automaticamente invece di scriverlo — non è un'ottimizzazione ma una condizione di
fattibilità.

## **(A) Adottare la strada C, ma solo a COPERTURA DICHIARATA per stazione verificata.**

Non è "sì" e non è "no": la distinzione è fra due funzioni diverse che è facile confondere.

**Si può fare** — *"su questo tabellone, quali treni fermano a Terme Euganee?"* per un
insieme **dichiarato** di stazioni di cui abbiamo verificato le forme stampate. Il caso
concreto del brief funziona **oggi**: sul board di Padova delle 14:53, filtrando per
`TERME EUGANEE` (alias già presente in `stations.json`), la risposta è

```
RV  3979  → BOLOGNA CENTRALE  part.15:09 bin.1   arrivo Terme Euganee 15:19
REG 17093 → ROVIGO            part.15:41 bin.1   arrivo Terme Euganee 15:53
RV  3981  → BOLOGNA CENTRALE  part.16:09 bin.1   arrivo Terme Euganee 16:17
REG 17019 → ROVIGO            part.16:41 bin.1   arrivo Terme Euganee 16:53
```

Dato reale, zero chiamate aggiuntive, zero inferenza. Da notare: **due dei quattro sono RV
per Bologna**, non il REG per Rovigo. La conoscenza statica di linea ipotizzata nel brief
("i REG Padova–Rovigo fermano a Terme Euganee") non solo sarebbe fabbricazione: sarebbe
**anche incompleta**, e avrebbe perso metà delle risposte. La misura conferma il vincolo
invece di indebolirlo.

**Non si può fare** — il filtro **universale** su una qualsiasi delle 2435 stazioni. Un
nome su tre non aggancia, e nessuna regola meccanica lo salva senza reintrodurre le
ambiguità che C4 ha eliminato.

### Le condizioni, tutte necessarie

1. **Solo partenze.** Sugli arrivi il dato non esiste (misurato: 0/96 righe). La funzione
   non va nemmeno offerta sul tabellone arrivi.
2. **Un vocabolario NUOVO, separato da `boardAliases`, chiavato sulla COPPIA
   `(stazione osservata, fermata)`** — vedi la premessa e il prerequisito **P1**. Un campo
   dedicato (es. `stopAliases`), con lo stesso rigore di C2: dichiarato, verificato,
   recensibile. **Non** allargare `boardAliases`, che ha un altro contratto.
3. **Il vocabolario si GENERA, non si scrive a mano.** L'allineamento RFI↔ViaggiaTreno
   descritto in C7 ha prodotto **92 coppie stampato→ufficiale in una sola passata**, con
   verifica incrociata sugli orari al minuto. È lo stesso uso *offline* che lo spike 17
   raccomandava per `autocompletaStazione`: strumento da riga di comando in fase di
   promozione stazione, **mai dipendenza runtime**. Così il deep-linking di VT non entra
   nel prodotto e i suoi limiti di copertura (niente Italo) non contano, perché serve solo
   a tradurre nomi.
4. **Un mancato aggancio è "non lo so", MAI "non ferma".** È il punto su cui la funzione
   può diventare disonesta senza che nessuno se ne accorga. Se filtro il board per una
   stazione e una lista contiene una forma che non riconosco, **non posso concludere che
   quel treno non ci ferma**: posso solo dire che non lo so. Un filtro che mostra "nessun
   treno" quando in realtà ce ne sono quattro è **fabbricazione in negativo** — vietata
   esattamente come quella in positivo, e più insidiosa perché sembra un risultato vuoto
   legittimo.
5. **Gli orari sono programmati, e l'orario è l'ARRIVO.** Cosa se ne può dire e cosa no è
   nella tabella della sezione seguente: è la parte più facile da sbagliare in UI.
6. **Sistemare i prerequisiti P1, P2, P3** prima o insieme all'implementazione. Ognuno dei
   tre produce, da solo, un mancato aggancio silenzioso.

### Cosa l'app POTRÀ dire e cosa NON POTRÀ dire

Discende dalla misura C4 (orari programmati, non live) e va fissato prima di scrivere UI,
perché la differenza fra le due colonne è la differenza fra un dato e un'invenzione.

| ✅ Si può dire | ❌ Non si può dire |
|---|---|
| "Questo treno **ferma** a Terme Euganee" | "**Arriva** a Terme Euganee **alle 12:53**" |
| "Fermate: Abano T., Terme Euganee, Battaglia T., …" | "Arrivo previsto 12:58" (12:53 + 5 min di ritardo) |
| "Orario di arrivo **da orario ufficiale**: 12:53" | "Arrivo stimato / previsto / effettivo: 12:53" |
| "12:53, **il treno ha 5 minuti di ritardo**" (due dati distinti, entrambi della fonte) | "12:53" da solo su una riga che il board segna in ritardo |
| "Non risulta una fermata a X" **solo** se ogni nome della lista è stato riconosciuto | "Non ferma a X" quando la lista contiene un nome non riconosciuto |

**Il fatto che vincola**: gli orari dentro `FERMA A` sono l'orario ufficiale programmato e
**non si muovono col ritardo** — misurato sui treni 8418 e 9588, passati da 0 a 5 minuti di
ritardo con la lista fermate identica carattere per carattere. Presentare `12:53` come
arrivo previsto di un treno che viaggia con 5 minuti di ritardo afferma una cosa che
nessuna fonte ha detto: è fabbricazione, nella stessa categoria di un binario inventato.

**E non possiamo nemmeno correggerlo noi.** Sommare il ritardo della riga all'orario
programmato (`12:53 + 5 = 12:58`) sembra innocuo ma è peggio: il ritardo del board è
misurato alla stazione di partenza, non alla fermata intermedia, e i treni recuperano o
accumulano lungo il percorso. Il numero risultante non verrebbe da nessuna fonte — sarebbe
nostro. La regola resta quella di sempre: due dati veri accostati, mai un terzo dato
calcolato.

**Etichetta**: il numero fra parentesi è l'**ARRIVO** alla fermata, non la partenza.
Misurato: il treno 17084 compare come `PADOVA (16:19)` nella lista, mentre il board di
Padova lo dà in partenza alle **16:21**; il 3980 come `PADOVA (15:51)` contro una partenza
alle **15:53**. Due minuti di sosta in entrambi i casi. Etichettarlo "partenza" sarebbe
sbagliato di poco e sistematicamente — il tipo di errore che nessuno segnala e che rende
l'app inaffidabile su un dettaglio verificabile.

### Prerequisiti del ticket di implementazione

Non curiosità: sono cose da sistemare **prima** o **insieme**, perché ognuna produce un
mancato aggancio silenzioso.

**P1 — `boardAliases` è tarato sui capolinea e non serve per le fermate.**
Misurato: 6 delle 17 stazioni del catalogo non agganciano nessuna forma stampata nei board
scaricati, e gli alias esistenti mancano il bersaglio proprio dove sembrerebbero coprirlo:

| Stazione | Alias presente | Forma stampata | Esito |
|---|---|---|---|
| Firenze S.M.Novella | `Firenze S.M.N.` | `FIRENZE SMN` | `FIRENZE S M N` ≠ `FIRENZE SMN` |
| Torino Porta Susa | `Torino P.S.` | `TORINO P. SUSA` | non aggancia |
| Genova Piazza Principe | `Genova P.Principe` | `GENOVA PRINCIPE` | non aggancia |
| Venezia Mestre | — | `VE MESTRE` (×13) / `VENEZIA M.` (×7) | nessun alias |

Serve un campo **nuovo e separato** (es. `stopAliases`), chiavato sulla coppia della
premessa. **Non** allargare `boardAliases`: ha un altro contratto (destinazioni) e
allargarlo lo indebolirebbe su entrambi i fronti.

**P2 — Normalizzare gli apostrofi ripetuti in ingresso.**
RFI serve l'apostrofo quadruplo-escapato:

```
S.DONA&#39;&#39;&#39;&#39; DI PIAVE   →  dopo unescape:  S.DONA'''' DI PIAVE
```

Il nome vero è `S.DONA' DI PIAVE`. Senza un collasso degli apostrofi ripetuti quel nome
non aggancerà mai nulla, e il fallimento è invisibile.

**P3 — La classificazione dei punti operativi ha 9 falsi positivi su 21.**
Il caso Caldiero non è isolato: verificato aprendo il monitor RFI di tutti i 21 punti
operativi e contando le righe reali di partenza.

| `placeId` | Nome in catalogo | Righe | Esempio |
|---|---|---|---|
| 520 | `BIVIO D'AURISINA` | 15 | REG 17368 → CARNIA, bin. 1 |
| 2288 | `EUROPA PES` | 15 | REG 12973 → CATANIA CENTRALE, bin. 2 |
| 2278 | `OGNINA PES` | 15 | REG 12973 → CATANIA CENTRALE, bin. 2 |
| 802 | `PC CALDIERO` | 15 | REG 17202 → VERONA PORTA NUOVA, bin. 2 |
| 1250 | `PC DOLCE'` | 15 | REG 16685 → VERONA PORTA NUOVA |
| 2067 | `PC MEANA` | 15 | FM3 ×10 → BARDONECCHIA |
| 1505 | `PM ISPRA` | 15 | BUS → SESTO CALENDE |
| 3276 | `VALLE DI MADDALONI PES` | 15 | REG 21197 → BENEVENTO, bin. 1 |
| 2627 | `VIGNA CLARA PES` | 15 | REG 5987 → ROMA S.PIETRO, bin. 1 |

Gli altri 12 (tutti `PM …` tranne `PM ISPRA`) restituiscono **0 righe**: la controprova
funziona, `PM THURIO` è davvero un posto di movimento. Le destinazioni dei 9 sono
geograficamente coerenti coi rispettivi nomi (Caldiero→Verona, Ognina/Europa→Catania,
Vigna Clara→Roma S.Pietro), quindi non sono pagine di errore.

**Cosa significa**: la regola di classificazione è **per prefisso/suffisso di stringa**
(`PM ` / `PC ` / `BIVIO ` / ` PES`, in `StationsArtifact.isOperationalPoint`), ma RFI usa
quei prefissi anche per **stazioni passeggeri reali**, dove i treni fermano e c'è un
binario. Oggi quelle 9 sono `operationalPoint: true`, quindi **escluse dalla ricerca e dal
matching delle destinazioni**. Per le fermate intermedie l'effetto sarebbe peggiore: una
fermata a Caldiero verrebbe scartata come "non è una stazione", producendo esattamente il
falso negativo che il punto 4 vieta.

Due note per chi lo sistemerà:
- Il prefisso resta parte del nome ufficiale: la stazione **si chiama** `PC CALDIERO` nella
  lista RFI, e non esiste una voce `CALDIERO` separata (verificato: 20 dei 21 nomi non
  hanno un gemello passeggeri in catalogo). Non è un duplicato da deduplicare.
- ViaggiaTreno conosce come stazioni passeggeri autonome `CALDIERO|S02437`,
  `ISPRA|S01121`, `VALLE DI MADDALONI|S09304` — utile come seconda conferma indipendente,
  con la cautela che l'`autocompletaStazione` di VT include anche le voci `PES` e quindi
  non è un oracolo "solo passeggeri".
- **Il criterio empirico che ha funzionato**, riusabile: un punto operativo vero ha un
  monitor con **0 righe**; una stazione passeggeri ne ha. È una verifica da fare una volta,
  offline, non a runtime.

### Perché non le altre

- **A (ViaggiaTreno) — scartata come fonte delle fermate.** Perde il 100% dei treni Italo
  (0/11), costa 74 chiamate per tabellone, e i suoi termini **vietano esplicitamente il
  deep linking**, che è esattamente il modo in cui la useremmo. **Promossa però a
  strumento offline** per generare il vocabolario del punto 3: è lì che il suo 89% di nomi
  ufficiali vale davvero.
- **B (GTFS) — resta chiusa**, con l'aggiornamento sul NAP registrato sopra.
- **"Non si fa" — scartata, ma per poco.** Sarebbe la risposta giusta se la funzione da
  costruire fosse quella universale: lì non regge, e volendola a tutti i costi si
  finirebbe a indovinare. È scartata solo perché la versione a copertura dichiarata è
  **onesta, misurabile e a costo marginale nullo** — il dato è già nel fetch che facciamo.

### Cosa NON fare, esplicitamente

- Non adottare un match di prefisso o di sottoinsieme per alzare il 66,3%. Riporterebbe
  `VENEZIA M.` a scegliere fra 4 stazioni Mestre e `MARINO` fra 2 — la collisione che C4
  ha rimosso, in un punto peggiore.
- Non dedurre una fermata da conoscenza di linea. Misurato che sarebbe anche sbagliata.
- Non promettere la funzione su stazioni non verificate, e non estenderla agli arrivi.

---

## Rischi noti

1. **Falsi negativi silenziosi** — il rischio principale, e non è tecnico ma di prodotto.
   Un filtro che tace è indistinguibile da un filtro che dice "non ci sono treni". La
   condizione 4 esiste per questo e va tenuta in UI, non solo nel modello.
2. **Il vocabolario invecchia** — la forma stampata cambia fra board e potrebbe cambiare
   nel tempo. Serve una verifica periodica, e un mancato aggancio deve degradare a "non
   lo so", non rompersi.
3. **Il blocco vive in un popup**, più ornamentale delle celle della tabella: RFI può
   ridisegnarlo senza toccare il tabellone.
4. **Stazioni passeggeri classificate come punti operativi** — **9 su 21**, verificate una
   per una (prerequisito **P3**). Finché non è corretto, una fermata a Caldiero, Vigna
   Clara, Ognina o Valle di Maddaloni verrebbe scartata come "non è una stazione": un
   falso negativo prodotto da noi, non dalla fonte. Il catalogo resta comunque un elenco
   di `PlaceId` del monitor, non un'anagrafica di fermate passeggeri.
5. **Stazioni estere fuori portata per costruzione** (12 nomi misurati): per un EC o un RJ
   la coda del percorso non sarà mai risolvibile. Va accettato, non tamponato.

## Riproducibilità

```bash
# Board di partenza (il blocco fermate è nella cella 8, RDettagli)
curl -s "https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2000"  # Padova
curl -s "https://iechub.rfi.it/ArriviPartenze/arrivalsdepartures/Monitor?arrivals=False&placeId=2829"  # Terme Euganee

# Il blocco, isolato
#   <div class="titoloInfoAggiuntive">Fermate successive</div>
#   <div class="testoinfoaggiuntive"> FERMA A:NOME (HH:MM) - NOME (HH:MM) … </div>

# Controprova che sugli ARRIVI non esiste (0 occorrenze)
curl -s ".../Monitor?arrivals=True&placeId=2000" | grep -c "Fermate successive"

# ViaggiaTreno, solo come strumento OFFLINE di traduzione nomi
curl -s "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/cercaNumeroTrenoTrenoAutocomplete/17019"
curl -s "http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/andamentoTreno/S02593/17019/1788213600000"

# P3 — un punto operativo VERO ha 0 righe, una stazione passeggeri no
curl -s ".../Monitor?arrivals=False&placeId=168"   # PM THURIO            -> 0 righe
curl -s ".../Monitor?arrivals=False&placeId=802"   # PC CALDIERO          -> 15 righe, con binario
curl -s ".../Monitor?arrivals=False&placeId=2627"  # VIGNA CLARA PES      -> 15 righe
```

HTML, JSON e script di misura vivono in una cartella scratch fuori dal repo: **nessun
payload RFI o VT è stato committato**, nessuna credenziale usata, nessun file di prodotto
modificato.

## Limiti di questo spike

- **Una sola finestra temporale** (14:53–15:05 di martedì 01/09/2026) e 5 stazioni, di cui
  3 sulla stessa direttrice veneta. La percentuale del 66,3% è quella di **questo** campione
  di 291 nomi: un campione su altre regioni la sposterebbe, in una direzione che non posso
  prevedere.
- **La regola che sceglie la forma stampata non l'ho determinata.** So che varia per board
  e che non è un semplice budget di lunghezza; non so cosa sia. Finché non lo si sa, un
  vocabolario non può essere dichiarato completo — solo verificato su board specifici.
- **Solo 2 ritardi osservati** nella finestra (8418 e 9588, entrambi 0→5 min). La
  conclusione "orari programmati" è coerente su due stazioni diverse e su 111 osservazioni
  riga-per-riga senza variazioni, ma un ritardo grosso (30+ min) o una soppressione non
  sono stati osservati. **Da ricontrollare durante un guasto o uno sciopero**, come già
  raccomandato per `cancelled` nello spike 17.
- **Nessuna prova di carico né rate limit** su RFI: la strada C non aggiunge chiamate,
  quindi non cambia il profilo — ma non l'ho misurato.
- **Il conteggio dei falsi positivi (P3) vale per i 21 nomi selezionati dalla regola
  attuale.** Ho verificato che i 9 hanno un board di partenza reale, non il contrario: non
  ho controllato se esistano stazioni passeggeri mancanti dal catalogo per altre ragioni,
  né ho ispezionato i loro board arrivi. Anche questo è uno snapshot: se RFI rinomina una
  voce, il set cambia.
- Non ho verificato se il blocco esista sulle stazioni molto piccole con poche righe oltre
  alle due provate (Abano 15, Terme Euganee 17), né su stazioni di sola fermata.
- **Non ho valutato la UI**: dove e come mostrare una fermata filtrata è fuori dal mandato.
