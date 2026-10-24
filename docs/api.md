# Simple Notes API v1

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

Test introdotti per data-only, ora legale, due database, fallback server, outbox e migrazione SQLite v4 già popolato → v5. **Risultati CI e prove real-device vanno verificati**, il codice GitHub non implica deployment. T3 (UI Forui con scelta esplicita, timezone IANA e DST) resta da realizzare. Flyway V7 non è stato distribuito su Coolify, necessario backup/restore reale prima del rollout. Flutter Web non ancora supportato.

## Synchronization
- `POST /sync/apply` — write idempotente con `operationId`, `entityId`, `entityType`, `action`, `expectedVersion`, `payload`.
- `GET /sync/changes?cursor=N&limit=100` — delta per utente; cursor monotono.
- `GET /sync/latest?entityType=note|task|list&entityId=UUID` — ultimo stato dell'elemento, compresi tombstone, limitato all'utente del JWT; 404 su elementi altrui/mancanti. Usato nel confronto conflitti.
- `entityType=list`: upsert/delete di lista personalizzata; payload `{title,createdAt}`.
- `entityType=task` ora include `listId`, `priority`, `tags`, `subtasks` (vedi [task-organization.md](task-organization.md)); `listId` è validato rispetto all'utente JWT.
- Contratto ed esempi: [sync.md](sync.md).

**Contratto backend introdotto nel codice, NON distribuito su Coolify:** `POST /sync/apply` supporta un oggetto `due` (`none/date/datetime/legacy`) per i task, con timezone IANA, offset DST e verifica dell'istante. Il server continua ad accettare `dueAt` per i task legacy. Il backend restituisce `due` canonico negli eventi `/sync/changes` e `/sync/latest`, mantenendo `dueAt` per compatibilità. Per non sovrascrivere le nuove scadenze, i client privi di `due` ricevono HTTP **426** + `code: CLIENT_UPGRADE_REQUIRED` quando modificano task `date/datetime`. `GET /api/v1/capabilities` autenticato restituisce `taskDueSchema: 1`. **Flutter T2 ora implementa il contratto nel codice, con capability e gestione 426**, e nessuna migrazione Coolify è stata verificata. Dettagli: [due-dates-timezones.md](due-dates-timezones.md).

**Nota:** i vecchi endpoint REST non alimentano ancora il change log: per dati multi-device usare esclusivamente `/sync/apply`. Mancano rate limiting, prove di conflitto su device reali e verifica del nuovo deploy Coolify; UI Forui e test simulati aggiunti.
