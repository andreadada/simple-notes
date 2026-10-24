# Architettura — stato reale (23 ottobre 2026)

> Questo file riassume il codice sul branch `main`; le verifiche di deploy e hardware sono in [P0-STATUS.md](P0-STATUS.md) e [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md). Lo stato CI non dimostra la presenza delle migrazioni sul Coolify reale.

## Client
- Flutter Windows 11 e Android con **Forui** come design system principale; alcuni widget Material rimangono come bridge.
- Stato Riverpod; SQLite/Drift **schema v4** per task, note, liste, priorità, tag, sottotask, descrizioni, revisioni e coda outbox.
- Ogni mutazione viene salvata prima localmente; l'outbox persistente invia operazioni idempotenti a `/api/v1/sync/apply` e scarica i delta da `/api/v1/sync/changes`.
- **Auto-sync foreground**: modifiche, login/ripristino, ritorno online, resume e pull periodico (60 s), con backoff; comando di sync manuale nel menu avatar.
- UI Forui per i conflitti 409: confronto locale/server e scelta esplicita, doppia conferma per usare la versione server. Il recupero edit-vs-delete non è ancora completo.
- Titolo delle liste modificabile inline con `InlineEditableTitle` in header mobile e desktop, senza pulsante Rinomina.

## Backend
- Monolite Spring Boot Java 21, Spring Security, OAuth Google validato server-side, refresh session ruotate, PostgreSQL 17 e Flyway.
- HTTPS su `https://api.notes.ddone.it` tramite Coolify; health `UP` confermato in precedenza. **Versione effettivamente distribuita e Flyway V5+V6 da verificare prima dei client aggiornati.**
- Log cambiamenti per account con serializzazione e versioning, tombstone, isolamento degli utenti. `/sync/latest` (Flyway V5) per conflitti e `entityType:list` (Flyway V6) per liste vere e metadata task.
- Endpoint REST legacy CRUD non alimentano ancora il change log di sync: i client multi-device devono usare il protocollo sync.

## Convenzioni grafico-input (24/10/2026)

I widget `InlineEditableTitle`, `InlineEditableBody`, `InlineQuickAdd` e l'input rapido in `main.dart` usano un solo helper `InlineTextMetrics.fieldWidth` da `notes_theme.dart` per determinare la larghezza esatta del testo o del placeholder. Non usare `Expanded(child: TextField)`, `minWidth` artificiali o padding extra che allunghino l'underline oltre i glifi. Sottolineatura grigia sottile a riposo, blu al focus; nessun riempimento; placeholder `NotesPalette.placeholder` semitrasparente (~72%). Queste regole sono codificate in `design.md` e `docs/ui-forui.md`. Il design Flutter è condiviso dai target Windows e Android, ma il browser web non è ancora disponibile.

## Verifiche e limiti
- Login Windows e note PC↔Android confermati dall'utente; task Android→Windows osservati.
- CI backend e Flutter (inclusi APK debug Android JDK 17/21 e build Windows) riuscite sugli incrementi descritti; nessuna CI equivale a test reali su due dispositivi.
- Script dump e restore isolato PostgreSQL verificati in CI con dati sintetici; backup reale, offsite e restore isolato del database Coolify ancora pendenti.
- P0 non pronta per rilascio: mancano prove di conflitti/retry reali, scadenze con ora/timezone, ricorrenze, notifiche Android/Windows, rate limiting, release signing, monitoraggio e UX/accessibilità complete.
- Non cancellare SQLite/outbox per forzare la sync e non redeployare prima del backup.

## Riferimenti
- [Project e checklist](../project.md) · [Handoff](HANDOFF.md) · [API](api.md) · [Sync](sync.md) · [Forui](ui-forui.md) · [Organizzazione task](task-organization.md)
