# Simple Notes

App Windows 11 + Android per **task, note e produttività**, ispirata all'organizzazione di TickTick, con interfaccia originale.

**Stack:** Flutter · Drift/SQLite · Spring Boot · PostgreSQL · Docker/Coolify.

**Stato:** P0 in corso. Backend Spring Boot su Coolify accessibile in HTTPS (`/actuator/health` = `UP`); client Windows e Google Login desktop avviati/testati manualmente. App Android e sync PC↔Android non ancora verificate. Sync manuale sperimentale; non pronta per un rilascio produttivo senza hardening e backup.

- [project.md](project.md) — fasi P0–P3, checklist, regole e `Edit Timespan`
- [design.md](design.md) — specifiche UI/UX e tutte le funzionalità previste
- [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — API e sincronizzazione
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth
- [infra/README.md](infra/README.md) — avvio backend e Coolify (`/docker-compose.yml`)

**Build di sviluppo:** GitHub → Actions → Flutter CI → Artifacts.
