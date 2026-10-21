# Architettura — sintesi (P0)

- Flutter Windows 11 / Android, UI adattiva e Riverpod. In P0 solo prototipo locale SharedPreferences; la migrazione a Drift/SQLite è obbligatoria prima di sync/release.
- Spring Boot Java 21 + PostgreSQL + Flyway, REST `/api/v1`; nessuna esposizione diretta del DB.
- Google ID token validato lato backend via JWKS + issuer + audience; API JWT HMAC, TTL 15 minuti. **Refresh, revoca e PKCE lato client ancora da implementare.**
- Task API: lista, creazione, completamento, soft delete; utenti isolati tramite UUID derivato dal token.
- Futuro offline-first: SQLite/Drift, outbox, idempotency key, versioni server, delta cursor, tombstone, conflitti non distruttivi.
- WebSocket solo per invalidazione cache; FCM Android e scheduling locale dei reminder.
- Non introdurre Redis/Kafka fino a necessità misurata.
- CI: unit test API + PostgreSQL Testcontainers, widget test Flutter, Windows release build; Android debug APK in pipeline.
- Roadmap e regole: `../project.md`.
