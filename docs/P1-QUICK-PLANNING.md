# P1.5 — Pianificazione rapida e filtri calendario

**Stato:** sviluppo su `feature/p1-5-quick-planning-filters`, Flutter `0.9.0+11`. Basato sulla P1.4 in `main`. Nessun deploy Coolify, nessuna migrazione API/DB e nessuna installazione dispositivo da questo lavoro.

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
- CI dell'ultimo commit: Flutter analyze, test widget/unit, Windows release, Android JDK 17/21. Non segnarla verde finché l'ultimo run non è completato.
- Collaudo combinato da effettuare **solo alla fine di più incrementi** secondo il workflow concordato: primo slot su giorno selezionato, filtri, priorità, ricerca, due date indipendente, blocchi multipli, modifiche offline e sincronizzazione Windows↔Android. Il server già verificato dall'utente sulla VPS era Flyway V8; **non dichiarare V9 reale senza una nuova ispezione**.
- Se si decidesse di integrare P1.5 in main, ricordare che una CI verde e un merge GitHub non costituiscono verifica dell'installazione su Coolify/dispositivi.

## Fuori ambito

- Non è una ricorrenza automatica, non genera notifiche e non modifica la priorità o la scadenza delle attività.
- La pianificazione rapida evita le collisioni ma non è un ottimizzatore del calendario né una prenotazione con lock fra dispositivi. Due client offline potrebbero scegliere lo stesso slot, coerentemente con la sincronizzazione task-level esistente.
- Per fusi non rilevati o orari fuori da 09:00–20:00 usare l'editor manuale; rimane modificabile direttamente il titolo del task.

## Sviluppi successivi

- P1.6 ricorrenze versionate con modello/sync e protezione client legacy.
- P1.7 promemoria locali Android/Windows, evitando notifiche duplicate, con consenso alle autorizzazioni e controllo DST.
