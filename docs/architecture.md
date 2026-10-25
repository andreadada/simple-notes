# Simple Notes — Architettura applicativa

<!-- CURRENT-STATUS-REF -->
> **Stato codice (25/10/2026):** P1.7 Android integrata su `main` (Flutter `0.11.0+13`, Flyway V10/Drift V8): promemoria nativi inexact e opt-in, CI verde, **senza collaudo reale**. Windows ZIP senza notifiche finché non è pronto MSIX. Ultimo Coolify verificato V8, V9/V10 non attestati. **Fonte unica:** [CURRENT-STATUS.md](CURRENT-STATUS.md). I riferimenti storici più sotto non documentano un deploy attuale.

## Componenti del codice attuale

| Livello | Implementazione | Responsabilità |
|---|---|---|
| UI Windows/Android | Flutter, Forui, Riverpod; `apps/flutter/lib/ui` | Liste, note, task, editor inline, calendario, pianificazione, ricorrenze |
| Persistenza client | Drift/SQLite schema **V8**, `app_database.dart`, `local_store.dart` | Offline-first, revisioni remote, owner, tombstone, outbox durevole |
| Sync | `auto_sync.dart`, `cloud_sync.dart` | Mutazioni idempotenti, delta per cursor, verifica capability, 409 e 426 |
| API | Spring Boot Java 21/Spring Security, `services/api` | OAuth Google, task/note/liste, sync autorizzata per utente |
| Server | PostgreSQL 17 + Flyway **V1–V10 nel repo**; Compose/Coolify | Stato cloud condiviso, versioni, migrazioni additive |

## Modello e migrazioni

- `TaskDue`: `none/date/datetime/legacy`, con date-only civile e timezone IANA/DST, introdotto con Flyway V7 e Drift V5.
- Time blocking: primo intervallo P1.2 con Flyway V8/Drift V6; multi-slot P1.4 (fino a 12) con Flyway V9/Drift V7. I blocchi restano distinti dalle scadenze.
- Ricorrenze P1.6: Flyway V10 (`recurrence_json`) e Drift V8; aggiornamento della **stessa attività/UUID** e del successivo `due` con un solo evento outbox. Nessuna creazione periodica server o notifica nativa.
- Il client moderno controlla `GET /api/v1/capabilities` autenticato (`taskDueSchema`, `timeBlockSchema`, `timeBlocksSchema`, `recurrenceSchema`, tutti 1 nel codice). Un server incompatibile non deve consumare la coda locale.
- Sync canonica: `POST /api/v1/sync/apply`, `GET /api/v1/sync/changes`, `GET /api/v1/sync/latest` per versioni e tombstone. HTTP 426 = upgrade richiesto e pending conservati; HTTP 409 = conflitto da risolvere.
- Non usare il semplice health `UP` per attestare le capability, le migrazioni effettive o il deploy.

## UX e piattaforme

La UI è **Forui-first**. I campi testuali già mostrati sono editabili inline; `InlineTextMetrics.fieldWidth` misura i glifi dell'underline e `inputWidth` garantisce spazio cursore, impedendo clipping. Ogni edit salva tramite `LocalStore` e outbox, non nel solo widget. Le selezioni complesse e le eliminazioni usano dialog/sheet Forui.

Target supportati nel codice: Windows desktop e Android; il web browser non è pronto per via di dipendenze native e OAuth. Le CI coprono test/build, **non** la sincronizzazione su due installazioni reali.

## Stato operativo e documenti

- [Stato corrente e gate](CURRENT-STATUS.md), [protocollo API](api.md), [sync](sync.md)
- [Forui e regole grafiche](ui-forui.md), [design](../design.md), [roadmap](../project.md)
- [Runbook V10](P1-RELEASE-BATCH.md), [check dispositivi](T4-DEVICE-SYNC.md), [handoff storico](HANDOFF.md)

**Deploy non attestato:** VPS verificata fino a V8 il 25/10; migrazioni V9/V10, capability di produzione e acceptance Windows↔Android devono essere controllate prima del prossimo rilascio. Non eseguire reset, cancellare volumi o assumere che `main` sia già su Coolify.
