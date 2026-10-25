# P1.7 — Promemoria Android e pianificazione cross-platform

**Stato del branch (25 ottobre 2026):** integrazione Android in PR #6, ancora da validare in CI e su dispositivo. P1.6 è già integrata su `main`. Non equivale a un deploy, a una release Windows né a notifiche E2E verificate.

## Implementato in questo incremento

- `ReminderPlanner` puro per scadenze **con ora esplicita** e blocchi temporali, lead a 15 minuti, chiavi deterministiche account/task/occorrenza/slot, limite di 14 giorni e 100 allarmi.
- `ReminderReconciler` confronta lo schedule desiderato con il ledger locale; rimuove richieste obsolete prima di registrare quelle nuove. Test unitari per deduplica, cancellazione, cambio account e collisioni.
- Android: `flutter_local_notifications` con `zonedSchedule` e alarm **inesatti** (nessun permesso esatto), `POST_NOTIFICATIONS` richiesto **solo dopo tocco esplicito** nel menu account; registro persistente tramite `SharedPreferences`. Receiver per ripristinare pianificazioni dopo reboot/aggiornamento.
- Default **spento**. Il menu account mostra «Attiva/Disattiva promemoria Android». Lo spegnimento annulla gli allarmi registrati; il logout tenta la cancellazione **prima** di chiudere la sessione e si ferma se fallisce.
- Ricalcolo dopo modifiche locali, delta remoto, login e resume; i dati SQLite devono essere associati allo stesso `boundOwnerId` dell'utente prima di schedulare. Non altera outbox, migrazioni, payload o backend.
- Privacy: il testo della notifica è generico (nessun titolo/nota sullo schermo bloccato). `TaskDue.date` non produce orari inventati; task completati e passati vengono esclusi. Ricorrenze seguono l'istanza *corrente* salvata, senza duplicare task.
- Versione Flutter prevista `0.11.0+13`, nessuna nuova migrazione Drift/Flyway.

## Cosa NON è ancora completo

- **Windows:** ZIP/EXE non possiede la package identity necessaria per annullare affidabilmente toast schedulati; scheduling disattivato su Windows. Serve MSIX o adapter verificato prima di abilitarlo.
- Nessuna precisione al minuto promessa su Android: modalità `inexactAllowWhileIdle` e limiti OEM/Doze. Testare permessi Android 13+, riavvio del dispositivo, battery optimization e comportamento a schermo spento.
- Nessun reminder per una sola data civile senza orario. Nessuno snooze, deep link tap-to-open, scelta del lead per task o opzione di privacy configurabile.
- Preferenza **device-local**, non sincronizzata fra dispositivi; la registrazione su un telefono non crea automaticamente notifiche sull'altro.
- Se lo stesso dispositivo resta offline con app mai riaperta, i promemoria già schedulati possono arrivare, ma il piano non può conoscere modifiche effettuate su altri dispositivi fino alla prossima sync.
- Un ledger corrotto o un'API OS che rifiuta l'operazione deve produrre errore visibile; non cancellare il ledger né dichiarare successo. Installazioni interrotte nel breve intervallo tra chiamata OS e persistenza del registro richiedono ancora audit delle pending native.

## Gate di verifica

1. CI Flutter analyze/test, Windows release, APK Android JDK17/JDK21: verdi **sullo SHA finale**.
2. Su Android autentica Google, verifica `boundOwnerId`, attiva dal menu, accetta permesso; conferma pending schedulati e ricezione reale con app chiusa.
3. Task data-only (nessun allarme), con orario, più time block, ricorrenza avanzata, DST fold/gap, modifica/cancellazione/completamento e assenza di duplicati.
4. Disattiva e verifica annullamento; riattiva e cambia account, verifica nessuna notifica del precedente; nega il permesso e conferma che lo stato non diventa «attivo».
5. Effettua E2E Windows↔Android **insieme** al batch finale P1.6, non in ogni commit. Su Windows il menu reminder non deve offrire attivazione non supportata.
6. Server Coolify **prima dei client**: ultima Flyway verificata V8; V9/V10 e capability `recurrenceSchema:1` devono essere confermate dall'utente, seguendo [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md).

**Divieti:** non effettuare deploy o reset; non pubblicizzare P1.7 come notifiche Windows, esatte Android o test su device superati. Stato operativo prevalente: [CURRENT-STATUS.md](CURRENT-STATUS.md).
