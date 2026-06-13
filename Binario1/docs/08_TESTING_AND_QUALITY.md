# 08 — Testing and Quality

## Obiettivo

Garantire che l'MVP sia stabile, leggibile e pronto a ricevere dati reali senza diventare fragile.

## Test unitari

### ViewModel

Testare:

- refresh success;
- refresh failure;
- cambio board type;
- gestione `isLoading`;
- gestione `isStale`;
- prevenzione doppio refresh simultaneo.

### Mapper

Testare:

- decoding JSON sample;
- fallback status sconosciuto;
- platform display;
- displayPlace per arrivi/partenze;
- delay formatting.

### Localization

Testare:

- presenza chiavi italiano e inglese;
- fallback lingua di sistema;
- nessuna stringa hardcoded nelle view principali;
- status `delayed/cancelled/platformChanged` tradotti correttamente;
- accessibility labels in italiano e inglese.

### Formatting

Testare:

- orario `HH:mm`;
- ritardo `--`, `+5`, `+25`, `CANC`;
- accessibility label row.

## Test UI manuali

Eseguire ogni controllo almeno in italiano e inglese.

### iPhone piccolo

- Nessuna colonna tagliata in modo grave.
- Destinazioni lunghe troncate con ellipsis.
- Binario sempre visibile.

### iPhone grande

- Board piena e leggibile.
- Righe dense ma non soffocanti.

### iPad

- Layout non troppo largo.
- Board centrata o con max width.

### Dynamic Type

- Almeno supporto ragionato fino a dimensioni medie/grandi.
- In caso di testo molto grande, preferire leggibilità rispetto alla densità.

## Stati da verificare

- Dati disponibili.
- Nessun treno.
- Errore rete.
- Dati stale.
- Treno cancellato.
- Binario mancante.
- Ritardo mancante.
- Ritardo alto.
- Destinazione lunga.

## Performance

Dataset test:

- 10 righe;
- 50 righe;
- 100 righe.

Requisito:

- scroll fluido;
- niente effetti troppo pesanti per riga;
- evitare Canvas complessi ripetuti dentro ogni row.

## Accessibilità

Ogni row deve avere `accessibilityLabel` leggibile e localizzata.

Esempio:

```text
IT: Frecciarossa 9421 per Roma Termini, partenza prevista alle 15:42, ritardo 7 minuti, binario 6.
EN: Frecciarossa 9421 to Roma Termini, scheduled departure at 15:42, 7 minutes late, platform 6.
```

## Qualità codice

- Nessun force unwrap non necessario.
- Nessun parsing date fragile nelle view.
- Nessun hardcoded URL nelle view.
- Nessun segreto nel repository.
- Service sostituibili.
- DTO separati dai domain model.

## Checklist prima fine MVP

- [ ] App compila.
- [ ] Mock service funziona.
- [ ] JSON sample decodificato.
- [ ] Board partenze visibile.
- [ ] Board arrivi visibile.
- [ ] Refresh manuale.
- [ ] Auto-refresh.
- [ ] Warning stale.
- [ ] Empty state.
- [ ] Error state.
- [ ] Test ViewModel.
- [ ] Test mapper.
- [ ] Preview SwiftUI.
- [ ] UI fedele alla reference.
- [ ] String Catalog IT/EN completo per le schermate MVP.
- [ ] Preview/test manuale in italiano.
- [ ] Preview/test manuale in inglese.
