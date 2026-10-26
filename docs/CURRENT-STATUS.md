# Stato corrente — Simple Notes

**Aggiornato 26/10/2026.** Codice GitHub, CI, deploy VPS e installazione effettiva Windows/Android **non sono equivalenti**. Questo file è la fonte operativa; i vecchi runbook restano cronologia.

## Stato verificato

| Componente | Stato |
|---|---|
| `main` | **P0–P1.11 integrate**. Ultima [PR #12](https://github.com/andreadada/simple-notes/pull/12), merge `486701a`. Flutter **`0.16.0+18`** |
| P1.12 Countdown | **Solo branch** `feature/p1-12-countdowns-main`, Flutter candidata **`0.17.0+19`**, CI/merge/hardware ancora da verificare |
| API/schema GitHub | Spring Boot, PostgreSQL 17, Flyway **V10**, client Drift/SQLite **V8** |
| Coolify reale | Ultimo stato comunicato dall'utente: Flyway **V8**, health UP. Deploy V9/V10, capability e stato attuale **non verificati** |
| P1.11 CI | [Flutter 40364300062](https://github.com/andreadada/simple-notes/actions/runs/40364300062) verde: analyze/test, APK JDK17/21, Windows EXE/MSIX; [Markdown 40364300000](https://github.com/andreadada/simple-notes/actions/runs/40364300000) verde |
| Installazioni reali | Nessuna evidenza che `0.16.0+18` o `0.17.0+19` siano installate e collaudate su Windows/Android |
| Sicurezza dati | Nessun deploy, reset PostgreSQL/SQLite, cancellazione di outbox, reinstallazione o operazione volumi effettuata da questi incrementi |

## Funzionalità

| Fase | Implementazione nel codice | Da verificare |
|---|---|---|
| P0 | Login Google, task/liste/note, offline-first, outbox, sincronizzazione e Forui, editing inline | E2E reale |
| P1.1–P1.3 | Calendario e time blocking con drag/resize | UX reale |
| P1.4–P1.6 | Blocchi multipli, filtri/pianificazione e ricorrenze con Flyway V9/V10 / Drift V7/V8 | Server reale V10 |
| P1.7 | Reminders Android inexact opt-in; Windows **solo MSIX**, nessuna notifica su ZIP | Device, cancellazione, firme, permessi |
| P1.8 | Matrice Eisenhower da priorità/scadenze | Device |
| P1.9 | Kanban per liste sincronizzate | Device |
| P1.10 | Pomodoro 25/5/15 e statistiche **solo locali** | Device e persistenza |
| P1.11 | Habit Tracker check-in/streak/archivio **solo locale** (PR #12) | Device, persistenza e isolamento owner |
| P1.12 | Countdown per eventi civili/IANA, editing inline e archivio **in branch** | CI, merge, prova reale |
| P2/P3 | Non iniziati | Integrazioni, collaborazione, AI e altre funzioni |

**Nota dati locali:** Pomodoro, Habit Tracker e Countdown usano SharedPreferences per account **sul singolo dispositivo**; non sono sincronizzati tra Windows e Android e non introducono nuove migrazioni server. Le date civili dei Countdown **non** vengono trasformate in mezzanotte UTC; le date con orario usano UTC + fuso IANA tramite editor condiviso.

## Gate prima di una release cumulativa

1. CI finale `flutter analyze`, `flutter test`, Windows EXE/MSIX, Android JDK17/21 e Markdown sullo stesso SHA; merge delle PR solo se verde.
2. Il proprietario verifica **sulla vera VPS** Flyway V10, health UP, `FAILED_MIGRATIONS=0` e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`.
3. Verifica il passaggio Windows ZIP→MSIX in profilo di prova (SQLite, secure storage **e SharedPreferences**) e la firma/publisher prima di qualsiasi installazione reale.
4. Un collaudo cumulativo Windows↔Android: offline/retry/409/426, note/task/liste, calendar, Kanban, reminder, Pomodoro, Habits e Countdown. I tre ultimi rimangono **volutamente distinti** sui due dispositivi.
5. Nessun `down -v`, reset SQLite/DB, `adb uninstall` o cancellazione di dati esistenti.

## Documenti

[Guida operativa](OPERATIONS.md) · [Runbook server-first](P1-RELEASE-BATCH.md) · [Specifiche Countdown](P1-COUNTDOWNS.md) · [Habits](P1-HABITS.md) · [Pomodoro](P1-POMODORO.md) · [Roadmap](../project.md) · [Architettura](architecture.md) · [API](api.md) · [Sync](sync.md) · [Handoff](HANDOFF.md).
