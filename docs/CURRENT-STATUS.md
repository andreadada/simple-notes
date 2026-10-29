# Stato corrente — Simple Notes

**Aggiornato 29 ottobre 2026.** Codice, CI, deploy Coolify e installazioni Windows/Android sono verifiche **distinte**; questa è la fonte operativa.

| Area | Stato verificato | Gate aperti |
|---|---|---|
| `main` | P0–P1.16 integrate; ultima [PR #17 Responsive](https://github.com/andreadada/simple-notes/pull/17), merge `2f574615`, Flutter **`0.21.0+23`** | Test reali Windows/Android non attestati |
| P1.17 Tray | **Solo branch** `feature/p1-17-windows-tray`, Flutter candidata **`0.22.0+24`**: X→tray, click/menu Apri, Esci esplicito, fallback fail-open | CI, merge e collaudo ZIP/MSIX |
| CI P1.16 | [Flutter 40761227373](https://github.com/andreadada/simple-notes/actions/runs/40761227373) e [Markdown 40761227307](https://github.com/andreadada/simple-notes/actions/runs/40761227307) verdi | CI P1.17 distinta |
| Backend repo | PostgreSQL 17 / Flyway **V10**, Drift SQLite **V8** | Ultima VPS Coolify attestata **V8**; V9–V10 reali e capability non confermate |
| Deploy | Nessun deploy, reset PostgreSQL/SQLite/outbox/SharedPreferences o installazione MSIX eseguiti con P1.17 | Rollout server-first e prova conservativa dei dati |

## Funzioni

- P0–P1.6: Google OAuth, task/note/liste offline-first e sync/outbox, Forui, editing inline, calendari, time blocking, filtri, ricorrenze.
- P1.7–P1.9: reminder Android opt-in inexact, Windows reminder **solo MSIX**, Eisenhower, Kanban.
- P1.10–P1.13: Pomodoro, Habits settimanali e Countdown **locali per account/dispositivo, non sincronizzati**.
- P1.14–P1.16: Sticky Notes Windows (stesso LocalStore), scorciatoie Windows, note responsive 1–3 colonne; integrate, test fisici aperti.
- P1.17: Windows tray; **branch**, non distribuita. Non è autostart né promemoria Windows ZIP.
- P2/P3: temi, integrazioni, condivisione, AI opzionale ancora da fare.

## Gate

1. CI sul commit finale: Flutter analyze/test, Windows EXE/MSIX, Android JDK17/JDK21, Markdown verdi. Poi merge.
2. VPS: Flyway **V10**, failed migrations zero, health UP, capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`.
3. ZIP→MSIX su **profilo di prova** dopo verifica firma/publisher e preservazione SQLite, secure storage, SharedPreferences e outbox. **Nessun reset dati o volumi**.
4. Tray Windows reale: X/hide, click/menu/restore, Esci completo, nessuna icona orfana, assenza tray duplicata nelle Sticky, fallback se plugin non disponibile. Android invariato.
5. Collaudo cumulativo Windows↔Android di sync e dati; Pomodoro/Habits/Countdown rimangono intenzionalmente locali.

[Operazioni](OPERATIONS.md) · [P1.17 Tray](P1-WINDOWS-TRAY.md) · [P1.16 Responsive](P1-RESPONSIVE.md) · [Runbook](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).
