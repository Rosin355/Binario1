# 00 — Product Requirements Document / PDR

## Nome progetto

**Binario1**  
Nome definitivo MVP: l’app deve usare questo nome in documentazione, naming progetto, display name e comunicazione prodotto.

## Visione

Binario1 è una app iOS che porta dentro l'iPhone l'esperienza viva dei tabelloni ferroviari italiani: una superficie nera, righe arancioni, numeri che respirano come led, binari che si accendono, ritardi che emergono come piccoli lampi nella notte della stazione.

L'app non vuole essere un generico travel planner. Vuole rispondere a una domanda molto concreta:

> “Il mio treno quando arriva? Da che binario parte? È in ritardo?”

## Problema

Chi viaggia in treno ha spesso bisogno di informazioni immediate, compatte e affidabili:

- arrivi e partenze per stazione;
- orario programmato;
- orario stimato/reale;
- ritardo;
- binario previsto o confermato;
- cancellazioni, variazioni e note;
- aggiornamento rapido mentre si è in movimento.

Le app ufficiali o generaliste spesso offrono molte funzioni, ma l'informazione da tabellone può essere dispersa. Binario1 punta a diventare una “lavagna viva”, essenziale e leggibile.

## Obiettivo MVP

Realizzare una prima app iOS SwiftUI che:

1. mostra un tabellone arrivi/partenze per una stazione;
2. usa una UI fedele ai tabelloni ferroviari italiani;
3. supporta dati mock e futuro backend JSON;
4. aggiorna automaticamente la vista;
5. evidenzia ritardi, binari e stato;
6. comunica chiaramente se i dati sono vecchi o non disponibili;
7. supporta italiano e inglese fin dalla prima versione.

## Requisito bilingue MVP

Binario1 deve nascere con una base di localizzazione pulita, non aggiunta dopo.

Lingue supportate nella prima versione:

- italiano: lingua principale e tono nativo del prodotto;
- inglese: lingua secondaria per rendere l'app più internazionale e pronta a viaggiatori non italiani.

Regole:

- usare `Localizable.xcstrings`;
- evitare stringhe hardcoded nelle view;
- localizzare header, colonne, stati, errori, empty state, disclaimer e accessibility labels;
- mantenere i nomi delle stazioni come dato ferroviario, senza traduzioni forzate;
- usare status key stabili (`delayed`, `cancelled`, `platformChanged`) e trasformarle in testo localizzato lato client;
- prevedere un futuro language switch interno, anche se nel primo MVP può bastare la lingua di sistema.

## Non-obiettivi MVP

Nella prima versione non implementare:

- acquisto biglietti;
- login utente;
- notifiche push reali;
- geolocalizzazione automatica;
- widget iOS;
- Live Activities;
- Apple Watch;
- integrazione diretta con sorgenti non ufficiali dentro l'app;
- scraping lato client;
- promesse di precisione assoluta rispetto ai monitor fisici in stazione.

## Target utenti

### Viaggiatore pendolare

Vuole sapere in pochi secondi binario, ritardo e partenza. Non vuole navigare in schermate complesse.

### Viaggiatore occasionale

Ha bisogno di una schermata chiara, con stazione selezionata e informazioni comprensibili.

### Appassionato ferroviario / power user

Apprezza una UI fedele, compatta, con molti treni visibili e dettagli tecnici.

## Funzionalità principali

### 1. Tabellone stazione

La schermata principale mostra una lista compatta di treni.

Campi minimi:

- ora programmata;
- categoria e numero treno;
- destinazione o provenienza;
- ritardo;
- binario;
- stato;
- note brevi.

### 2. Arrivi / Partenze

Controllo segmentato o toggle discreto:

- `PARTENZE`
- `ARRIVI`

La UI deve restare coerente con il tabellone fisico.

### 3. Ricerca stazione

MVP con dataset mock di stazioni principali.

Campi stazione:

- `id`
- `name`
- `city`
- `rfiCode` opzionale
- `displayName`

### 4. Refresh dati

- Pull/manual refresh.
- Auto-refresh ogni 30 secondi quando la view è visibile.
- Indicatore “aggiornato alle HH:mm:ss”.
- Warning se i dati hanno più di 3 minuti.

### 5. Stati UI

La view deve gestire:

- loading;
- empty state;
- errore rete;
- dati obsoleti;
- dati disponibili ma incompleti;
- modalità mock/development.

## Requisiti non funzionali

### Performance

- Render fluido con 50+ righe.
- Evitare layout costosi dentro ogni row.
- Aggiornamenti incrementali dove possibile.

### Affidabilità

- L'app non deve crashare se alcuni campi sono nulli.
- Tutte le date devono essere gestite in timezone Europe/Rome per l'MVP italiano.
- Il mapping JSON deve essere tollerante.

### Manutenibilità

- Separare UI, domain model, service e DTO.
- Nessuna URL esterna hardcoded nelle view.
- Service sostituibili con mock.

### Privacy

- MVP senza account.
- Nessun tracking utente obbligatorio.
- Nessuna geolocalizzazione senza consenso esplicito.

## Metriche di successo MVP

- L'utente capisce in meno di 3 secondi il prossimo treno e il binario.
- La schermata principale è utilizzabile senza onboarding.
- La UI è riconoscibile come tabellone ferroviario.
- Il progetto può passare da mock data a backend reale senza riscrivere la UI.
- Il progetto può passare da italiano a inglese senza modificare le view.

## Rischi principali

### Dati live

Il rischio più grande non è SwiftUI, ma la disponibilità stabile e autorizzata dei dati. Per questo il client iOS deve dipendere solo da un backend proprietario normalizzato.

### Accuratezza percepita

L'app deve mostrare sempre `lastUpdated` e uno stato di affidabilità. Non deve promettere precisione assoluta se la fonte non la garantisce.

### UI troppo moderna

Il rischio estetico è trasformarla in una normale app trasporti. L'MVP deve proteggere il carattere del tabellone fisico.

## Roadmap sintetica

### Milestone 1 — Prototype UI + Mock Data

- Schermata tabellone.
- Dati mock.
- Refresh simulato.
- Design fedele.

### Milestone 2 — Backend Contract

- Endpoint JSON normalizzato.
- Cache lato backend.
- Mapping dati.

### Milestone 3 — Live Data Adapter

- Adapter dati in backend.
- Monitoraggio errori.
- Fallback su cache.

### Milestone 4 — UX avanzata

- Stazioni preferite.
- Dettaglio treno.
- Notifiche locali/push.
- Geofence stazione.

## Nota legale/funzionale

L'MVP deve includere una dicitura informativa:

Italiano:

> Le informazioni possono subire variazioni. In stazione fare sempre riferimento agli annunci e ai monitor ufficiali.

English:

> Information may change. At the station, always refer to official announcements and displays.
