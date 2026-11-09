# Simple Notes — Architettura applicativa

<!-- CURRENT-STATUS-REF -->
> **Stato corrente 09/11/2026:** [PR #59](https://github.com/andreadada/simple-notes/pull/59) merged (`aa17094`), regole locali di notifiche per owner e backup opzionale. [Flutter CI #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) **success**: 377 test, analisi e build Android/Windows; [Markdown #42701809467](https://github.com/andreadada/simple-notes/actions/runs/42701809467) **success**. Flyway V11 nel codice, VPS V10 attestata; nessun deploy o E2E. Automazioni task/server e resto P2 non conclusi. [Stato canonico](CURRENT-STATUS.md).

> **Cronologia (stato del 02/11 o 31/10/2026):** R1 gate server-first integrato su `main` ([PR #26](https://github.com/andreadada/simple-notes/pull/26), commit [`f19ee8b0`](https://github.com/andreadada/simple-notes/commit/f19ee8b0a5bea2cb2c2231d85b3e8ad10a5233a7); [Compose CI](https://github.com/andreadada/simple-notes/actions/runs/41523319857) **success** con PostgreSQL 17 sintetico, [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41523319860) **success**). Flutter resta `0.29.0+31` e 191 test già attestati. **VPS reale V10, health/capability live, backup recente e collaudo hardware non verificati**; ultimo stato VPS attestato V8. Nessun deploy o intervento su dati. [Stato](CURRENT-STATUS.md) · [R1](RELEASE-V10-READINESS.md).

## Componenti del codice attuale

| Livello | Implementazione | Responsabilità |
|---|---|---|
| UI Windows/Android | Flutter, Forui, Riverpod; `apps/flutter/lib/ui` | Liste, note, task, editor inline, calendario, pianificazione, ricorrenze |
| Persistenza client | Drift/SQLite schema **V8**, `app_database.dart`, `local_store.dart` | Offline-first, revisioni remote, owner, tombstone, outbox durevole |
| Sync | `auto_sync.dart`, `cloud_sync.dart` | Mutazioni idempotenti, delta per cursor, verifica capability, 409 e 426 |
| API | Spring Boot Java 21/Spring Security, `services/api` | OAuth Google, task/note/liste, sync autorizzata per utente |
| Server | PostgreSQL 17 + Flyway **V1–V11 nel repo**; Compose/Coolify | Stato cloud condiviso, versioni, migrazioni additive |

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

**Deploy non attestato per V11:** VPS attestata fino a Flyway V10 il 03/11/2026; migrazione V11, capability autenticate strict e collaudo Windows↔Android restano da verificare separatamente prima del prossimo rilascio. Non eseguire reset, cancellare volumi o assumere che `main` sia già su Coolify.

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

## P2.1 — Livello archivio portabile (main, PR #20)

`PortableArchive` separa modello JSON versionato e validazione dal picker nativo; `LocalStore` aggiunge copie attraverso transazione SQLite/outbox esistente. La UI nel menu account usa Forui, con conteggi e conferma. Nessuna migrazione, backend API o ownership delle note Sticky modificata. **Non è un backup bit-a-bit**, né ripristina cursori/credenziali/cronologia. [Specifica](P2-PORTABLE-ARCHIVE.md).


## P2.2 — ICS reader device-local (main, PR #21)

`IcsParser` produce eventi esterni immutabili da file in UTF-8 con validazione fail-closed. `IcsLibrary` serializza sorgenti multiple in SharedPreferences per hash del Google owner; `CalendarBoard` le proietta senza metodi `LocalStore` o sync. **Limite storico del solo P2.2:** in quel batch non esistevano feed HTTPS o ricorrenze; P2.3B–P2.3D li hanno aggiunti successivamente. L'OAuth con i provider non è implementato. [P2-ICS.md](P2-ICS.md).

## P2.3A — Identità sorgenti ICS (main, PR #22, Flutter 0.26)

L'overlay ICS rimane in `SharedPreferences` per owner e non usa SQLite, API o outbox. La struttura dati locale evolve a `schema=2`, con ID stabile distinto da `name` e `kind=file/url`; il codice legge in modo non distruttivo lo schema 1 e ne mantiene gli eventi. La sorgente URL è **solo metadata, senza fetch**, fino a P2.3C. Rimozione e sostituzione agiscono sull'identità della fonte, non sugli UID evento. [Specifica](P2-ICS-SOURCES.md).

## P2.3B — Proiezione lazy delle serie ICS

La UI calendario continua a invocare `IcsLibrary.onDay`, che unisce eventi singoli e occorrenze ricorrenti generate per il solo giorno richiesto. Regole e stato ricorrenze persistono nel JSON owner-scoped schema 3. Nessuna estensione Spring Boot, SQLite/Drift o API. [Specifica](P2-ICS-RECURRENCE.md).

## P2.3C — Layer download feed ICS

`ui/ics_feed.dart` isola validazione HTTPS/DNS, pinning socket, redirects e limiti. `IcsFeedService` sostituisce la sorgente tramite `IcsLibrary` solo dopo download e parsing, mentre la UI conserva il modello read-only e SharedPreferences owner-scoped. Niente API/SQL. [Specifica](P2-ICS-FEEDS.md).

## P2.3D — Presentazione sorgenti ICS

`IcsCalendar` mantiene il nome originario e un `displayLabel` opzionale; `IcsLibrary.renameById` salva soltanto metadati locali, `onDay` crea una proiezione con etichetta per la UI. `ics_source_details.dart` formatta conteggi, tipo e tempo refresh; `ics_calendar_controls.dart` presenta un pannello collassabile Forui con modifica direttamente sul testo. Nessuna migrazione backend/Drift. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## R1 — Gate architetturale server-first

Il client Flutter storico `0.29.0+31` contiene funzionalità sync che richiedono Flyway V10 e le capability versione 1. Gli strumenti `infra/release-readiness.sh`, `t4-inspect-db.sh`, `t4-check-api.sh` verificano il contratto solo dopo un eventuale deploy approvato. Nessun nuovo microservizio, endpoint o migration; test sintetici non equivalgono a stato reale VPS. [Runbook](RELEASE-V10-READINESS.md).

## P2.4A — Export CSV client-only

`lib/data/portable_csv.dart` trasforma lo snapshot locale `LocalData` in tre CSV diversi e ne controlla dimensione/iniezione di formule. `main.dart` offre il selettore Forui e usa gli adattatori esistenti `file_selector` e `share_plus`. Nessun endpoint Spring, Flyway, Drift migration, token o outbox creato. Prove real-device rinviate per decisione dell'utente. [Specifiche](P2-CSV-EXPORT.md).

## P2.4B1 — Architettura archivio cifrato locale

Nuovo modulo `lib/data/full_backup.dart`: `FullBackupSource.capture` combina `AppDatabase.fullBackupRows` (transazione read-only per cinque tabelle SQLite Drift V8, incluse tombstone/outbox) e preferenze locali per owner. Whitelist di tabelle/colonne/sync settings e validatori di dominio fail-closed; `FullBackupCodec` cifra AES-256-GCM con chiave PBKDF2-HMAC-SHA256 (180.000 iterazioni). Il file .snb contiene owner solo nel payload cifrato. La cattura delle SharedPreferences avviene separatamente e non offre atomicità globale tra storage. Nessun RESTORE live fino a P2.4B2 cold-start con rollback e stop sync. [Specifica](P2-FULL-BACKUP.md).

## Stato P2 aggiornato al 09/11/2026

La repository include API Flyway V11 di fingerprint delle operazioni sync, controlli server-first read-only e client Flutter con timeline, dashboard analytics, modelli personali locali, calendario ICS export e widget Android di sola navigazione. Le definizioni dei modelli non sono sincronizzate fra dispositivi: il loro JSON di trasferimento manuale è una funzionalità in sviluppo separata. I gate di ripristino restano esercitati solo in sandbox: nessun writer di produzione, nessun replay dell'outbox importata. VPS V11, backup/restore live, S3, OAuth Calendar/Outlook, collaborazione ACL e collaudi fisici non sono attestati. [Matrice P2](P2-DELIVERY-MATRIX.md) · [Restore](P2-RESTORE-DURABILITY.md) · [V11](RELEASE-V11-READINESS.md).
