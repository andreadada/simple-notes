# AGENTS.md — Istruzioni di lavoro per assistenti AI

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
- Non riaprire il vecchio dialog `Modifica nota`; il corpo e il titolo della nota sono inline nella card. Non eliminare task/note senza conferma Forui.
- I metodi `LocalStore.renameTask/setTask*/renameNote/setNoteBody/renameSubtask` devono preservare SQLite/outbox e gli attributi non modificati. Eseguire `flutter analyze`, `flutter test` e build Windows/Android in CI.
- **Web non è dichiarabile pronto:** il progetto usa ancora `dart:io`/Drift Native/OAuth desktop; UI condivisa ≠ app browser funzionante. Leggere `docs/ui-design-audit.md` prima di affermare supporto web.

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
- T1 backend `TaskDue`/Flyway V7/protezione 426/capabilities aggiunto nel commit `1bafec0`; **non distribuito**. In T2 il Flutter client deve leggere `/api/v1/capabilities`, gestire 426 senza perdita di outbox e migrare Drift v4→v5. Prima del deploy backup/restore reale.
- Prossima priorità: **prima** backup PostgreSQL reale e restore isolato/offsite, **poi** deploy backend V5+V6 e verifica PC↔Android (liste, tag, sottotask, conflitti/offline e sessioni). Solo dopo, scadenze con orario e fusi, ricorrenze e reminder nativi. Vedere `docs/P0-DEVICE-CHECKS.md`; non presupporre che Coolify abbia già applicato V6. Avatar Google (claim picture) richiede il backend con migration Flyway V4.

**Su qualsiasi incongruenza tra handoff e codice/CI più recente, verificare e aggiornare la documentazione invece di inventare uno stato.**

- Dialoghi di modifica attività/nota e scadenze usano **FDialog/FCalendar**, con layout in `apps/flutter/lib/ui/notes_dialogs.dart`. Non reintrodurre `showDatePicker`/Material `AlertDialog` nei loro flussi; mantenere test dei picker e date locali.

- Organizzazione P0: le liste sono entità sync `list` vere, non nomi locali; `TaskListEntity`, `LocalTaskList` e task `listId/priority/tags/subtasks` sono obbligatori. Preservare ordine outbox (prima lista, poi task; prima movimento task, poi delete-list) e vincolo owner. Non introdurre delete cascade. Qualsiasi modifica ai modelli richiede migration Flyway/Drift incrementale e test con due client. Leggere `docs/task-organization.md`.
