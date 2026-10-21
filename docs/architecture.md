# Architettura — stato reale

- Flutter Android/Windows: layout adattivo e Riverpod, task/note locali in Drift/SQLite, migrazione da SharedPreferences.
- Outbox SQLite in transazioni; sync manuale verso `/api/v1/sync/apply` con operazioni idempotenti, then pull delta con cursor.
- Spring Boot Java 21, PostgreSQL, Flyway, REST OAuth Google, refresh session hashate/ruotate, versioning per task/note.
- Delta sync backend serializzato per utente su PostgreSQL. Conflitti 409 **non sovrascritti**: UI risolutiva ancora da fare.
- Login Android `google_sign_in`; Windows system browser, loopback+PKCE, exchange server-side. Login reale da configurare/testare.
- Sync manuale soltanto: non ancora auto-sync, recovery completo, change log per vecchie rotte REST e risoluzione conflitti visuale.
- Coolify, notifiche Android/Windows, Docker release hardening, backup restore sono ancora WIP.
- Roadmap e gate: [../project.md](../project.md); design: [../design.md](../design.md).
