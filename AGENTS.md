# AGENTS.md — Istruzioni operative per agenti AI

> **Stato operativo 06/11/2026:** `main` integra fino a **P2.4B2U** ([PR #53](https://github.com/andreadada/simple-notes/pull/53), merge `afa835d6`); Flutter `0.31.0+33`, Drift V8 e backend Flyway **V11 nel codice**. [Flutter CI #42239264547](https://github.com/andreadada/simple-notes/actions/runs/42239264547) **success** (322 test, Android Java 17/21, Windows EXE/MSIX e recovery sandbox Windows); [Markdown CI #42239264424](https://github.com/andreadada/simple-notes/actions/runs/42239264424) **success**. Backend e Compose erano verdi su [PR #50](https://github.com/andreadada/simple-notes/pull/50). **VPS attestata solo a Flyway V10 (03/11); V11/API strict e prove fisiche non attestati.** Restore live, replay outbox importata e deploy restano fuori scope. [Stato](docs/CURRENT-STATUS.md) · [Backup](docs/P2-FULL-BACKUP.md) · [V11](docs/RELEASE-V11-READINESS.md).

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

## Vincolo P2.2 — Calendari esterni

Un evento ICS resta **read-only** e **device-local per account**: non creare UUID task, outbox, migrazioni, endpoints, reminder o mutazioni sincronizzate. Fallire in modo esplicito quando un file contiene ricorrenze/exception, timezone non IANA o orari DST ambigui; non nascondere eventi parziali. Conferma con Forui prima di cambiare l'overlay locale; non toccare liste/task/note né cache credenziali. [Contratto](docs/P2-ICS.md).


## Vincolo P2.3A — Identità delle sorgenti ICS

Archivio JSON locale `schema=2` nella **stessa** preferenza owner-scoped ICS v1. Leggere i vecchi `schema=1` senza scrittura automatica; ID legacy deterministico per filename, UUID v4 per nuove importazioni e ID conservato ai reimport. `IcsSourceKind.url` è **solo modello**: non aggiungere fetch, OAuth, sync, outbox, migrazioni o trigger di rete in P2.3A. Rimuovere per `id`, mantenere read-only, limite cinque fonti, parsing fail-closed e controllare l'owner dopo qualunque `await` del picker/dialogo. Non presentare `schema=2` come retrocompatibile con vecchi client P2.2: la lettura è v1→v2, non v2→v1. [Specifica](docs/P2-ICS-SOURCES.md).

## Vincolo P2.3B — Serie ICS

Evento esterno ricorrente sempre **read-only** e **device-local per account**: non creare task, notifiche, API o outbox. RRULE solo per sottoinsieme dichiarato, senza materializzare serie infinite; EXDATE prevale su RDATE/RRULE, RECURRENCE-ID individua l'occorrenza originale. Non ignorare parametri RFC ignoti: import fail-closed. JSON schema 3 letto insieme a schema 1/2 senza scrittura al load; vietato downgrade silenzioso a client P2.3A. [Specifica](docs/P2-ICS-RECURRENCE.md).

## Regola P2.3C — Fonti ICS HTTPS

Fetch URL **solo su gesto esplicito** utente, nessun auto-refresh/background o token OAuth. Controllare DNS per socket, rifiutare IP privati e redirect cross-host, non esporre query token in UI/log. Conservare la cache dopo errori, isolare per owner, non convertire VEVENT in task/outbox. Il caricamento schema 1/2/3 non deve riscrivere preferenze. [Specifica](docs/P2-ICS-FEEDS.md).

## Regole P2.3D — ICS source displayLabel

Il nome visibile ICS si modifica **direttamente nel testo** con InlineEditableTitle; niente pulsante Rinomina o modal. Non modificare `IcsCalendar.name`, URI feed, ID o UID evento: usare `displayLabel` opzionale (max 80 caratteri) distinto dall'identità originale. Reimport file e refresh URL preservano il label, eventi read-only visualizzano quello rinominato senza mutare il JSON dei master. Pannello sorgenti mostra solo hostname/refresh riuscito, mai URL completo/query-token. Storage schema 3 owner-scoped, non riscrivere al caricamento, nessuna modifica API/sync. [Contratto](docs/P2-ICS-SOURCE-MANAGEMENT.md).

## Regola rilascio R1 — Vietato confondere CI con deploy VPS

Il gate server-first (PR #26, CI sintetica verde) per il client cumulativo richiede **Flyway V10 reale**, nessuna migration fallita, colonne V7–V10, health UP e capability autenticate `taskDueSchema`, `timeBlockSchema`, `timeBlocksSchema`, `recurrenceSchema`, `noteRestoreSchema` tutti versione 1. Usare solo il wrapper read-only `infra/release-readiness.sh` con container verificato e token temporaneo nell'ambiente. Nessun reset/redeploy/backfill automatico, nessun segreto nel repo/chat; un test su DB sintetico non prova lo stato VPS. Conservare il workflow T4 senza strict flag per ispezioni storiche. [Runbook](docs/RELEASE-V10-READINESS.md).

## Regola P2.4A — CSV è un export, NON backup

CSV si genera soltanto dal locale `AppDatabase.snapshot()` dopo scelta esplicita; niente modifiche SQLite, outbox o sync, nessun trashedNotes, owner, credenziali o URL ICS privati. Limite 8 MiB/10.000 record, UTF-8 BOM, quoting RFC4180 e formule neutralizzate prima di quoting. La selezione CSV usa Forui e le destinazioni native esistenti; non creare un importer CSV implicito. **Test manuali Windows↔Android rinviati dall'utente**, ma CI/test automatici obbligatori; non marcarli completati. [CSV](docs/P2-CSV-EXPORT.md) · [Rinvio](docs/DEVICE-ACCEPTANCE-DEFERRED.md).

## Vincoli P2.4B — Backup reale senza perdita

Il formato .snb deve essere cifrato obbligatoriamente (AES-256-GCM, PBKDF2 e salt/nonce casuali) e includere tutte le tabelle SQLite e preferenze del solo owner. Mai includere JWT/refresh token, file di secure storage, log di password o dati di altri account. Rifiutare schema/tabelle/colonne ignote invece di produrre backup incompleti. In P2.4B1 **solo export + inspect read-only**: nessun pulsante di restore che sovrascriva SQLite, SharedPreferences o sync outbox. P2.4B2 dovrà operare a cold-start, con stop sync, checkpoint verificato e rollback prima di consentire restore. Test fisici rinviati dall'utente, ma CI obbligatoria. [Specifiche](docs/P2-FULL-BACKUP.md).

**Stato ufficiale (03/11/2026):** P2.4B1 PR #28 integrata su `main`, Flutter `0.31.0+33`, CI 204 test e build native PASS. Il ripristino P2.4B2 **non è implementato**: mantenere il blocco fino a cold-start, anti-replay, checkpoint verificato e rollback. [Specifica](docs/P2-FULL-BACKUP.md).


## Gate P2.4B2A — solo ripristino isolato

FullBackupRestoreRehearsal decifra e ricostruisce SQLite esclusivamente in un nuovo NativeDatabase.memory(). Mai usare la stessa procedura su AppDatabase persistente né aggiungere una voce «Ripristina» prima di cold-start isolato, checkpoint recuperabile, rollback SQLite+preferenze e strategia anti-replay provati. Un report di rehearsal non autorizza sync, re-invio della outbox o interventi VPS. [Contratto](docs/P2-FULL-BACKUP.md).


## P2.4B2B1 — checkpoint come gate, mai consenso di restore

FullBackupCheckpointPreflight effettua una cattura logica validata dello snapshot corrente, la cifra, chiede a uno store di scrivere un **file nuovo**, lo rilegge e confronta SHA-256, payload e prova SQLite isolata. FileFullBackupCheckpointStore non deve mai sovrascrivere un backup, usare path impliciti del profilo o essere invocato da una UI di restore live. Il receipt non autorizza restore o sync. Mancano ancora robustezza crash/power loss, rollback SharedPreferences, cold-start e anti-replay prima dell'attivazione. [Contratto](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2B2 — rollback cross-store solo in memoria

`FullBackupRollbackRehearsal` NON è una procedura di restore: il DB è sempre `NativeDatabase.memory()`, le preferenze sono una mappa privata e il rollback è provato prima di chiudere il sandbox. Non sostituire `NativeDatabase.memory()` con `AppDatabase()`, non indirizzare a file del profilo, non riprodurre l'outbox e non aggiungere una UI «Ripristina». Per passare a dati reali restano obbligatori cold-start, checkpoint fsync/recovery, rollback delle preferenze su disco, gestione credenziali, controllo anti-replay e test distruttivi **solo su profili di prova**. [Specifiche](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2C1 — journal fail-closed ma non operativo

`FullBackupColdStartGuard` e `FileRestoreJournal` sono **solo prototipi per test isolati**: il journal è in directory esplicita temporanea, manca fsync directory e protezione multi-processo, e non va collegato a startup/AutoSyncHost o a un path del profilo installato. Un file temporaneo, una sequenza mancante, un hash non valido o un account diverso devono bloccare il recovery. `RestoreReplayRisk` **non autorizza mai** il replay delle `pending_mutations` o del `syncCursor` importato, nemmeno con cursor uguale/outbox vuota; è necessaria riconciliazione remota esplicita e testata. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2C2 — vietato aggirare l'interlock

`main.dart` DEVE eseguire `probeRestoreStartup()` **prima** di istanziare AppDatabase, migrare SQLite, inizializzare Google OAuth o AutoSync. La directory riservata `simple-notes-recovery-v1`, anche vuota/errata, impone blocco fail-closed; non rimuovere automaticamente marker sospetti. `restoreSyncGateProvider` va sovrascritto nell'entrypoint di produzione e rispettato da **tutti** gli ingressi sync, compresi upload manuale e risoluzione conflitti. Il reader `RestoreCloudReadOnlyPreflight` ammette solo richieste GET e produce osservazioni non autorevoli: **non** usare i suoi dati per autorizzare upload/cursor importati. Nessun writer live fino a lock esclusivo, recovery persistente multi-store e riconciliazione cloud. [Specifica](docs/P2-FULL-BACKUP.md).

`RestoreServerInventoryReader` è scollegato dal normale sync e può emettere solo GET `/sync/inventory`; non interpretare un inventario completo come consenso per ricaricare outbox o cursor. Rifiutare payload extra, risposte parziali, 404 e dati malformati. Il deployment del backend deve essere separato e autorizzato.


## Vincolo P2.4B2C3 — inventario remoto senza dati riservati

L'API `/api/v1/sync/inventory` è **solo GET** e deve filtrare ogni query con owner dal JWT, usare snapshot coerente in sola lettura, omettere completamente i payload di task/note, non presentare risposte parziali senza contrassegno e non aggiornare `sync_change`/`sync_operation`. Anche con inventory completo l'upload di outbox/cursori restaurati deve restare vietato finché non esiste protocollo esplicito di riconciliazione e precondizioni concorrenti. Non eseguire il deploy Coolify né migrazioni senza autorizzazione. [API](docs/api.md).


## Vincolo P2.4B2D — file persistenti solo nel temp dei test

`DiskRestoreRehearsal.create()` è una prova distruttiva *solo* su file creati nella propria directory `Directory.systemTemp`. Non aggiungere constructor o path override per puntare a `ApplicationSupport`/SQLite installata, né collegarlo a `main.dart`, CloudSync/AutoSyncHost, SharedPreferences reali, OAuth o UI. Non cancellare automaticamente marker sospetti in un profilo live. Il lock consultivo e il rename dei file non garantiscono da soli durabilità/recupero su Android e Windows; tali gate richiedono prove per piattaforma, lock multiprocesso, fsync della directory e procedure di compensazione cross-store. Nessuna sync di outbox importata senza riconciliazione esplicita. [Specifiche](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2E — confronto .snb sempre sola lettura

`FullBackupCompare.preview` e la voce «Confronta backup con questo dispositivo» **non devono** chiamare `upsert`, `applyRemote`, `bindOwner`, `synchronize`, `/sync/apply`, cancellare marker o sostituire SQLite/SharedPreferences. Confrontare solo snapshot validati e stesso owner dopo decifratura autenticata. Il summary pubblico deve contenere esclusivamente conteggi e indicatori, mai testo note/task, payload outbox, token, password o owner ID. Non interpretare un cursore identico, una outbox vuota o un confronto uguale come consenso al restore o upload. [Specifica](docs/P2-FULL-BACKUP.md).

## Regola CI — non duplicare push e PR
Le CI Flutter, Backend e Compose devono girare per ogni pull request rilevante e per i push su `main`; non rieseguire lo stesso set di job sul push di un branch con PR. Usare il group `concurrency` per numero PR/ref e cancellare esecuzioni obsolete **solo** sulle PR, mai su `main`. Mantieni obbligatori analyze, widget test, build Windows e Android JDK17/21, integrazione PostgreSQL/Testcontainers, Compose e link Markdown. Prima dei merge verificare sempre l'ultimo HEAD SHA.


## Vincolo P2.4B2F — inventario cloud consultabile solo su azione utente

Il pulsante «Consulta inventario cloud» deve essere **opt-in**, non chiamato da startup, timer, auto-sync o selezione del backup. Usare solo GET `/sync/inventory` e token già valido della stessa sessione owner, rifiutare 404/risposte malformate e non loggare token, note, ID entità o payload. Un risultato rassicurante non è autorizzazione a ripristinare, cancellare o rieseguire l'outbox. La UI mostra soltanto conteggi e mantiene `canRestoreLive`, `canResumeAutoSync` e `canApplyImportedOperations` sempre false. Nessun deploy VPS/Coolify nel workflow di sviluppo. [Specifiche](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2G — nessuna autorizzazione dal dry-run

`ReconciliationDryRunPlanner` deve essere **puro e read-only**. Tutte le strategie (rimanda / preferisci locale / backup / cloud) sono ipotesi di presentazione, senza operazioni applicabili o salvataggio delle scelte. Il report mostra soltanto numeri e avvisi: vietati ID entità, note, titoli, payload, owner ID e token. Il fingerprint SHA-256 locale non è firma, consenso o precondizione server e non permette restore. Anche quando `entitiesNeedingReview == 0`, `canRestoreLive`, `canWriteToCloud`, `canReplayImportedOutbox`, `canResumeAutoSync` e `isExecutable` devono restare false. L'outbox importata resta sempre in quarantena; nessun deploy o modifica dati reali. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2H — per-item draft solo in RAM

`ReconciliationWorksheet` e i suoi `DraftConflictChoice` devono essere **puramente locali e non eseguibili**. Nessuna chiamata HTTP, modifica SQLite o SharedPreferences, backup importato, journal rimosso o ripristino deve derivare da una scelta. La UI può mostrare titolo e tipo del record solo nel dialog esplicitamente aperto dall'owner autenticato; report/summary/log/token opachi **non** devono includere ID, titoli, body, owner, password o payload. Token falsificati, preferenze per sorgenti assenti e fingerprint/owner cambiati vanno rifiutati. Oltre 500 record fail-closed, senza paginazione/troncamento silenzioso. Tutti i getter di autorizzazione restano false anche con 0 conflitti. [Specifica](docs/P2-FULL-BACKUP.md).

## Vincolo P2.4B2I — write con cursore owner-scoped solo sotto lock

Non spostare il check `expectedAccountCursor` fuori dalla transazione `SyncService.apply` né prima del lock transazionale per account. Il confronto deve usare `MAX(sync_change.id)` filtrato per owner, non MAX globale. Un 409 non può creare eventi, operazioni o mutare note/task/liste. Il preflight `/sync/reconciliation/check` è solo read-only, same-owner, max 100, chiavi uniche e validazione fail-closed; non esportare body o payload. Un risultato `consistent=true` non è consenso al restore. Legacy client senza cursore invariati, restore live e replay disabilitati. [Specifiche](docs/P2-FULL-BACKUP.md).

## Vincolo P2.4B2J — ricontrollo remoto mai mutante

`ReconciliationPreflightClient` deve essere invocato solo da azione esplicita in UI, dopo GET inventory. La POST a `/sync/reconciliation/check` è **sola lettura**: consentito solo body ID/versioni/tombstone/cursor, vietati note/body, payload sync, password, dati personali e token nei log. Non invocare `/sync/apply`, refresh auth, AutoSync o restore da questo flusso. Rifiutare se >100 item (mai batch parziale), owner cambiato, token scaduto, HTTP errore o flag incoerenti. Un check `consistent=true` non è consenso e non sblocca `canRestoreLive`, `canApplyDecisions`, `canWriteCloud`, `canReplayImportedOutbox` o `canResumeAutoSync`. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2K — nessun falso `consistent` dal ledger

Il preflight revisioni **non può** dichiarare `consistent=true` se la riga materializzata dell'owner ha `version` o `deleted_at` discordanti dall'evento latest, oppure solo uno dei due esiste. Usare sempre query parametrizzate per owner/ID e allowlist hardcoded di tabella, senza lettura di contenuti nota. Un disallineamento deve fallire chiuso (409); nessun reset, replay, cancellazione o auto-restore. Il check non protegge l'intero account da futuri write legacy: mantenere disabilitato il restore. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2L — preflight sull'intero account, non solo sugli ID noti

La verifica `/sync/reconciliation/check` non deve considerare sicuro un account quando esistono righe note/task/liste non rappresentate dal ledger, anche se tali righe non figurano nell'inventory e non sono richieste nel batch. Eseguire scan read-only owner-scoped su tutte e tre le tabelle nel medesimo snapshot `REPEATABLE_READ`. Non rifiutare i tombstone sintetici consentiti dal protocollo per entity fisicamente già assenti. Non leggere/mostrare titoli/body. Errore 409 significa blocco del flusso e non può autorizzare restore, cancellazione o replay. [Specifiche](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2M — ogni write legacy dentro sync/ledger

Tutte le mutazioni dei controller REST storici `/notes` e `/tasks` devono avvenire nello stesso percorso owner-locked `SyncService.apply`; vietato introdurre `saveAndFlush` diretto nei servizi legacy. Prima di leggere una riga per update, PATCH completion o delete, acquisire il lock advisory owner nella **stessa transazione**. Preservare `expectedVersion`, tombstone e 426 per vecchi editor su scadenze civili, non cancellare timeBlocks/recurrence/tags/subtasks durante PATCH completion. REST non fornisce idempotency key client, quindi evitare di promettere retry exactly-once per POST create. Testare che `sync_change` e `sync_operation` accompagnino commit REST; anomalie SQL storiche vanno rilevate, non autoriparate. Restore live e deploy restano fuori scope. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2N — inventory non può essere completo su un account incoerente

Il GET `/sync/inventory` deve restare read-only, JWT owner-scoped, e invocare la stessa guardia di coerenza account-wide del preflight prima di dichiarare `complete=true`. Se l'ultimo evento sync non rappresenta una riga materializzata, o un latest attivo manca nella tabella, rispondere 409 senza payload di note o account. I synthetic tombstones rimangono validi. **Non** tentare backfill, reset, replay o restore come risposta automatica. Un inventory coerente non è un lease per future mutazioni. [Specifica](docs/P2-FULL-BACKUP.md).


## Vincolo P2.4B2O — operationId identifica un intento immutabile

Ogni `SyncOperation` **nuova** deve memorizzare fingerprint SHA-256 canonico di entityType/entityId, action, expectedVersion e payload; mai includere token/password o loggare il contenuto. Confrontare sotto lock owner **prima** di rispondere a un retry; stesso ID ma diversa azione/body/versione = 409 senza scritture. Escludere `expectedAccountCursor` perché è guard CAS transitorio e può avanzare dopo un primo commit valido. Ordinare ricorsivamente le proprietà JSON, conservare l'ordine degli array. Per righe pre-V11 con fingerprint NULL mantenere compatibilità storica, senza inventare backfill o cancellare righe. La migrazione V11 è additiva e non va eseguita in produzione senza runbook, backup e autorizzazione. Nessun fingerprint concede restore/auto-sync. [Specifica](docs/P2-FULL-BACKUP.md).

## P2.4B2P — Ispezione V11 solo in lettura

Mantenere `infra/release-readiness.sh` V10 compatibile con lo storico; usare `infra/release-v11-readiness.sh` per la verifica esatta V11 **solo dopo un rollout separatamente autorizzato**. L'inspector PostgreSQL deve rifiutare mismatch Flyway ↔ colonna fingerprint, schema diverso da nullable VARCHAR(64), formati non esadecimali, DB sbagliato o migration fallita, senza stampare password, token, ID o valori. Testare con Compose su schema PostgreSQL **sintetico**. Non introdurre `ALTER TABLE`, `flyway migrate`, `pg_restore`, reset o deploy in script read-only. [Runbook](docs/RELEASE-V11-READINESS.md).


## Vincolo P2.4B2Q — non riutilizzare operation ID incompatibili

Il backend deve distinguere un conflitto versionato risolvibile da `SYNC_OPERATION_ID_REUSE` (stesso owner, ID operazione già presente, payload/action/version differente). Per collisioni fra account restituire soltanto 409 generico, senza indizi di proprietà. La risposta tipizzata non deve contenere note, token, ID, fingerprint o dati privati. Nel client il codice tipizzato **non** deve mai attivare `resolveConflict`, rebase, ACK o scarto outbox. Sospendere AutoSync e preservare tutto il contenuto locale; il normale 409 resta compatibile con backend storici. [Runbook](docs/P2-SYNC-INTENT-CONFLICTS.md).

## Vincolo P2.4B2R — V11 richiede anche capability runtime

Non interpretare `FLYWAY_LATEST=11` come prova che il binario API sia aggiornato: `release-v11-readiness.sh` deve verificare il campo JWT `syncOperationFingerprintSchema=1` con tipo **intero**, rifiutando campo assente/stringa/bool. Il gate storico V10 rimane compatibile senza flag obbligatorio. La capability non deve esporre fingerprint, ID, body, email, JWT o payload; non deve attivare ripristino/scritture. Testare il validatore Python offline e l'API con Testcontainers. [Runbook](docs/RELEASE-V11-READINESS.md).

## Vincolo P2.4B2S — nessuna bozza utilizzabile su snapshot locale stantio

Il confronto `.snb` / inventario / worksheet è valido solo rispetto allo snapshot **locale** originariamente catturato. Prima e dopo GET inventory e POST reconciliation preflight, e prima di aprire il worksheet, ricatturare SQLite + preferenze owner-scoped e confrontare l'intera semantica inclusi tombstone, outbox, cursor, theme; ignorare solo capture timestamp e ordine righe. Qualsiasi errore, owner cambiato o differenza invalida il draft in modalità fail-closed. Non persistire il digest, non esporre titoli/body/token/owner nei riepiloghi e **non** trasformare il match in permesso di ripristino o replay. Il doppio controllo non dà atomicità cross-store o un cloud lease: nessun writer restore è autorizzato.

## Vincolo P2.4B2T — receipt di revisione non equivale ad autorizzazione

`ReconciliationReviewReceiptBuilder` è un calcolo read-only da owner + snapshots + worksheet + preflight. Non deve mai generare un permesso da `reviewComplete`: validare stessa identità, fingerprint delle sorgenti, selezioni complete e preflight coerente sull'intero inventario (limite 100). Nessun fallback a verifica parziale, nessuna persistenza delle scelte o del digest, nessun contenuto privato nel riepilogo. I getter di autorizzazione restano `false` anche in review completa. Invalidare tutte le evidenze su cambio di account, sorgente locale o revisione cloud; il preflight non riserva il server e l'outbox importata resta sempre in quarantena.

## Vincolo P2.4B2U — consenso sandbox ≠ restore live

`SandboxRestoreConsent` è un intento monouso esclusivamente per test, bound a owner e SHA-256 dei due archivi AES-GCM; richiede frase `SIMULA RIPRISTINO` e due acknowledgement. Rifiutare consenso mancante/riutilizzato, owner o byte mutati, password errata e archivio non autentico prima delle scritture di staging. `SandboxRestoreOrchestrator.create()` accetta solo `DiskRestoreRehearsal.create()` su OS temp: non importarlo in `main.dart`/bootstrap/Auth/CloudSync, non aggiungere path di produzione. Il crash recovery deve compensare e verificare i file senza azzerare il journal; non sbloccare AutoSync o replay neanche dopo rollback riuscito. Prima di una vera implementazione rimangono fsync directory, lock cross-process e atomicità tra SQLite e preferenze.
