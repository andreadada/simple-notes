# Delta Sync v1 — protocollo e storia degli incrementi

<!-- CURRENT-STATUS-REF -->
> **Stato coerente con repository:** P1.6 (ricorrenze, Flyway V10/Drift V8) integrata in `main`; P1.7 promemoria solo foundation su branch, **senza OS scheduler operativo**. Ultimo server verificato V8, V9/V10 da verificare prima di aggiornare i client. [Versioni e gate attuali](CURRENT-STATUS.md). I riferimenti precedenti nel documento costituiscono storico.


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
