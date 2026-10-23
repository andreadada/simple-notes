# Architettura — stato reale

- Flutter Android/Windows: layout adattivo e Riverpod, task/note locali in Drift/SQLite, migrazione da SharedPreferences.
- Outbox SQLite in transazioni; sync manuale verso `/api/v1/sync/apply` con operazioni idempotenti, then pull delta con cursor.
- Spring Boot Java 21, PostgreSQL, Flyway, REST OAuth Google, refresh session hashate/ruotate, versioning per task/note.
- Delta sync backend serializzato per utente su PostgreSQL. Conflitti 409 **non sovrascritti**: UI risolutiva ancora da fare.
- Login Android `google_sign_in`; Windows system browser, loopback+PKCE, exchange server-side. Windows OAuth Google reale verificato dall'utente; Android avviato sul telefono, ma login OAuth Android dopo gli ultimi fix ancora da verificare distintamente.
- Sync manuale soltanto: non ancora auto-sync, recovery completo, change log per vecchie rotte REST e risoluzione conflitti visuale.
- API Coolify deployata, dominio HTTPS health `UP` confermato dall'utente. Notifiche Android/Windows, hardening release, backup/restore sono ancora WIP.
- Roadmap e gate: [../project.md](../project.md); design: [../design.md](../design.md).

- Per nuovo contributore/assistente AI: [HANDOFF.md](HANDOFF.md), [android-troubleshooting.md](android-troubleshooting.md) e [../AGENTS.md](../AGENTS.md).
