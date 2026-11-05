# Simple Notes API v1

<!-- CURRENT-STATUS-REF -->
> **Stato operativo 02/11/2026:** R1 gate server-first integrato su `main` ([PR #26](https://github.com/andreadada/simple-notes/pull/26), commit [`f19ee8b0`](https://github.com/andreadada/simple-notes/commit/f19ee8b0a5bea2cb2c2231d85b3e8ad10a5233a7); [Compose CI](https://github.com/andreadada/simple-notes/actions/runs/41523319857) **success** con PostgreSQL 17 sintetico, [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41523319860) **success**). Flutter resta `0.29.0+31` e 191 test già attestati. **VPS reale V10, health/capability live, backup recente e collaudo hardware non verificati**; ultimo stato VPS attestato V8. Nessun deploy o intervento su dati. [Stato](CURRENT-STATUS.md) · [R1]( RELEASE-V10-READINESS.md).


## Auth
- `POST /auth/google`: `{"idToken":"..."}` → `{accessToken,refreshToken,expiresInSeconds,userId,displayName,photoUrl?}`.
- `POST /auth/desktop/exchange`: `{"code":"...","codeVerifier":"...","redirectUri":"http://127.0.0.1:PORT/oauth/callback"}`.
- `POST /auth/refresh`: `{"refreshToken":"..."}` → sessione aggiornata (refresh token ruotato).
- `POST /auth/logout`: `{"refreshToken":"..."}` → 204, revoca.
- Google ID token convalidato server-side; claim opzionale `picture` (HTTPS Googleusercontent) salvato su utente, restituito come `photoUrl` in login/refresh; secret Desktop solo in variabili backend. Auth rate limiting da completare.

## Tasks
- `GET /tasks` — task dell'utente.
- `POST /tasks` — `{title,description,dueAt}`.
- `PUT /tasks/{id}` — `{version,title,description,dueAt,completed}` (409 se obsoleto).
- `PATCH /tasks/{id}/completion` — `{completed}` (legacy senza controllo versione).
- `DELETE /tasks/{id}` — soft delete.

## Notes
- `GET /notes` — note dell'utente.
- `POST /notes` — `{title,body}`.
- `PUT /notes/{id}` — `{version,title,body}`.
- `DELETE /notes/{id}?version=N` — soft delete.

## T2 — aggiornamento Flutter e compatibilità (24/10/2026)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Synchronization
- `POST /sync/apply` — write idempotente con `operationId`, `entityId`, `entityType`, `action`, `expectedVersion`, `payload`.
- `GET /sync/changes?cursor=N&limit=100` — delta per utente; cursor monotono.
- `GET /sync/latest?entityType=note|task|list&entityId=UUID` — ultimo stato dell'elemento, compresi tombstone, limitato all'utente del JWT; 404 su elementi altrui/mancanti. Usato nel confronto conflitti.
- `entityType=list`: upsert/delete di lista personalizzata; payload `{title,createdAt}`.
- `entityType=task` ora include `listId`, `priority`, `tags`, `subtasks` (vedi [task-organization.md](task-organization.md)); `listId` è validato rispetto all'utente JWT.
- Contratto ed esempi: [sync.md](sync.md).

**Contratto presente nel codice, V7 applicata al DB reale; disponibilità della nuova API ancora da testare:** `POST /sync/apply` supporta un oggetto `due` (`none/date/datetime/legacy`) per i task, con timezone IANA, offset DST e verifica dell'istante. Il server continua ad accettare `dueAt` per i task legacy. Il backend restituisce `due` canonico negli eventi `/sync/changes` e `/sync/latest`, mantenendo `dueAt` per compatibilità. Per non sovrascrivere le nuove scadenze, i client privi di `due` ricevono HTTP **426** + `code: CLIENT_UPGRADE_REQUIRED` quando modificano task `date/datetime`. `GET /api/v1/capabilities` autenticato restituisce `taskDueSchema: 1`. **Flutter T2 ora implementa il contratto nel codice, con capability e gestione 426**, e la migrazione V7 sul DB reale è già stata verificata, mentre capability e comportamento HTTP restano da provare. Dettagli: [due-dates-timezones.md](due-dates-timezones.md).

**Nota:** i vecchi endpoint REST non alimentano ancora il change log: per dati multi-device usare esclusivamente `/sync/apply`. Mancano rate limiting, prove di conflitto su device reali e verifica del nuovo deploy Coolify; UI Forui e test simulati aggiunti.

## Contratto P1.2 — timeBlock (versione storica, integrata su main)

**Per il payload corrente di task multi-slot e ricorrenze, vedere [P1-MULTI-BLOCKS.md](P1-MULTI-BLOCKS.md) e [P1-RECURRENCE.md](P1-RECURRENCE.md).** Il seguente schema è la forma singolo-blocco di P1.2 mantenuta per compatibilità. Su `POST /api/v1/sync/apply` per `entityType:task`, payload opzionale `timeBlock`: `{"kind":"none"}` oppure `{"kind":"range","start":"2026-10-26T08:00:00Z","end":"2026-10-26T09:30:00Z","timeZone":"Europe/Rome"}`. Il blocco è indipendente dal campo `due`. Durata 1 minuto–24h, fuso IANA valido. `GET /api/v1/capabilities` annuncia `timeBlockSchema:1` soltanto con backend V8 aggiornato. Un vecchio client senza `timeBlock` su task già pianificato riceve HTTP 426. Nuovi client non inviano upsert senza capability, preservano outbox. Dettagli: [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). Non attestare deploy.

## Aggiornamento contratto corrente (26 ottobre 2026)

Il backend presente in `main` contiene Flyway V10 e le capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` (consultare [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md)). La Matrice Eisenhower P1.8 non aggiunge endpoint/campi. Le notifiche P1.7 sono locali per dispositivo e non creano un endpoint di scheduling. La versione Flyway/capability effettivamente deployata su Coolify **deve ancora essere verificata**.

## P1.10 — Timer Pomodoro (branch, device-only)

Timer 25/5/15 e statistiche locali, identità Google isolata nelle chiavi SharedPreferences, ID sessione per impedire doppi conteggi. Nessun endpoint, outbox, SQLite/Flyway schema o sync dedicata. La CI del branch e i test device restano separati dalla compilazione di P1.9. [Specifiche](P1-POMODORO.md).

## P1.10/P1.11 — Contratto attuale (26/10/2026)

Il Pomodoro P1.10 (main) e Habit Tracker P1.11 (branch) non aggiungono API, DTO, capability o migrazioni backend. I dati restano in SharedPreferences per dispositivo e account; **non esiste endpoint di sync abitudini**, né storico Pomodoro sincronizzato. [Stato](CURRENT-STATUS.md).

## P1.12 — Nessun contratto API aggiuntivo

Countdown è device-only in SharedPreferences per account. Non esiste endpoint per eventi Countdown, push, condivisione o sincronizzazione; riutilizza il parser locale TaskDue solo lato Flutter. Backend ancora Flyway V10 nel repository, deploy reale non attestato oltre V8. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Nessuna nuova API

`weeklyTarget` è un campo **opzionale locale** del JSON Habit schema 1, default 7 per record P1.11. Nessun DTO, endpoint, Flyway, PostgreSQL, sync capability o outbox. Non dichiarare che gli obiettivi settimanali siano sincronizzati. [P1.13](P1-WEEKLY-HABITS.md).

## P1.14 — Sticky Windows non introduce API

Le finestre detached Windows non hanno backend o token propri: comunicano con il processo principale che aggiorna `LocalStore`/outbox e continua a sincronizzare note secondo il contratto esistente. Nessun endpoint e nessuna migration. [Specifica](P1-STICKY-WINDOWS.md).

## P1.15 — Tastiera UI Windows

I comandi app-local selezionano viste già presenti o invocano i metodi normali di `LocalStore` per creare una nota; nessuna API, DTO, migration Flyway/Drift, endpoint, outbox distinta o altro processo. Ctrl+Shift+T mette solo a fuoco un input. [Specifiche](P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Layout senza API o sync nuove

La griglia responsive è una proiezione della lista `LocalNote` esistente e non crea nuovi DTO, endpoint, cursor, outbox, richieste o migrazioni. La modifica di titolo/corpo usa il LocalStore già sincronizzato; cambiare larghezza schermo non invia mutazioni. [Specifica](P1-RESPONSIVE.md).

## P1.17 — Tray Windows senza server né sync nuove

Hide/restore/quit della finestra non crea entità, endpoint, migrazione, cursor, outbox o credenziali. Il LocalStore/sync già esistente rimane attivo mentre il processo main è nascosto. Il comando Esci chiude il processo; nessun secondo DB nell'engine Sticky. [P1.17](P1-WINDOWS-TRAY.md).

## P2.3A — Nessuna estensione API

Il client ICS schema 2, identificativi sorgente e distinzione file/URL sono persistiti soltanto nelle preferenze locali per account. Nessuna nuova API Spring Boot, capability, migrazione Flyway, sync outbox, endpoint o credenziale OAuth introdotta. Il gate di compatibilità backend Flyway V10 è valido per il **client cumulativo**, non è causato dalla sola P2.3A. [Specifiche](P2-ICS-SOURCES.md).

## P2.3B — Nessun nuovo endpoint

RRULE e gli override dei VEVENT vengono interpretati localmente dal client, senza DTO, API, OAuth scope, SQL/Flyway o capability aggiuntive. [Specifica](P2-ICS-RECURRENCE.md).

## P2.3C — Nessun endpoint aggiunto

I GET diretti ai provider ICS via HTTPS non sono API Simple Notes e non includono credenziali dell'app: niente nuovi DTO, capability, Flyway, backend o Cloud sync. [Specifica](P2-ICS-FEEDS.md).

## P2.3D — Nessun endpoint

Modifica etichetta sorgente, conteggi eventi e ultimo refresh sono metadati e projection client-only: nessuna API, DTO, capability, nuova Flyway o token OAuth. Il feed HTTPS continua a scaricarsi soltanto tramite gesto utente. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## R1 — Gate capacità API per client cumulativo V10

La risposta autenticata `GET /api/v1/capabilities` deve includere `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`, `noteRestoreSchema:1`, `taskDueKinds` e `requiresExplicitDueForModernTasks:true`. Il probe rigido read-only (`REQUIRE_FULL_SCHEMA=1`) fallisce senza uno di questi campi; non cambia endpoint né backend. [Runbook](RELEASE-V10-READINESS.md).

## P2.4A — Nessuna API o capability aggiuntiva

Il CSV viene generato interamente dalla SQLite locale, senza chiamate HTTP a Simple Notes, token applicativi o sincronizzazione. Il backend VPS ha Flyway V10 verificata ma la risposta capability strict autenticata non è stata attestata. [Specifica](P2-CSV-EXPORT.md) · [Evidenze](DEVICE-ACCEPTANCE-DEFERRED.md).

## P2.4B1 — Nessuna API o JWT di backup

Il backup .snb viene generato offline dal client, cifrato con password locale e verificato senza rete. Non aggiunge endpoint backend, scope Google, capability, migration PostgreSQL o upload. Le credenziali OAuth sono escluse. Il gate API strict della VPS e i test Windows↔Android restano separati e rinviati. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2C3 — GET /api/v1/sync/inventory (branch API, 04/11/2026)

Endpoint autenticato **solo GET** che restituisce l'ultima revisione conosciuta per ciascuna coppia `entityType/entityId` dell'account JWT, inclusi tombstone. Risposta `{cursor: long, items: [{entityType, entityId, version, deleted, changeId}], complete: true}`; non contiene titoli, contenuto delle note, payload task, token o operation ID. L'account è letto esclusivamente dal JWT e filtrato in SQL. Implementazione tramite transazione `REPEATABLE_READ` di sola lettura PostgreSQL e `DISTINCT ON`, cursor e righe dallo stesso snapshot transazionale. La query ha massimo 10.001 righe per bloccare (HTTP 413) gli account con oltre 10.000 entità, senza risposte parziali.

La risposta offre inventario coerente al momento della lettura, **non** una prenotazione del futuro stato server: scritture simultanee successive possono invalidare il confronto. Non è una API per ripristinare; non invia/modifica operazioni e non autorizza upload. Il client deve continuare a trattare outbox/cursor importati come non affidabili. Nessuna migrazione database nuova.


## Consumo GET inventory dall'app (P2.4B2F)

`RestoreServerInventoryReader` viene ora richiamato soltanto dopo pressione esplicita di «Consulta inventario cloud» nel dialog confronto backup. Il client usa access token **non scaduto**, controlla il medesimo account prima e dopo, accetta solo risposta completa con schema previsto e non esegue refresh/POST o altre scritture. Un backend senza l'endpoint (404) lascia il confronto soltanto locale. Inventario letto = osservazione puntuale, non autorizzazione di restore o replay; restano necessarie precondizioni lato server.

## P2.4B2I — Controllo remoto e CAS atomico (05/11/2026)

Nuovo endpoint **POST /api/v1/sync/reconciliation/check**: POST è richiesto soltanto per trasmettere l'elenco JSON e **non esegue scritture**. Contratto: `{"expectedCursor": 91, "items": [{"entityType":"note", "entityId":"UUID", "changeId":80, "version":3, "deleted":false}]}`. Fino a 100 revisioni (note, task, list), stesso owner dal JWT. Per entità non osservate nel ledger usare `changeId`, `version` e `deleted` tutti null. Risposta con `cursor`, `cursorMatches`, `consistent` e lista di revisioni osservate con `matches`; nessun titolo, body, payload o operation ID. Isolamento dell'account e snapshot PostgreSQL `REPEATABLE_READ`, lettura senza mutazioni.

`POST /api/v1/sync/apply` accetta il nuovo campo facoltativo `expectedAccountCursor` (intero >= 0). Dopo `pg_advisory_xact_lock` per owner, e dopo la gestione del retry idempotente già applicato, verifica che `MAX(sync_change.id)` dello stesso account corrisponda al cursore atteso. In caso negativo **409 Conflict prima di ogni nuova scrittura**. Rimane il controllo `expectedVersion` sul record. I client esistenti che non inviano il campo funzionano come prima. Interleaving di cambiamenti su altri account non invalida il cursore locale.

Il check read-only **non riserva** lo stato remoto: dopo la sua risposta altre richieste possono mutare i dati. Ogni futuro writer di riconciliazione dovrà portare precondizioni CAS/versione nello stesso commit e richiedere consenso. Nessuna migrazione o deploy in questa fase.

## P2.4B2J — Client opt-in per check read-only (05/11/2026)

Flutter usa il contratto `POST /api/v1/sync/reconciliation/check` solo quando l'utente preme «Ricontrolla revisioni» dopo aver consultato l'inventario cloud. **POST non significa scrittura** in questa specifica API: invia solo un JSON limitato di ID/versioni/cancellazioni e cursore, senza titoli, body, payload, preferenze o contenuti del backup. Il client valida rigorosamente HTTPS, token esistente, fino a 100 elementi completi, UUID, revisioni e risposta server esatta con ordine, ID, flag `matches` e `consistent` coerenti. Un 404 (backend non ancora deployato) o una risposta malformata non autorizzano alcuna operazione.

La risposta è soltanto un controllo istantaneo delle revisioni: server e client non creano una prenotazione né un consenso, e la UI non usa il risultato per costruire chiamate `/sync/apply`. [Specifiche](P2-FULL-BACKUP.md).


## P2.4B2K — Preflight fail-closed se i dati materializzati non corrispondono al ledger (05/11/2026)

Durante `POST /api/v1/sync/reconciliation/check`, per ogni entità richiesta il server confronta ora **versione e tombstone** della riga PostgreSQL reale (`note`, `task`, `task_list`) con l'ultimo evento `sync_change` dell'owner, oltre alle revisioni/cursor richieste dal client. Se l'evento manca ma la riga esiste, se la riga manca ma l'evento esiste, o se versione/cancellazione differiscono, restituisce **HTTP 409** senza un falso `consistent=true`. Non legge né espone body/title. Transazione `REPEATABLE_READ` in sola lettura, zero nuove tabelle/migrazioni.

Motivazione: le API legacy `/api/v1/notes` e `/api/v1/tasks` possono salvare modifiche senza scrivere nuovi eventi di sync. Il solo cursore ledger potrebbe quindi rimanere invariato anche se i dati reali sono cambiati. La guardia evita quel falso positivo. Non verifica però uguaglianza dei contenuti a parità di versione (es. SQL esterno non versionato), non copre record **non richiesti** o futuri cambiamenti dopo la risposta. Il CAS `expectedAccountCursor` su `/sync/apply` rimane limitato al percorso sync e non è un lock globale per tutte le API legacy. È vietato usare il preflight come permesso di restore.


## P2.4B2L — Integrità account completa prima del preflight (05/11/2026)

Prima di rispondere a `POST /api/v1/sync/reconciliation/check`, il server verifica, nello **stesso snapshot `REPEATABLE_READ`**, la coerenza di **tutte** le righe `note`, `task`, `task_list` dell'owner con il ledger `sync_change` (non soltanto gli ID inseriti nella richiesta). Due query per tipo cercano: (1) righe materializzate senza ultimo evento compatibile in versione/tombstone; (2) eventi latest non cancellati privi di una corrispondente riga materiale. Un evento di cancellazione sintetica senza riga è consentito perché `/sync/apply` può registrare delete su un'entità già assente. Se emerge una divergenza, HTTP 409, nessun payload o modifica.

Il controllo è owner-scoped e soltanto di lettura, con tabella da allowlist hardcoded e ID parametrizzati; non richiede una migrazione. Può rilevare record legacy **non visibili nell'inventario** e non inclusi fra i max 100 ID del preflight. Restano limiti importanti: non fa il confronto integrale dei contenuti (titoli/body) se le versioni coincidono, non previene nuove scritture legacy appena dopo la lettura e non sostituisce un lock globale per i futuri restore.


## P2.4B2M — Endpoint REST legacy sincronizzati (05/11/2026)

I vecchi endpoint `/api/v1/notes` (POST, PUT, DELETE) e `/api/v1/tasks` (POST, PUT, PATCH completion, DELETE) ora **delegano al medesimo `SyncService.apply`** usato da Flutter. Le mutazioni non saltano più il ledger: un singolo commit PostgreSQL comprende riga materializzata, evento `sync_change` e record di idempotenza `sync_operation`. Gli endpoint, request/response legacy e isolamento JWT rimangono invariati; ogni chiamata REST genera un proprio operation ID server-side.

Per update/delete/completion, il service **acquisisce il lock advisory per owner prima di leggere il record**, quindi applica il confronto di versione sotto lo stesso lock. Un conflitto concorrente provoca 409 invece di un overwrite silenzioso. Le note cancellate non vengono risuscitate da un PUT. Gli update REST di task continuano a rifiutare civil due `date`/`datetime` (426). Il PATCH completion, invece, invia un payload canonico che preserva due, timeBlocks, recurrence, lista, priority, tags e subtasks. Qualsiasi mutazione legacy è quindi visibile in `GET /sync/changes` e invalida correttamente il cursore opzionale `expectedAccountCursor`.

**Attenzione:** dati già scritti in passato fuori dal registro non vengono migrati o cancellati. Il fail-closed owner-wide del preflight rimane necessario contro righe storiche discordanti o scritture SQL esterne. Nessuna migrazione DB richiesta, nessun deploy eseguito.


## P2.4B2N — Inventory GET fail-closed sull'integrità dell'account (05/11/2026)

Anche `GET /api/v1/sync/inventory` esegue ora la verifica già prevista da `/sync/reconciliation/check` di **tutte** le note, attività e liste materializzate contro il più recente evento per proprietario, dentro lo stesso snapshot PostgreSQL `REPEATABLE_READ`. Non può più inviare `complete=true` quando il ledger omette dati legacy, quando una riga è stata aggiornata fuori protocollo o quando il latest event segnala un'entità attiva fisicamente assente. Per una discrepanza risponde HTTP 409 senza dati riservati. Un tombstone sintetico senza riga resta valido. Nessun endpoint, schema, migration o response JSON modificato.

I client Flutter che interrogano inventario gestiscono già gli errori 409 come non verificabile e **non** proseguono con il restore. Il controllo non garantisce assenza di future modifiche, contenuti identici a parità di versione, né corregge i dati storici. Non è un'operazione di backfill e non richiede reset.
