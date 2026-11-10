# Delta Sync v1 — protocollo e storia degli incrementi

<!-- CURRENT-STATUS-REF -->
> **Stato corrente 09/11/2026:** [PR #60](https://github.com/andreadada/simple-notes/pull/60) merged `e051162`, automazioni locali crea/completa con tag/priorità/lista, un solo upsert/outbox e backup opzionale. [Flutter CI #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) **success** (392 test, Windows EXE/MSIX/recovery, Android JDK17/21), [Markdown #42714514223](https://github.com/andreadada/simple-notes/actions/runs/42714514223) **success**. Flutter `0.31.0+33`, Flyway V11 nel repo, VPS V10 verificata il 03/11, nessun deploy/restore live/E2E. Restano aperti automazioni server, OAuth provider, ACL, S3 e release gates. [Stato canonico](CURRENT-STATUS.md).


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

## P2.3A — Sorgenti ICS schema 2, ancora non sincronizzate

L'evoluzione locale degli ICS aggiunge solo `id`, `kind` ed eventuale URL di futura sottoscrizione in SharedPreferences per owner. I calendari esterni e gli eventi **non entrano** nel protocollo `/sync/apply`, non generano task, outbox, versioni remote né change log. L'import file conserva la conferma esplicita e l'isolamento del profilo. Nessun endpoint backend o schema SQL nuovo. [Specifica](P2-ICS-SOURCES.md).

## P2.3B — Ricorrenze ICS escluse da sync

Master, RRULE, date aggiuntive/escluse e override per RECURRENCE-ID appartengono soltanto a SharedPreferences locali e alla vista in sola lettura. Non producono mutation, cursor, tombstone, task o API call. [Specifica](P2-ICS-RECURRENCE.md).

## P2.3C — Feed ICS fuori dalla sync

Le richieste HTTPS avvengono dal dispositivo verso il provider ICS soltanto su richiesta esplicita; URL/cache owner-scoped non sono sincronizzati tra dispositivi e non producono outbox, mutation, task o token OAuth. [Specifica](P2-ICS-FEEDS.md).

## P2.3D — Nomi sorgenti ICS locali

`displayLabel` è salvata nelle stesse SharedPreferences ICS per owner e dispositivo; rinominarla non causa task/outbox/cursor, non chiama provider HTTPS né Simple Notes API e non sincronizza il nome sugli altri dispositivi. I master VEVENT mantengono filename/hostname originali. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## P2.4A — CSV non invia modifiche

L'azione CSV legge `AppDatabase.snapshot()` locale dopo scelta dell'utente, serializza i soli dati selezionati e non chiama backend/OAuth, non modifica cursor/outbox/versioni e non presume che tutti i dati di altri dispositivi siano sincronizzati. Diagnostica Windows recente (pending 0) e prove server V10 sono documentate separatamente, Android E2E rinviato. [CSV](P2-CSV-EXPORT.md) · [Evidenze](DEVICE-ACCEPTANCE-DEFERRED.md).

## P2.4B1 — Backup conserva outbox, non la reinvia

Il file .snb cifrato include `pending_mutations`, IDs originari, versioni remote, cursor e owner binding. Creazione/verifica backup non eseguono sync, non riscrivono SQLite, non ripristinano operazioni. Sync automatica del client può proseguire durante la cattura: le cinque tabelle sono lette in una transazione coerente, ma preferenze e SQLite non sono atomiche fra loro. Non usare un vecchio snapshot in un profilo live: occorrono in P2.4B2 blocco sync e politica anti-replay/409. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2C3 — Inventario remoto per sola consultazione

`GET /api/v1/sync/inventory` (Bearer JWT) restituisce revisioni attuali e tombstone per l'account attivo senza payload. Si ottiene in un'unica vista `REPEATABLE_READ` con cursor massimo e latest `changeId` per entità, cap 10.000 entità e fail-closed oltre soglia. Non è un token di lock, non riserva versioni e non rende sicuro un replay: il restore deve prima applicare una nuova policy di riconciliazione e verificare precondizioni ottimistiche lato server. Endpoint ancora **da rilasciare** su Coolify, nessun deploy eseguito.


## P2.4B2F — Inventory GET manuale dal confronto backup

Il client può richiedere volontariamente `/api/v1/sync/inventory` dall'UI di confronto .snb; passa il token della sessione corrente solo se non scaduto, non richiama refresh e non invoca `/sync/apply`. La risposta è metadata-only e confrontata localmente con note, liste, task e outbox dell'archivio; i risultati non sbloccano auto-sync o replay. In caso di errore, 404 o dati mancanti, resta una verifica incompleta. Il ledger non sostituisce un futuro handshake di riconciliazione con revisione attesa e CAS.


## P2.4B2G — Bozza read-only e outbox in quarantena

Il confronto a tre vie usa l'unione degli ID e le outbox dei due snapshot, inclusi record assenti dal cloud ledger. Versioni e cancellazioni incompatibili restano conflitti non risolti; quattro strategie possono essere simulate soltanto come *etichette*, non come comandi. Una parità di versioni non rimuove il gate `canResumeAutoSync=false`. Una futura riconciliazione richiede precondizioni di versione remote, deduplica e approvazione esplicita da parte dell'utente prima di qualsiasi invio. Il GET inventory non è una prenotazione di versione.

## P2.4B2I — Precondizioni di concorrenza

Il nuovo `expectedAccountCursor` è opzionale in `/sync/apply`; se fornito il confronto col massimo change ID owner-scoped è atomico rispetto alla mutazione grazie all'advisory lock già esistente. Quando due dispositivi inviano modifiche con lo stesso cursore atteso, dopo il primo commit il secondo riceve 409 senza nuove righe sync. Un retry di operation ID già applicato resta idempotente; un client legacy non è costretto a inviare il campo.

`POST /sync/reconciliation/check` consulta senza scritture un batch di massimo 100 revisioni/versioni/tombstone e il cursore owner-scoped in una transazione `REPEATABLE_READ`. Non è un lease, non garantisce l'assenza di modifiche successive e non sblocca replay di outbox importate. L'inventory GET e il preflight sono due letture distinte; le decisioni reali richiedono CAS ricontrollato al write.

## P2.4B2J — Preflight client senza sincronizzazione

Il client richiede esclusivamente su click utente una singola POST a `/sync/reconciliation/check` (operazione server read-only), con snapshot inventory precedente. Fino a 100 revisioni; se inventario è vuoto o supera 100, rifiuta la verifica completa senza inviare un batch parziale. La risposta incoerente, con owner cambiato o server non disponibile invalida la vecchia bozza del confronto. I getter `canWriteCloud`, `canResumeAutoSync` e `canReplayImportedOutbox` rimangono false anche con `consistent=true`. Nessuna operazione va inviata a `/sync/apply` da questa schermata.


## P2.4B2K — Incoerenza legacy e letture del ledger

Il preflight di riconciliazione deve fallire chiuso con 409 se una riga `note`, `task` o `task_list` dell'owner non è rappresentata da un evento coerente nel ledger. Controlla `version` e `deleted_at` sotto `REPEATABLE_READ` con query owner-scoped. Questo intercetta creazioni/aggiornamenti/cancellazioni da API legacy che non appendono `sync_change`; non cambia il comportamento di `/sync/apply` né quello dei client esistenti. Un inventory incompleto o un record mai sincronizzato non diventa automaticamente sicuro. Senza un vero protocollo di commit unico su tutte le API, resta possibile che una scrittura legacy avvenga dopo il preflight: non attivare mai un restore sulla sola base di questo check.


## P2.4B2L — Copertura owner-wide della verifica sync

Il preflight non si limita più alla lista degli ID richiesta dal client: controlla per l'intero proprietario la compatibilità tra righe reali (note/task/liste) e ultima versione/tombstone registrata nel ledger. Un record legacy mai sincronizzato, anche fuori dall'inventory, rende il controllo **409 fail-closed**. Un evento latest attivo privo della riga corrispondente è un'incoerenza. Un tombstone sintetico per entità già assente rimane rappresentabile e non blocca erroneamente l'account. Non viene inviata alcuna mutazione. Il controllo restando uno snapshot, non equivale a serializzazione dei writer legacy o a consenso per restore.


## P2.4B2M — Il lock e il ledger includono anche REST legacy

Il write-path è unificato: note e task dei vecchi endpoint passano per `SyncService.apply`, con lock advisory PostgreSQL transazionale per account, version check e evento `sync_change` scritto nella stessa transazione. Per evitare ORM stale-read, il lock viene ottenuto **prima** di caricare una nota/task da aggiornare o cancellare. Anche PATCH completion pubblica l'intero payload moderno preservando scheduled due, blocks e recurrence. Il vecchio editor completo non può sostituire una scadenza civile e conserva 426.

I retry REST non hanno un operation ID fornito dal client e ne generano uno nuovo, perciò non hanno deduplica end-to-end dopo retry di rete; resta invece l'optimistic lock sui PUT e la serializzazione per owner. I client sync continuano a usare i propri operation ID idempotenti. I record legacy storicamente non tracciati rimangono rilevabili dal controllo owner-wide e sono volutamente **non riparati automaticamente**.


## P2.4B2N — Contratto `complete=true` dell'inventory

La risposta `complete=true` indica un inventario completo **solo se** il database owner-scoped è coerente con il registro sync per presenza, versione e tombstone di note/task/liste; altrimenti HTTP 409, nessuna vista parziale. Il controllo avviene in sola lettura nello stesso snapshot repeatable-read e usa il metodo già testato dal preflight. Non copre eventuali SQL esterni senza aumento di versione o race dopo la risposta. Il client continua a richiedere consenso e guard CAS in ogni futuro write; nessuna sync/import automatico è autorizzato da `complete=true`.


## P2.4B2O — Retry sicuro e Operation ID legato al payload

Per nuovi eventi, `sync_operation.request_fingerprint` protegge dal riutilizzo accidentale dello stesso operationId con azione, versione attesa o payload diversi. Il server costruisce SHA-256 di un JSON canonico con entity ID/type, action, expectedVersion e contenuto, ignorando il cursore CAS momentaneo per conservare l'idempotenza dopo il commit. Confronto **sotto l'advisory lock** prima di ogni write. Intento diverso = 409, stessa richiesta semantica con proprietà JSON riordinate = stesso changeId/versione già applicati. L'array order resta significativo.

Per compatibilità, record `sync_operation` storici `request_fingerprint=NULL` restano deduplicati con il comportamento precedente; non esiste una prova affidabile dell'intento originario. La migrazione V11 è solo ADD COLUMN nullable: nessun backfill o cleanup. Nuovi operation ID emessi dagli endpoint REST legacy ricevono anch'essi il fingerprint lato server, ma senza chiave idempotente fornita dal client un retry HTTP di un POST create può ancora generare una nuova entità. La protezione non abilita restore/replay delle outbox importate.


## P2.4B2Q — Gestione separata per 409 d'intento immutabile

Client Flutter: soltanto il codice esplicito `SYNC_OPERATION_ID_REUSE` su `/sync/apply` viene interpretato come errore strutturale. Blocca la sincronizzazione, lascia intatti pending mutations/SQLite, non presenta la decisione conservare locale/remoto e non chiama `rebaseLocalConflict`. Gli altri 409 restano version conflicts tradizionali. Un errore d'intento non è risolvibile modificando la versione attesa e ritentando con il medesimo operation ID. [Specifica](P2-SYNC-INTENT-CONFLICTS.md).

## P2.4B2R — Capability operativa V11 e client precedenti

Il campo `syncOperationFingerprintSchema=1` segnala che l'istanza API pubblica il supporto per il fingerprint idempotente. I client preesistenti ignorano il nuovo campo senza cambi di protocollo; il gate V11 deve controllarlo per evitare un falso PASS quando DB e binario sono di versioni differenti. È un'annuncio, non una prova transazionale di un singolo retry o un'autorizzazione al restore. [Runbook](RELEASE-V11-READINESS.md).

## P2 — azioni automatiche locali e protocollo outbox

La [PR #60](https://github.com/andreadada/simple-notes/pull/60) integra azioni task sul solo evento locale di creazione/completamento. La trasformazione avviene **prima** della scrittura SQL e del normale `upsert` outbox. Il pull remoto non innesca automazioni e non crea nuove mutazioni; il server continua a imporre il normale `remoteVersion` e le risoluzioni conflitti. Le regole non sono sincronizzate: non esiste deduplica distribuita di trigger. [Specifiche](P2-TASK-ACTIONS.md).

## Catalogo cloud regole task: scambio separato da Delta Sync (PR #61 in verifica)

Il catalogo JSON owner-scoped non viene inserito nel registro sync_change dei task e non entra nella outbox SQLite. I comandi Forui **Pubblica sul cloud** e **Scarica dal cloud** richiedono un'azione esplicita e verificano account/archivio locale; il PUT usa expectedVersion, quindi in caso di 409 non può cancellare una revisione remota concorrente. Le definizioni non si trasferiscono automaticamente via polling di Delta Sync e il server non modifica né ricalcola attività. [Contratto](P2-CLOUD-ACTION-CATALOG.md).
