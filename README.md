# Simple Notes

App Windows 11 + Android per **task, note e produttività**, ispirata alle funzionalità di TickTick con interfaccia originale.

**Stack:** Flutter + **Forui (design system)** + Riverpod + Drift/SQLite (offline-first); Spring Boot Java 21 + PostgreSQL/Flyway; Docker Compose/Coolify; Google OAuth Windows/Android.

## Stato effettivo — 23 ottobre 2026

**P0 in corso: non pronto per il rilascio pubblico.** Liste, priorità, tag e sottotask implementati nel codice con backend/Flyway V6 e Flutter/Drift v4; test automatizzati riusciti, verifica su dispositivi reali ancora aperta. I titoli delle liste sono modificabili direttamente nell'header senza comando Rinomina. La CI Flutter più recente verificata per questo incremento è [40001351564](https://github.com/andreadada/simple-notes/actions/runs/40001351564): analyze/test, Windows release e Android debug JDK 17/21 riusciti; non equivale a deploy Coolify o test E2E. API Coolify health `UP`; Google Login su Windows/Android; **note sincronizzate realmente PC↔Android** e un'attività creata sul telefono visibile su Windows (conferme dell'utente).

L'auto-sync è foreground; sono stati aggiunti gestione dei conflitti Forui, descrizioni delle attività, test offline simulati e procedure di backup PostgreSQL con ripristino di prova in CI. Non sono ancora verificati sul vero Coolify/dei dispositivi i nuovi flussi di conflitto e il restore reale.

**[Leggi il P0 aggiornato](docs/P0-STATUS.md)** per i dettagli e per le parti ancora mancanti (verifica reale delle liste/tag/sottotask, scadenze con orario, ricorrenze, reminder/notifiche native, sicurezza e release).

## Da dove iniziare

- **[docs/HANDOFF.md](docs/HANDOFF.md)** — leggere per primo entrando in una nuova chat/sessione; stato, setup, problemi risolti e prossimi test.
- **[AGENTS.md](AGENTS.md)** — istruzioni per assistenti AI/Codex (criteri di verifica e workflow).
- [project.md](project.md) — roadmap P0–P3, checklist, registro `Edit Timespan`.
- [docs/P0-STATUS.md](docs/P0-STATUS.md) — stato P0 verificabile, nuove funzioni e blocchi.
- [docs/task-organization.md](docs/task-organization.md) — liste, priorità, tag, sottotask e deploy Flyway V6.
- [docs/due-dates-timezones.md](docs/due-dates-timezones.md) — **prossimo incremento P0 pianificato**: date-only, ora, timezone IANA, migrazioni V7/v5 e test (non implementato).
**Regola UI aggiornata (24/10):** tutti gli input inline (titoli, descrizioni, tag, note e quick-add) hanno sfondo trasparente e underline **lunga esattamente quanto il testo o l'hint** (non fino al bordo del contenitore), con tolleranza di ~1px per il cursore; placeholder semitrasparente. `InlineTextMetrics.fieldWidth` misura i glifi; `InlineGlyphUnderline` disegna la linea indipendentemente dalle dimensioni minime interne del campo Flutter, evitando qualsiasi bordo eccessivo. Implementazione nel commit [7303d45](https://github.com/andreadada/simple-notes/commit/7303d45c34eda2d38f3442080b0959c69ab1bbf0); [design.md](design.md), [Forui](docs/ui-forui.md), [audit](docs/ui-design-audit.md). UI web futura ancora non operativa. CI dell'incremento in verifica separata.

- [design.md](design.md) — requisiti UI/UX e funzionalità obiettivo; non tutte implementate.
- [docs/ui-forui.md](docs/ui-forui.md) — Forui come design system di riferimento e stato della migrazione.
- [docs/architecture.md](docs/architecture.md) · [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — architettura e contratti.
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth.
- [docs/android-troubleshooting.md](docs/android-troubleshooting.md) — Kotlin/Gradle JDK 17/21, Google OAuth Android, ADB e installazione USB.
- [infra/README.md](infra/README.md) — Compose Coolify, ambiente backend e sicurezza.

**Avanzamento T1 (backend CI verde, non deploy):** Flyway V7, modello `TaskDue` e protezione vecchi client sono presenti nel commit [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26); la [CI 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) ha superato test e bootJar. Flutter continua con Drift v4. Dettagli in [piano scadenze](docs/due-dates-timezones.md). **Prossimo passo vincolante:** fare un backup *del database PostgreSQL* Coolify (non della sola API), verificarne il restore isolato, conservare copia offsite e soltanto dopo valutare il redeploy backend da `main` con Flyway V5+V6. Aggiornare entrambi i client e verificare organizzazione attività, sessioni, conflitti e offline su PC/telefono. **Nuovo incremento successivo:** scadenze con orario e semantica date-only, poi ricorrenze/notifiche. Procedura: [checklist P0](docs/P0-DEVICE-CHECKS.md) e [runbook infrastruttura](infra/README.md). Non modificare credenziali e non eliminare database locali.
