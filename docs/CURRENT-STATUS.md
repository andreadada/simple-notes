# Stato corrente — Simple Notes

**Verificato il 26 ottobre 2026.** Distinguere codice GitHub, CI, installazioni Windows/Android e database Coolify: **non sono equivalenti**. Questo documento è la fonte operativa; le guide precedenti sono cronologia tecnica.

## Stato reale

| Componente | Confermato | Gate ancora aperto |
|---|---|---|
| `main` | P0–P1.12 integrate, ultima [PR #13 Countdown](https://github.com/andreadada/simple-notes/pull/13), merge `5312d91`; Flutter **`0.17.0+19`** | Nessuna attestazione di installazione reale dell'ultima versione |
| P1.13 settimanale | `feature/p1-13-weekly-habit-goals`, candidato Flutter **`0.18.0+20`**, UI e logica 1–7 giorni, streak settimanali, vecchio JSON compatibile | CI, merge e hardware da verificare; **non in main** |
| Schema repository | API Spring Boot, Flyway **V10**, client SQLite/Drift **V8** | Sul VPS Coolify l'ultima versione comunicata è Flyway **V8**; V9/V10 reali e capability non attestate |
| CI P1.12 | [Flutter 40368229874](https://github.com/andreadada/simple-notes/actions/runs/40368229874) verde (analyze/test, Windows EXE+MSIX, APK JDK17/JDK21); [Markdown 40368230012](https://github.com/andreadada/simple-notes/actions/runs/40368230012) verde | Nessun collaudo device reale |
| Dati | Nessun deploy/reset PostgreSQL, SQLite, outbox, Android o preferenze eseguito con la P1.13 | Server-first verification e collaudo cumulativo non distruttivo |

## Funzioni presenti

| Fase | Codice | Collaudo |
|---|---|---|
| P0 | Google OAuth, task/notes/liste, offline-first, sync con outbox, Forui e input inline | E2E due dispositivi |
| P1.1–P1.3 | Calendario, blocchi tempo, drag/resize | Hardware |
| P1.4–P1.6 | Multi-blocchi, filtri e pianificazione, ricorrenze; Flyway V9/V10 | Server V10 + device |
| P1.7 | Promemoria Android inexact opt-in, Windows solo **MSIX**; ZIP non supportato | Notifiche hardware, permessi, cancel e firma |
| P1.8–P1.9 | Eisenhower e Kanban per liste sincronizzate | E2E |
| P1.10 | Pomodoro 25/5/15, storia locale per account/device | Test locale e persistenza |
| P1.11 | Habit Tracker quotidiano/streak/check-in/archivio locale | Test device/owner |
| P1.12 | Countdown civili/UTC-IANA, editing inline, archivio, **locale**, PR #13 | Test device/owner |
| P1.13 | Obiettivo 1–7 check-in/settimana, barra avanzamento, streak settimane, vecchi dati preservati **solo nel branch** | CI/merge/device |
| P2/P3 | Non avviate | Integrazioni, collaborazione, AI |

## Contratti e sicurezza

- **Task/Note/Liste** sincronizzati tramite server con la protezione già esistente. **Pomodoro, Habit Tracker e Countdown NON sincronizzati**: SharedPreferences isolate per owner Google e dispositivo; nessuna nuova migration dalla P1.13.
- `weeklyTarget` per Habit Tracker è un campo **opzionale nel JSON schema 1**, default `7` sui record P1.11; aggiornare target non cancella check-in, storico, streak precedenti o preferenze. Check-in settimana lunedì–domenica in **giorni civili**, non blocchi di 24 ore UTC.
- Regola design: campi semplici direttamente editabili; Forui-first. Controlli cambi target nella card, non modali superflue.
- Per distribuire: verificare Flyway **V10** e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` sulla VPS reale, prima di installare nuovi client.
- Su Windows ZIP→MSIX provare **in un profilo separato** identità/firma e preservazione SQLite, secure storage e SharedPreferences; non disinstallare, resettare o cancellare i dati.
- Un solo collaudo cumulativo Windows↔Android, incluse sync offline/retry/409/426 e test locali P1.10–P1.13; non affermare supporto multi-device per questi ultimi.

[Guida operativa](OPERATIONS.md) · [Runbook V10](P1-RELEASE-BATCH.md) · [P1.13 Settimanali](P1-WEEKLY-HABITS.md) · [P1.12 Countdown](P1-COUNTDOWNS.md) · [Habit Tracker](P1-HABITS.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).
