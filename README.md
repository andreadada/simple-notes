# Simple Notes

## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](docs/T4-DEVICE-SYNC.md).


## T4.1 — Gate database (solo lettura)

Aggiunto `infra/t4-inspect-db.sh`: verifica su PostgreSQL 17, versione Flyway e coerenza colonne scadenze, senza modificare dati. Il gate restore richiede una prova recente (24 ore, limite configurabile fino a 168 ore). Inventario VPS e restore reale già verificati; offsite non effettuata per scelta, API/hardware ancora da controllare: [runbook](docs/T4-RELEASE-RUNBOOK.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](docs/T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Scadenze e fusi orari (24/10/2026)

Il client Flutter ha ora un editor scadenze Forui riutilizzato in creazione rapida, pannello dettagli e editor avanzato (`ui/task_due_editor.dart`). Supporta `date` senza ora, `datetime` con HH:mm + timezone IANA, scelta del fold DST e rifiuto del gap; non converte automaticamente `legacy`. Il rilevamento OS fallibile non produce una UTC inventata: l'utente sceglie un fuso valido. `task_due_view.dart` centralizza l'etichetta (mostra il fuso) e i filtri Oggi/7 giorni in giorni civili; gli aggiornamenti rimangono offline-first.

**Stato aggiornato:** T3 implementato nel codice, Flyway V7 già nel DB reale, backup SHA256 e restore isolato riusciti. Rimangono verifica API autenticata e test hardware Windows↔Android. Esecuzione web, ricorrenze e notifiche non sono supportate in T3. Leggere [T3-SCADENZE.md](docs/T3-SCADENZE.md) e verificare le [CI Flutter](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml) per l'esito esatto.


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
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Stato storico — 23 ottobre 2026 (vedere aggiornamento T3)

**P0 in corso: non pronto per il rilascio pubblico.** Liste, priorità, tag e sottotask implementati nel codice con backend/Flyway V6 e Flutter/Drift v4; test automatizzati riusciti, verifica su dispositivi reali ancora aperta. I titoli delle liste sono modificabili direttamente nell'header senza comando Rinomina. La CI Flutter più recente verificata per questo incremento è [40001351564](https://github.com/andreadada/simple-notes/actions/runs/40001351564): analyze/test, Windows release e Android debug JDK 17/21 riusciti; non equivale a deploy Coolify o test E2E. API Coolify health `UP`; Google Login su Windows/Android; **note sincronizzate realmente PC↔Android** e un'attività creata sul telefono visibile su Windows (conferme dell'utente).

L'auto-sync è foreground; sono stati aggiunti gestione dei conflitti Forui, descrizioni delle attività, test offline simulati e procedure di backup PostgreSQL con ripristino di prova in CI. Non sono ancora verificati sul vero Coolify/dei dispositivi i nuovi flussi di conflitto e il restore reale.

**[Leggi il P0 aggiornato](docs/P0-STATUS.md)** per i dettagli e per le parti ancora mancanti (verifica reale delle liste/tag/sottotask, scadenze con orario, ricorrenze, reminder/notifiche native, sicurezza e release).

## Da dove iniziare

- **[docs/HANDOFF.md](docs/HANDOFF.md)** — leggere per primo entrando in una nuova chat/sessione; stato, setup, problemi risolti e prossimi test.
- **[AGENTS.md](AGENTS.md)** — istruzioni per assistenti AI/Codex (criteri di verifica e workflow).
- [project.md](project.md) — roadmap P0–P3, checklist, registro `Edit Timespan`.
- [docs/P0-STATUS.md](docs/P0-STATUS.md) — stato P0 verificabile, nuove funzioni e blocchi.
- [docs/task-organization.md](docs/task-organization.md) — liste, priorità, tag, sottotask e deploy Flyway V6.
- [docs/due-dates-timezones.md](docs/due-dates-timezones.md) — specifica e codice T1–T3 presenti, prove real-device T4.2 ancora aperte.
**Regola UI aggiornata (24/10):** tutti gli input inline (titoli, descrizioni, tag, note e quick-add) hanno sfondo trasparente e underline **lunga esattamente quanto il testo o l'hint** (non fino al bordo del contenitore), con ~1px di tolleranza della linea e **margine aggiuntivo del campo** (~18dp) che evita la troncatura del testo; placeholder semitrasparente. `InlineTextMetrics.fieldWidth` misura i glifi; `InlineGlyphUnderline` disegna la linea indipendentemente dalle dimensioni minime interne del campo Flutter, evitando qualsiasi bordo eccessivo. Implementazione nel commit [7303d45](https://github.com/andreadada/simple-notes/commit/7303d45c34eda2d38f3442080b0959c69ab1bbf0); [design.md](design.md), [Forui](docs/ui-forui.md), [audit](docs/ui-design-audit.md). UI web futura ancora non operativa. CI dell'incremento in verifica separata.

- [design.md](design.md) — requisiti UI/UX e funzionalità obiettivo; non tutte implementate.
- [docs/ui-forui.md](docs/ui-forui.md) — Forui come design system di riferimento e stato della migrazione.
- [docs/architecture.md](docs/architecture.md) · [docs/api.md](docs/api.md) · [docs/sync.md](docs/sync.md) — architettura e contratti.
- [apps/flutter/README.md](apps/flutter/README.md) — build Windows/Android e OAuth.
- [docs/android-troubleshooting.md](docs/android-troubleshooting.md) — Kotlin/Gradle JDK 17/21, Google OAuth Android, ADB e installazione USB.
- [infra/README.md](infra/README.md) — Compose Coolify, ambiente backend e sicurezza.

**Cronologia T1 (23/10, superata per il database):** `TaskDue` e V7 introdotti in [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26); sul DB reale V7, backup e restore sono riusciti il 24/10. Ora verificare capability API e due build T4.2 PC↔Android.
