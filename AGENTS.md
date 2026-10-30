# AGENTS.md — Istruzioni operative per agenti AI

> **Stato operativo 30/10/2026:** P2.1 import/export JSON portabile integrata su `main` ([PR #20](https://github.com/andreadada/simple-notes/pull/20), Flutter `0.24.0+26`, CI Flutter/Markdown verde: 152 test e build Windows/Android). Collaudi fisici e rilascio cumulativo non attestati. Backend repo Flyway V10, ultima VPS verificata V8; nessun deploy/reset. [Stato](docs/CURRENT-STATUS.md) · [Archivio](docs/P2-PORTABLE-ARCHIVE.md).

<!-- CURRENT-STATUS-REF -->

## Prima di qualsiasi modifica

1. Leggere [guida operativa](docs/OPERATIONS.md), [CURRENT-STATUS](docs/CURRENT-STATUS.md), [roadmap](project.md), [design](design.md) e la specifica della feature; usare [HANDOFF](docs/HANDOFF.md) solo come cronologia.
2. Confrontare il testo con codice, migrazioni, `apps/flutter/pubspec.yaml`, i workflow GitHub e le PR **più recenti**. Distingere sempre **implementato / CI verde / deploy VPS attestato / device E2E attestato**.
3. L'utente preferisce commit direttamente su `main` quando possibile, lavoro in piccoli incrementi, documentazione aggiornata e test hardware **in un batch finale**, non dopo ogni feature. Non dichiarare effettuato un merge senza verifica GitHub.
4. Non ripetere domande con risposta documentata. Aggiornare roadmap, handoff e registro `Edit Timespan` per cambiamenti funzionali, mantenendo [CURRENT-STATUS](docs/CURRENT-STATUS.md) fonte unica.

## Architettura e invarianti

- Client Flutter Windows/Android in `apps/flutter`: Forui, Riverpod, Drift/SQLite offline-first, `LocalStore` e outbox. Backend Spring Boot Java 21 in `services/api`: Spring Security, Google OAuth, PostgreSQL 17/Flyway e REST sync. Compose esistente in `docker-compose.yml`.
- Ogni modifica funzionale salva realmente in SQLite/outbox. Preservare `boundOwner`, UUID, `operationId`, `remoteVersion`, cursor, pending e tombstone; sincronizzazione idempotente e account isolati.
- Le migrazioni Flyway e Drift sono **additive**, preservano dati reali e offline e vanno testate con fixture esistenti. Non confondere schema su `main` (Flyway V10/Drift V8) con schema realmente applicato su Coolify.
- `TaskDue` ha semantiche `none/date/datetime/legacy`; date-only **non** significa mezzanotte UTC. Conservare IANA/DST, fold/gap, independence delle scadenze dai time block; fino a 12 slot per task e ricorrenze versione P1.6.
- Prima di inviare nuovi payload, verificare `GET /api/v1/capabilities` con JWT: `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`. HTTP **426** blocca la sync conservando l'outbox; HTTP **409** è un conflitto, non un successo. Non usare CRUD legacy per simulare delta-sync.
- P1.7 (PR #6/#7) integra planner UTC, riconciliazione/ledger, permesso Android opt-in e scheduler inexact; **Windows MSIX** è nel codice, ZIP/EXE non pianifica notifiche. P1.8 (PR #8) include la Matrice Eisenhower con proiezione da priorità/scadenze e modifica inline. P1.9 Kanban è un board per **liste sincronizzate**, integrato su main (PR #10): drag/drop cambia soltanto `listId`; non dichiarare stati workflow separati né drag interno riordinabile. **Non** dichiarare delivery reale Android/Windows, persistenza ZIP→MSIX, snooze o deep-link verificati: mancano test fisici.

## Regole di design obbligatorie

- **Forui-first**, con UI responsive Windows/Android; nessuna regressione a `showDatePicker` / dialog Material sui percorsi migrati.
- **Inline-edit first:** titolo/lista/task/sottotask/nota/tag/descrizione già visibili diventano editabili in posizione; evitare comandi "Rinomina" e dialog superflui. Salva su Invio/blur, annulla su Esc, valida, conserva bozza e focus anche durante sync.
- Underline neutro a riposo/blu al focus **largo quanto il testo o placeholder**, non fino alla Row; `InlineTextMetrics.fieldWidth` per glifi e `inputWidth` per il campo con margine cursore. Usare `InlineGlyphUnderline`, non `Expanded` full-width per la linea. Non troncare testo e placeholder. Test su stringhe lunghe e mobile stretto.
- `FDialog`/`FSheet` per interazioni composte e distruttive; cancellazioni confermate. Modifica advanced ammessa per più campi correlati; non sacrificare sync o accessibilità.
- Flutter Web **non** è un target operativo finché `dart:io`, Drift native e flussi OAuth desktop non sono sostituiti/collaudati.

## Verifiche, deploy e sicurezza

- Eseguire i test pertinenti e controllare CI per Flutter (analyze, test, build Windows/Android JDK17/21), backend e Compose. Il solo job documenti valida link/consistenza, **non** funzionalità o distribuzione.
- Google: Android package `it.andreadada.simplenotes`, Web Client ID Android, Desktop OAuth Windows; non committare secret, token, credenziali, keystore o `.env`.
- **Mai** cancellare volumi Coolify, dati PostgreSQL, SQLite/outbox, usare `down -v`, `adb uninstall`, `pm clear`, `flyway repair`, `pg_restore` in produzione o reset per sbloccare una feature. Reset dei soli dati test già eseguito il 25/10/2026; non ripeterlo.
- Deploy e prove hardware restano distinti dalle CI. Runbook attuale [P1-RELEASE-BATCH](docs/P1-RELEASE-BATCH.md): inventario DB, backup secondo policy approvata, backend V10 e capability/health prima di Flutter 0.10+, E2E Windows↔Android in batch. Nessun deploy tacito.
- L'offsite non è stato eseguito per scelta dell'utente; backup/restore storico del 24/10 non prova la sicurezza o la freschezza di un nuovo rilascio.
- Prima di concludere, verificare lo SHA effettivo su `main`, gli esiti dei job e il contenuto dei documenti aggiornati; registrare chiaramente le prove mancanti.

## P1.10 locale

Pomodoro (P1.10, PR #11 su main) è **device-only**: non aggiungere attributi o sessioni alla sync task, nessun API/DB migration. La preferenza JSON per owner è versionata, scadenza UTC e record deduplicato; un errore di parse **non** deve sovrascrivere i dati. Nessuna promessa di notifiche a timer chiuso. [Specifica](docs/P1-POMODORO.md).

## P1.11 — Habit Tracker (branch)

Check-in giornalieri e streak **locali per owner**, data civile ISO, archivio ripristinabile: non aggiungere nuove tabelle/endpoint né pretendere sync. JSON in SharedPreferences versione 1, su corruzione non resettare/overwrite. UX Forui e editing inline, test date DST, isolamento account e widget. [Specifica](docs/P1-HABITS.md).

## P1.12 — Countdown (main, PR #13)

Usare `TaskDue.dateOnly` per date civili senza inventare midnight UTC, oppure `TaskDue.datetime` risolte con fuso IANA dall'editor Forui. Le card sono dispositive, non cloud; `SharedPreferences` per owner, JSON schema 1 e archivio reversibile. Mai sovrascrivere su parse failure; no reminder o sync inventati. [Specifica](docs/P1-COUNTDOWNS.md).

## P1.13 — Obiettivi settimanali Habit

Il modello `LocalHabit.weeklyTarget` è retrocompatibile con JSON schema 1 P1.11, default 7. Non eliminare check-in o scrivere a server/outbox; solo SharedPreferences locale e isolata per owner. Settimane lunedì–domenica per data civile (no UTC midnight), streak corrente incompleto eredita settimana precedente. Widget Forui nella card, nessun Rename/modal superfluo. [P1.13](docs/P1-WEEKLY-HABITS.md).

## P1.14 — Windows Sticky

Le finestre detached NON aprono SQLite/Drift, OAuth o AutoSync. Usare il bridge al processo main e il suo LocalStore/outbox con controllo della vecchia stringa, così le modifiche stale non sovrascrivono automaticamente i dati. Bootstrap child prima di AppDatabase, plugin registrato su ogni engine; funzione solo Windows, richiede prova reale. [Specifica](docs/P1-STICKY-WINDOWS.md).

## P1.15 — Shortcuts Windows

Solo Ctrl+combinazioni esplicite, solo nella finestra attiva Windows. Mai consumare Ctrl+C/V/Z/A o digitazioni ordinarie; nessuna hotkey globale. `Ctrl+Shift+T` mette a fuoco l'input senza scrivere in DB; `Ctrl+Shift+N` usa LocalStore/outbox già esistente. La guida è un dialogo Forui. [Specifiche](docs/P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Layout responsive

Derivare il numero di colonne **dalla larghezza utile del contenuto**, non dalla piattaforma; mantenere dimensione verticale intrinseca delle note, titolo/corpo inline, comandi Sticky e LocalStore/outbox. Un resize non deve produrre writes, cambiare ID o cancellare i dati. Unit + widget test 320–1600px e nessun overflow. [Specifica](docs/P1-RESPONSIVE.md).

## P1.17 — Tray Windows (PR #18 su main, CI verde)

Solo processo main/Windows: le Sticky separate **non** inizializzano la tray né un DB. La X nasconde soltanto quando la tray è stata registrata; fallimento plugin = close normale. Esci dal menu disabilita prevent-close, libera la tray e chiude normalmente. Nessun autostart, nuovo server, reset dati o toast native Windows ZIP. [Specifica](docs/P1-WINDOWS-TRAY.md).

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](docs/P1-APPEARANCE.md) · [Stato](docs/CURRENT-STATUS.md).

## Vincolo P2.1 — import/export sicuro

L'archivio portabile JSON deve rimanere distinta da backup/ripristino completo e dalla sincronizzazione: non includere token, owner, cursore, outbox, cestino o dati locali di Focus. Import solo dopo parsing/validazione e conferma esplicita in modale Forui; nuove UUID per tutte le copie, associazioni liste/attività conservate e una transazione SQLite, senza replace, reset, update dello storico o sovrascritture. L'operazione importa sull'account locale corrente e genera operazioni di sync normali. [Specifica](docs/P2-PORTABLE-ARCHIVE.md).
