# Simple Notes — Project

**Obiettivo:** app offline-first Windows 11 + Android ispirata alle funzionalità di TickTick, con UI originale, login Google e backend self-hosted su Coolify.
**Stack:** Flutter/Dart + Riverpod + Drift/SQLite; Spring Boot (Java 21) + Spring Security + PostgreSQL/Flyway; REST + sync incrementale + WebSocket; Android FCM; Docker/Coolify.
**Stato:** P0 IN CORSO (backend Coolify HTTPS `UP`, client Windows e Google Login Windows verificati dall'utente; sync manuale sperimentale, release non pronta). Spuntare una voce solo quando implementata **e verificata**; nessuna funzione è completa per definizione.

## Regole vincolanti — COME FARE
- [ ] Lavorare in piccoli commit descrittivi, con test e documentazione aggiornati.
- [ ] Architettura modulare: UI → applicazione → dominio → dati; backend per domini.
- [ ] Offline-first: scrivere prima in SQLite, poi sincronizzare con outbox persistente.
- [ ] API versionate, migrazioni Flyway, UUID, revisioni, idempotenza e soft-delete/tombstone.
- [ ] Login Google verificato lato server; OAuth PKCE su Windows; credenziali e token in storage sicuro.
- [ ] Distinguere layout Windows e Android; testare accessibilità, ridimensionamento e dark/light.
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
- [x] Configurazione Android versionata: applicationId/namespace `it.andreadada.simplenotes`, Gradle Java 17, Kotlin incremental off su dischi differenti, Activity Java e verifica in CI (build da confermare).
- [ ] Verificare su CI con JDK 17/21 l'allineamento bytecode Java/Kotlin: la modifica precedente `enableKotlin = false` non bastava con JDK 21; ora Java segue la JDK di Gradle.
- [ ] Android: APK compilato localmente, installazione tramite USB ancora bloccata dal sistema (`INSTALL_FAILED_USER_RESTRICTED`); verificare permesso sul telefono e ritestare il Google Login.
- [ ] Test end-to-end Google Login con client ID reali su due dispositivi.
- [ ] Verifica client sync PC↔Android con dati reali, recupero errori, conflitti e sync automatica.
- [ ] Notifiche, liste, tag, sottotask, ricorrenze e ricerca completa.
- [x] Backend deployato su Coolify e raggiungibile via HTTPS: health check `https://api.notes.ddone.it/actuator/health` con `UP` (confermato dall'utente).
- [ ] Hardening produzione: backup/restore, rate limiting, controlli di sicurezza e monitoraggio.
- Stato della sync **client**: implementata in modalità manuale sperimentale; verifiche CI/E2E non equivalgono a validazione completa.

## P0 — Fondamenta e MVP
- [x] Inizializzazione repository, README breve, design.md, project.md e documentazione API/sync.
- [x] Bootstrap Flutter Android/Windows + Riverpod + Drift/SQLite e CI.
- [ ] Routing/deep link, UX mobile definitiva e test accessibilità.
- [x] Backend Spring Boot Java 21, PostgreSQL, Flyway, API health (test CI).
- [x] Compose in root `docker-compose.yml` validato con `docker compose config --quiet` (CI run `39634311667`).
- [x] Deployment Coolify HTTPS e health check `UP` verificati dall'utente; NON equivale a validazione di sicurezza per la produzione.
- [x] Windows: compilazione e avvio dell'app, login Google reale verificato; dipendenza C++ ATL installata su Build Tools.
- [ ] Android: Google login e sessione sicura da verificare su dispositivo (app avviata, OAuth in errore codice 16).
- [ ] Persistenza sessione Windows/Android, logout e refresh dopo riavvio da verificare con test E2E.
- [x] Struttura iniziale utenti, task, note, versioni, tombstone, refresh sessions.
- [ ] Liste, tag, sottotask, filtri, scadenze/ricorrenze avanzate e reminder.
- [ ] Sync completa: retry in background, risoluzione conflitti, rebootstrap, più device.
- [ ] Notifiche Android e Windows, snooze, recurring, controllo fusi orari.
- [ ] Test E2E PC↔Android, offline, recupero conflitti/riavvio, back-up/restore.

## P1 — Produttività completa
- [ ] Calendario giorno/settimana/mese e time blocking.
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
