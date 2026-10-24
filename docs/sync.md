# Delta Sync v1 (P0 in sviluppo)

> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

**Autenticazione:** Bearer JWT Simple Notes.

### Write
`POST /api/v1/sync/apply`

```json
{
  "operationId": "UUID-stabile-per-retry",
  "entityType": "task",
  "entityId": "UUID-scelto-dal-client",
  "action": "upsert",
  "expectedVersion": null,
  "payload": {"title":"Comprare pane", "completed":false, "dueAt":null}
}
```

Per note: `entityType:note`, payload `{"title":"...", "body":"..."}`.
Per cancellare: `action:delete`, `expectedVersion` dalla versione remota nota.

Risposta `{"operationId":"...","version":0,"changeId":1}`. Retry con lo stesso `operationId` non duplica l'operazione. `409` per conflitto di versione. Non usare endpoint REST legacy per sync.

### Read
`GET /api/v1/sync/changes?cursor=0&limit=100` (limit 1..200).
Ritorna `changes[]` con `changeId,entityType,entityId,payload,deleted,version`, più `nextCursor,hasMore`.

**Concorrenza:** advisory lock PostgreSQL per account serializza le mutazioni sync e garantisce ordine stabile degli identificativi di change per singolo utente. Tutte le scritture devono passare da questo percorso affinché il delta sia completo.

**Stato attuale:** il client Flutter implementa invio sequenziale dell'outbox, ack e pull delta per cursor in `apps/flutter/lib/sync/cloud_sync.dart`; `app_database.dart` gestisce owner e versioni locali. È **auto-sync foreground**, con sync manuale di fallback: l'utente ha confermato note PC↔Android e attività Android→Windows. I 409 preservano l'outbox; ora esiste una UI di risoluzione Forui, ma va provata su due dispositivi reali. Rimangono integrazione endpoint REST legacy/change log, conflitti su cancellazioni, rebootstrap, background e compattazione.

### Diagnostica note multi-device (23/10/2026)

- Verificare che **entrambi** i client siano aggiornati e autenticati con lo stesso ID utente dell'API, non solo con la stessa etichetta visualizzata.
- Per una nota con titolo vuoto, il backend accetta il valore e la UI mostra `Senza titolo`: prima la richiesta poteva restituire HTTP 400 e bloccare l'outbox.
- Usare lo stato sincronizzazione dal menu account anche su Android: dettagli upload/download, operazioni ancora in coda, messaggi HTTP. Un `409` non cancella la coda.
- Test backend `noteCreatedOnDeviceAIsVisibleToDeviceBAndCanBeEdited`: create blank title → delta pull → update → delta pull. **Non sostituisce un test con 2 telefoni/PC reali.**

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
