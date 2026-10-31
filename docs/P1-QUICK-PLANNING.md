# P1.5 — Pianificazione rapida e filtri calendario

> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI Flutter/Markdown verde: 162 test, Windows EXE/MSIX, Android JDK17/21). Test fisici e deploy cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [ICS](P2-ICS.md).

<!-- CURRENT-STATUS-REF -->
> **Snapshot 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. Le sezioni originali sottostanti restano storiche; vedere lo stato canonico. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).


**Stato codice:** integrata in `main` con PR #4, Flutter `0.9.0+11` e CI Flutter verde. Nessuna migrazione aggiuntiva; deploy e prove hardware non attestati.

## Funzionalità

- **Slot libero in un tocco:** seleziona un giorno nel calendario, scegli **30, 60 o 90 minuti**, poi premi `Slot libero` sull'attività nella sezione `Da pianificare`. L'app cerca il primo slot disponibile fra **09:00 e 20:00** nella zona IANA del dispositivo.
- **Ricerca senza collisioni:** vengono considerate **tutte** le attività (anche completate e temporaneamente nascoste da ricerca/filtri) e tutti i loro blocchi, anche quelli che attraversano la mezzanotte. Un blocco che termina esattamente all'inizio di un altro è compatibile.
- **Ora e DST:** ricerca per ore civili nel fuso IANA, risoluzione UTC esplicita, step da 15 minuti. Le ore inesistenti o ambigue nelle transizioni DST vengono saltate; non vengono «aggiustate» tacitamente. L'algoritmo non propone orari già passati.
- **Fallback sicuro:** se Windows/Android non fornisce un fuso IANA valido, la scorciatoia **non salva nulla** e suggerisce l'editor completo `Pianifica` con scelta esplicita del fuso. Non viene ipotizzato UTC o Europe/Rome.
- **Filtri visivi:** `Tutte`, `Da fare`, `Completate`, `Priorità P1–P3` e ricerca testuale insensibile al maiuscolo nel titolo, descrizione, tag e sottotask. I filtri sono applicati a calendario/agenda/timeline e riepilogo, senza mutare SQLite, ID, outbox, cursor o versioni remote.
- **Nessuna eliminazione dei dati:** il blocco suggerito viene salvato solo dopo scelta dell'utente con `LocalStore.addTaskTimeSlot`, che rilegge il task corrente e produce una sola operazione nella normale outbox. La scadenza `due` non viene modificata. Il limite P1.4 di **12 blocchi/task** è rispettato.

## File

| Percorso | Responsabilità |
|---|---|
| `apps/flutter/lib/ui/calendar_quick_planner.dart` | Motore puro di ricerca dello slot, collisioni e filtro non distruttivo |
| `apps/flutter/lib/ui/calendar_board.dart` | Comandi Forui dei filtri, ricerca e scorciatoia `Slot libero` |
| `apps/flutter/test/calendar_quick_planner_test.dart` | Collisioni, slot adiacenti, oggi/past, DST gap/fold, fuso invalido e filtri |
| `apps/flutter/test/calendar_board_test.dart` | Test widget di filtri status/priority/search e invarianza dati |
| `apps/flutter/pubspec.yaml` | Versione `0.9.0+11` |

## Verifiche e prerequisiti

- P1.5 riusa **Flyway V9/Drift V7** di P1.4. Il backend deve esporre `timeBlocksSchema:1`; il client fallisce in modo sicuro lasciando l'outbox in attesa se il server non è aggiornato. Nessuna nuova capability.
- CI dell'incremento P1.5: Flutter analyze, test widget/unit, Windows release, Android JDK 17/21. Per i risultati correnti consultare [CURRENT-STATUS.md](CURRENT-STATUS.md).
- Collaudo combinato da effettuare **solo alla fine di più incrementi** secondo il workflow concordato: primo slot su giorno selezionato, filtri, priorità, ricerca, due date indipendente, blocchi multipli, modifiche offline e sincronizzazione Windows↔Android. Il server già verificato dall'utente sulla VPS era Flyway V8; **non dichiarare V9 reale senza una nuova ispezione**.
- Se si decidesse di integrare P1.5 in main, ricordare che una CI verde e un merge GitHub non costituiscono verifica dell'installazione su Coolify/dispositivi.

## Fuori ambito

- Non è una ricorrenza automatica, non genera notifiche e non modifica la priorità o la scadenza delle attività.
- La pianificazione rapida evita le collisioni ma non è un ottimizzatore del calendario né una prenotazione con lock fra dispositivi. Due client offline potrebbero scegliere lo stesso slot, coerentemente con la sincronizzazione task-level esistente.
- Per fusi non rilevati o orari fuori da 09:00–20:00 usare l'editor manuale; rimane modificabile direttamente il titolo del task.

## Sviluppi previsti all'epoca (P1.6 già integrata)

- P1.6 ricorrenze versionate con modello/sync e protezione client legacy.
- P1.7 promemoria locali Android/Windows, evitando notifiche duplicate, con consenso alle autorizzazioni e controllo DST.
