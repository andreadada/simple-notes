# Simple Notes

App Windows 11 + Android per **task, note e produttività**, ispirata all'organizzazione di TickTick, con interfaccia originale.

**Stack:** Flutter · Drift/SQLite · Spring Boot · PostgreSQL · Docker/Coolify.

**Stato:** P0 in corso. Task/note locali, login Google nel codice e sync manuale sperimentale. Non è pronta per uso produttivo o deploy pubblico.

- [project.md](project.md) — fasi P0–P3, checklist, regole e `Edit Timespan`
- [design.md](design.md) — specifiche UI/UX e tutte le funzionalità previste
- [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — API e sincronizzazione
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth
- [infra/README.md](infra/README.md) — avvio backend e Coolify

**Build di sviluppo:** GitHub → Actions → Flutter CI → Artifacts.
