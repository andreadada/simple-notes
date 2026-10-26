# Stato corrente — Simple Notes

**Aggiornato il 26 ottobre 2026.** Distinguere **codice GitHub, CI, deploy Coolify e installazione reale**; le guide vecchie sono cronologia, non la fonte di verità.

| Area | Stato verificato | Da fare |
|---|---|---|
| `main` | P0–P1.13 integrate. Ultima [PR #14](https://github.com/andreadada/simple-notes/pull/14), merge `5ddd9e9`. Flutter **`0.18.0+20`** | E2E e installazioni reali |
| P1.14 | Sticky Notes Windows **solo branch** `feature/p1-14-sticky-windows`, Flutter candidata **`0.19.0+21`**, pop-out/edit note via main engine | CI finale, merge, test Windows |
| Backend repository | Spring Boot, Flyway **V10**, SQLite/Drift **V8** | Coolify reale ultimo attestato Flyway **V8**; V9/V10 e capability da controllare |
| CI PR #14 | [Flutter 40371894259](https://github.com/andreadada/simple-notes/actions/runs/40371894259) e [Markdown 40371894390](https://github.com/andreadada/simple-notes/actions/runs/40371894390) **verdi** | CI distinta per P1.14 |
| Rilascio | Nessun deploy, reset di DB/SQLite/outbox, upgrade ZIP/MSIX o installazione eseguiti nella P1.14 | Prima server V10 reale, poi un collaudo batch |

## Incrementi

- **P0–P1.6:** autenticazione Google, task, note e liste offline/sync, calendario, time-blocking, filtri, ricorrenze e Forui; test automatizzati ma device E2E da fare
- **P1.7–P1.9:** reminder Android opt-in inexact e Windows solo MSIX, Eisenhower e Kanban; test reali di notifiche e upgrade MSIX mancanti
- **P1.10–P1.13:** Pomodoro, Habit quotidiane/settimanali, Countdown con storico **locale separato per account/dispositivo** e **non sincronizzato**; P1.13 integrata PR #14
- **P1.14:** dalle note **già sincronizzate** apre finestre Windows indipendenti, che comunicano col LocalStore/outbox principale senza un secondo DB. **Solo branch**, e non verificata sul PC reale
- **P2/P3:** non avviate

## Gate non distruttivi

1. Flutter analyze/test, APK Android JDK17/21, Windows EXE/MSIX e link Markdown **verdi sullo stesso SHA**, poi merge.
2. Prima dei nuovi client verificare sulla VPS Flyway **V10**, `FAILED_MIGRATIONS=0`, health e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`.
3. Windows ZIP→MSIX solo dopo controllo identità, firma, SQLite, secure storage, SharedPreferences, DLL/plugin; **mai disinstallare o resettare** per superare un errore.
4. Windows Sticky: aprire due note in finestre diverse, salvare verso il main, testare conflitto e chiusura principale. Il plugin Windows non è un supporto Android.
5. Collaudo batch Windows↔Android dopo deploy; i dati di Pomodoro/Habit/Countdown **rimangono locali**, le note sticky invece usano la normale sync.

[Guida operativa](OPERATIONS.md) · [P1.14 Sticky Windows](P1-STICKY-WINDOWS.md) · [P1.13](P1-WEEKLY-HABITS.md) · [Runbook](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).
