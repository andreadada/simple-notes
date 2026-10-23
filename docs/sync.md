# Delta Sync v1 (P0 in sviluppo)

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

## Prossima estensione date-only / timezone (solo piano)

Il campo `dueAt` attuale è un istante UTC e non preserva il significato di un *giorno civile* o la differenza tra `00:00` esplicita e «solo giorno». Prima delle ricorrenze è progettato un nuovo campo `due` con `none/date/datetime/legacy`, migrazioni additive e protezione contro client vecchi. Vedi [due-dates-timezones.md](due-dates-timezones.md). Flyway V7/Drift v5 **non** sono ancora implementati; non cambiare i payload senza relativo version gating.

## Organizzazione attività — sync v1 estesa

- `entityType: list`: stessa struttura di `/sync/apply` (`operationId` UUID, `entityId` UUID, `action=upsert|delete`, `expectedVersion`), con payload `{title,createdAt}` per gli upsert. Il server valida owner e versioni. `/sync/changes` trasporta anche create/update/delete/tombstone delle liste; `/sync/latest` accetta `entityType=list`.
- `entityType: task` aggiunge nel payload: `listId: UUID|null`, `priority: 0..3`, `tags: string[]`, `subtasks: [{id:UUID,title:string,completed:bool}]`. I vecchi payload senza campi continuano a essere validi (valori di default).
- Il backend impedisce riferimenti cross-account `listId` con HTTP 400 e rifiuta con 409 l'eliminazione di una lista ancora contenente task. Il client sposta prima i task in Inbox poi cancella la lista; le operazioni vengono registrate con timestamp monotoni anche durante un burst offline.
- Conflitti: la lista è una entità con revisione propria; le modifiche ai sottotask appartengono alla versione dell'intero task, non hanno merge automatico per campo.

Per dettagli, limiti e sequenza di deploy: [task-organization.md](task-organization.md).
