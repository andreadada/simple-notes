# Simple Notes — Progetto e roadmap

> **Stato operativo 29/10/2026:** P1.16 Responsive su `main` ([PR #17](https://github.com/andreadada/simple-notes/pull/17), Flutter `0.21.0+23`, CI verde). P1.17 Windows Tray **solo sul branch** `feature/p1-17-windows-tray` (`0.22.0+24`, CI/merge/device da verificare). Repo Flyway V10, VPS attestata fino a V8; nessun deploy/reset. [Stato](docs/CURRENT-STATUS.md) · [Tray](docs/P1-WINDOWS-TRAY.md).

<!-- CURRENT-STATUS-REF -->

**Obiettivo:** Windows 11 + Android offline-first, Google OAuth, Flutter/Forui/Drift + Spring Boot/PostgreSQL su Coolify. Regole UX in [design.md](design.md); deploy sicuro in [P1-RELEASE-BATCH.md](docs/P1-RELEASE-BATCH.md). Le checklist sotto includono traguardi storici: `[x]` significa **codice verificato nella CI o prova specifica**, non distribuzione sul VPS.

## Gate corrente (non eseguito)

- [x] P1.7 Android con scheduler inexact, ledger, opt-in e CI verde (PR #6). [ ] Prova fisica Android app chiusa/reboot e controllo permessi; [x] codice packaging MSIX + promemoria Windows integrato (PR #7, CI verde); [ ] test fisici MSIX/identità/dati e firma pubblica.
- [ ] Verificare Flyway V10, health **e** capability su Coolify prima di nuovi client.
- [ ] Eseguire il collaudo E2E Windows↔Android **solo a fine batch**, preservando database e dati locali.
- [ ] Concludere hardening, signing, offsite secondo decisione esplicita prima di release pubblica.

## Regole vincolanti — COME FARE
- [ ] Lavorare in piccoli commit descrittivi, con test e documentazione aggiornati.
- [ ] Architettura modulare: UI → applicazione → dominio → dati; backend per domini.
- [ ] Offline-first: scrivere prima in SQLite, poi sincronizzare con outbox persistente.
- [ ] API versionate, migrazioni Flyway, UUID, revisioni, idempotenza e soft-delete/tombstone.
- [ ] Login Google verificato lato server; OAuth PKCE su Windows; credenziali e token in storage sicuro.
- [ ] Distinguere layout Windows e Android; testare accessibilità, ridimensionamento e dark/light.
- [x] **Design rule inline-edit first:** se un titolo/nome/attributo semplice è già visibile, renderlo editabile sul posto, senza bottone/modale Rinomina. Invio/blur salva, Esc annulla; validazione e SQLite/outbox sempre obbligatori. Eccezioni per form complessi o distruttivi.
- [x] **Design rule larghezza esatta:** testo senza sfondo, sottolineatura neutra solo larga quanto valore/placeholder (non il contenitore; ~1px per cursore), blu al focus, placeholder semitrasparente (~72%). Implementazione condivisa `InlineTextMetrics.fieldWidth` in `notes_theme.dart`, utilizzata da titolo, descrizione, note, tag, sottotask e input task rapido; vedi `design.md` / `docs/ui-forui.md`. Il codice è nel commit `7303d45`; CI e test real-device da registrare separatamente.
- [x] **Fondamenta promemoria:** fusi IANA/DST, ricorrenze, deduplicazione e delivery Android P1.7 implementate; prove hardware ancora pendenti. Windows MSIX integrato su `main` in PR #7 (CI verde), installazione reale da verificare.
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
- [x] **P1.1 Calendario giorno/settimana/mese** integrato su `main` (implementazione iniziale Flutter `0.5.0+7`), CI della linea P1 successiva verde; E2E hardware ancora aperto; [specifica](docs/P1-CALENDAR.md). 
- [x] **P1.2 Time blocking**: PR #1 integrata su `main`, Flyway V8/Drift V6; CI riuscita, verifica deploy/hardware del batch ancora aperta. [Specifica](docs/P1-TIME-BLOCKING.md).
- [x] **P1.3 Interazioni calendario**: PR #2 integrata su `main`, Flutter 0.7; hardware non ancora verificato. [Specifica](docs/P1-CALENDAR-INTERACTIONS.md).
- [x] **P1.4 Multi-block + riepilogo**: PR #3 integrata in main; 12 slot per attività, Flyway V9/Drift V7, CI superate. Deploy e collaudo hardware ancora da verificare. [Specifica](docs/P1-MULTI-BLOCKS.md).
- [x] **P1.5 Pianificazione rapida e filtri**: PR #4 unita in `main` (Flutter `0.9.0+11`, CI verde), hardware non collaudato. [Specifica](docs/P1-QUICK-PLANNING.md).
- [x] **P1.6 Ricorrenze**: PR #5 integrata, Flutter 0.10/Flyway V10/Drift V8, CI completa verde; deploy ancora da verificare. [Specifica](docs/P1-RECURRENCE.md).
- [x] **P1.7 Android nel codice**: PR #6 integrata, Flutter 0.11, scheduler inexact e ledger opt-in; CI verde, test fisici non eseguiti. [x] Windows MSIX integrato con PR #7 (Flutter 0.12, CI verde), [ ] cancellazione e upgrade reali da verificare. [Specifica](docs/P1-REMINDERS-FOUNDATION.md).
- [x] **P1.8 Matrice Eisenhower nel codice:** PR #8 integrata su `main`, Flutter `0.13.0+15`; 4 quadranti responsive, classificazione P2/P3 e scadenza, editing inline/Forui, test CI verdi. [ ] Test E2E Windows/Android reali. [Specifica](docs/P1-EISENHOWER.md).
- [x] **P1.9 Kanban per liste:** [PR #10](https://github.com/andreadada/simple-notes/pull/10) su main, Flutter `0.14.0+16`, CI verde. Inbox/liste, drag/drop Windows/Android, menu spostamento, editor e aggiunta inline. [ ] Device E2E non ancora verificati. [Specifica](docs/P1-KANBAN.md).
- [x] **P1.10 Pomodoro locale e statistiche:** PR #11 integrata su main, Flutter `0.15.0+17`, CI verde; timer 25/5/15, pausa/ripresa, dati per account e statistiche device-only. Test reali/upgrade ancora aperti. **Statistiche device-only, non sincronizzate.** [Specifica](docs/P1-POMODORO.md).
- [x] **P1.11 Habit Tracker locale:** PR #12 integrata su `main`, Flutter `0.16.0+18`, CI verde; check-in e streak, 7/30 giorni, archiviazione e dati **solo locali**. Test hardware ancora aperti. [Specifica](docs/P1-HABITS.md).
- [x] **P1.12 Countdown eventi:** PR #13 integrata su `main`, Flutter `0.17.0+19`, CI verde; data civile/ora IANA, edit inline, archivio reversibile. Device test e upgrade dati ancora aperti. [Specifica](docs/P1-COUNTDOWNS.md).
- [x] **P1.13 Obiettivi settimanali Habit:** PR #14 integrata su `main`, Flutter `0.18.0+20`, CI verde; target 1–7 giorni, streak e storico JSON retrocompatibile. Test fisici aperti. [Specifica](docs/P1-WEEKLY-HABITS.md).
- [ ] Habit sync cross-device e notifiche Countdown (futuri, non implementati).
- [x] **P1.14 Sticky Notes Windows:** PR #15 su `main`, Flutter `0.19.0+21`, CI verde; editing inline in finestre indipendenti con stesso LocalStore. Device ancora da collaudare. [Specifica](docs/P1-STICKY-WINDOWS.md).
- [x] **P1.15 Scorciatoie desktop:** PR #16 integrata su `main`, Flutter `0.20.0+22`, CI Flutter/Markdown verde; Ctrl+1..5, Ctrl+Shift+T/N, Ctrl+/ guida Forui. Test PC reale da fare. [Specifica](docs/P1-DESKTOP-SHORTCUTS.md).
- [x] **P1.16 Responsive Windows/Android:** PR #17 merged su `main`, Flutter `0.21.0+23`, CI verde. Test hardware aperti. [Specifica](docs/P1-RESPONSIVE.md).
- [ ] **P1.17 Windows Tray:** icona tray, hide-on-close, riapri e uscita esplicita; branch `feature/p1-17-windows-tray`, Flutter candidata `0.22.0+24`, CI/merge/hardware aperti. [Specifica](docs/P1-WINDOWS-TRAY.md).
- [ ] Temi chiaro/scuro e altre rifiniture future.

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

## Cronologia — gate del 23 ottobre 2026 (non operativo)

- [x] Backup reale PostgreSQL, SHA256 e restore temporaneo isolato PASS 24/10. [ ] Offsite non eseguita per scelta, gate separato per release.
- [ ] Controllare API `taskDueSchema:1` e provare Flutter `0.4.0+4` su Windows e Android, senza eliminare SQLite o ripetere migrazioni.
- [ ] Verifica E2E hardware delle liste, tag, priorità, sottotask, sessioni, conflitti e offline con [checklist dedicata](docs/P0-DEVICE-CHECKS.md).
- [ ] Scadenze: primo editor opzionale HH:mm implementato con campo `dueAt` esistente; **ancora pendenti** modello date-only distinto, timezone IANA/DST e test reali. A seguire ricorrenze e notifiche native.
- [ ] Correggere residui di documentazione storica prima dei rilasci, preservando attestazioni e prove precedenti.

## Cronologia — T2 Flutter/SQLite v5 (schema storico)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Cronologia — date-only e timezone (23 ottobre 2026, implementato)

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
- 2026-10-25 | feat(p1.3) | Branch separato P1.3 per trascinamento e resize della timeline, drop su altri giorni, DST e test; senza migrazioni aggiuntive. Non deployato né integrato su main; P1.2 resta prerequisito di rollout.
- 2026-10-25 | feat(p1.4–p1.6) | PR #3–#5 fuse su main: multi-blocco Flyway V9/Drift V7, pianificazione rapida, ricorrenze Flyway V10/Drift V8, Flutter 0.10. CI verdi; server verificato soltanto a V8 e collaudo hardware non attestato.
- 2026-10-25 | feat(p1.7) | PR #6 (merge `df40b93e`): Flutter 0.11.0+13, planner promemoria, ledger e reconciler, opt-in Android con permessi e alarm inexact, cancellazione prima del logout, receiver reboot. CI [40231569864](https://github.com/andreadada/simple-notes/actions/runs/40231569864) verde su analyze/test, Android JDK17/21 e Windows release. Windows reminder disabilitati fino a MSIX; nessun E2E fisico o deploy.
- 2026-10-25 | docs(p1.7) | Allineati i 31 file Markdown, `CURRENT-STATUS.md` e runbook V10: distinguere codice, CI e distribuzione reale; prossimo gate Windows MSIX e Android E2E finale. Nessun reset o deploy.

- 2026-10-26 | feat(p1.7-windows) | Branch Windows MSIX: opt-in limitato a package identity, scheduler/ledger condiviso con Android, packaging MSIX CI; nessun dato cancellato, nessun deploy, verifica CI e test Windows reali ancora aperti.

- 2026-10-26 | feat(p1.8) | Quattro quadranti Eisenhower calcolati dai campi task correnti, Forui Windows/Android, modifica inline titolo/priorità/scadenza, conferma completamento, test della logica. Branch `feature/p1-8-eisenhower-matrix`, Flutter 0.13, CI+merge ancora da verificare. Nessuna migrazione, reset o deploy.

- 2026-10-26 | docs(audit) | PR #8 P1.8 integrata su main dopo CI Windows/Android e Markdown verdi. Audit dei 32 documenti Markdown: stato canonico unico, status storici chiariti, roadmap e rollout versioni aggiornati. Coolify resta non attestato oltre V8; nessun deploy o reset.

- 2026-10-26 | feat(p1.9)+docs | Branch P1.9 Kanban per liste esistenti (cross-column drag/drop, alternativa menu, inline edits, outbox invariata), Flutter 0.14.0+16; nuova guida [OPERATIONS.md](docs/OPERATIONS.md) per Windows/Coolify/Android e gates reali, nessun deploy/reset. CI, merge ed E2E da confermare.

- 2026-10-26 | feat(p1.10) | PR #10 P1.9 Kanban integrata dopo CI verde. Nuovo branch P1.10 Pomodoro: state machine 25/5/15, dedup session ID, UTC deadline e recupero al rientro, SharedPreferences per owner, statistiche di 7 giorni; nessuna modifica a SQLite/Flyway, Coolify o outbox. CI/merge/test hardware da verificare. [Specifica](docs/P1-POMODORO.md).

- 2026-10-26 | feat(p1.11) | PR #11 Pomodoro integrata in main, CI verde. Nuovo branch Habit Tracker 0.16: check-in su date civili, streak, archivio ripristinabile, proprietario locale isolato, nessun Flyway/Drift/Cloud change. Allineamento documentazione, CI/merge e device test restano distinti; nessun deploy o reset. [Specifica](docs/P1-HABITS.md).

- 2026-10-26 | feat(p1.12) | PR #12 P1.11 merged dopo CI Flutter/Markdown verde. Countdown civili/IANA, store local owner-scoped, archivio reversibile e test sul branch `feature/p1-12-countdowns-main`, Flutter 0.17.0+19. Nessun deploy/reset o migrazione; CI e prove hardware aperte. [Specifica](docs/P1-COUNTDOWNS.md).

- 2026-10-26 | feat(p1.13) | Countdown PR #13 integrata su main, CI verde. Implementati nel branch settimanale 1–7 giorni, barra, streak lunedì–domenica e migrazione compatibile da P1.11 JSON schema 1; Flutter 0.18.0+20, nessuna nuova API/Flyway/Drift né deploy. CI/merge/device da verificare. [P1.13](docs/P1-WEEKLY-HABITS.md).

- 2026-10-26 | feat(p1.14) | P1.13 PR #14 merged dopo CI verde. Branch Sticky Windows 0.19: plugin desktop multiwindow, runner nativo registrazione engine, bootstrap subwindow senza DB, edit titolo/corpo via LocalStore principale con guard conflitti, test e doc. Nessun deploy/reset. [Specifica](docs/P1-STICKY-WINDOWS.md).

- 2026-10-26 | feat(p1.15) | P1.14 PR #15 merged dopo CI verde. Nuova P1.15 Windows: navigazione tastiera, nuova nota via LocalStore, focus nuovo task e help Forui, test policy/widget, versione 0.20.0+22. Nessun deploy, migration o reset. [Specifiche](docs/P1-DESKTOP-SHORTCUTS.md).

- 2026-10-28 | feat(p1.16) | PR #16 scorciatoie Windows merged con CI Flutter e Markdown verdi. P1.16 responsive 0.21: griglia note Wrap a 1/2/3 colonne con larghezza contenuto, inline editing/outbox invariati, test 320/390/1110/1600. Nessuna migrazione/deploy/reset. [Specifica](docs/P1-RESPONSIVE.md).

- 2026-10-29 | feat(p1.17) | P1.16 PR #17 merged con CI verde. P1.17 Windows Tray: sistema hide, restore e uscita esplicita, isolamento Sticky, fallback su plugin; nessuna migration, deploy o reset. [Specifica](docs/P1-WINDOWS-TRAY.md).
