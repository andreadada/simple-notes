# Simple Notes — Project

**Obiettivo:** app offline-first Windows 11 + Android ispirata alle funzionalità di TickTick, con UI originale, login Google e backend self-hosted su Coolify.
**Stack:** Flutter/Dart + Riverpod + Drift/SQLite; Spring Boot (Java 21) + Spring Security + PostgreSQL/Flyway; REST + sync incrementale + WebSocket; Android FCM; Docker/Coolify.
**Stato:** P0 IN CORSO. Spuntare una voce solo quando implementata **e verificata**; nessuna funzione è completa per definizione.

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

## P0 — Fondamenta e MVP
- [x] Inizializzare il repository e la documentazione.
- [ ] Bootstrap Flutter Android/Windows; Riverpod, routing, Drift.
- [ ] Backend Spring Boot Java 21, PostgreSQL, Flyway, API health.
- [ ] Docker Compose e prima prova di deployment Coolify.
- [ ] Login Google Android, Windows (browser + PKCE), sessioni sicure.
- [ ] Modelli utenti, liste, task, note, tag, ricorrenze, reminder.
- [ ] CRUD task, sottotask, liste, note e ricerca.
- [ ] Sync offline-first: outbox, cursor, revisioni, tombstone, conflitti.
- [ ] Notifiche Android e Windows, snooze, recurring.
- [ ] Test end-to-end PC ↔ Android, offline, conflitti, riavvio.

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
