# API v1 — preliminary

**Auth:** `POST /api/v1/auth/google` body `{"idToken":"<Google ID token>"}` -> app Bearer JWT (15-minute TTL).
Google public JWKS validates ID-token signature, `iss`, `aud`, expiry. Only configured `GOOGLE_CLIENT_IDS` are accepted. Android must use native Google login; Windows must use system browser with OAuth PKCE.

**Tasks** (required header `Authorization: Bearer <app JWT>`):
- `GET /api/v1/tasks` — user-owned tasks only.
- `POST /api/v1/tasks` — `{"title":"...", "description":null, "dueAt":null}`.
- `PATCH /api/v1/tasks/{uuid}/completion` — `{"completed":true}`.
- `DELETE /api/v1/tasks/{uuid}` — soft-delete (204).

**Current limitations:** No refresh/session revocation, lists/notes endpoints, task edit endpoint, offline delta-sync or device notifications. DO NOT deploy publicly before TLS, rate limiting, auth flow verification and tests.

**Health:** `GET /actuator/health` (database + application).
