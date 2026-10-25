# Simple Notes

## P1.4 — Multi-block e riepilogo focus (25/10/2026)

**Branch in sviluppo `feature/p1-4-multi-blocks-batch`, NON ancora su `main`, NON deployato su Coolify.** Flutter `0.8.0+10`; backend Flyway V9, Drift V7, fino a 12 slot per attività con ID stabili; CRUD/pannello Forui, copia slot, drag mirato e riepilogo pianificate/completate. Compatibilità protetta con `timeBlocksSchema:1` / 426 su client V8 incapaci di salvare il multi-block. Il server attualmente installato dall'utente rimane Flyway V8 e il client effettivo non è stato aggiornato a V0.8. Niente reset/dati persi e **collaudo dispositivi rimandato a fine batch**. [Specifiche](docs/P1-MULTI-BLOCKS.md).


## Stato corrente — rilascio 0.7.0+9 (25/10/2026)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](docs/P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


## P1.3 — Calendar drag/resize (25/10/2026)

**Su branch `feature/p1-3-calendar-interactions` (non su `main`): Flutter `0.7.0+9`, timeline interattiva giorno/settimana, move/resize a step 15 minuti, drag su intestazioni giornaliere e celle del mese, supporto DST e corsie sovrapposizioni; test dedicati.** Non richiede nuove tabelle oltre Flyway V8 di P1.2 e Drift V6. *CI e test hardware da verificare; nessun deploy/merge di P1.2 e P1.3 né modifica ai dati reali*. P1.2 `feature/p1-2-time-blocking` ha CI backend e Flutter completamente verde ma resta draft, non distribuito. P1.3 è documentato in [P1-CALENDAR-INTERACTIONS.md](docs/P1-CALENDAR-INTERACTIONS.md). Multi-blocco per task resta fuori ambito, per successiva revisione di modello.


## P1.2 — Time blocking in sviluppo (25 ottobre 2026)

**Branch `feature/p1-2-time-blocking`, Flutter `0.6.0+8`.** Introdotto intervallo `timeBlock` indipendente dalla scadenza, con editor Forui, blocchi nel calendario e percorso di sincronizzazione versionato. **Backend V8/Drift V6 sono solo codice: nessun deploy Coolify, migrazione reale, nuova pulizia dati o installazione sui dispositivi effettuata.** `timeBlockSchema:1` è un gate obbligatorio prima di inviare nuovi task. I test CI automatici e l'accettazione PC↔Android sono ancora da verificare. Non confondere codice implementato con feature già rilasciata. Specifica e piano: [P1-TIME-BLOCKING.md](docs/P1-TIME-BLOCKING.md). La versione su `main` resta `0.5.0+7` fino a merge autorizzato/dopo verifiche.


## Stato operativo aggiornato — 25 ottobre 2026 (fonte corrente)

**Reset del workspace di test concluso dall'utente:** PostgreSQL `simplenotes` verificato con **0 task, 0 liste, 0 note, 0 eventi e 0 operazioni di sync**; SQLite Windows eliminata dallo script, dati Android cancellati dalle impostazioni del dispositivo dopo che ADB `pm clear` era stato rifiutato dal sistema. Il reset è stato confermato dall'utente: **non va ripetuto** per avviare P1. `app_user`, sessioni backend, schema e Flyway restano conservati. I conteggi storici (5 note soft-deleted, cursor 34, backup e restore PASS) descrivono lo stato **prima** del reset, non quello corrente.

**Codice:** Flutter `0.5.0+7` introduce **P1.1 Calendario** (giorno/settimana/mese, agenda, scadenze date-only e timed, edit inline, aggiunta rapida) tramite proiezione dei task già sincronizzati, **senza migrazioni DB né nuove API**. Vedi [P1-CALENDAR.md](docs/P1-CALENDAR.md) (oppure [specifica P1.1](P1-CALENDAR.md) per i documenti in `docs/`). Cestino note/restore versionato già implementato in `0.4.2+6`, ma **non verificato sui dispositivi** e per il ripristino cloud richiede l'API aggiornata `noteRestoreSchema:1`; il deploy Coolify non è attestato. P1.2 time blocking, P0 reminder/ricorrenze/hardening e test E2E restano **aperti**, non vengono segnati completati.

**CI:** la revisione precedente `d29d2f3` (0.4.2+6) è verde su Flutter e backend; per P1.1 citare la **nuova CI** dopo averne verificato l'esito. **Nessun nuovo deploy, backup o ulteriore reset eseguito da ChatGPT.**

> Le sezioni datate 23–24 ottobre più in basso sono **cronologia**, non istruzioni operative correnti; prevale questo stato e [RESET-TEST-DATA.md](docs/RESET-TEST-DATA.md) per la storia del reset.

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
