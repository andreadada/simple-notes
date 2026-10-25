# Simple Notes API v1

## P1.4 — Multi-block e riepilogo focus (25/10/2026)

**Branch in sviluppo `feature/p1-4-multi-blocks-batch`, NON ancora su `main`, NON deployato su Coolify.** Flutter `0.8.0+10`; backend Flyway V9, Drift V7, fino a 12 slot per attività con ID stabili; CRUD/pannello Forui, copia slot, drag mirato e riepilogo pianificate/completate. Compatibilità protetta con `timeBlocksSchema:1` / 426 su client V8 incapaci di salvare il multi-block. Il server attualmente installato dall'utente rimane Flyway V8 e il client effettivo non è stato aggiornato a V0.8. Niente reset/dati persi e **collaudo dispositivi rimandato a fine batch**. [Specifiche](P1-MULTI-BLOCKS.md).


> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

Base URL `/api/v1`. Per endpoint privati: header `Authorization: Bearer <accessToken>`.

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

## Protocollo P1.2 — timeBlock (proposto su branch feature)

Su `POST /api/v1/sync/apply` per `entityType:task`, payload opzionale `timeBlock`: `{"kind":"none"}` oppure `{"kind":"range","start":"2026-10-26T08:00:00Z","end":"2026-10-26T09:30:00Z","timeZone":"Europe/Rome"}`. Il blocco è indipendente dal campo `due`. Durata 1 minuto–24h, fuso IANA valido. `GET /api/v1/capabilities` annuncia `timeBlockSchema:1` soltanto con backend V8 aggiornato. Un vecchio client senza `timeBlock` su task già pianificato riceve HTTP 426. Nuovi client non inviano upsert senza capability, preservano outbox. Dettagli: [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). Non attestare deploy.
