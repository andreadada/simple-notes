## Stato operativo aggiornato — 25 ottobre 2026 (fonte corrente)

## P1.2 — Time blocking in sviluppo (25 ottobre 2026)

**Branch `feature/p1-2-time-blocking`, Flutter `0.6.0+8`.** Introdotto intervallo `timeBlock` indipendente dalla scadenza, con editor Forui, blocchi nel calendario e percorso di sincronizzazione versionato. **Backend V8/Drift V6 sono solo codice: nessun deploy Coolify, migrazione reale, nuova pulizia dati o installazione sui dispositivi effettuata.** `timeBlockSchema:1` è un gate obbligatorio prima di inviare nuovi task. I test CI automatici e l'accettazione PC↔Android sono ancora da verificare. Non confondere codice implementato con feature già rilasciata. Specifica e piano: [P1-TIME-BLOCKING.md](docs/P1-TIME-BLOCKING.md). La versione su `main` resta `0.5.0+7` fino a merge autorizzato/dopo verifiche.


**Reset del workspace di test concluso dall'utente:** PostgreSQL `simplenotes` verificato con **0 task, 0 liste, 0 note, 0 eventi e 0 operazioni di sync**; SQLite Windows eliminata dallo script, dati Android cancellati dalle impostazioni del dispositivo dopo che ADB `pm clear` era stato rifiutato dal sistema. Il reset è stato confermato dall'utente: **non va ripetuto** per avviare P1. `app_user`, sessioni backend, schema e Flyway restano conservati. I conteggi storici (5 note soft-deleted, cursor 34, backup e restore PASS) descrivono lo stato **prima** del reset, non quello corrente.

**Codice:** Flutter `0.5.0+7` introduce **P1.1 Calendario** (giorno/settimana/mese, agenda, scadenze date-only e timed, edit inline, aggiunta rapida) tramite proiezione dei task già sincronizzati, **senza migrazioni DB né nuove API**. Vedi [P1-CALENDAR.md](docs/P1-CALENDAR.md) (oppure [specifica P1.1](P1-CALENDAR.md) per i documenti in `docs/`). Cestino note/restore versionato già implementato in `0.4.2+6`, ma **non verificato sui dispositivi** e per il ripristino cloud richiede l'API aggiornata `noteRestoreSchema:1`; il deploy Coolify non è attestato. P1.2 time blocking, P0 reminder/ricorrenze/hardening e test E2E restano **aperti**, non vengono segnati completati.

**CI:** la revisione precedente `d29d2f3` (0.4.2+6) è verde su Flutter e backend; per P1.1 citare la **nuova CI** dopo averne verificato l'esito. **Nessun nuovo deploy, backup o ulteriore reset eseguito da ChatGPT.**

> Le sezioni datate 23–24 ottobre più in basso sono **cronologia**, non istruzioni operative correnti; prevale questo stato e [RESET-TEST-DATA.md](docs/RESET-TEST-DATA.md) per la storia del reset.

## Aggiornamento 24/10/2026 — test reali, sicurezza note e futuro P1

**Verificato dall'utente:** Flutter `0.4.1+5` installata via `adb install -r`, login Google e API `taskDueSchema:1` su Windows e Android, entrambi cursor 34 e pending 0. L'audit PostgreSQL **sola lettura** ha individuato 5 note tutte in soft-delete, in particolare eventi 33–34 dal server; i dati sono di test e l'utente sceglie di azzerarli. La sorgente dei DELETE non è attribuibile a un dispositivo dal solo registro: non chiamarla causa risolta.

**Nuovo codice:** Cestino note sincronizzato, ripristino dello stesso ID con verifica della versione, blocco delle vecchie operazioni che tentano di sovrascrivere tombstone ed eventi remoti più vecchi ignorati, capability API `noteRestoreSchema:1`, Flutter `0.4.2+6`. È presente un reset esplicito del solo workspace di test (server PostgreSQL + SQLite Windows/Android), con **anteprime obbligatorie e conferme**; nessun reset/deploy è stato eseguito da questa chat. [Guida operativa](docs/RESET-TEST-DATA.md). La CI prova il codice, non i dati live; verificare prima del deployment.

**Prossimo sviluppo dopo il reset e breve verifica E2E:** P1 calendario giorno/settimana/mese e time blocking. Le funzioni richiedono nuovi incrementi, non sono ancora implementate. T4.2 non è completata finché non si verificano i nuovi flussi offline/cestino su entrambi i dispositivi.

# Simple Notes — Project

## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](docs/T4-DEVICE-SYNC.md).


## T4.1 — Inventario pre-deploy

Sorgente `infra/t4-inspect-db.sh`: query SELECT sul solo PostgreSQL selezionato, verifica versione 17, ultima Flyway, colonne V7 e conteggi strutturali. Preflight richiede restore verificato nelle ultime 24 ore per evitare attestati obsoleti. Verifica VPS realmente eseguita 24/10; V1–V7, SHA256 e restore isolato già PASS. Non ripetere per T4.2. [Runbook](docs/T4-RELEASE-RUNBOOK.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](docs/T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Scadenze Forui, IANA e DST (24/10/2026)

**Implementato nel codice su main, non distribuito.** Un unico editor `ui/task_due_editor.dart` gestisce scadenze solo-giorno e data/ora, calendario Forui, HH:mm, fuso IANA e scelta esplicita delle due occorrenze in un cambio d'ora. Gli orari inesistenti sono rifiutati, la mezzanotte scelta rimane `datetime`, e le scadenze `legacy` non sono reinterpretate in automatico. Il fuso OS viene rilevato se disponibile, altrimenti richiesto esplicitamente.

`data/task_due_clock.dart` usa `timezone ^0.11.2` e `flutter_timezone ^5.1.0`; `data/task_due_view.dart` presenta label e filtri Oggi/7 giorni secondo **giorni civili**, evitando il calcolo sbagliato di 168 ore attorno all'ora legale. Aggiunta rapida, dettagli ed editor avanzato salvano `TaskDue` con SQLite/outbox; una rinomina non muta `date/datetime` in `legacy`. Test per gap/fold, visualizzazione, filtri e modifica avanzata. **V7 già verificata sul database reale**, backup SHA256 e restore isolato PASS. Mancano capability API `taskDueSchema:1` e prove Windows/Android; non ripetere deploy senza un'incompatibilità accertata. Ricorrenze, notifiche e browser web restano fuori da T3.

Dettagli e checklist: [specifica T3](docs/T3-SCADENZE.md). CI: [Flutter Actions](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml).


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

**Obiettivo:** app offline-first Windows 11 + Android ispirata alle funzionalità di TickTick, con UI originale, login Google e backend self-hosted su Coolify.
**Stack:** Flutter/Dart + Forui (UI) + Riverpod + Drift/SQLite; Spring Boot (Java 21) + Spring Security + PostgreSQL/Flyway; REST + sync incrementale + WebSocket; Android FCM; Docker/Coolify.
**Stato:** P0 IN CORSO. Note sincronizzate realmente PC↔Android e attività create su Android viste su Windows (conferma utente, 23/10). Auto-sync foreground funzionante per questi flussi. Nuovo recupero conflitti, descrizioni attività e backup operativo implementati con test automatici, ma da verificare con Coolify/dispositivi aggiornati. **Non pronto per il rilascio**. Stato dettagliato in [docs/P0-STATUS.md](docs/P0-STATUS.md).

## Regole vincolanti — COME FARE
- [ ] Lavorare in piccoli commit descrittivi, con test e documentazione aggiornati.
- [ ] Architettura modulare: UI → applicazione → dominio → dati; backend per domini.
- [ ] Offline-first: scrivere prima in SQLite, poi sincronizzare con outbox persistente.
- [ ] API versionate, migrazioni Flyway, UUID, revisioni, idempotenza e soft-delete/tombstone.
- [ ] Login Google verificato lato server; OAuth PKCE su Windows; credenziali e token in storage sicuro.
- [ ] Distinguere layout Windows e Android; testare accessibilità, ridimensionamento e dark/light.
- [x] **Design rule inline-edit first:** se un titolo/nome/attributo semplice è già visibile, renderlo editabile sul posto, senza bottone/modale Rinomina. Invio/blur salva, Esc annulla; validazione e SQLite/outbox sempre obbligatori. Eccezioni per form complessi o distruttivi.
- [x] **Design rule larghezza esatta:** testo senza sfondo, sottolineatura neutra solo larga quanto valore/placeholder (non il contenitore; ~1px per cursore), blu al focus, placeholder semitrasparente (~72%). Implementazione condivisa `InlineTextMetrics.fieldWidth` in `notes_theme.dart`, utilizzata da titolo, descrizione, note, tag, sottotask e input task rapido; vedi `design.md` / `docs/ui-forui.md`. Il codice è nel commit `7303d45`; CI e test real-device da registrare separatamente.
- [ ] Gestire i fusi orari, DST, le ricorrenze e la deduplicazione dei promemoria.
- [ ] Eseguire test unitari, integrazione, offline/online e ripristino backup prima dei rilasci.
- [ ] Aggiornare **Edit Timespan** in fondo ad ogni commit che modifica il progetto.

## Regole vincolanti — COME NON FARE
- [ ] NON mettere segreti, token, file .env reali o credenziali Google nel repository.
- [ ] NON usare Firebase come database principale o dipendere dal cloud per consultare i task.
- [ ] NON sovrascrivere modifiche concorrenti senza una policy di conflitto verificata.
- [ ] NON duplicare notifiche o presumere che il desktop spento possa notificare.
- [ ] NON copiare codice, immagini o asset protetti di TickTick.
- [ ] NON introdurre microservizi, Redis o code distribuite senza esigenza misurata.
- [ ] NON segnare [x] senza implementazione, test e verifica effettuati.
- [ ] NON effettuare deploy in produzione senza health check, backup e configurazione sicura.

## P0 — Incrementi verificati (CI)
- [x] Spring Boot, Flyway, PostgreSQL/Testcontainers e API health/CRUD task-note (run `39603724091`).
- [x] Refresh token ruotabili, logout e modifica con controllo versione (run `39603724091`).
- [x] Desktop OAuth exchange server-side e validazione callback (run `39604096529`).
- [x] Protocollo delta-sync: idempotenza, change log per utente e test PostgreSQL (run `39605619133`).
- [x] Flutter dark Windows/Android, task-note locali e build Android/Windows (run `39604983987`).
- [x] Drift/SQLite, outbox e migrazione dati legacy; analyze/test Flutter (run `39604983987`).
- [x] Windows: avvio Flutter desktop e login Google OAuth reale verificati manualmente (21 ottobre 2026).
- [x] App Android avviata sul dispositivo fisico (22 ottobre 2026); prima build Kotlin locale risolta disattivando la cache incrementale.
- [x] Configurazione Android versionata: applicationId/namespace `it.andreadada.simplenotes`, Java target allineato a JDK 17/21, Kotlin incremental off su dischi differenti, Activity Java; CI Android/JDK17/JDK21 riuscita (run `39955667440`).
- [x] JDK 17 e JDK 21: Android debug APK build riuscite su entrambi, Flutter CI run `39955667440` (success).
- [x] Android: dopo correzioni Gradle/JVM l'utente segnala «Perfetto funziona» il 23/10. L'errore precedente `INSTALL_FAILED_USER_RESTRICTED` è storicizzato nel runbook; evitare di dichiarare verificato il login Google senza conferma specifica.
- [x] Login con lo stesso account Google su Windows e Android e sync note PC↔Android confermate dall'utente (23/10). Session refresh, logout, riavvio da testare.
- [ ] Sincronizzazione bidirezionale note confermata dall'utente e attività Android→Windows visualizzate; **restano** test offline/409/cancellazioni su device reali. Gestione conflitto Forui (scelta locale/server), endpoint latest e prove simulate aggiunti; richiede nuovo backend Coolify.
- [ ] Liste, tag, priorità, sottotask e ricerca testuale introdotti con test automatici; **ancora da verificare sui due dispositivi reali** dopo deploy V6. Ricorrenze, notifiche e filtri avanzati da sviluppare.
- [ ] Avatar Google e menu unico account implementati (Flutter + claim `picture` sul backend con Flyway), da verificare con login reale e redeploy Coolify.
- [x] Backend deployato su Coolify e raggiungibile via HTTPS: health check `https://api.notes.ddone.it/actuator/health` con `UP` (confermato dall'utente).
- [ ] Hardening produzione: backup SHA256 e restore reale isolato già PASS; offsite non effettuata per scelta; rate limiting e monitoraggio ancora da fare.
- Stato della sync **client**: automatica foreground sperimentale e fallback manuale; verifiche CI/E2E non equivalgono a validazione completa.

## P0 — Incrementi di affidabilità (23 ottobre 2026)

- [x] Endpoint `GET /sync/latest` isolato per account con test backend, indice Flyway V5 (CI backend).
- [x] Dialog Forui per confronto versioni e scelta esplicita, con doppia conferma prima di scartare modifiche locali; test simulato PC↔Android e offline/retry (CI Flutter).
- [x] Descrizioni delle attività persistenti SQLite, sincronizzate nel payload già supportato dal backend, con test e migrazione Drift V3 (CI Flutter).
- [x] Script dump e restore isolato con smoke test su dati sintetici in CI Compose.
- [ ] Verificare funzioni su due device con API autenticata; backup/restore reali già riusciti, redeploy solo se necessario.
- [ ] Completare P0: verifica E2E dell'organizzazione, filtri avanzati, ricorrenze, reminder/notifiche native, sicurezza, backup offsite e release.
- Guida di stato e criteri: [docs/P0-STATUS.md](docs/P0-STATUS.md).

## P0 — Organizzazione attività (23 ottobre 2026)

- [x] Liste personalizzate CRUD e vista per lista, comprese liste vuote, con entità `list` sincronizzata e privacy per owner verificata (Backend CI 39990997833).
- [x] Priorità 0–3, tag multipli, sottotask con stato e UUID, ricerca per contenuti e filtro priorità; UI Forui per modifica attività e liste.
- [x] Drift/SQLite schema v4 + PostgreSQL/Flyway V6, senza eliminazione dei dati precedenti, test Flutter simulati a due database (run 39991667611).
- [x] Eliminazione lista con spostamento task in Inbox e 409 backend se la lista contiene ancora task; test automatici riusciti.
- [ ] **Verifica ancora necessaria:** V6/V7 già nel DB reale; controllare API e PC↔Android/riavvio/offline. Non segnare release-ready.
- Specifiche e runbook: [docs/task-organization.md](docs/task-organization.md).

## P0 — Fondamenta e MVP
- [x] Inizializzazione repository, README breve, design.md, project.md e documentazione API/sync.
- [x] Bootstrap Flutter Android/Windows + Riverpod + Drift/SQLite e CI.
- [ ] Routing/deep link, UX mobile definitiva e test accessibilità.
- [x] Backend Spring Boot Java 21, PostgreSQL, Flyway, API health (test CI).
- [x] Compose in root `docker-compose.yml` validato con `docker compose config --quiet` (CI run `39634311667`).
- [x] Deployment Coolify HTTPS e health check `UP` verificati dall'utente; NON equivale a validazione di sicurezza per la produzione.
- [x] Windows: compilazione e avvio dell'app, login Google reale verificato; dipendenza C++ ATL installata su Build Tools.
- [ ] Android: confermare Google Login e ripristino sessione **dopo** fix JVM e package Android. Il precedente `[16] Account reauth failed` era prima degli ultimi fix; non sappiamo ancora se risolto.
- [ ] Persistenza sessione Windows/Android, logout e refresh dopo riavvio da verificare con test E2E.
- [x] Struttura iniziale utenti, task, note, versioni, tombstone, refresh sessions.
- [ ] Liste, tag, sottotask, priorità, ricerca base **implementati nel codice e verificati con test automatici**, con Drift v4 e Flyway V6; restano verifica PC↔Android reale, filtri avanzati, ricorrenze e reminder.
- [ ] Sync completa: auto-sync foreground e sync note multi-device confermate; UI conflitti Forui implementata e testata in simulazione, ma non ancora su due device reali; restano tombstone recovery, rebootstrap, REST legacy e possibile background.
- [ ] Notifiche Android e Windows, snooze, recurring, controllo fusi orari.
- [ ] Test E2E PC↔Android, offline, recupero conflitti/riavvio, back-up/restore.

## Valutazione UI library (23 ottobre 2026)

- **Forui** ([GitHub](https://github.com/duobaseio/forui), [pub.dev](https://pub.dev/packages/forui)): candidata preferita per restyle cross-platform Windows+Android, stile minimalista shadcn-like, oltre 50 widget, resizable panes, temi; release 0.26+ richiedono Flutter >=3.47.
- **shadcn_ui** ([pub.dev](https://pub.dev/packages/shadcn_ui)): alternativa valida per personalizzazioni profonde e interfaccia shadcn-style.
- **fluent_ui** ([pub.dev](https://pub.dev/packages/fluent_ui)): migliore per estetica Windows nativa, meno prioritaria per identità uniforme mobile+desktop.
- **Decisione aggiornata 23/10:** **Forui è stata adottata come base UI** con migrazione graduale. L'introduzione non modifica il protocollo sync; test multi-device ancora aperti.

## Forui — design system principale (dal 23 ottobre 2026)

- [x] Decisione adottata: `forui ^0.27.6` come libreria UI principale Flutter. Documentazione [docs/ui-forui.md](docs/ui-forui.md).
- [ ] Tema Forui centralizzato, sidebar, schede note, pulsanti principali e ricerca inseriti nel codice; considerare **verificati** solo dopo CI verde su Windows/Android e prova manuale.
- [ ] Completare migrazione input rapido, checkbox, menu, bottom sheet e pannelli ridimensionabili; **editor task/nota e selettore scadenza migrati a Forui**; test Flutter widget+analyzer riusciti (run 39977182371), build native/device da verificare.
- [ ] Screenshot/test responsive Android e Windows con stato offline/sync e contenuti reali.
- [ ] Sincronizzazione PC↔Android ancora da confermare E2E; la migrazione UI non ne prova il funzionamento.

## P1 — Produttività completa
- [ ] **P1.1 Calendario giorno/settimana/mese** implementato nel codice Flutter `0.5.0+7`, in attesa di CI e verifica hardware; [specifica](docs/P1-CALENDAR.md). 
- [ ] **P1.2 Time blocking**: modello start/end, backend Flyway V8, Flutter Drift V6, editor e sincronizzazione implementati sul branch `feature/p1-2-time-blocking`; CI/hardware/deploy ancora da verificare. [Specifica](docs/P1-TIME-BLOCKING.md).
- [ ] Eisenhower Matrix a quattro quadranti.
- [ ] Kanban con drag & drop.
- [ ] Pomodoro/cronometro e statistiche.
- [ ] Habit tracker, streak, check-in e countdown.
- [ ] Sticky Notes in finestre Windows indipendenti.
- [ ] UI responsive, scorciatoie, tray, temi.

## P2 — Estensioni
- [ ] Timeline/Gantt e filtri avanzati.
- [ ] Import/export e subscription ICS.
- [ ] Collegamento Google Calendar/Outlook con consenso separato.
- [ ] Liste condivise, ruoli, assegnazioni e audit.
- [ ] Allegati con storage S3 compatibile.
- [ ] Widget Android, template, automazioni e analytics.
- [ ] Backup verificato, installer Windows e release Android.

## P3 — Funzioni smart
- [ ] Parsing date/orari in italiano (es. «domani alle 18»).
- [ ] Input vocale e comandi rapidi.
- [ ] Riepiloghi/suggerimenti AI **opzionali**, con controllo privacy.
- [ ] Ottimizzazioni, test di carico e UX.

## Gate immediato e prossimo incremento (23 ottobre 2026)

- [x] Backup reale PostgreSQL, SHA256 e restore temporaneo isolato PASS 24/10. [ ] Offsite non eseguita per scelta, gate separato per release.
- [ ] Controllare API `taskDueSchema:1` e provare Flutter `0.4.0+4` su Windows e Android, senza eliminare SQLite o ripetere migrazioni.
- [ ] Verifica E2E hardware delle liste, tag, priorità, sottotask, sessioni, conflitti e offline con [checklist dedicata](docs/P0-DEVICE-CHECKS.md).
- [ ] Scadenze: primo editor opzionale HH:mm implementato con campo `dueAt` esistente; **ancora pendenti** modello date-only distinto, timezone IANA/DST e test reali. A seguire ricorrenze e notifiche native.
- [ ] Correggere residui di documentazione storica prima dei rilasci, preservando attestazioni e prove precedenti.

## T2 — Flutter e SQLite v5 (implementato nel repository, non distribuito)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Prossimo incremento pianificato — date-only e timezone (23 ottobre 2026)

Specifica **solo progettuale**: [docs/due-dates-timezones.md](docs/due-dates-timezones.md). L'editor HH:mm esistente ha CI Flutter verde; NON distingue ancora mezzanotte esplicita da «solo giorno».

- [x] T0 parziale: backup reale, restore isolato e Flyway V1–V7 verificati. [ ] Offsite (declinata) e test E2E separati.
- [x] T1 backend: **codice, test e bootJar verificati nella [CI 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083)** (commit `1bafec0`), Flyway V7/capabilities/protezione 426. **V7 verificata sul DB reale; API da collaudare.**
- [ ] Verificare API e 426, già gestito da Flutter T2 nel codice; nessun deploy/migrazione automatico.
- [ ] T2: **implementato nel codice**, con value object Flutter `TaskDue`, Drift v5, migrazione SQLite v4→v5, sync capability/426 e test multi-device; convalidare CI e prove fisiche.
- [x] T3 nel codice: Forui date/ora/fuso, DST, filtri Oggi/7 giorni e test. [ ] Prove hardware T4.2.
- [ ] T4: CI, backend-first deploy sicuro ed E2E PC↔Android; solo dopo ricorrenze e notifiche.

## UI cross-platform e regola inline-first (24/10/2026)

- [x] Titoli delle liste, task, note e sottotask con editing diretto; descrizione task e corpo nota inline; aggiornamenti offline-first tramite SQLite/outbox.
- [x] Proprietà semplici del task con popover Forui per priorità/lista, calendario Forui per data, Forui sheet mobile; profilo con menu Forui.
- [x] Richiesta conferma Forui prima di eliminare task/nota/lista; editor avanzato multi-campo disponibile come eccezione.
- [ ] Verifica visuale E2E Windows e Android, focus, DPI, keyboard, outbox e sincronizzazione reale per tutte le modifiche.
- [ ] **Web browser runtime**: Drift nativo e OAuth `dart:io` sono ancora incompatibili con web. Progettare porting database/auth/CI separato (non fingere web pronto).
- [ ] Migrazione residui Material del quick-add e layout, tema chiaro, accessibilità completa.

Dettagli e matrice: [docs/ui-design-audit.md](docs/ui-design-audit.md). Aggiornare i checkbox solo dopo verifica reale del relativo comportamento.

## Handoff e nuova chat

- Partire da [docs/HANDOFF.md](docs/HANDOFF.md), [AGENTS.md](AGENTS.md) e [docs/android-troubleshooting.md](docs/android-troubleshooting.md) per ricostruire lo stato senza cronologia della chat.
- Registrare ciò che è verificato manualmente separatamente dalle build CI; prossimi test: Google Login Android, sync PC↔Android con stesso account, offline, conflitti.

## Convenzioni
- **P0–P3:** priorità di rilascio, non stato di completamento.
- **[ ]** pendente/non verificato; **[x]** fatto e verificato.
- Prima di ogni release: build Windows + Android, API tests, sync offline, notifiche, security review e restore backup.
- Tutti i nuovi moduli devono avere error states, migrazioni e test minimi.

## Edit Timespan
Formato: `AAAA-MM-GG HH:mm TZ | commit <sha> | commento sintetico` (data/ora del commit locale al progetto; hash verificato).
Esempio: `2026-10-21 14:20 CEST | commit abc1234 | Aggiunto modulo promemoria e test`
- 2026-10-21 14:18 CEST | commit 5cadacf | Inizializzazione README; pianificazione P0–P3.
- 2026-10-21 14:20 CEST | commit 549e139e | Creato project.md con roadmap e checklist. 
- 2026-10-21 14:20 CEST | commit 9e73dd13 | Scaffold API, database, Docker Compose, documentazione Flutter e architettura.
- 2026-10-21 14:30 CEST | commit 6ad2df9 | Autenticazione Google server-side, Task API e test unitari.
- 2026-10-21 14:33 CEST | commit 3481644 | UI Flutter locale, note/task e CI Windows.
- 2026-10-21 14:36 CEST | commit e18ae67 | Test di integrazione API con PostgreSQL; fix JWT decoder.
- 2026-10-21 14:39 CEST | commit 4bd2e13 | CI build Android/APK e artefatti Windows, istruzioni deploy.
- 2026-10-21 14:40 CEST | commit 5e970ea | Stato P0, checklist e registro modifiche aggiornati.
- 2026-10-21 14:51 CEST | commit e59fbe95 | README sintetico e design.md con specifiche.
- 2026-10-21 14:54 CEST | commit 42f62529 | Note API, refresh token e versioning task.
- 2026-10-21 14:56 CEST | commit 1529ce6c | Correzione test Spring Boot.
- 2026-10-21 14:59 CEST | commit 4afd5ae0 | Exchange OAuth PKCE desktop nel backend.
- 2026-10-21 15:01 CEST | commit 547f7529 | Login Google Flutter per Android/Windows e secure storage.
- 2026-10-21 15:04 CEST | commit 600c8827 | Drift SQLite, import legacy e outbox.
- 2026-10-21 15:05 CEST | commit 7b50bacb | Fix analyzer per OAuth Windows.
- 2026-10-21 15:10 CEST | commit 5c34fb9f | Protocollo sync idempotente, change log, test API.
- 2026-10-21 15:13 CEST | commit 5235193d | Sync manuale Flutter, delta pull e blocco conflitti.
- 2026-10-21 15:14 CEST | commit a8fa7e2c | Preservazione remoteVersion su modifiche offline.
- 2026-10-21 15:16 CEST | commit 801c9162 | Test SQLite versioni e isolamento account.
- 2026-10-21 15:17 CEST | commit a6d572d2 | Sessione sicura conservata durante disconnessioni.
- 2026-10-21 15:20 CEST | commit e5c5c319 | Allineati README, design, API, architettura e checklist.
- 2026-10-21 15:21 CEST | commit 921ee40e | Consentito il callback OAuth desktop pre-login.
- 2026-10-21 15:23 CEST | commit e15017ad | Ricerca/modifica attività e permesso Internet Android.
- 2026-10-21 18:23 CEST | commit 0fa64e08 | Nuovo Compose root per Coolify, porta API privata, lint Compose CI riuscito.
- 2026-10-21 18:50 CEST | commit 338247dd | Corretta interpolazione dei segreti solo runtime durante build Coolify.
- 2026-10-21 18:51 CEST | commit c06ee07e | Test CI per build senza credenziali e mapping runtime.
- 2026-10-22 14:45 CEST | commit e267ae3a | Registrato deploy backend HTTPS con health UP, build e login Google Windows verificati manualmente; Android e sync multi-device ancora da testare.
- 2026-10-22 15:55 CEST | commit 4c9e2fef | Android avviata su telefono, errore Google Credential Manager [16] diagnosticato; logout Android ora chiude anche sessione Google, guida verifica SHA-1/package/Web Client ID.
- 2026-10-23 14:25 CEST | commit 369a170d | Versionata configurazione Android: package/namespace it.andreadada.simplenotes, Activity Java, Kotlin incremental off, verifiche Flutter CI; APK locale compilato, autorizzazione installazione USB ancora pendente.
- 2026-10-23 14:36 CEST | commit 3d02014c | Disabilitata compilazione Kotlin non necessaria nel modulo app Java; CI Android su JDK 17/21 per evitare mismatch JVM.
- 2026-10-23 14:44 CEST | commit a6397709 | Fix JVM 17/21: target bytecode Java allineato al JDK di Gradle; CI JDK17/JDK21 in verifica.
- 2026-10-23 15:17 CEST | commit 11d08f5b | Handoff completo per nuove chat: AGENTS.md, docs/HANDOFF.md, runbook Android, README/architettura/sync/deploy allineati allo stato verificato; Google Login Android post-fix e sync E2E ancora aperti.
- 2026-10-23 15:44 CEST | commit cd47aac6 | Auto-sync foreground: debounce dopo modifiche, login, resume, rete e pull periodico con backoff.
- 2026-10-23 15:46 CEST | commit 239507b2 | Avatar Google con menu account, claim picture lato backend, migrazione Flyway V4.
- 2026-10-23 15:48 CEST | commit c3332929 | Test revisione modifiche locali e handoff auto-sync.
- 2026-10-23 15:49 CEST | commit ffbcefe0 | Corretto callback di fallback avatar per analyzer Dart.
- 2026-10-23 15:49 CEST | commit 2e8e5be2 | Trigger auto-sync aggiunto anche al completamento attività.
- 2026-10-23 15:52 CEST | commit 32b976d4 | Documentazione onboarding e test menu profilo.
- 2026-10-23 15:52 CEST | commit b47b36c3 | Corretto controllo flusso auto-sync per lint Dart.
- 2026-10-23 16:28 CEST | commit 6a5ef5cf | Fix server sync note senza titolo, test JUnit note su 2 device simulati (backend CI success).
- 2026-10-23 16:30 CEST | commit 8d0c733b | Stato/errori sync e operazioni pendenti visibili anche nel menu profilo Android.
- 2026-10-23 16:32 CEST | commit 87f1ca2f | Test Flutter due database indipendenti: nota PC→Android→PC con mock API.
- 2026-10-23 16:34 CEST | commit cc2b576c | Ripristino sessione Google salvata dopo offline/rientro rete.
- 2026-10-23 16:35 CEST | commit fa93c40d | Valutazione UI Forui/shadcn_ui/fluent_ui, nessuna adozione prima di E2E sync.
- 2026-10-23 16:44 CEST | commit 2d67866b | Forui ^0.27.6 aggiunto, FTheme, tokens dark desktop/touch, sidebar, FTextField, FButton, FCard.
- 2026-10-23 16:46 CEST | commit 761008bc | Forui design system ufficiale documentato in docs/ui-forui.md, README, design, handoff, AGENTS.
- 2026-10-23 16:47 CEST | commit 7e3a5e78 | Corretto costruttore FThemeData, vincolo Dart SDK e ordine argomenti sidebar.
- 2026-10-23 16:49 CEST | commit 3f8f25ce | Test automatici tokens Forui e sidebar desktop.
- 2026-10-23 | commit bed16b48 | Editor attività/nota e picker scadenza migrati da AlertDialog/showDatePicker Material a Forui FDialog/FTextField/FCalendar/FButton.
- 2026-10-23 | commit 8ed6a3f1 | Test modali Forui, date-only e persistenza task; aggiornati ui-forui.md, README Flutter, AGENTS.md e handoff.
- 2026-10-23 | commit cc0a6328 | Risolto overflow header calendario Forui e disposal anticipato controller editor; analyze+widget tests CI 39977182371 riusciti.
- 2026-10-23 | commit 5bbc32c4 / 6ee76330 | Endpoint latest per elemento con scope utente, test backend (versione corretta delle query).
- 2026-10-23 | commit 84c3a248 / 2cdad403 | Risoluzione conflitti Forui, confronto versioni, doppia conferma scelta server, retry sicuro e correzione analyzer.
- 2026-10-23 | commit 82aea37e / 69ff820e | Test due SQLite, edit concorrenti, modalità keep-local/use-server e offline; fix aspettative versioni.
- 2026-10-23 | commit 3f2a3a7d | Descrizioni attività Forui/SQLite/sync, migrazione Drift V3 e test.
- 2026-10-23 | commit 785cd547 / ccb96021 / 77a70efc | Backup e restore isolato PostgreSQL, smoke CI e fix init temporaneo.
- 2026-10-23 | commit 622e3278 | Indice Flyway V5 per latest entity/account.

- 2026-10-23 | commit fbb363a3 / 9443fe3d | Flyway V6 e backend per liste e metadati task; test scope utente e rimozione lista.
- 2026-10-23 | commit d073147c / e51e2737 / 79387d33 | Modelli Flutter, Drift v4, lista CRUD e outbox a ordine deterministico.
- 2026-10-23 | commit b58984fd / 41d41c2f / ddd1325b | Navigazione e filtri liste, editor Forui tag/priorità/sottotask, dettagli interattivi.
- 2026-10-23 | commit 634fbc41 / fd23f1fd | Test Flutter a due device simulati e widget sidebar; analyze/test success CI 39991667611.

- 2026-10-23 | UX design rule inline-edit first: `InlineEditableTitle` condiviso per titoli in-place Windows/Android; rimosso `Rinomina` dal titolo di lista. Specifica vincolante in design.md, AGENTS.md e docs/ui-forui.md. Test widget del salvataggio inline.
- 2026-10-23 | docs audit | Riallineamento README, AGENTS, handoff, architettura, client, P0; nuova checklist real-device e deploy sicuro. Commit di riferimento nella cronologia Git.

- 2026-10-23 | feat(tasks) | Primo editor scadenza HH:mm opzionale via dueAt esistente, senza migrazioni; semantica date-only/timezone esplicita ancora da realizzare. Verifiche CI/hardware separate.

- 2026-10-23 | docs(plan) | Specifica P0 scadenze date-only/datetime/legacy, timezone IANA/DST, backend Flyway V7, Flutter Drift v5, compatibilità old-client e matrice test in `docs/due-dates-timezones.md`. Nessuna migrazione applicata; commit documentale nella cronologia Git.

- 2026-10-23 | commit 1bafec0 | T1 backend: `TaskDue` con date/ora/fuso e DST, Flyway V7 additiva, sync con payload `due`, protezione HTTP 426 old-client, capabilities e test. **Non deployato; Flutter T2 pendente.**

- 2026-10-24 | feat(ui) | Refactoring inline-first su task, note, descrizioni, sottotask e proprietà Forui; menù account Forui, sheet mobile, conferme delete, test Flutter e matrice UI in `docs/ui-design-audit.md`. Web runtime ancora non supportato; verifiche hardware pendenti.

- 2026-10-24 | style(ui) | Commit `7303d45`: rimossi min-width e padding extra dall'underline, larghezza misurata sui glifi di testo o hint anche nei quick-add, placeholder più trasparente e test Flutter dedicati. Regola registrata in `design.md`, audit e guide. Non equivale a rilascio browser.

- 2026-10-24 | fix(ui) | Correzione del parent tight/Expanded: Align libera la larghezza interna del TextField nonostante il contenitore grande; verifica su TextField effettivo, non wrapper. Commit `5f14fce` successivo allo stile `7303d45`. Verifiche CI e native separate.

- 2026-10-24 | fix(ui) | Commit `e55c87b`: la sottolineatura è ora disegnata separatamente dal bordo interno Material con `InlineGlyphUnderline`, seguendo i glifi (anche quando `InputDecorator` impone larghezza minima). Focus blu, default grigio; input border nativo invisibile. Test dedicati su `inline-glyph-underline`; UI web runtime non ancora portato.

- 2026-10-24 | T2 Flutter | TaskDue, Drift v5, sync capability e HTTP 426 senza perdita outbox, test unit/sync/migrazione SQLite popolata. Nessun deploy Coolify; T3 UX e verifiche hardware pendenti.

- 2026-10-24 | T3 | Editor scadenze Forui condiviso quick/dettagli/advanced, IANA e DST fold/gap, filtri a giorni civili, test widget e unitari; V7 nel DB reale; API e test hardware ancora da fare. Vedi `docs/T3-SCADENZE.md`.

- 2026-10-24 | T4 strumenti | Script backup SHA256, restore isolato con receipt, preflight fail-closed, check HTTPS e prova migrazione V6→V7 con Testcontainers in CI. Backup/restore VPS reali eseguiti successivamente; test device ancora da fare; vedi `docs/T4-RELEASE-RUNBOOK.md`.

- 2026-10-24 | T4.2 | Client Flutter `0.4.0+4`: diagnostica locale/cloud nel menu Forui, avvisi HTTP 426, ultimo sync riuscito persistito, test read-only e checklist reale Windows/Android. Backup VPS reale e restore isolato confermati dall'utente, Flyway V7 già presente; E2E fisico da eseguire. [Protocollo](docs/T4-DEVICE-SYNC.md).

- 2026-10-24 | docs(audit) | Audit Markdown sullo stato VPS: PostgreSQL 17.11/Flyway V1–V7, backup `simple-notes-20261024T132857Z-271921.dump` SHA256 e restore isolato PASS. Offsite non effettuata per scelta; API autenticata e T4.2 Windows↔Android ancora da verificare. Flutter CI [40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS. Solo documentazione, nessuna modifica al software o al DB.
- 2026-10-24 | T4.2 build/hardening | `tools/t4-build-devices.ps1` crea APK Android debug e ZIP Windows con stesso commit e OAuth IDs locali da `.t4-device-build.json` ignorato; nessuna installazione/reset/deploy. Flutter `0.4.1+5`; il controllo `_supportsTypedDue()` ora richiede il contratto completo API prima di inviare data/ora; aggiunto test fail-closed. Verificare CI e prove fisiche, ancora non eseguite.
- 2026-10-24 | fix(t4.2) | Lo script per build locali permette working tree tracciati modificati senza cancellarli; segnala build non riproducibile da HEAD nel manifest, supporta `-CheckOnly` e `-RequireClean` opzionale, evita rigenerazione piattaforme se già presenti e non usa cancellazione automatica output di build_runner. Nessuna migrazione/deploy/data reset.
- 2026-10-24 | feat(notes)+tools | Nuovo cestino note, restore versionato tramite backend con controllo capacità, protezione contro delta vecchi, test Flutter/backend; script di reset del SOLO workspace test con conferme e anteprima, locali Windows/Android e dati server. Nessuna cancellazione dati, migrazione o deploy effettuato da ChatGPT. Successivo P1 calendario dopo smoke test.
- 2026-10-25 | feat(p1.1) | Implementato Calendario giorno/settimana/mese su Flutter (TaskDue civili/IANA esistenti, navigazione, task inline, quick-add e test). Reset dati di test confermato dall'utente su server/Windows/Android; nessun deploy o modifica DB svolta dall'assistente. P1.2 time blocking ancora da fare.
- 2026-10-25 | feat(p1.2) | Sviluppo branch P1.2: TimeBlock UTC/IANA come periodo distinto dalla scadenza, PostgreSQL V8, Drift V6, sync capability fail-closed, calendario/editor e test. Non applicato su Coolify né sui device. Dopo CI restano rollout e test reali.
