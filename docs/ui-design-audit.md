# Audit applicazione di design.md — UI condivisa Flutter

> Aggiornato il 24 ottobre 2026. Questo documento separa **codice implementato**, **verifica CI** e **runtime web realmente disponibile**. Il refactoring non introduce modifiche a PostgreSQL, OAuth o formato dei dati.

## Regola unica su tutte le schermate

- Gli attributi testuali semplici già mostrati si modificano direttamente: tap/click nel contenuto, Enter (campo breve)/perdita del focus per salvare, Esc per annullare. Il corpo multilinea salva al blur oppure Ctrl/Cmd+Enter.
- Componente `InlineEditableTitle` per titoli e tag; `InlineEditableBody` per testo lungo; `InlineQuickAdd` per sottotask. Niente campo a larghezza pagina per titoli corti.
- Tutti gli aggiornamenti richiamano `LocalStore` e **scrivono realmente in SQLite/outbox**; non basta aggiornare il widget. I metodi dedicati leggono lo stato task più recente per non sovrascrivere altri attributi della stessa attività.
- Per dati non testuali usare selettori mirati Forui (priorità, lista, data). Dialog Forui solo per azioni distruttive, creazione di una nuova lista e modifica avanzata multi-campo.
- Il percorso di creazione rapida delle attività e alcuni widget del contenitore `MaterialApp/Scaffold` restano bridge Material dichiarati, **non** nuovi flussi in Material.

## Stato per area UI

| Area | Comportamento attuale nel codice | Persistenza |
| --- | --- | --- |
| Sidebar e intestazione lista | `InlineEditableTitle` già presente; FSidebar Forui | `renameList` → SQLite/outbox |
| Riga task | Titolo direttamente modificabile; `FCheckbox` per completamento | `renameTask` / `toggleTask` |
| Dettagli task | Titolo e descrizione inline; data con calendario Forui; priorità/lista via `FPopoverMenu`; tag editabili nel testo | `setTask*`, `renameTask` |
| Sottotask | Titolo inline, `FCheckbox`, aggiunta diretta e rimozione per elemento | `renameSubtask`, `addSubtask`, `removeSubtask`, `toggleSubtask` |
| Note | Titolo e corpo scrivibili direttamente nella card `FCard`; eliminato il passaggio nel dialog `Modifica nota` | `renameNote`, `setNoteBody` |
| Eliminazioni | Conferma Forui per task, note e lista | Tombstone/offline-first preesistenti |
| Account e sync | `FPopoverMenu` unico su sidebar desktop e AppBar mobile; stato e azioni autentiche | Auth/sync preesistenti |
| Dettagli mobile | `showFSheet` Forui invece di `showModalBottomSheet` Material | Stesso `LocalStore` |
| Editor avanzato task | Resta un `FDialog` Forui per modificare più campi nella stessa operazione | `editTask` |

**Vincoli non ancora completamente raggiunti:** l'editor avanzato dei sottotask resta un modulo multi-campo; il quick-add principale e alcuni componenti strutturali di compatibilità sono Material. Non è ancora presente un tema chiaro, preferenze UI o una validazione visuale manuale su DPI, tastiere virtuali e lettori schermo. Nessuna delle funzionalità future in `design.md` (Pomodoro, Habit, Calendario, etc.) è stata creata da questo refactoring.

## Desktop, Android e web — distinzione obbligatoria

Le schermate sopra risiedono in **un unico client Flutter**, quindi condividono design, widget e logica responsive tra piattaforme **una volta che il runtime della piattaforma è supportato**.

- **Windows desktop / Android:** target già configurati; CI Flutter per analisi, widget e build native. Le modifiche UX vanno verificate visivamente su Windows/Android fisici.
- **Web browser:** **runtime non ancora portato**. `data/app_database.dart` importa `dart:io` e usa `NativeDatabase` di Drift; `auth/cloud_auth.dart` dipende da `dart:io`, `Platform.isAndroid/Windows` e listener loopback per OAuth desktop. Non affermare che una build web funzioni soltanto perché Forui è cross-platform. La UI responsive è *riusabile*, ma l'esecuzione e la sincronizzazione via browser **non sono verificate né supportate**.
- **Work item web separato:** backend adattato a CORS/origini esplicite, auth web Google con flusso adeguato al browser, storage sessione sicuro, Drift web/SQLite WASM con migrazione e isolamento account, bootstrap web, build `flutter build web` in CI, E2E browser e verifica offline/outbox. Non usare localStorage per sostituire silenziosamente SQLite né esporre secret OAuth.

## Test consigliati

1. Titolo lista/task/nota: digitazione inline, Enter/blur, Esc, whitespace, lunghezza massima e riavvio.
2. Descrizione e corpo nota: input multilinea, Ctrl/Cmd+Enter, Esc e sincronizzazione PC↔Android dopo upload.
3. Priorità, lista, data e subtasks: menù Forui, nessun valore perso in caso di 409; verificare outbox. Creazione/rimozione senza perdita di altri campi.
4. Eliminazione: non cancella senza conferma; annulla conserva record; delete produce tombstone e si propaga con sync.
5. Responsive: finestre desktop da 950 a 1200 px, panel dettagli a 1200+, layout mobile sotto 950 px, DPI alti e keyboard avoidance.
6. Accessibilità: focus e semantica dei TextField/checkbox/popover/sheet, navigazione tastiera, touch target minimo 44–48 dp, contrasto, reduced motion.
7. Solo quando runtime web è pronto: Chrome/Edge, refresh/offline, upload/cambio account e conflitti.

## Stato delle prove

Il lavoro UI è in GitHub, **non equivale a test visivi reali o rilascio web**. Consultare [GitHub Actions Flutter](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml) per l'ultimo risultato esatto: non confondere build native e test widget con compatibilità browser end-to-end.

Riferimenti: [design.md](../design.md), [Forui](ui-forui.md), [roadmap](../project.md), [status P0](P0-STATUS.md).
