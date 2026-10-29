# Simple Notes — Architettura applicativa

<!-- CURRENT-STATUS-REF -->
> **Stato operativo 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).

## Componenti del codice attuale

| Livello | Implementazione | Responsabilità |
|---|---|---|
| UI Windows/Android | Flutter, Forui, Riverpod; `apps/flutter/lib/ui` | Liste, note, task, editor inline, calendario, pianificazione, ricorrenze |
| Persistenza client | Drift/SQLite schema **V8**, `app_database.dart`, `local_store.dart` | Offline-first, revisioni remote, owner, tombstone, outbox durevole |
| Sync | `auto_sync.dart`, `cloud_sync.dart` | Mutazioni idempotenti, delta per cursor, verifica capability, 409 e 426 |
| API | Spring Boot Java 21/Spring Security, `services/api` | OAuth Google, task/note/liste, sync autorizzata per utente |
| Server | PostgreSQL 17 + Flyway **V1–V10 nel repo**; Compose/Coolify | Stato cloud condiviso, versioni, migrazioni additive |

## Modello e migrazioni

- `TaskDue`: `none/date/datetime/legacy`, con date-only civile e timezone IANA/DST, introdotto con Flyway V7 e Drift V5.
- Time blocking: primo intervallo P1.2 con Flyway V8/Drift V6; multi-slot P1.4 (fino a 12) con Flyway V9/Drift V7. I blocchi restano distinti dalle scadenze.
- Ricorrenze P1.6: Flyway V10 (`recurrence_json`) e Drift V8; aggiornamento della **stessa attività/UUID** e del successivo `due` con un solo evento outbox. Nessuna creazione periodica server o notifica nativa.
- Il client moderno controlla `GET /api/v1/capabilities` autenticato (`taskDueSchema`, `timeBlockSchema`, `timeBlocksSchema`, `recurrenceSchema`, tutti 1 nel codice). Un server incompatibile non deve consumare la coda locale.
- Sync canonica: `POST /api/v1/sync/apply`, `GET /api/v1/sync/changes`, `GET /api/v1/sync/latest` per versioni e tombstone. HTTP 426 = upgrade richiesto e pending conservati; HTTP 409 = conflitto da risolvere.
- Non usare il semplice health `UP` per attestare le capability, le migrazioni effettive o il deploy.

## UX e piattaforme

La UI è **Forui-first**. I campi testuali già mostrati sono editabili inline; `InlineTextMetrics.fieldWidth` misura i glifi dell'underline e `inputWidth` garantisce spazio cursore, impedendo clipping. Ogni edit salva tramite `LocalStore` e outbox, non nel solo widget. Le selezioni complesse e le eliminazioni usano dialog/sheet Forui.

Target supportati nel codice: Windows desktop e Android (notifiche Windows abilitate soltanto con MSIX, non ZIP/EXE). Matrice Eisenhower P1.8 su entrambi, derivata dai campi task attuali e senza nuova migrazione; il web browser non è pronto per via di dipendenze native e OAuth. Le CI coprono test/build, **non** la sincronizzazione su due installazioni reali.

## P1.7–P1.8 (aggiornamento architetturale)

La pianificazione promemoria P1.7 è device-local (opt-in/ledger), Android inexact e Windows soltanto MSIX. La Matrice P1.8 è una proiezione pura di `LocalTask` basata su `TaskDue` e priorità, con modifiche via `LocalStore`/SQLite/outbox; non introduce un modello remoto né schema aggiuntivo.

## Stato operativo e documenti

- [Stato corrente e gate](CURRENT-STATUS.md), [protocollo API](api.md), [sync](sync.md)
- [Forui e regole grafiche](ui-forui.md), [design](../design.md), [roadmap](../project.md)
- [Runbook V10](P1-RELEASE-BATCH.md), [check dispositivi](T4-DEVICE-SYNC.md), [handoff storico](HANDOFF.md)

**Deploy non attestato:** VPS verificata fino a V8 il 25/10; migrazioni V9/V10, capability di produzione e acceptance Windows↔Android devono essere controllate prima del prossimo rilascio. Non eseguire reset, cancellare volumi o assumere che `main` sia già su Coolify.

## P1.9 — Kanban per liste (integrato su main)

Il board non introduce stato sincronizzato nuovo: proietta `LocalData` in Inbox + liste esistenti, aggiorna `task.listId` tramite `LocalStore.setTaskList` e conserva la outbox esistente. La UI usa Forui, gesti drag/drop o menu accessibile e input rapidi inline. Integrato su main con PR #10 e CI verde; device E2E ancora da verificare. [Specifica](P1-KANBAN.md).

## P1.10 — Timer Pomodoro (branch, device-only)

Timer 25/5/15 e statistiche locali, identità Google isolata nelle chiavi SharedPreferences, ID sessione per impedire doppi conteggi. Nessun endpoint, outbox, SQLite/Flyway schema o sync dedicata. La CI del branch e i test device restano separati dalla compilazione di P1.9. [Specifiche](P1-POMODORO.md).

## P1.11 — Storage locale per account (candidate)

Il modello Habit Tracker `LocalHabit/HabitsState` serializza un documento versionato in SharedPreferences; date civili, titoli inline, streak e archivio ripristinabile. Le chiavi sono isolate da hash SHA-256 dell'owner, ma non sono condivise fra device. Restano fuori da SQLite/outbox/sync e non creano tabelle Flyway. Un JSON corrotto è mostrato come errore non distruttivo. [Specifiche](P1-HABITS.md).

## P1.12 — Countdown device-only

`CountdownsState` aggrega `CountdownEvent` con `TaskDue.date` civile o `TaskDue.datetime` UTC/IANA, owner isolation, validazione JSON schema 1 e archivio reversibile. Nessuna tabella Drift/Flyway, endpoint, outbox, processo background o aggiornamento dati task. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Weekly Habit (solo branch)

`LocalHabit.weeklyTarget` 1–7 viene serializzato nello stesso JSON schema 1 delle abitudini locali, chiave SharedPreferences per owner. `HabitWeek` calcola settimane civili lunedì–domenica e streak senza introdurre timestamp, processi periodici in background o nuove tabelle. La modifica obiettivo non riscrive i check-in. [P1.13](P1-WEEKLY-HABITS.md).

## P1.14 — Sticky Notes Windows

Finestre Flutter separate senza Drift/SQLite proprio: via method channel leggono e aggiornano le note esistenti nel main engine, che conserva ID, outbox, conflitti e sync. La guardia contro valori stale evita sovrascritture silenziose; nessuna migration/API nuova. [Specifica](P1-STICKY-WINDOWS.md).

## P1.15 — Tastiera UI Windows

I comandi app-local selezionano viste già presenti o invocano i metodi normali di `LocalStore` per creare una nota; nessuna API, DTO, migration Flyway/Drift, endpoint, outbox distinta o altro processo. Ctrl+Shift+T mette solo a fuoco un input. [Specifiche](P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Rendering responsive

`NotesResponsivePolicy` calcola sidebar e pannello dettagli dalla viewport e le colonne dalla larghezza **disponibile** dopo le decorazioni; `Wrap` lascia le card ad altezza variabile. Nessun fork dei dati, nessuna migrazione Drift/Flyway, né cambi in auth/sync. [P1.16](P1-RESPONSIVE.md).

## P1.17 — Tray Windows senza server né sync nuove

Hide/restore/quit della finestra non crea entità, endpoint, migrazione, cursor, outbox o credenziali. Il LocalStore/sync già esistente rimane attivo mentre il processo main è nascosto. Il comando Esci chiude il processo; nessun secondo DB nell'engine Sticky. [P1.17](P1-WINDOWS-TRAY.md).
