# Architettura — stato reale (23 ottobre 2026)

> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

> Questo file riassume il codice sul branch `main`; le verifiche di deploy e hardware sono in [P0-STATUS.md](P0-STATUS.md) e [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md). Lo stato CI non dimostra la presenza delle migrazioni sul Coolify reale.

## T2 — aggiornamento Flutter e compatibilità (24/10/2026)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Client
- Flutter Windows 11 e Android con **Forui** come design system principale; alcuni widget Material rimangono come bridge.
- Stato Riverpod; SQLite/Drift **schema v5** per task, note, liste, priorità, tag, sottotask, descrizioni, revisioni e coda outbox.
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
- Test CI sintetici e prove reali distinti: backup SHA256 e restore isolato PASS sul DB reale il 24/10. Offsite non effettuata per scelta; API/hardware da controllare.
- P0 non pronta per rilascio: mancano prove di conflitti/retry reali, scadenze con ora/timezone, ricorrenze, notifiche Android/Windows, rate limiting, release signing, monitoraggio e UX/accessibilità complete.
- Non cancellare SQLite/outbox per forzare la sync e non redeployare prima del backup.

## Riferimenti
- [Project e checklist](../project.md) · [Handoff](HANDOFF.md) · [API](api.md) · [Sync](sync.md) · [Forui](ui-forui.md) · [Organizzazione task](task-organization.md)
