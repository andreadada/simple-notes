# Stato corrente — Simple Notes

**Aggiornato il 26 ottobre 2026**: P1.9 Kanban integrata su main; P1.10 Pomodoro in sviluppo in branch. Questa è la fonte di verità per il codice e per le verifiche *effettivamente attestabili*; i runbook T2/T3/T4 e le vecchie release sono cronologia, non istruzioni correnti.

## Stato verificato

| Area | Stato |
|---|---|
| `main` | P0 + P1.1–P1.9 **nel codice**; ultima integrazione [PR #10](https://github.com/andreadada/simple-notes/pull/10), commit `bce22d1` |
| Flutter `main` | **`0.14.0+16`**; Android e Windows, Forui, Riverpod, Drift offline-first |
| Flutter P1.10 branch | **`0.15.0+17`**; Pomodoro locale, in verifica; non distribuito |
| Backend del repository | Spring Boot, PostgreSQL 17, Flyway **V1–V10** versionate e capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` |
| Database client | Drift/SQLite **V8**; outbox persistente, tombstone e sync con protezione conflitti/versioni |
| CI PR #10 P1.9 | [Flutter run 40328803094](https://github.com/andreadada/simple-notes/actions/runs/40328803094) **verde**; [Markdown run 40328803015](https://github.com/andreadada/simple-notes/actions/runs/40328803015) **verde**. CI post-merge main distinta |
| CI P1.8 PR #8 | [Flutter run 40313588569](https://github.com/andreadada/simple-notes/actions/runs/40313588569) **verde**: analyze/test, APK JDK17+21, Windows EXE+MSIX; [Markdown run 40313588470](https://github.com/andreadada/simple-notes/actions/runs/40313588470) **verde**. Controllare anche i nuovi run `main` dopo il merge |
| Coolify reale | **Ultima verifica comunicata:** PostgreSQL 17, Flyway **V8**, health `UP` il 25/10/2026. Migrazioni **V9/V10 e capability su VPS non attestate**. L'eventuale auto-deploy richiede controllo reale, non supposizioni |
| Client installati | **Non attestati** su versione `0.14.0+16` o `0.15.0+17`; non affermare che PC/telefono abbiano già queste funzioni |
| E2E hardware | Test completo Windows↔Android, offline/retry/conflitti, notifiche Android e Windows MSIX **ancora da eseguire** |
| Release | Nessun nuovo deploy Coolify, installazione, reset PostgreSQL/SQLite o modifica dei volumi effettuati nell'audit |

## Funzionalità implementate

| Incremento | Codice su `main` | Restante gate |
|---|---|---|
| P0 | Google OAuth, task/note/liste, priorità/tag/sottotask, cestino, auto-sync foreground e conflitti Forui, modifica inline | Prova E2E su due dispositivi; hardening |
| P1.1–P1.3 | Calendario giorno/settimana/mese, blocchi orari, drag/resize e gestione DST | UX su hardware |
| P1.4–P1.6 | Max 12 time block/task, quick planner, filtri, ricorrenze daily/weekly/monthly; Flyway V9/V10 e Drift V7/V8 | Server reale V9/V10 e compatibilità client |
| P1.7 Android | Scheduler nativo **inexact**, opt-in, ledger, annullamento prima del logout, testo privacy-safe | Reboot, Doze, permessi, cancellazione e notifiche reali |
| P1.7 Windows | Scheduling solo con identità **MSIX**, packaging CI e opt-in; eseguibile ZIP/EXE **senza** notifiche | Firma/installer attendibile, accesso SQLite/OAuth preesistenti, cancellazione affidabile su PC |
| P1.8 | Matrice Eisenhower a quattro quadranti, responsive, lettura di priorità/scadenza e modifica inline; nessuna migrazione | Test UI e sync su dispositivi reali |
| P1.9 Kanban | **Integrata su main** PR #10: Inbox+liste, drag/drop, menu spostamento, edit inline; nessuna migrazione | Verifica E2E hardware e sync |
| P1.10 Pomodoro | **Solo branch** `feature/p1-10-pomodoro-focus`: 25/5/15, pause e ripresa, salvataggio locale per account e statistiche su questo dispositivo; nessuna migrazione | CI su SHA finale, merge, test fisici e persist/owner isolation |
| P2/P3 | Non avviate | Habit, integrazioni, funzioni smart, secondo roadmap |

La matrice P1.8 **non** introduce un campo autonomo di importanza/urgenza: `priority >= 2` indica importante; è urgente la scadenza con istante entro 48h, mentre per `date-only` contano oggi/domani/giorni trascorsi. Il quadrante "Delega" non assegna attività ad altri account.

## Regole permanenti

1. **Forui-first, editing inline:** titolo/nome/attributi semplici visibili editabili direttamente; underline della sola lunghezza del testo.
2. **Offline-first:** ogni modifica locale preserva SQLite/outbox, cursor, UUID, boundOwner e idempotenza; HTTP 409 non è 426.
3. **Versioni diverse:** codice, CI, deploy e installazione reale non sono equivalenti. Non scambiare un backup storico per un backup nuovo.
4. **Rilascio sicuro:** verificare schema Flyway **V10** e capability sulla VPS, poi installare client; E2E in batch. Non effettuare `down -v`, reset, reinstallazioni distruttive o spostamenti dati MSIX non testati.

## Riferimenti operativi

- [Roadmap e Edit Timespan](../project.md), [regole agenti](../AGENTS.md), [UX](../design.md)
- [P1.8 Matrice](P1-EISENHOWER.md), [P1.7 Android](P1-REMINDERS-FOUNDATION.md), [P1.7 Windows MSIX](P1-WINDOWS-MSIX.md)
- [Guida operativa](OPERATIONS.md), [P1.9 Kanban](P1-KANBAN.md), [P1.10 Pomodoro](P1-POMODORO.md), [runbook rollout backend V10](P1-RELEASE-BATCH.md), [sync](sync.md), [API](api.md), [dispositivi](T4-DEVICE-SYNC.md), [handoff storico](HANDOFF.md)

**Prossima sequenza:** CI e merge P1.10 / documentazione → verifica del backend V10 su Coolify → controllo non distruttivo del passaggio ZIP→MSIX → installazioni → un collaudo E2E Windows/Android. L'utente gestisce personalmente il deploy Coolify.
