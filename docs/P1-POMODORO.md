# P1.10 — Pomodoro locale e statistiche

> **Stato operativo 30/10/2026:** P2.1 import/export JSON portabile integrata su `main` ([PR #20](https://github.com/andreadada/simple-notes/pull/20), Flutter `0.24.0+26`, CI Flutter/Markdown verde: 152 test e build Windows/Android). Collaudi fisici e rilascio cumulativo non attestati. Backend repo Flyway V10, ultima VPS verificata V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Archivio](P2-PORTABLE-ARCHIVE.md).

> **Snapshot 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. Le sezioni originali sottostanti restano storiche; vedere lo stato canonico. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).

**Stato (26/10/2026):** **integrata su main con PR #11**, Flutter `0.15.0+17`, [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40347771381) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40347771324). P1.9 Kanban PR #10 è stata integrata su `main` dopo [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40328803094). P1.10 CI/merge confermati; **test su dispositivi reali ancora da completare**. Coolify non modificato: ultimo Flyway reale attestato V8, V10 soltanto nel repository.

## Comportamento implementato

- Voce **Pomodoro** nella navigazione Forui su Windows e Android, UI responsive a 1/2 colonne.
- Timer `25 minuti focus / 5 minuti pausa breve / 15 minuti pausa lunga dopo ogni 4 focus completati`. Avvio, pausa, ripresa, ricomincia e salto della pausa; nessun avanzamento automatico con suoneria e nessuna notifica in background.
- La scadenza del timer è un **istante UTC persistente**, non il numero di tick: dopo sospensione, navigazione o riapertura dell'app, il client calcola il tempo residuo; una sessione scaduta durante la chiusura è registrata al prossimo accesso al pannello, **una sola volta** tramite `activeSessionId` stabile.
- Ogni focus terminato registra un `FocusRecord` (ID, timestamp UTC, 1500 s). Le statistiche mostrano sessioni di oggi, minuti totali e numero di focus completati, più barre per gli ultimi 7 giorni **nel fuso locale del dispositivo**. Storico limitato agli ultimi **500** record, senza cancellare database, task o note.
- Preferenze `SharedPreferences` isolate per account Google tramite SHA-256 dell'ID utente; account non autenticato usa un profilo separato `signed-out-local`. Cambiare account non espone l'altro timer.
- Parsing/versionamento esplicito dello stato JSON: se il formato non è valido, l'app **non lo sovrascrive** e mostra un errore. Un fallimento del salvataggio blocca le nuove azioni finché il salvataggio non riesce, per evitare falsi conteggi.
- La sessione in corso si può azzerare **senza cancellare statistiche già completate**. Sessioni abortite non vengono conteggiate.

## Confini e sicurezza dati

- **Solo locale sul singolo dispositivo.** Non è sincronizzato tra Windows e Android; timer e statistiche sono separati per piattaforma e per account. Non sono task sincronizzati, né allegati a un task.
- Nessun nuovo endpoint backend, servizio in background, SQLite migration, Flyway migration, outbox, push notification, autorizzazione o modifica alla gestione dell'account.
- Il passaggio da ZIP a MSIX **potrebbe modificare la directory di SharedPreferences**, così come quella SQLite: non installare un MSIX in sostituzione su un profilo reale prima di confermare la conservazione dei dati.
- I fusi orari locali e l'orologio del sistema influenzano la visualizzazione giornaliera e un timer basato su UTC; se l'orologio viene cambiato, il risultato può cambiare. Senza esecuzione in background non c'è garanzia di avviso esatto a timer scaduto.
- Lo storico è limitato agli ultimi 500 record; i contatori `focusCompleted` rimangono conservati. I minuti totali si basano sullo storico conservato (quindi parziali oltre 500).

## Verifiche da completare

1. [x] Flutter `analyze`, unit/widget `test`, build APK JDK17+21, Windows EXE/MSIX e Markdown verdi sulla PR #11; [ ] collaudo hardware e verifica di installazione.
2. [ ] Desktop e Android reali: 25/5/15, pause, riprese, riapertura dopo timer scaduto, navigate fra schermate e riavvio (niente duplicati).
3. [ ] Cambio account Google e logout: nessuna statistica di un account visibile dall'altro; profilo locale separato.
4. [ ] Salvataggio preferenze, corruzione/upgrade incompatibile gestiti senza perdita dati; differenze ZIP/MSIX.
5. [ ] Eseguire test E2E cloud soltanto al termine del batch, prima dopo attestazione Flyway V10/capability sul server reale.

[Guida operativa](OPERATIONS.md) · [Stato canonico](CURRENT-STATUS.md) · [Roadmap](../project.md).

## Stato attuale del progetto (26 ottobre 2026)

La P1.13 in branch aggiunge obiettivi settimanali Habit (locale e senza migrazioni); non modifica Pomodoro, registro sessioni e contatori. P1.12 Countdown è integrata su main. [Stato](CURRENT-STATUS.md) · [P1.13](P1-WEEKLY-HABITS.md).
