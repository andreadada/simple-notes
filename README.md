# Simple Notes

## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

App Windows 11 + Android per **task, note e produttività**, ispirata alle funzionalità di TickTick con interfaccia originale.

**Stack:** Flutter + **Forui (design system)** + Riverpod + Drift/SQLite (offline-first); Spring Boot Java 21 + PostgreSQL/Flyway; Docker Compose/Coolify; Google OAuth Windows/Android.

## T2 — Flutter e SQLite v5 (implementato nel repository, non distribuito)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Perimetro**: T2 è codice e test, **non** rilascio. T3 editor Forui solo-giorno/ora e timezone IANA ancora da completare; notifiche/ricorrenze successive. Backend Flyway V7 ancora **non deployato su Coolify**; prima del rollout completare il backup PostgreSQL e restore isolato. Il runtime Flutter Web resta non supportato.

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
**Regola UI aggiornata (24/10):** tutti gli input inline (titoli, descrizioni, tag, note e quick-add) hanno sfondo trasparente e underline **lunga esattamente quanto il testo o l'hint** (non fino al bordo del contenitore), con ~1px di tolleranza della linea e **margine aggiuntivo del campo** (~18dp) che evita la troncatura del testo; placeholder semitrasparente. `InlineTextMetrics.fieldWidth` misura i glifi; `InlineGlyphUnderline` disegna la linea indipendentemente dalle dimensioni minime interne del campo Flutter, evitando qualsiasi bordo eccessivo. Implementazione nel commit [7303d45](https://github.com/andreadada/simple-notes/commit/7303d45c34eda2d38f3442080b0959c69ab1bbf0); [design.md](design.md), [Forui](docs/ui-forui.md), [audit](docs/ui-design-audit.md). UI web futura ancora non operativa. CI dell'incremento in verifica separata.

- [design.md](design.md) — requisiti UI/UX e funzionalità obiettivo; non tutte implementate.
- [docs/ui-forui.md](docs/ui-forui.md) — Forui come design system di riferimento e stato della migrazione.
- [docs/architecture.md](docs/architecture.md) · [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — architettura e contratti.
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth.
- [docs/android-troubleshooting.md](docs/android-troubleshooting.md) — Kotlin/Gradle JDK 17/21, Google OAuth Android, ADB e installazione USB.
- [infra/README.md](infra/README.md) — Compose Coolify, ambiente backend e sicurezza.

**Avanzamento T1 (backend CI verde, non deploy):** Flyway V7, modello `TaskDue` e protezione vecchi client sono presenti nel commit [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26); la [CI 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) ha superato test e bootJar. Flutter continua con Drift v4. Dettagli in [piano scadenze](docs/due-dates-timezones.md). **Prossimo passo vincolante:** fare un backup *del database PostgreSQL* Coolify (non della sola API), verificarne il restore isolato, conservare copia offsite e soltanto dopo valutare il redeploy backend da `main` con Flyway V5+V6. Aggiornare entrambi i client e verificare organizzazione attività, sessioni, conflitti e offline su PC/telefono. **Nuovo incremento successivo:** scadenze con orario e semantica date-only, poi ricorrenze/notifiche. Procedura: [checklist P0](docs/P0-DEVICE-CHECKS.md) e [runbook infrastruttura](infra/README.md). Non modificare credenziali e non eliminare database locali.
