# Audit applicazione di design.md — UI condivisa Flutter

## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

> Aggiornato il 24 ottobre 2026. Questo documento separa **codice implementato**, **verifica CI** e **runtime web realmente disponibile**. Il refactoring non introduce modifiche a PostgreSQL, OAuth o formato dei dati.

## Regola unica su tutte le schermate

- Gli attributi testuali semplici già mostrati si modificano direttamente: tap/click nel contenuto, Enter (campo breve)/perdita del focus per salvare, Esc per annullare. Il corpo multilinea salva al blur oppure Ctrl/Cmd+Enter.
- Componenti `InlineEditableTitle` per titoli/tag, `InlineEditableBody` per descrizioni/note, `InlineQuickAdd` per sottotask e input task rapido. Niente righe a larghezza pagina: `InlineTextMetrics.fieldWidth` misura il testo o, se assente, il placeholder usando font e text-scaling correnti; evita i vecchi `minWidth 84/120` **per la linea**; il viewport interno conserva spazio ulteriore per caret e testo.
- **Regola misurabile:** il segmento sottolineato deve seguire **solo** la larghezza dei caratteri, più ~1px di spazio per il cursore; nessun riempimento. Placeholder semitrasparente `NotesPalette.placeholder` (~72%), sotto gli stessi glifi. Alla selezione la linea diventa blu. Una `Row` può essere larga, ma il campo rimane intrinseco e il resto è vuoto. Anche quando il parent passa constraints stretti, `Align(widthFactor:1)` deve mantenere il `TextField` interno corto. Non misurare il wrapper padre durante i widget test: può rimanere largo quanto la sidebar; il `TextField` stesso può essere dilatato da `InputDecorator`. Per la regola visiva **misurare il widget `inline-glyph-underline`**, creato da `InlineGlyphUnderline` sotto il testo. Il bordo nativo è invisibile; focus e sfondo restano invariati.
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

**Vincoli non ancora completamente raggiunti:** l'editor avanzato dei sottotask resta un modulo multi-campo; l'input task rapido è ancora un `TextField` Material, ma ora rispetta larghezza intrinseca e placeholder semitrasparente. Alcuni componenti strutturali di compatibilità sono Material. Non è ancora presente un tema chiaro, preferenze UI o una validazione visuale manuale su DPI, tastiere virtuali e lettori schermo. Nessuna delle funzionalità future in `design.md` (Pomodoro, Habit, Calendario, etc.) è stata creata da questo refactoring.

## Desktop, Android e web — distinzione obbligatoria

Le schermate sopra risiedono in **un unico client Flutter**, quindi condividono design, widget e logica responsive tra piattaforme **una volta che il runtime della piattaforma è supportato**.

- **Windows desktop / Android:** target già configurati; CI Flutter per analisi, widget e build native. Le modifiche UX vanno verificate visivamente su Windows/Android fisici.
- **Web browser:** **runtime non ancora portato**. `data/app_database.dart` importa `dart:io` e usa `NativeDatabase` di Drift; `auth/cloud_auth.dart` dipende da `dart:io`, `Platform.isAndroid/Windows` e listener loopback per OAuth desktop. Non affermare che una build web funzioni soltanto perché Forui è cross-platform. La UI responsive è *riusabile*, ma l'esecuzione e la sincronizzazione via browser **non sono verificate né supportate**.
- **Work item web separato:** backend adattato a CORS/origini esplicite, auth web Google con flusso adeguato al browser, storage sessione sicuro, Drift web/SQLite WASM con migrazione e isolamento account, bootstrap web, build `flutter build web` in CI, E2E browser e verifica offline/outbox. Non usare localStorage per sostituire silenziosamente SQLite né esporre secret OAuth.

## Check regressione sulla lunghezza esatta della linea

- Task molto corto, es. `A`: la linea **non** si allunga fino alla vecchia lunghezza minima di 84 px; l'underline segue il carattere.
- Input vuoti `Aggiungi tag...`, `Aggiungi una descrizione...`, `Aggiungi sottotask...`: underline della sola scritta di placeholder, resa meno opaca dei valori già salvati.
- Compilazione e inserimento progressivo: la linea cresce quando cresce la stringa, senza banda fino al margine del pannello; al focus resta sottile ma accent.
- Note multilinea e ridimensionamento: misurare ogni riga, rispettare il wrapping e i limiti del pannello; niente overflow su Android o Windows.
- Input task della pagina principale: la linea termina con `Aggiungi attività` e non arriva all'icona calendario a destra.

## Test consigliati

1. Titolo lista/task/nota: digitazione inline, Enter/blur, Esc, whitespace, lunghezza massima e riavvio.
2. Descrizione e corpo nota: input multilinea, Ctrl/Cmd+Enter, Esc e sincronizzazione PC↔Android dopo upload.
3. Priorità, lista, data e subtasks: menù Forui, nessun valore perso in caso di 409; verificare outbox. Creazione/rimozione senza perdita di altri campi.
4. Eliminazione: non cancella senza conferma; annulla conserva record; delete produce tombstone e si propaga con sync.
5. Responsive: finestre desktop da 950 a 1200 px, panel dettagli a 1200+, layout mobile sotto 950 px, DPI alti e keyboard avoidance.
6. Accessibilità: focus e semantica dei TextField/checkbox/popover/sheet, navigazione tastiera, touch target minimo 44–48 dp, contrasto, reduced motion.
7. Solo quando runtime web è pronto: Chrome/Edge, refresh/offline, upload/cambio account e conflitti.

## Stato delle prove

Il lavoro UI è in GitHub, **non equivale a test visivi reali o rilascio web**. La [CI Flutter 40047841376](https://github.com/andreadada/simple-notes/actions/runs/40047841376) sul commit `59e13bc` ha superato **flutter analyze e flutter test**, incluso il test di apertura del menu account Forui. Le build native Windows/Android erano ancora in corso all'ultima verifica. I popover Forui per account, priorità e lista comandano esplicitamente i rispettivi controller. Non confondere questi risultati con validazione visuale o con compatibilità browser end-to-end.

Riferimenti: [design.md](../design.md), [Forui](ui-forui.md), [roadmap](../project.md), [status P0](P0-STATUS.md).
