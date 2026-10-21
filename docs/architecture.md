# Architettura — decisioni iniziali

- Un client Flutter con UI adattiva Windows/Android e SQLite locale.
- REST per lettura/scrittura; delta sync per cursor e outbox persistente. WebSocket solo per invalidation.
- Spring Boot monolite modulare, PostgreSQL + Flyway.
- OAuth/OIDC Google: Android Credential Manager; Windows browser + PKCE; sessione app gestita dal server.
- FCM Android + scheduling locale; Windows native notifications; limite delle app chiuse/spente esplicitato.
- Regole Sync: UUID client, operation ID idempotente, revisione server, tombstone, conflitto non distruttivo.
- Nessuna dipendenza Redis/Kafka prevista prima di una misurazione.
- Checklist vincolante: `../project.md`.
