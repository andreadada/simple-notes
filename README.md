# Simple Notes

App Windows 11 + Android per **task, note e produttività**, ispirata alle funzionalità di TickTick con interfaccia originale.

**Stack:** Flutter + Riverpod + Drift/SQLite (offline-first); Spring Boot Java 21 + PostgreSQL/Flyway; Docker Compose/Coolify; Google OAuth Windows/Android.

## Stato effettivo — 23 ottobre 2026

**P0 in corso, non pronto per il rilascio.** API su `https://api.notes.ddone.it` con health `UP` confermato dall'utente. Windows e login Google Desktop verificati; app Android segnalata funzionante sul telefono dopo fix Gradle/JVM. **Login Google Android dopo gli ultimi fix e sync Windows↔Android non sono ancora verificati esplicitamente.** È stata implementata **auto-sync foreground sperimentale** con outbox, retry/backoff e pull ogni 60 s, non ancora verificata end-to-end.

Ultima pipeline verificata: [Flutter CI 39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440) — **successo** di Android JDK 17/21, Windows, analisi e test. Questo **non** certifica il login o la sincronizzazione reali.

## Da dove iniziare

- **[docs/HANDOFF.md](docs/HANDOFF.md)** — leggere per primo entrando in una nuova chat/sessione; stato, setup, problemi risolti e prossimi test.
- **[AGENTS.md](AGENTS.md)** — istruzioni per assistenti AI/Codex (criteri di verifica e workflow).
- [project.md](project.md) — roadmap P0–P3, checklist, registro `Edit Timespan`.
- [design.md](design.md) — requisiti UI/UX e funzionalità obiettivo; non tutte implementate.
- [docs/architecture.md](docs/architecture.md) · [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — architettura e contratti.
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth.
- [docs/android-troubleshooting.md](docs/android-troubleshooting.md) — Kotlin/Gradle JDK 17/21, Google OAuth Android, ADB e installazione USB.
- [infra/README.md](infra/README.md) — Compose Coolify, ambiente backend e sicurezza.

**Novità P0:** avatar Google con menu account unico (Accedi, Sincronizza ora, Esci), invece di due pulsanti; la foto è fornita dal backend dopo redeploy Coolify. **Prossimo passo:** confermare il login Google Android, poi test reale dell'auto-sync delle attività/note fra Windows e Android con lo stesso account, anche offline. Per build e comandi usare [docs/HANDOFF.md](docs/HANDOFF.md).
