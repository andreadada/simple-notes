# Delta Sync v1 — protocollo e storia degli incrementi

<!-- CURRENT-STATUS-REF -->
> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`; Flutter CI verde: **162 test**, Windows EXE/MSIX, Android JDK17/21, Markdown). Collaudo fisico e deploy cumulativo non attestati. Backend repo Flyway V10; ultima VPS verificata V8, nessun reset/deploy. [Stato](CURRENT-STATUS.md) · [ICS](P2-ICS.md).


## Ultima versione di un elemento / risoluzione conflitto (P0)

`GET /api/v1/sync/latest?entityType=task|note&entityId=UUID`: autenticazione JWT obbligatoria. Filtra per `owner_id` corrente, tipo e ID; restituisce `{entityType,entityId,payload,deleted,version,changeId}` con ultima versione/tombstone, oppure 404. Indice Flyway V5; non rivela dati di altri utenti.

Quando una mutazione riceve 409, il client conserva **tutte** le modifiche in coda e confronta il contenuto del dispositivo con l'ultima versione server. Nel menu avatar compare `Risolvi conflitto`, che apre un FDialog. Due scelte:

- **Tieni locale:** recupera la versione server un'altra volta e imposta `remoteVersion`; ripete l'invio con la verifica della versione. Nuovi conflitti restano bloccanti. Non forza il ripristino di una entità già eliminata sul server.
- **Usa server:** richiede una seconda conferma; elimina **soltanto** le operazioni locali dell'elemento e applica l'ultima versione remota, non azzera altri dati.

Per i test: `apps/flutter/test/sync_conflict_test.dart` copre note concorrenti PC/telefono simulati, retry offline, entrambe le risoluzioni. `SyncIntegrationTest` verifica query latest e isolamento per account. Il protocollo mantiene limitazioni per la risoluzione di delete-vs-edit, da trattare con copia/recupero in una nuova UUID.

## T2 — aggiornamento Flutter e compatibilità (24/10/2026)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Estensione date-only / timezone (T1 codice, DB V7 verificato, API da collaudare)

Il campo `due` è ora supportato nel **codice backend**: `{kind:none}`, `{kind:date,date:YYYY-MM-DD}`, `{kind:datetime,date,time,timeZone,instant,offsetSeconds}`, `{kind:legacy,instant}`. Viene validato contro le regole IANA e restituito come payload canonico anche nei delta e nel latest. `dueAt` è conservato per gli istanti legacy e timed, ed è nullo/vuoto per date-only. Vecchi client senza `due` non possono sovrascrivere date/datetime: HTTP 426 con `CLIENT_UPGRADE_REQUIRED`, **non** un normale 409. `GET /api/v1/capabilities` richiede JWT e presenta `taskDueSchema: 1`. **Drift v5 e gestione 426/capability presenti nel client; migrazione PostgreSQL reale e deploy Coolify non ancora eseguiti.** Vedere [due-dates-timezones.md](due-dates-timezones.md).

## Organizzazione attività — sync v1 estesa

- `entityType: list`: stessa struttura di `/sync/apply` (`operationId` UUID, `entityId` UUID, `action=upsert|delete`, `expectedVersion`), con payload `{title,createdAt}` per gli upsert. Il server valida owner e versioni. `/sync/changes` trasporta anche create/update/delete/tombstone delle liste; `/sync/latest` accetta `entityType=list`.
- `entityType: task` aggiunge nel payload: `listId: UUID|null`, `priority: 0..3`, `tags: string[]`, `subtasks: [{id:UUID,title:string,completed:bool}]`. I vecchi payload senza campi continuano a essere validi (valori di default).
- Il backend impedisce riferimenti cross-account `listId` con HTTP 400 e rifiuta con 409 l'eliminazione di una lista ancora contenente task. Il client sposta prima i task in Inbox poi cancella la lista; le operazioni vengono registrate con timestamp monotoni anche durante un burst offline.
- Conflitti: la lista è una entità con revisione propria; le modifiche ai sottotask appartengono alla versione dell'intero task, non hanno merge automatico per campo.

Per dettagli, limiti e sequenza di deploy: [task-organization.md](task-organization.md).

## P1.2 — protezione dei blocchi orari

Il task serializza `timeBlock` come `kind:none|range` con `start/end` UTC e `timeZone` IANA. Qualsiasi task upsert nuovo verifica prima `timeBlockSchema:1` via API capabilities; fallimento conserva la coda. Il server, dopo Flyway V8, rifiuta con 426 aggiornamenti legacy privi di `timeBlock` se l'entità ha un blocco esistente. La scadenza `due` non è collegata al blocco. [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md).

## Compatibilità degli incrementi correnti (26 ottobre 2026)

P1.7 (notifiche Android/Windows MSIX) usa planner e ledger locali, senza schema di sincronizzazione. P1.8 (Matrice Eisenhower) legge campi task esistenti `priority` e `due`, modificandoli esclusivamente tramite `LocalStore` e outbox; nessuna nuova migrazione. Prima di un client Flutter 0.13, il backend reale deve avere Flyway V10 e le capability in [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md). Per stato CI/distribuzione vedere [CURRENT-STATUS.md](CURRENT-STATUS.md).

## P1.10 — Timer Pomodoro (branch, device-only)

Timer 25/5/15 e statistiche locali, identità Google isolata nelle chiavi SharedPreferences, ID sessione per impedire doppi conteggi. Nessun endpoint, outbox, SQLite/Flyway schema o sync dedicata. La CI del branch e i test device restano separati dalla compilazione di P1.9. [Specifiche](P1-POMODORO.md).

## P1.11 — Nessuna sync abitudini

Habit Tracker resta device-only per account (SharedPreferences con schema 1 e check-in per data civile). Non invia `habit` a `/sync/apply`, non tocca cursor, versioni, outbox, liste/task. Non promettere coerenza del tracker Windows↔Android; una futura versione server richiederà schema, modello conflitti e test dedicati. [Specifica](P1-HABITS.md).

## P1.12 — Countdown non sincronizzato

Gli eventi Countdown non sono entità task, non entrano nei payload `/sync` né nella outbox, non producono cursor né capability. Restano locali a ogni installazione per account Google, così come Pomodoro e Habit Tracker. Non descrivere i Countdown come sincronizzati tra PC e telefono. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Weekly Habit sempre locale

Il target settimanale e lo streak derivano dai check-in locali, **non** sono inviati a `/sync/apply` o a PostgreSQL, non hanno `baseVersion`, cursor o outbox. JSON esistente P1.11 compatibile grazie al default 7 del campo opzionale. Non promettere sync PC↔Android per Habit. [P1.13](P1-WEEKLY-HABITS.md).

## P1.14 — Sticky Notes Windows

Finestre Flutter separate senza Drift/SQLite proprio: via method channel leggono e aggiornano le note esistenti nel main engine, che conserva ID, outbox, conflitti e sync. La guardia contro valori stale evita sovrascritture silenziose; nessuna migration/API nuova. [Specifica](P1-STICKY-WINDOWS.md).

## P1.15 — Tastiera UI Windows

I comandi app-local selezionano viste già presenti o invocano i metodi normali di `LocalStore` per creare una nota; nessuna API, DTO, migration Flyway/Drift, endpoint, outbox distinta o altro processo. Ctrl+Shift+T mette solo a fuoco un input. [Specifiche](P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Layout senza API o sync nuove

La griglia responsive è una proiezione della lista `LocalNote` esistente e non crea nuovi DTO, endpoint, cursor, outbox, richieste o migrazioni. La modifica di titolo/corpo usa il LocalStore già sincronizzato; cambiare larghezza schermo non invia mutazioni. [Specifica](P1-RESPONSIVE.md).

## P1.17 — Tray Windows senza server né sync nuove

Hide/restore/quit della finestra non crea entità, endpoint, migrazione, cursor, outbox o credenziali. Il LocalStore/sync già esistente rimane attivo mentre il processo main è nascosto. Il comando Esci chiude il processo; nessun secondo DB nell'engine Sticky. [P1.17](P1-WINDOWS-TRAY.md).

## P2.1 — Import JSON portabile e outbox

Importare dati tramite `LocalStore.importPortable` crea nuove UUID per liste, task e note, preservando riferimenti task/lista e sottotask/slot; le operazioni SQLite generano gli stessi upsert versionati e l'ordinamento lista→task→note del flusso standard. Non importa operationId, remoteVersion, owner, sync cursor o tombstone di altri dispositivi. No endpoint o capability nuovi; server V10 obbligatorio per i campi P1. [Specifica](P2-PORTABLE-ARCHIVE.md).


## P2.2 — Eventi ICS mai sincronizzati

L'import ICS legge un file locale, non invia alcuna richiesta cloud, non crea entityType, outbox, UUID di task, cursor o metadata di versioning. Cambio account cambia la chiave SharedPreferences e nasconde subito gli eventi dell'owner precedente. Dati app e API V10 invariati. [Specifica](P2-ICS.md).

