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

**Stato attuale:** il client Flutter implementa invio sequenziale dell'outbox, ack e pull delta per cursor in `apps/flutter/lib/sync/cloud_sync.dart`; `app_database.dart` gestisce owner e versioni locali. È **sincronizzazione manuale sperimentale**, senza prova E2E su Windows↔Android. Gli errori 409 preservano le operazioni locali ma **non** esiste ancora una UI di risoluzione. Da completare: test isolamento profili/rebootstrap multi-device, integrazione endpoint REST legacy col change log, compattazione, recupero conflitti, retry/background/auto-sync.
