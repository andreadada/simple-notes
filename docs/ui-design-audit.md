# Audit applicazione di design.md — UI condivisa Flutter

<!-- CURRENT-STATUS-REF -->
> **Stato operativo 29/10/2026:** P1.16 Responsive integrata su `main` ([PR #17](https://github.com/andreadada/simple-notes/pull/17), Flutter `0.21.0+23`, CI verde). P1.17 Windows Tray candidata su `feature/p1-17-windows-tray`, Flutter `0.22.0+24`, CI/merge/device aperti. Repo Flyway V10, ultima VPS attestata V8, nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Tray](P1-WINDOWS-TRAY.md).


> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Editor scadenze Forui e calendario civile (24/10/2026)

Un editor condiviso `task_due_editor.dart` ora gestisce data senza ora, data/ora+IANA, conversione esplicita `legacy` e fold/gap dell'ora legale. `task_due_clock.dart` calcola le possibilità UTC senza arrotondamenti nascosti e tenta di rilevare il fuso OS (in caso di errore richiede una selezione); `task_due_view.dart` centralizza le etichette e i filtri per giorni di calendario. Tutte le scritture T3 utilizzano SQLite/outbox; nessuna migrazione Coolify è stata eseguita. [Specifiche T3](T3-SCADENZE.md).


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

## Aggiornamento audit P1.8 (26 ottobre 2026)

La Matrice Eisenhower usa Forui per card/menu e `InlineEditableTitle` per il titolo; due colonne su desktop e una su mobile. Le modifiche di priorità/scadenza/completamento passano da `LocalStore`. La CI Flutter di PR #8 è verde, ma non documenta una verifica visiva su hardware o compatibilità degli upgrade MSIX. [Specifica P1.8](P1-EISENHOWER.md).

## P1.10 — Timer Pomodoro (branch, device-only)

Timer 25/5/15 e statistiche locali, identità Google isolata nelle chiavi SharedPreferences, ID sessione per impedire doppi conteggi. Nessun endpoint, outbox, SQLite/Flyway schema o sync dedicata. La CI del branch e i test device restano separati dalla compilazione di P1.9. [Specifiche](P1-POMODORO.md).

## Stato del design P1.11 (candidato)

Habit Tracker usa FCard/FCheckbox/FButton, InlineQuickAdd e InlineEditableTitle, con progressivo oggi, streak e selettori di date civili. Verificare su hardware: rientro dopo cambio giorno, overflow su Android stretto, interazione tastiera e touch, archiviazione reversibile e isolamento account. CI widget automatizzata da confermare su SHA finale. [P1.11](P1-HABITS.md).

## Verifica UI P1.12 candidata

Countdown usa FCard/FButton, `InlineEditableTitle`, `InlineQuickAdd` e l'editor Forui delle date condiviso. Da testare su hardware: dialogo DST, overflow Android, countdown scaduto, modifica inline, archivio e persistenza dopo ZIP→MSIX. CI compilazione non equivale a prova visuale. [Specifica](P1-COUNTDOWNS.md).

## Audit P1.13 (branch)

Nella card Forui degli Habit il menu obiettivo sceglie 1–7 giorni/settimana; sotto sono visibili progresso e streak delle settimane, senza introdurre modali per rinominare. Verificare test mobile stretto, tastiera, menu, overflow e non perdita delle date durante edit/archiviazione. Nessun test hardware attestato. [P1.13](P1-WEEKLY-HABITS.md).

## P1.14 — Pop-out Sticky Notes

Comando apri finestra soltanto sulle card Note di Windows; editor inline titolo/corpo e pulsante Ricarica nel detached window, avviso sui conflitti. Controllare UX in Windows reale (ridimensionamento, keyboard focus, più note, principale chiusa); Flutter CI e build non sono test di interazione manuale. [Specifica](P1-STICKY-WINDOWS.md).

## P1.15 — Scorciatoie e help Forui

Icona tastiera nell'header Windows e dialogo Forui tramite Ctrl+/. Ctrl+1..5 cambia sezione, Ctrl+Shift+T mette il focus sul nuovo task, Ctrl+Shift+N crea la nota tramite LocalStore. Verificare tastiera italiana, focus in campi inline, Ctrl+C/V/Z/A, dialogo aperto e Android invariato. CI/widget distinti dalla prova fisica. [Specifica](P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Verifica responsive (candidate)

Card Forui Note in `Wrap` a 1/2/3 colonne con larghezza utile reale, `InlineEditableTitle` e `InlineEditableBody` integri, niente clipping verticale. Check desktop 1110/1600 e mobile 320/390 logical px, tastiera, testo lungo, sticky pop-out e resize continuo. La CI widget non sostituisce collaudo grafico fisico. [Specifica](P1-RESPONSIVE.md).

## P1.17 — Tray e finestra principale Windows

L'header Windows contiene un piccolo comando Nascondi quando la tray è pronta; X nasconde, click sulla tray riapre e menu Apri/Esci permette ripristino o uscita esplicita. Niente nuova modale, editing inline invariato. Da verificare focus, più finestre Sticky, icone orfane, X in caso di plugin non disponibile. [P1.17](P1-WINDOWS-TRAY.md).
