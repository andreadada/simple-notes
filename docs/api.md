# Simple Notes API v1

Base URL `/api/v1`. Per endpoint privati: header `Authorization: Bearer <accessToken>`.

## Auth
- `POST /auth/google`: `{"idToken":"..."}` → `{accessToken,refreshToken,expiresInSeconds,userId,displayName}`.
- `POST /auth/desktop/exchange`: `{"code":"...","codeVerifier":"...","redirectUri":"http://127.0.0.1:PORT/oauth/callback"}`.
- `POST /auth/refresh`: `{"refreshToken":"..."}` → sessione aggiornata (refresh token ruotato).
- `POST /auth/logout`: `{"refreshToken":"..."}` → 204, revoca.
- Google ID token convalidato server-side; secret Desktop solo in variabili backend. Auth rate limiting da completare.

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

## Synchronization
- `POST /sync/apply` — write idempotente con `operationId`, `entityId`, `entityType`, `action`, `expectedVersion`, `payload`.
- `GET /sync/changes?cursor=N&limit=100` — delta per utente; cursor monotono.
- Contratto ed esempi: [sync.md](sync.md).

**Nota:** i vecchi endpoint REST non alimentano ancora il change log: per dati multi-device usare esclusivamente `/sync/apply`. Mancano rate limiting, UI di conflitto, resilienza E2E e verifica deploy.
