# Stato corrente — Simple Notes

**Aggiornato 28 ottobre 2026.** Stato del codice GitHub, CI automatica, deploy VPS e installazioni Windows/Android **sono verifiche distinte**. Questo documento prevale sulle note storiche.

| Componente | Stato verificato | Da verificare |
|---|---|---|
| `main` | P0–P1.15 integrate. Ultima [PR #16 Keyboard](https://github.com/andreadada/simple-notes/pull/16), squash `3e6ee08`, Flutter **`0.20.0+22`** | Installazione e collaudo reali |
| P1.16 responsive | **Solo branch** `feature/p1-16-responsive-layout`, Flutter candidata **`0.21.0+23`**; note Wrap 1/2/3 colonne e gate sidebar/detail centralizzati | CI SHA finale, PR/merge, test PC/Android |
| CI P1.15 | [Flutter 40384676154](https://github.com/andreadada/simple-notes/actions/runs/40384676154) e [Markdown 40384676062](https://github.com/andreadada/simple-notes/actions/runs/40384676062) **verdi** | CI P1.16 distinta |
| Backend repository | Spring Boot/PostgreSQL; Flyway **V10**; Drift/SQLite **V8** | VPS Coolify ultimo stato attestato **V8**, deploy V9/V10/capability non confermato |
| Deploy/upgrade | Nessun deploy Coolify, SQLite/outbox/DB reset o installazione dispositivi effettuati in P1.16 | Release cumulativa server-first e test hardware |

## Fasi

- **P0–P1.6:** Google OAuth, task/note/liste offline-first e outbox/sync, Forui/inline edit, calendario, multi-time-blocks, filtri e ricorrenze.
- **P1.7–P1.9:** reminder opt-in Android inexact e Windows MSIX, Eisenhower e Kanban; test reali ancora necessari.
- **P1.10–P1.13:** Pomodoro, abitudini con target settimanali, Countdown; dati **locali per account/device, non sincronizzati**.
- **P1.14:** Sticky Notes in finestre Windows separate, bridge con processo principale/LocalStore; CI verde, device reale non attestato.
- **P1.15:** shortcut Windows `Ctrl+1..5`, `Ctrl+Shift+T/N`, `Ctrl+/`; **integrate** su `main`, test hardware aperti.
- **P1.16:** adaptive notes 1/2/3 colonne in base a **larghezza del contenuto**, card senza clipping e nuove prove 320–1600px; **solo branch**.
- **Future:** tray Windows, temi, esportazione/calendari, collaborazione, AI opzionale.

## Gate operativi

1. Confermare CI sullo stesso SHA (analyze/test, Windows EXE/MSIX, Android JDK17/21, Markdown), poi merge.
2. Prima dell'installazione di nuovi client, verificare server reale Flyway **V10**, `FAILED_MIGRATIONS=0`, health e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`.
3. ZIP→MSIX Windows solo su **profilo di test** e dopo verifica identità/firma, SQLite, secure storage e SharedPreferences. Non cancellare volumi, database, outbox o preferenze.
4. Un unico collaudo cumulativo Windows/Android: sync offline/retry, calendario/ricorrenze, reminder, Sticky/shortcuts, note responsive e persistenza. Non promettere sync per Pomodoro, Habits o Countdown.
5. CI non dimostra interazioni reali né notifiche quando l'app è chiusa. Non dichiarare già distribuita la candidata P1.16.

[Guida operativa](OPERATIONS.md) · [P1.16 Responsive](P1-RESPONSIVE.md) · [P1.15 Keyboard](P1-DESKTOP-SHORTCUTS.md) · [Runbook server-first](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).
