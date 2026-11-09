# P2 — Azioni automatiche locali sulle attività

**9 novembre 2026 — [PR #60](https://github.com/andreadada/simple-notes/pull/60) integrata su `main` (`e051162`).** [Flutter CI #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) **success** (392 test, analisi, Android JDK17/21, Windows EXE/MSIX/recovery); [Markdown #42714514223](https://github.com/andreadada/simple-notes/actions/runs/42714514223) **success**. Nessun deploy o hardware test. [Stato canonico](CURRENT-STATUS.md).

## Funzionalità

Da Strumenti → Automazioni → Azioni automatiche sulle attività è possibile creare, modificare, sospendere o eliminare fino a 20 regole per dispositivo e account Google.

Ogni regola definisce un evento locale (creazione o completamento), un filtro facoltativo sul titolo (sottostringa case-insensitive) e un'azione: impostare priorità P0–P3, aggiungere un tag senza duplicati oppure spostare il task in una lista esistente. Le regole sono valutate in ordine; una lista di destinazione eliminata è ignorata. Non ci sono regole attive di default. L'opt-in delle notifiche non influisce sulle azioni task.

## Invarianti, esecuzione e sicurezza

- Si valutano **solo** gli eventi manuali locali di creazione (anche da modello) e di completamento (solo task non ricorrenti). La ricorrenza avanza senza segnare il task come completato e non attiva l'evento completato. Annullare un completamento non attiva nulla; un secondo completamento manuale è un nuovo evento.
- L'effetto viene applicato al modello in memoria **prima di un unico upsert SQLite**, che crea **una sola normale operazione nella outbox**. Le azioni non creano entità aggiuntive, non riattivano se stesse e restano idempotenti rispetto agli stessi attributi. I pull remoti, l'avvio, la ricarica e l'importazione JSON non rieseguono le regole.
- L'archivio regole è locale in SharedPreferences, isolato per owner con chiave hash SHA-256, schema v1, massimo 20 regole e 32 KiB. Letture malformate sono fail-closed e non cancellano né riscrivono preferenze. Un task normale deve poter essere creato anche con archivio automazioni corrotto.
- Prima e dopo il caricamento regole il motore verifica account Google autenticato e boundOwnerId del database. Guest, cambio account o database non associato non eseguono azioni.
- La preferenza taskActions è **opzionale** nei nuovi backup cifrati .snb v1; i backup precedenti rimangono leggibili. Non viene sincronizzata tra dispositivi e nessun restore live è stato abilitato.
- Il server continua a verificare remoteVersion e a generare conflitti su modifiche concorrenti. **Non esiste deduplicazione distribuita** per due eventi manuali contemporanei su due dispositivi, né un job server sempre attivo. Nessuna migrazione Drift/Flyway o nuova API.

## Prove automatiche e limiti

I file task_action_automations_test.dart, task_action_store_integration_test.dart, task_action_automations_widget_test.dart e user_template_backup_test.dart coprono regole, persistenza, owner, outbox, editor Forui, cifratura/retrocompatibilità e archivi malformati. Ciò non sostituisce prove su dispositivi reali.

**Restano aperti:** scheduling remoto, cataloghi sincronizzati tra device, deduplica multi-device, trigger temporali, filtri avanzati e tutto il resto della P2. [Matrice](P2-DELIVERY-MATRIX.md) · [Collaudo differito](DEVICE-ACCEPTANCE-DEFERRED.md).
