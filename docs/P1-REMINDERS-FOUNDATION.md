# P1.7 — Promemoria Android e pianificazione cross-platform

> **Stato operativo 30/10/2026:** P1.18 Tema Chiaro/Scuro/Sistema integrata su `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19), Flutter `0.23.0+25`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Tema](P1-APPEARANCE.md).

**Stato del codice (25 ottobre 2026):** P1.7 Android integrata su `main` con [PR #6](https://github.com/andreadada/simple-notes/pull/6), merge `df40b93e`. CI Flutter **verde** ([run 40231569864](https://github.com/andreadada/simple-notes/actions/runs/40231569864)) su test, Windows release e APK JDK17/21. **Nessun test fisico Android**, deploy e delivery Windows da attestare.

## Implementato in questo incremento

- `ReminderPlanner` puro per scadenze **con ora esplicita** e blocchi temporali, lead a 15 minuti, chiavi deterministiche account/task/occorrenza/slot, limite di 14 giorni e 100 allarmi.
- `ReminderReconciler` confronta lo schedule desiderato con il ledger locale; rimuove richieste obsolete prima di registrare quelle nuove. Test unitari per deduplica, cancellazione, cambio account e collisioni.
- Android: `flutter_local_notifications` con `zonedSchedule` e alarm **inesatti** (nessun permesso esatto), `POST_NOTIFICATIONS` richiesto **solo dopo tocco esplicito** nel menu account; registro persistente tramite `SharedPreferences`. Receiver per ripristinare pianificazioni dopo reboot/aggiornamento.
- Default **spento**. Il menu account mostra «Attiva/Disattiva promemoria Android». Lo spegnimento annulla gli allarmi registrati; il logout tenta la cancellazione **prima** di chiudere la sessione e si ferma se fallisce.
- Ricalcolo dopo modifiche locali, delta remoto, login e resume; i dati SQLite devono essere associati allo stesso `boundOwnerId` dell'utente prima di schedulare. Non altera outbox, migrazioni, payload o backend.
- Privacy: il testo della notifica è generico (nessun titolo/nota sullo schermo bloccato). `TaskDue.date` non produce orari inventati; task completati e passati vengono esclusi. Ricorrenze seguono l'istanza *corrente* salvata, senza duplicare task.
- Versione Flutter prevista `0.11.0+13`, nessuna nuova migrazione Drift/Flyway.

## Cosa NON è ancora completo

- **Windows:** PR #7 ha aggiunto scheduling opt-in solo in MSIX (CI verde), il client ZIP/EXE resta disabilitato. Test installazione, identità, storage e annullamento su PC reale ancora pendenti. Vedere [P1-WINDOWS-MSIX.md](P1-WINDOWS-MSIX.md).
- Nessuna precisione al minuto promessa su Android: modalità `inexactAllowWhileIdle` e limiti OEM/Doze. Testare permessi Android 13+, riavvio del dispositivo, battery optimization e comportamento a schermo spento.
- Nessun reminder per una sola data civile senza orario. Nessuno snooze, deep link tap-to-open, scelta del lead per task o opzione di privacy configurabile.
- Preferenza **device-local**, non sincronizzata fra dispositivi; la registrazione su un telefono non crea automaticamente notifiche sull'altro.
- Se lo stesso dispositivo resta offline con app mai riaperta, i promemoria già schedulati possono arrivare, ma il piano non può conoscere modifiche effettuate su altri dispositivi fino alla prossima sync.
- Un ledger corrotto o un'API OS che rifiuta l'operazione deve produrre errore visibile; non cancellare il ledger né dichiarare successo. Installazioni interrotte nel breve intervallo tra chiamata OS e persistenza del registro richiedono ancora audit delle pending native.

## Gate di verifica

1. [x] CI Flutter analyze/test, Windows release, APK Android JDK17/JDK21 **verdi** sul branch prima del merge (run 40231569864); [ ] nuova CI di main se richiesta.
2. Su Android autentica Google, verifica `boundOwnerId`, attiva dal menu, accetta permesso; conferma pending schedulati e ricezione reale con app chiusa.
3. Task data-only (nessun allarme), con orario, più time block, ricorrenza avanzata, DST fold/gap, modifica/cancellazione/completamento e assenza di duplicati.
4. Disattiva e verifica annullamento; riattiva e cambia account, verifica nessuna notifica del precedente; nega il permesso e conferma che lo stato non diventa «attivo».
5. Effettua E2E Windows↔Android **insieme** al batch P1.8, non in ogni commit. Su Windows il menu reminder deve offrire opt-in solo se installato come MSIX (mai sull'EXE/ZIP).
6. Server Coolify **prima dei client**: ultima Flyway verificata V8; V9/V10 e capability `recurrenceSchema:1` devono essere confermate dall'utente, seguendo [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md).

**Divieti:** non effettuare deploy o reset; non pubblicizzare P1.7 come notifiche Windows **già testate**, esatte Android o test su device superati. Stato operativo prevalente: [CURRENT-STATUS.md](CURRENT-STATUS.md).
