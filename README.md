# Simple Notes

App di **task, note e produttività** per **Windows 11 e Android**, con interfaccia originale ispirata all'organizzazione di TickTick.

- **Client:** Flutter, offline-first
- **Backend:** Spring Boot + PostgreSQL, self-hosted su Coolify
- **Account:** Google Login; sincronizzazione PC ↔ telefono
- **Stato:** P0 in sviluppo. Non ancora adatta alla produzione.

**Documentazione**
- [project.md](project.md) — roadmap P0–P3, checklist, cosa fare/non fare e storico commit
- [design.md](design.md) — UX/UI, funzionalità, modelli e scelte tecniche
- [docs/api.md](docs/api.md) — API
- [infra/README.md](infra/README.md) — avvio locale e Coolify
- [apps/flutter/README.md](apps/flutter/README.md) — build client

Le CI producono APK Android e build Windows nella pagina **GitHub Actions → Flutter CI → Artifacts**. Login, sincronizzazione e notifiche saranno rilasciati solo dopo i rispettivi test.
