# AGENTS.md — Istruzioni operative per agenti AI

<!-- CURRENT-STATUS-REF -->
> **Unica fonte operativa:** [docs/CURRENT-STATUS.md](docs/CURRENT-STATUS.md). Al 25/10/2026, `main` include P1.6 (Flutter `0.10.0+12`, Drift V8, Flyway V10); P1.7 Android è integrata con [PR #6](https://github.com/andreadada/simple-notes/pull/6), Flutter `0.11.0+13`: opt-in e scheduler Android inexact, **senza prova E2E reale**; su Windows notifiche disattivate senza MSIX. Ultimo DB Coolify verificato: V8; V9/V10 e accettazione hardware del batch non confermati. Non trasformare versioni storiche in istruzioni correnti.

## Prima di qualsiasi modifica

1. Leggere [CURRENT-STATUS](docs/CURRENT-STATUS.md), [roadmap](project.md), [design](design.md) e la specifica della feature; usare [HANDOFF](docs/HANDOFF.md) solo come cronologia.
2. Confrontare il testo con codice, migrazioni, `apps/flutter/pubspec.yaml`, i workflow GitHub e le PR **più recenti**. Distingere sempre **implementato / CI verde / deploy VPS attestato / device E2E attestato**.
3. L'utente preferisce commit direttamente su `main` quando possibile, lavoro in piccoli incrementi, documentazione aggiornata e test hardware **in un batch finale**, non dopo ogni feature. Non dichiarare effettuato un merge senza verifica GitHub.
4. Non ripetere domande con risposta documentata. Aggiornare roadmap, handoff e registro `Edit Timespan` per cambiamenti funzionali, mantenendo [CURRENT-STATUS](docs/CURRENT-STATUS.md) fonte unica.

## Architettura e invarianti

- Client Flutter Windows/Android in `apps/flutter`: Forui, Riverpod, Drift/SQLite offline-first, `LocalStore` e outbox. Backend Spring Boot Java 21 in `services/api`: Spring Security, Google OAuth, PostgreSQL 17/Flyway e REST sync. Compose esistente in `docker-compose.yml`.
- Ogni modifica funzionale salva realmente in SQLite/outbox. Preservare `boundOwner`, UUID, `operationId`, `remoteVersion`, cursor, pending e tombstone; sincronizzazione idempotente e account isolati.
- Le migrazioni Flyway e Drift sono **additive**, preservano dati reali e offline e vanno testate con fixture esistenti. Non confondere schema su `main` (Flyway V10/Drift V8) con schema realmente applicato su Coolify.
- `TaskDue` ha semantiche `none/date/datetime/legacy`; date-only **non** significa mezzanotte UTC. Conservare IANA/DST, fold/gap, independence delle scadenze dai time block; fino a 12 slot per task e ricorrenze versione P1.6.
- Prima di inviare nuovi payload, verificare `GET /api/v1/capabilities` con JWT: `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`. HTTP **426** blocca la sync conservando l'outbox; HTTP **409** è un conflitto, non un successo. Non usare CRUD legacy per simulare delta-sync.
- P1.7 (PR #6) integra planner UTC, riconciliazione, ledger, permesso Android richiesto solo su opt-in e scheduler inexact. **Non** dichiarare delivery Android con app chiusa verificata, reminder Windows, snooze, deep-link o packaging MSIX pronti: i test fisici e il packaging Windows mancano.

## Regole di design obbligatorie

- **Forui-first**, con UI responsive Windows/Android; nessuna regressione a `showDatePicker` / dialog Material sui percorsi migrati.
- **Inline-edit first:** titolo/lista/task/sottotask/nota/tag/descrizione già visibili diventano editabili in posizione; evitare comandi "Rinomina" e dialog superflui. Salva su Invio/blur, annulla su Esc, valida, conserva bozza e focus anche durante sync.
- Underline neutro a riposo/blu al focus **largo quanto il testo o placeholder**, non fino alla Row; `InlineTextMetrics.fieldWidth` per glifi e `inputWidth` per il campo con margine cursore. Usare `InlineGlyphUnderline`, non `Expanded` full-width per la linea. Non troncare testo e placeholder. Test su stringhe lunghe e mobile stretto.
- `FDialog`/`FSheet` per interazioni composte e distruttive; cancellazioni confermate. Modifica advanced ammessa per più campi correlati; non sacrificare sync o accessibilità.
- Flutter Web **non** è un target operativo finché `dart:io`, Drift native e flussi OAuth desktop non sono sostituiti/collaudati.

## Verifiche, deploy e sicurezza

- Eseguire i test pertinenti e controllare CI per Flutter (analyze, test, build Windows/Android JDK17/21), backend e Compose. Il solo job documenti valida link/consistenza, **non** funzionalità o distribuzione.
- Google: Android package `it.andreadada.simplenotes`, Web Client ID Android, Desktop OAuth Windows; non committare secret, token, credenziali, keystore o `.env`.
- **Mai** cancellare volumi Coolify, dati PostgreSQL, SQLite/outbox, usare `down -v`, `adb uninstall`, `pm clear`, `flyway repair`, `pg_restore` in produzione o reset per sbloccare una feature. Reset dei soli dati test già eseguito il 25/10/2026; non ripeterlo.
- Deploy e prove hardware restano distinti dalle CI. Runbook attuale [P1-RELEASE-BATCH](docs/P1-RELEASE-BATCH.md): inventario DB, backup secondo policy approvata, backend V10 e capability/health prima di Flutter 0.10+, E2E Windows↔Android in batch. Nessun deploy tacito.
- L'offsite non è stato eseguito per scelta dell'utente; backup/restore storico del 24/10 non prova la sicurezza o la freschezza di un nuovo rilascio.
- Prima di concludere, verificare lo SHA effettivo su `main`, gli esiti dei job e il contenuto dei documenti aggiornati; registrare chiaramente le prove mancanti.
