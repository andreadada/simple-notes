# AGENTS.md — Istruzioni di lavoro per assistenti AI

## P1.4 — Multi-block e riepilogo focus (25/10/2026)

**Branch in sviluppo `feature/p1-4-multi-blocks-batch`, NON ancora su `main`, NON deployato su Coolify.** Flutter `0.8.0+10`; backend Flyway V9, Drift V7, fino a 12 slot per attività con ID stabili; CRUD/pannello Forui, copia slot, drag mirato e riepilogo pianificate/completate. Compatibilità protetta con `timeBlocksSchema:1` / 426 su client V8 incapaci di salvare il multi-block. Il server attualmente installato dall'utente rimane Flyway V8 e il client effettivo non è stato aggiornato a V0.8. Niente reset/dati persi e **collaudo dispositivi rimandato a fine batch**. [Specifiche](docs/P1-MULTI-BLOCKS.md).


## Stato corrente — rilascio 0.7.0+9 (25/10/2026)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](docs/P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


> **P1.3 in sviluppo (25/10/2026):** su `feature/p1-3-calendar-interactions` (base: P1.2) Flutter `0.7.0+9` introduce drag/resize dei blocchi nella timeline Giorno/Settimana, drop su altro giorno con gestione DST, snap 15 minuti e test. Non è su `main`; Flyway V8/Drift V6 sono gli stessi di P1.2. **Nessun deploy/migrazione su Coolify e nessun reset dati!** La specifica corrente è [docs/P1-CALENDAR-INTERACTIONS.md](docs/P1-CALENDAR-INTERACTIONS.md). Mai dichiarare P1.3 su dispositivo senza collaudo esplicito.


> **Stato aggiornato 25/10/2026:** il reset dei dati di test è completato per server, SQLite Windows e Android (utente: «tutto 0»). Non ripetere reset. Su `main` è presente P1.1 calendario `0.5.0+7`, CI verde. Sul branch `feature/p1-2-time-blocking` è in sviluppo P1.2 (`0.6.0+8`): periodo UTC + fuso IANA indipendente dalla deadline, Flyway V8, Drift V6, editor Forui, sync capability `timeBlockSchema:1`, test. **Non applicare V8 o fare deploy automatici al DB Coolify**: controllare CI e rollout esplicitamente. La documentazione corrente è [docs/P1-TIME-BLOCKING.md](docs/P1-TIME-BLOCKING.md), che prevale sulle istruzioni storiche qui sotto.

## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](docs/T4-DEVICE-SYNC.md).


## Regole T4.1 obbligatorie

- Eseguire `infra/t4-inspect-db.sh` solo su container specificamente identificato; è un controllo di sola lettura.
- Non dichiarare un restore ancora valido se `.restore-ok` è più vecchio di 24 ore senza esplicita giustificazione operativa, e non superare la soglia massima di 168 ore.
- Non confondere CI sintetica con accesso VPS/Coolify, identità del database o prova della copia cifrata offsite.
- Per ogni futuro deploy verificare commit approvato e gate attuale; inventario DB, V7, backup SHA256 e restore isolato reali sono già stati verificati il 24/10.

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

Repository: **Simple Notes** — Flutter Windows/Android + Spring Boot/PG su Coolify. Lingua preferita per spiegazioni e documentazione: **italiano**.

**Se questa è una nuova sessione senza contesto**, prima di lavorare leggere nell'ordine:
1. [docs/P0-STATUS.md](docs/P0-STATUS.md) — stato verificabile; non confondere CI con test reali.
2. [docs/P0-DEVICE-CHECKS.md](docs/P0-DEVICE-CHECKS.md) — checklist di backup, deploy sicuro e test PC↔Android.
3. [docs/HANDOFF.md](docs/HANDOFF.md) — contesto storico, subordinato allo stato corrente.
4. [project.md](project.md) — checklist P0–P3 e `Edit Timespan`.
5. [docs/task-organization.md](docs/task-organization.md), [docs/due-dates-timezones.md](docs/due-dates-timezones.md) (**prossimo incremento, solo piano**), [docs/ui-forui.md](docs/ui-forui.md), [design.md](design.md).
6. [docs/architecture.md](docs/architecture.md), [docs/api.md](docs/api.md), [docs/sync.md](docs/sync.md).
7. [apps/flutter/README.md](apps/flutter/README.md), [docs/android-troubleshooting.md](docs/android-troubleshooting.md), [infra/README.md](infra/README.md).

## Regola UI verificabile su tutta l'app

- Applicare `design.md` alle schermate Flutter **desktop e mobile**, usando la stessa struttura responsive; per i campi semplici presenti anche in una riga usare `InlineEditableTitle` / `InlineEditableBody` senza bottone `Modifica`. Per dati non testuali scegliere Forui; eccezione di editor avanzato solo se ci sono più campi correlati.
- **LARGHEZZA UNDERLINE VINCOLANTE (24/10/2026):** nessuno sfondo grigio; underline neutra a riposo e blu al focus, lunga esattamente quanto i caratteri del valore o del placeholder (solo ~1 px per cursore), MAI fino al bordo di una `Row`/`Expanded`. Eliminare min-width non giustificati **dalla linea** e input full-width per stringhe brevi; riservare invece ~18dp *al campo* per evitare clipping. Placeholder `NotesPalette.placeholder` semitrasparente (~72%); misurare con `InlineTextMetrics.fieldWidth` (TextPainter + textScaler). Applicare a task/list/nota/sottotask/tag/descrizioni e quick-add. Testare `A` e placeholder vuoti. **Attenzione a `Expanded`:** può forzare il `SizedBox` alla larghezza completa; separarlo con `Align(widthFactor: 1, alignment: AlignmentDirectional.centerStart)` e usare **`InlineGlyphUnderline` con `NotesTheme.invisibleInlineBorder`**, perché `InputDecorator` può avere una dimensione minima autonoma. Il test deve misurare `Key('inline-glyph-underline')` invece del wrapper o del `TextField` per garantire la linea esatta. Regressione coperta dal test `Underline follows text and placeholder lengths`.
- Non riaprire il vecchio dialog `Modifica nota`; il corpo e il titolo della nota sono inline nella card. Non eliminare task/note senza conferma Forui.
- I metodi `LocalStore.renameTask/setTask*/renameNote/setNoteBody/renameSubtask` devono preservare SQLite/outbox e gli attributi non modificati. Eseguire `flutter analyze`, `flutter test` e build Windows/Android in CI.
- **Web non è dichiarabile pronto:** il progetto usa ancora `dart:io`/Drift Native/OAuth desktop; UI condivisa ≠ app browser funzionante. Leggere `docs/ui-design-audit.md` prima di affermare supporto web.

## T2 — Flutter e SQLite v5 (implementato nel repository, non distribuito)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Criteri di verità

- **La CI non equivale a un test OAuth/sync E2E.** Ultima CI Flutter verificata sull'incremento inline-title: [40001351564](https://github.com/andreadada/simple-notes/actions/runs/40001351564), analyze/test, Windows e Android JDK 17/21 riusciti. I soli commit `.md` non attivano questa CI.
- **Windows + Google Login** verificati manualmente; Android segnalato funzionante su dispositivo dopo fix JVM. **Login Google su entrambi e sync note PC↔Android confermati dall'utente il 23/10; attività create da Android viste su Windows.** Resta da provare la risoluzione dei conflitti reali.
- Backend HTTPS operativo secondo health-check dell'utente, **non release production-ready**.
- Auto-sync foreground è implementata (login, edit, resume, rete, pull 60 s), con outbox e comando manuale nel menu avatar; mancano test conflitti reali e background sync; la UI di conflitto Forui ora esiste.
- **Non segnare `[x]` finché non hai prove** del comportamento richiesto; distinguere implementato, test CI, test manuale e non verificato.

## Modalità di lavoro

- Quando l'utente chiede modifiche software, preferisce **commit direttamente su `main` di GitHub**, poi `git pull origin main` sul suo PC. Lavorare in piccoli commit descrittivi, con test e documenti coerenti; non dichiarare di aver committato senza effettiva verifica del commit.
- Non risolvere problemi di build con cambi non necessari a backend, domini, Google Cloud o Coolify. Non inventare configurazioni/secret.
- Non fare comandi Git distruttivi su modifiche locali. Preservare sempre outbox, SQLite e dati offline.
- Aggiornare `project.md` e aggiungere una voce a `Edit Timespan` quando si modifica significativamente il progetto.
- **REGOLA UX VINCOLANTE — INLINE EDIT FIRST:** quando un titolo/nome/attributo testuale semplice è già visibile, renderlo direttamente editabile **nello stesso punto** (testo che diventa input) invece di aggiungere un bottone `Rinomina`/`Modifica` + dialog. Invio/perdita focus salva; Esc annulla; validazione, focus accessibile, salvataggio offline-first reale, niente perdita di bozze su refresh. La larghezza deve seguire il contenuto, non essere un form full-width. Eccezioni solo per dati complessi, conferme o azioni distruttive. Riferimenti: `design.md`, `docs/ui-forui.md`, `ui/inline_editable_title.dart`; niente `Rinomina` sulle liste.
- UI Flutter: **Forui-first**, vedi `apps/flutter/lib/ui/notes_theme.dart` e `docs/ui-forui.md`; preservare i widget Material che supportano i test finché non vengono migrati correttamente.
- Flutter: `apps/flutter`. API: `services/api`. Compose Coolify: `/docker-compose.yml`.
- Package Android OAuth: **`it.andreadada.simplenotes`**; Web Client ID per `google_sign_in` su Android, Desktop Client ID per OAuth Windows. Mai committare secret, file credenziali, token o keystore.
- La build Android con JDK 21 richiede la configurazione JVM del modulo in `android/app/build.gradle.kts`; **non ripristinare target Java 17 fisso** senza considerare Kotlin 21.
- Per modifiche a scadenze e timezone seguire [docs/due-dates-timezones.md](docs/due-dates-timezones.md): value object `none/date/datetime/legacy`, Flyway V7/Drift v5, DST/ambiguità 00:00 e protezione dei vecchi client. È un **piano**, non codice pronto.
- T1 backend `TaskDue`/Flyway V7/protezione 426/capabilities aggiunto nel commit `1bafec0`; **non distribuito**. T2 Flutter ora legge `/api/v1/capabilities`, gestisce 426 senza cancellare l'outbox e migra Drift v4→v5. Convalidare CI ed E2E prima del rollout. Prima del deploy backup/restore reale.
- Prossima priorità: **T4.2** con build `0.4.1+5` Windows↔Android, capability `taskDueSchema:1`, sync in entrambi i sensi, offline e DST. Non riavviare backup/restore o migrazioni V7 già eseguite; offsite non eseguita per scelta.

**Su qualsiasi incongruenza tra handoff e codice/CI più recente, verificare e aggiornare la documentazione invece di inventare uno stato.**

- Dialoghi di modifica attività/nota e scadenze usano **FDialog/FCalendar**, con layout in `apps/flutter/lib/ui/notes_dialogs.dart`. Non reintrodurre `showDatePicker`/Material `AlertDialog` nei loro flussi; mantenere test dei picker e date locali.

- Organizzazione P0: le liste sono entità sync `list` vere, non nomi locali; `TaskListEntity`, `LocalTaskList` e task `listId/priority/tags/subtasks` sono obbligatori. Preservare ordine outbox (prima lista, poi task; prima movimento task, poi delete-list) e vincolo owner. Non introdurre delete cascade. Qualsiasi modifica ai modelli richiede migration Flyway/Drift incrementale e test con due client. Leggere `docs/task-organization.md`.

- **T4 OBBLIGATORIO:** nessun agente deve marcare T4 completato per il solo superamento della CI sintetica, né avviare redeploy, import, `pg_restore` verso produzione, `flyway repair`, rimuovere volumi, o attestare una copia S3 mai controllata. `t4-preflight.sh` è di sola lettura e deve fallire se manca receipt o conferma offsite reale.
