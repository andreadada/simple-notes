# P1.6 — Ricorrenze versionate

> **Snapshot aggiornato 28/10/2026:** P1.15 Keyboard Shortcuts integrata su `main` ([PR #16](https://github.com/andreadada/simple-notes/pull/16), Flutter `0.20.0+22`, CI verde). P1.16 Responsive note è **solo in branch** `feature/p1-16-responsive-layout` (Flutter `0.21.0+23`), CI/merge/hardware da verificare. Backend repository Flyway V10; ultima VPS Coolify attestata V8. Nessun deploy/reset. Le versioni e i gate precedenti sotto sono **storici**, per le operazioni correnti leggere [Stato](CURRENT-STATUS.md), [Guida](OPERATIONS.md), [P1.16](P1-RESPONSIVE.md).

**Stato codice:** integrata su `main` con PR #5 (CI complete verdi), Flutter `0.10.0+12`. **Il deploy non è stato verificato.** Backend Flyway **V10** additiva, Drift **V8** additiva.

## Requisiti implementati

- `recurrence: {kind: "none"}` oppure `recurrence: {kind:"daily"|"weekly"|"monthly", interval:1..12}`.
- Una regola è applicabile soltanto a task con `due.kind=date` o `due.kind=datetime`; una scadenza assente/legacy non viene convertita automaticamente. Se si cancella `due`, la regola viene disabilitata esplicitamente.
- L'interfaccia Forui dei dettagli task consente di scegliere la frequenza e alcuni intervalli comuni senza togliere l'edit inline del titolo.
- Quando una attività ricorrente aperta viene completata, viene aggiornata **la stessa attività e lo stesso UUID**, con `completed=false` e la prossima scadenza. L'operazione è **una sola scrittura SQLite e un singolo evento outbox**: non vengono inseriti automaticamente altri task. Un secondo client offline che tenta di avanzare la stessa versione incontra il normale conflitto di sync, non una duplicazione di nuovi UUID.
- Calcolo con **date civili**: daily +N giorni, weekly +7N giorni, monthly +N mesi con day-of-month limitato all'ultimo giorno (es. 31 gennaio→28 febbraio). Il mese successivo a tale data parte dalla nuova scadenza: non è una regola «ultimo giorno del mese».
- Scadenze datetime: conserva HH:mm e IANA; gap DST viene **saltato** fino alla successiva ricorrenza valida; nel fold DST viene preferito l'offset precedente se presente, altrimenti la prima occorrenza UTC. Scelte deterministiche, testate. Non si spostano time block multipli insieme alla scadenza.
- Finché il task è ricorrente, la prima tap su «completato» lo avanza direttamente alla successiva scadenza, senza uno storico delle sessioni precedenti (storico in scope futuro). Nessuna notifica o servizio schedulato in background è introdotto da P1.6.

## Contratto dati

- PostgreSQL `V10__task_recurrence.sql` aggiunge `task.recurrence_json TEXT NOT NULL DEFAULT '{"kind":"none"}'`. Non altera i record, tag, note, liste, block JSON, outbox o sequenze.
- Flutter `TaskEntries.recurrenceJson` additiva Drift V8, default nessuna ricorrenza. Il nuovo client serializza `recurrence` per tutte le mutazioni task, così eliminazione della regola è esplicita.
- API `GET /api/v1/capabilities` espone `recurrenceSchema:1`; il nuovo client la verifica prima di ogni upsert task. Senza V10, l'outbox resta in attesa e l'utente vede il requisito upgrade.
- Il backend legge il campo `recurrence`, lo valida e lo scrive nel payload canonico. Client vecchi che **omettono** `recurrence` possono modificare task privi di regola, ma ricevono **426** quando la regola attiva potrebbe venire cancellata tacitamente.
- L'API non crea task periodici autonomamente, non presume che un client spento possa generare occorrenze né invia notifiche.

## Gate

- Backend CI Testcontainers PostgreSQL 17: schema V6→V10 con fixture intatte; validazione sintassi e protezioni legacy.
- Flutter CI: analisi/lint, widget/logic tests, build Windows e Android JDK17/21.
- Test manuali **solo nel batch successivo:** scegliere ricorrenza, completare e verificare data cambiata e ID invariato; test cross-device, offline/online e DST; vecchio client HTTP 426, senza reset.
- Per distribuire: Flyway V10 **prima** di Flutter 0.10, health e capability verificate. Aggiornare [CURRENT-STATUS.md](CURRENT-STATUS.md) soltanto con prova reale.
- P1.7 Android è stata integrata successivamente con opt-in, deduplica e scheduler locale inexact, ma non è stata verificata su hardware; Windows necessita MSIX. Queste funzioni non appartengono al contratto P1.6: [stato corrente](CURRENT-STATUS.md), [P1.7](P1-REMINDERS-FOUNDATION.md).
