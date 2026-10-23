# AGENTS.md — Istruzioni di lavoro per assistenti AI

Repository: **Simple Notes** — Flutter Windows/Android + Spring Boot/PG su Coolify. Lingua preferita per spiegazioni e documentazione: **italiano**.

**Se questa è una nuova sessione senza contesto**, prima di lavorare leggere nell'ordine:
1. [docs/HANDOFF.md](docs/HANDOFF.md) — situazione effettiva al 23/10/2026, problemi risolti e test mancanti.
2. [project.md](project.md) — checklist P0–P3 e `Edit Timespan`.
3. [design.md](design.md) — visione prodotto (molte feature future).
4. [docs/architecture.md](docs/architecture.md), [docs/api.md](docs/api.md), [docs/sync.md](docs/sync.md).
5. [apps/flutter/README.md](apps/flutter/README.md), [docs/android-troubleshooting.md](docs/android-troubleshooting.md), [infra/README.md](infra/README.md).

## Criteri di verità

- **La CI non equivale a un test OAuth/sync E2E.** Ultima CI Flutter verificata: [39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440), tutto riuscito, incluso Android JDK 17/21.
- **Windows + Google Login** verificati manualmente; Android segnalato funzionante su dispositivo dopo fix JVM. **Login Google Android post-fix e sync PC↔Android non ancora confermati esplicitamente.**
- Backend HTTPS operativo secondo health-check dell'utente, **non release production-ready**.
- Auto-sync foreground è implementata (login, edit, resume, rete, pull 60 s), con outbox e comando manuale nel menu avatar; mancano test E2E, background sync e UI di conflitto.
- **Non segnare `[x]` finché non hai prove** del comportamento richiesto; distinguere implementato, test CI, test manuale e non verificato.

## Modalità di lavoro

- Quando l'utente chiede modifiche software, preferisce **commit direttamente su `main` di GitHub**, poi `git pull origin main` sul suo PC. Lavorare in piccoli commit descrittivi, con test e documenti coerenti; non dichiarare di aver committato senza effettiva verifica del commit.
- Non risolvere problemi di build con cambi non necessari a backend, domini, Google Cloud o Coolify. Non inventare configurazioni/secret.
- Non fare comandi Git distruttivi su modifiche locali. Preservare sempre outbox, SQLite e dati offline.
- Aggiornare `project.md` e aggiungere una voce a `Edit Timespan` quando si modifica significativamente il progetto.
- Flutter: `apps/flutter`. API: `services/api`. Compose Coolify: `/docker-compose.yml`.
- Package Android OAuth: **`it.andreadada.simplenotes`**; Web Client ID per `google_sign_in` su Android, Desktop Client ID per OAuth Windows. Mai committare secret, file credenziali, token o keystore.
- La build Android con JDK 21 richiede la configurazione JVM del modulo in `android/app/build.gradle.kts`; **non ripristinare target Java 17 fisso** senza considerare Kotlin 21.
- Prossima priorità: confermare Google Login Android, testare auto-sync foreground Windows↔Android con lo stesso account, offline/retry/conflitti; valutare in seguito background sync. Avatar Google (claim picture) richiede il backend con migration Flyway V4.

**Su qualsiasi incongruenza tra handoff e codice/CI più recente, verificare e aggiornare la documentazione invece di inventare uno stato.**
