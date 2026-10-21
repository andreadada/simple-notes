# Simple Notes API v1

Base URL: `/api/v1`. JSON/HTTPS. Routes private richiedono `Authorization: Bearer <accessToken>`.

## Auth
- `POST /auth/google`: `{"idToken":"<Google ID token>"}` → `{"accessToken","refreshToken","expiresInSeconds","userId","displayName"}`.
- `POST /auth/refresh`: `{"refreshToken":"..."}` → stessa risposta, con **rotazione** del refresh token.
- `POST /auth/logout`: `{"refreshToken":"..."}` → HTTP 204, revoca la sessione.
- ID token Google verificato per `iss`, `aud`, firma e scadenza; sessioni per account e refresh token salvato *hashato*.
- Restano da fare: rate limit, device identity, audit, logout all devices, flow OAuth completo nei client.

## Tasks
- `GET /tasks` → task attivi del solo utente.
- `POST /tasks` → `{"title":"...","description":null,"dueAt":null}` (201).
- `PUT /tasks/{id}` → `{"version":0,"title":"...","description":null,"dueAt":null,"completed":false}`.
- `PATCH /tasks/{id}/completion` → `{"completed":true}`.
- `DELETE /tasks/{id}` → 204 (tombstone logica).
- Versione obsoleta su PUT → 409. PATCH legacy ancora privo di version guard: non usare per offline sync.

## Notes
- `GET /notes` → note dell'utente.
- `POST /notes` → `{"title":"...","body":"..."}`.
- `PUT /notes/{id}` → `{"version":0,"title":"...","body":"..."}`.
- `DELETE /notes/{id}?version=0` → 204.
- Versione obsoleta → 409. L'API usa owner verificato sul server, non dal payload.

## Stato
API REST con ownership e concorrenza **parziale**. Delta sync, UUID scelti dal client, idempotency key, refresh session scadute e GDPR delete da implementare prima di produzione.
