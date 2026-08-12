# 16 — Spike GTFS: fattibilità di B2 (ricerca tratta A→B)

**Tipo**: spike di valutazione, non un ticket di prodotto. Nessun codice applicativo
scritto, nessuna dipendenza aggiunta, app non toccata.
**Data**: 2026-08-12. **Autore**: spike tecnico su richiesta.

## Domanda chiave

> Con i GTFS pubblici disponibili, posso calcolare le soluzioni **Padova → Roma Termini**
> e **Roma Termini → Padova**, con orari corretti e treni reali?

**Risposta: NO.** Con i feed GTFS pubblici verificabili oggi la tratta Padova↔Roma
**non è calcolabile**: nessun feed trovato contiene un solo viaggio che colleghi le due
stazioni. Sotto le prove empiriche, non teoriche.

## Metodo

Verifica **empirica**: feed scaricati in una cartella scratch fuori dal repo, estratti e
ispezionati con `stops.txt` / `routes.txt` / `trips.txt` / `stop_times.txt`. Il criterio
di copertura è: *esiste un `trip_id` che contiene sia lo stop Padova sia lo stop Roma
Termini?* — non "la regione dichiara di coprire i treni a lunga percorrenza".

## Feed trovati e verificati

### 1. Regione Toscana — "TRENITALIA.gtfs"

| Campo | Valore (verificato) |
|---|---|
| Ente pubblicatore | Regione Toscana (portale `dati.toscana.it`) |
| Pagina dataset | https://dati.toscana.it/dataset/rt-oraritb/resource/4f85393b-357d-443d-8378-65de4198505f |
| URL download | `https://dati.toscana.it/dataset/8bb8f8fe-.../download/trenitalia.gtfs` |
| Licenza | **Creative Commons Attribution** (dichiarata sulla pagina del dataset) |
| Ultimo aggiornamento | **15 gennaio 2026** (pagina + timestamp interni dei file) |
| Dimensione | **6,1 MB** zip → **19,7 MB** estratto |
| Contenuto | 14 route, 313 stop, 1.119 trip, 13.306 stop_times |
| Copertura dichiarata | "servizio ferroviario svolto da Trenitalia S.p.A. sulle **linee regionali toscane**" |

**Verifica Padova↔Roma**: Roma Termini **presente** (`S08409_1`); **Padova ASSENTE**
(0 occorrenze in `stops.txt`). Zero route AV/FR/IC (tutte regionali toscane:
Firenze–Pisa–Livorno, Siena–Chiusi, …). → **Tratta non calcolabile.**

### 2. Regione Liguria — "Dati servizio pianificato TRENITALIA S.p.A."

| Campo | Valore (verificato) |
|---|---|
| Ente pubblicatore | Regione Liguria |
| Pagina dataset | https://dati.regione.liguria.it/dataset/ds-637 |
| URL download | `https://srvcarto.regione.liguria.it/dtuff/download_statico/opendata/trasporti/GTFS/GTFS-IT-ITC3-TRENITALIA-20260614-20261212-pf.zip` |
| Licenza | **CC BY 4.0** (dichiarata sulla pagina del dataset) |
| Ultimo aggiornamento | dataset **03-07-2026**; file interni **09-06-2026**; validità **14/06/2026 – 12/12/2026** |
| Dimensione | **26,5 MB** zip → **~80 MB** estratto (di cui `shapes.txt` da solo 74,7 MB) |
| Contenuto | 358 stop, 1.823 trip; route REG, RV, IC, ICN, EC, BUS (+ FR nei trip) |
| Copertura dichiarata | regionali **e treni a lunga percorrenza**, ma solo se "fermano in almeno una stazione sul territorio ligure" |

**Verifica Padova↔Roma** — questo è il test decisivo, perché il feed *contiene davvero
l'alta velocità*:
- Padova **presente** (`830002581`), toccata da **12 trip** — incluso un
  **FR 9744 con partenza da Padova 16:16 → Milano Centrale / Genova Brignole**.
- Roma Termini **presente** (`830008409`), toccata da **112 trip**.
- **Trip che contengono ENTRAMBE: 0.**

→ La lunga percorrenza c'è, ma solo per i treni che passano dalla Liguria. Padova→Roma
non tocca la Liguria, quindi **non è nel feed**. **Tratta non calcolabile.**

## Feed cercati e NON trovati

| Cercato | Esito |
|---|---|
| GTFS ferroviario **Veneto** (Trenitalia) | **Non trovato.** Il Veneto pubblica GTFS **bus** (ACTV Venezia, Busitalia Padova), non ferroviario. |
| GTFS ferroviario **Lazio** | **Non trovato** su `dati.gov.it` né su portali regionali raggiunti. |
| GTFS **nazionale** Trenitalia (lunga percorrenza/AV) | **Non trovato.** Nessun feed nazionale pubblico. |
| `dati.gov.it`, tag `gtfs` | Solo: Lombardia/**Trenord** (ferroviario regionale, **ultimo agg. 2016**), Comune di Milano, Matera, Puglia/Lecce, Bari. Nessun Veneto/Lazio, nessun nazionale. |
| **NAP** nazionale (`cciss.it/nap`) | **Non verificato**: la pagina pubblica descrive il modello RAP→NAP (NeTEx) ma non espone dataset scaricabili raggiungibili da lì. Non posso affermare né escludere che il catalogo interno contenga un feed ferroviario nazionale. |
| "GTFS Trenitalia" su Mobility Database / transport.data.gouv.fr | **Fuorviante**: la maggior parte dei risultati è **Trenitalia France** (rete francese, `helpdesk@trenitalia.fr`) — non pertinente. Il feed italiano indicizzato come "TRENITALIA S.p.A." punta al file **toscano** di cui sopra. |
| Altri feed regionali (Marche, Piemonte, Sardegna) | Esistono per il traffico regionale Trenitalia, ma **irrilevanti**: la direttrice Padova–Roma non tocca quelle regioni. Non scaricati. |
| File per analogia (stesso server Liguria, altri codici NUTS: `ITH3` Veneto, `ITI4` Lazio, `ITH5` Emilia-Romagna) | **HTTP 404** su tutti e tre. Prova solo che quel server ospita il proprio feed, non che gli altri non esistano altrove. |

## Perché non funziona: il modello di pubblicazione

I GTFS ferroviari italiani sono **regionali e frammentati per contratto di servizio**.
Ogni Regione pubblica i treni che **toccano il proprio territorio** — inclusa la lunga
percorrenza, ma solo con quel filtro. Non esiste (pubblicamente) il feed nazionale che
conterrebbe l'intera relazione Padova↔Roma.

Perché la tratta fosse calcolabile servirebbe **almeno uno** tra:
- un feed **nazionale** Trenitalia (non trovato);
- il feed del **Veneto** o del **Lazio** con la lunga percorrenza (non trovati);
- un feed dell'**Emilia-Romagna** con la lunga percorrenza passante (non trovato: la
  regione pubblica dati di rete ferroviaria, non un GTFS Trenitalia).

Nota: anche trovandoli, **il GTFS non contiene binari né ritardi** — resterebbe uno
strato *orario*, con il live attuale sopra per binario/ritardo (approccio ibrido).

## Stima di implementazione (se i feed esistessero)

Numeri ricavati dai feed reali scaricati, non stimati a occhio.

| Voce | Stima | Note |
|---|---|---|
| **Ingest** | 2–3 gg | Parser GTFS (CSV in zip) + validazione + normalizzazione verso il modello app. Da gestire: encoding, `calendar` vs `calendar_dates`, orari `>24:00:00`. |
| **Storage** | ~5 MB/regione utili | Un feed regionale è ~26 MB zip / 80 MB estratto, ma **`shapes.txt` è il 93% del peso** ed è inutile per la ricerca orari → scartabile. Con ~20 regioni: ~100 MB di dati utili, ~200–300 MB in DB con indici. |
| **Aggiornamento periodico** | 1–2 gg + presidio | I feed hanno **validità a scadenza** (il ligure: 14/06→12/12/2026) e cambio orario a giugno/dicembre. Serve job di refresh **e allarme di scadenza**: un feed scaduto produce orari falsi, il peggior fallimento possibile per questa app. |
| **Motore soluzioni — solo dirette** | 3–5 gg | Query su `stop_times`: trip che contengono A prima di B nella stessa corsa, filtrati per data di servizio. Fattibile e testabile su fixture. |
| **Motore soluzioni — con cambi** | settimane | Serve RAPTOR/CSA o simile + gestione trasferimenti. Fuori portata per un MVP. |
| **Ibrido GTFS + live** | 3–5 gg, **fragile** | Il match tra corsa GTFS e riga del tabellone live avviene per **numero treno**; oggi il live è per stazione e non espone un id stabile di corsa. Rischio concreto di associare binario/ritardo alla corsa sbagliata → violerebbe la regola "mai dati inventati". |

**Totale, nell'ipotesi ottimistica in cui i dati esistessero**: ~2–3 settimane per le sole
soluzioni dirette, con un impegno ricorrente di manutenzione dei feed. Oggi questo
lavoro **non è nemmeno avviabile** per il caso d'uso principale.

## Raccomandazione

**(c) Rinviare B2.**

Motivazione: la strada (a) *GTFS ibrido* è **tecnicamente bloccata** per il caso d'uso
del prodotto (Padova↔Roma), non costosa-ma-fattibile: i dati non esistono in forma
pubblica. Implementare l'ingest GTFS oggi produrrebbe un motore che copre tratte
regionali toscane o liguri — non ciò che serve al tester pendolare.

- **(a) GTFS ibrido — scartata ora.** Da riconsiderare solo se compare un feed
  nazionale o quello di Veneto/Lazio con lunga percorrenza. Vale la pena rifare questo
  spike (mezza giornata) al prossimo cambio orario (dicembre 2026).
- **(b) Provider commerciale — unica strada tecnicamente aperta**, da valutare solo se
  B2 diventa prioritario: richiede analisi di costo, licenza d'uso dei dati e termini di
  ridistribuzione in-app, non affrontata in questo spike.
- **(c) Rinviare B2 — raccomandata.** L'app resta onesta su ciò che sa fare: tabellone
  live di stazione (Padova, Roma Termini) + tratte salvate col prossimo treno reale.
  Nessuna promessa di "ricerca soluzioni" che non possiamo mantenere.

**Implicazione di prodotto**: B2 è nel core del PRD ma **non è realizzabile con dati
aperti** allo stato attuale. Va comunicato come scelta esplicita, non lasciato come
funzione "in arrivo" a tempo indeterminato.

## Riproducibilità

```bash
# Feed Toscana (Trenitalia regionale toscano)
curl -L -o trenitalia-toscana.zip \
  "https://dati.toscana.it/dataset/8bb8f8fe-fe7d-41d0-90dc-49f2456180d1/resource/4f85393b-357d-443d-8378-65de4198505f/download/trenitalia.gtfs"
unzip -o trenitalia-toscana.zip -d toscana
grep -ic "padova" toscana/stops.txt        # → 0

# Feed Liguria (include lunga percorrenza che tocca la Liguria)
curl -L -o liguria.zip \
  "https://srvcarto.regione.liguria.it/dtuff/download_statico/opendata/trasporti/GTFS/GTFS-IT-ITC3-TRENITALIA-20260614-20261212-pf.zip"
unzip -o liguria.zip -d liguria
# trip che contengono SIA Padova SIA Roma Termini → 0 (script Python nello spike)
```

I feed scaricati vivono in una cartella scratch fuori dal repo: **nessun dato GTFS è
stato committato** (licenze CC-BY richiederebbero comunque attribuzione esplicita).

## Limiti di questo spike

- Il **NAP nazionale** non è stato esplorato oltre la landing page pubblica: se espone un
  catalogo ferroviario dietro registrazione, questo spike non lo copre.
- Non ho contattato Trenitalia/RFI per un feed su richiesta: possibile, non verificato.
- La conclusione vale **allo stato di agosto 2026** e per i feed elencati; il panorama
  open data italiano cambia (obblighi EU NeTEx via RAP→NAP in corso di adozione).
