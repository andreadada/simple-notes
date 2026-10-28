# Stato corrente — Simple Notes

**Aggiornato il 26 ottobre 2026.** Codice GitHub, CI, deploy Coolify e installazione su Windows/Android sono stati distinti.

| Componente | Stato confermato | Gate aperto |
|---|---|---|
| `main` | P0–P1.14 integrate; ultima [PR #15 Sticky Windows](https://github.com/andreadada/simple-notes/pull/15), commit `119ef57`, Flutter **`0.19.0+21`** | Installazione e collaudo reali |
| P1.15 scorciatoie | **Solo branch** `feature/p1-15-desktop-shortcuts`, candidata `0.20.0+22`; Ctrl+1..5, Ctrl+Shift+T/N, Ctrl+/ e guida Windows | CI finale, merge, test PC |
| CI P1.14 | [Flutter](https://github.com/andreadada/simple-notes/actions/runs/40377359849) e [Markdown](https://github.com/andreadada/simple-notes/actions/runs/40377360259) **verdi** | Nuova CI P1.15 separata |
| Backend repo | Flyway **V10**, client Drift/SQLite **V8** | Ultima VPS Coolify attestata **V8**; V9/V10 e capability non confermate |
| Deploy/installazioni | Nessun deploy, reset SQLite/PostgreSQL/outbox né reinstallazione effettuati per P1.15 | Backend-first, E2E dispositivo cumulativo |

## Stato delle funzioni

- **P0–P1.6:** OAuth Google, task/note/liste, offline-first, outbox, Forui e inline edit, calendario, blocchi, filtri e ricorrenze; server V10 reale da confermare
- **P1.7–P1.9:** promemoria Android inexact opt-in e Windows solo MSIX, Eisenhower e Kanban; test hardware da fare
- **P1.10–P1.13:** Pomodoro, Habits settimanali e Countdown **solo locali per account/dispositivo, non sincronizzati**
- **P1.14:** Sticky Notes Windows in finestre indipendenti tramite LocalStore principale e normale sincronizzazione note; codice/CI completati, test fisici aperti
- **P1.15:** shortcut app-local Windows e dialogo Forui **solo branch**, nessun hotkey globale, API o migrazione; test CI e hardware aperti
- **P2/P3:** non avviate

## Vincoli di release

1. CI Flutter analyze/test, Windows EXE/MSIX, Android JDK17/21 e Markdown sullo stesso SHA, prima del merge.
2. Su VPS confermare Flyway **V10**, health e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` prima dell'upgrade cumulativo dei client.
3. Zero reset: preservare DB, volumi, SQLite/outbox, Android, secure storage e SharedPreferences; ZIP→MSIX su profilo di prova con firma/identity verificate.
4. Test Windows di tastiera, finestra sticky, menu/inline-edit, Ctrl+C/V/Z e focus; Android invariato. Un unico collaudo cumulativo Windows↔Android quando il backend reale è allineato.

[Guida operativa](OPERATIONS.md) · [P1.15 scorciatoie](P1-DESKTOP-SHORTCUTS.md) · [P1.14 Sticky](P1-STICKY-WINDOWS.md) · [Runbook server-first](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).
