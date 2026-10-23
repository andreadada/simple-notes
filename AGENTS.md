# AGENTS.md — Istruzioni di lavoro per assistenti AI

Repository: **Simple Notes** — Flutter Windows/Android + Spring Boot/PG su Coolify. Lingua preferita per spiegazioni e documentazione: **italiano**.

**Se questa è una nuova sessione senza contesto**, prima di lavorare leggere nell'ordine:
1. [docs/P0-STATUS.md](docs/P0-STATUS.md) — **stato P0 più recente**, progressi verificati e blocchi.
2. [docs/HANDOFF.md](docs/HANDOFF.md) — storia precedente, non sovrascrivere lo stato recente.
2. [project.md](project.md) — checklist P0–P3 e `Edit Timespan`.
3. [docs/task-organization.md](docs/task-organization.md) — liste/task metadata con Drift v4 e Flyway V6, deploy e test.
4. [docs/ui-forui.md](docs/ui-forui.md) — **Forui base UI ufficiale** e regole di migrazione.
3. [design.md](design.md) — visione prodotto (molte feature future).
4. [docs/architecture.md](docs/architecture.md), [docs/api.md](docs/api.md), [docs/sync.md](docs/sync.md).
5. [apps/flutter/README.md](apps/flutter/README.md), [docs/android-troubleshooting.md](docs/android-troubleshooting.md), [infra/README.md](infra/README.md).

## Criteri di verità

- **La CI non equivale a un test OAuth/sync E2E.** Ultima CI Flutter verificata: [39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440), tutto riuscito, incluso Android JDK 17/21.
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
- Prossima priorità: distribuire il nuovo backend SOLO dopo backup; verificare conflitti/offline su device reali, poi liste/tag/sottotask, reminder, hardening e test restore sul VPS. Avatar Google (claim picture) richiede il backend con migration Flyway V4.

**Su qualsiasi incongruenza tra handoff e codice/CI più recente, verificare e aggiornare la documentazione invece di inventare uno stato.**

- Dialoghi di modifica attività/nota e scadenze usano **FDialog/FCalendar**, con layout in `apps/flutter/lib/ui/notes_dialogs.dart`. Non reintrodurre `showDatePicker`/Material `AlertDialog` nei loro flussi; mantenere test dei picker e date locali.

- Organizzazione P0: le liste sono entità sync `list` vere, non nomi locali; `TaskListEntity`, `LocalTaskList` e task `listId/priority/tags/subtasks` sono obbligatori. Preservare ordine outbox (prima lista, poi task; prima movimento task, poi delete-list) e vincolo owner. Non introdurre delete cascade. Qualsiasi modifica ai modelli richiede migration Flyway/Drift incrementale e test con due client. Leggere `docs/task-organization.md`.
