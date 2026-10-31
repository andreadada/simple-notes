# Flutter client — P0 e P1

> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`; Flutter CI verde: **162 test**, Windows EXE/MSIX, Android JDK17/21, Markdown). Collaudo fisico e deploy cumulativo non attestati. Backend repo Flyway V10; ultima VPS verificata V8, nessun reset/deploy. [Stato](../../docs/CURRENT-STATUS.md) · [ICS](../../docs/P2-ICS.md).

<!-- CURRENT-STATUS-REF -->

> **P1.9 integrato su main (PR #10):** Kanban per liste e Inbox, drag/drop, menu "Sposta in", campo aggiunta inline, Flutter `0.14.0+16`; CI verde, collaudo reale ancora aperto. [Specifica](../../docs/P1-KANBAN.md) e [guida operativa](../../docs/OPERATIONS.md).


## Cronologia — rilascio 0.7.0+9 (superato da P1.8)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](../../docs/P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


> **P1.3 (`0.7.0+9`, solo branch):** timeline drag/resize, snap di 15 minuti, drop tra giorni, gestione DST e test. Non richiede nuove migrazioni rispetto a P1.2. Nessun deploy e nessun reset dati; [specifica P1.3](../../docs/P1-CALENDAR-INTERACTIONS.md).

> **P1.2 su branch dedicato (25/10):** Flutter `0.6.0+8`, editor blocchi temporali e calendario, migration Drift V6, `timeBlockSchema:1` prima dell'upload. Ancora NON rilasciato. [Specifica](../../docs/P1-TIME-BLOCKING.md).


> **25/10/2026 — versione `0.5.0+7`**: P1.1 Calendario giorno/settimana/mese (proiezione di `TaskDue`, aggiunta rapida, inline edit; senza migrazioni) implementato nel client, CI e prova hardware distinte. Reset del workspace test eseguito dall'utente su PostgreSQL, Windows e Android, non da GitHub Actions. Documentazione: [P1-CALENDAR](../../docs/P1-CALENDAR.md) e [RESET-TEST-DATA](../../docs/RESET-TEST-DATA.md). Il ripristino del Cestino richiede backend con capability `noteRestoreSchema:1`; Coolify non è stato aggiornato da questa sessione.

## Evidenza storica — T4.2 del 24 ottobre

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](../../docs/T4-DEVICE-SYNC.md).


## T3 — Editor scadenze Forui e calendario civile (24/10/2026)

Un editor condiviso `task_due_editor.dart` ora gestisce data senza ora, data/ora+IANA, conversione esplicita `legacy` e fold/gap dell'ora legale. `task_due_clock.dart` calcola le possibilità UTC senza arrotondamenti nascosti e tenta di rilevare il fuso OS (in caso di errore richiede una selezione); `task_due_view.dart` centralizza le etichette e i filtri per giorni di calendario. Tutte le scritture T3 utilizzano SQLite/outbox; Flyway V7 risulta già applicata al DB reale, contratto API da provare. [Specifiche T3](../../docs/T3-SCADENZE.md).


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

**Design system ufficiale:** Forui `^0.27.6` (Flutter >= 3.47), con tema dark centralizzato in `lib/ui/notes_theme.dart`, responsive desktop/touch; usare [docs/ui-forui.md](../../docs/ui-forui.md) per regole e widget migrati. `MaterialApp` resta un bridge per dialoghi e componenti legacy.

Client Flutter Windows/Android con UI dark, task/note, **ricerca e modifica task**, Drift/SQLite e outbox transazionale. Auto-sync foreground sperimentale con delta pull, outbox e retry con backoff; sync manuale ancora disponibile dal menu profilo. **Windows + Google Login Desktop** verificati manualmente (21/10/2026); **Android avviato e segnalato funzionante** dopo il fix JVM del 23/10 (CI JDK 17/21 riuscita). **Note sincronizzate PC↔Android e attività Android→PC confermate manualmente dall'utente il 23/10.** Restano prove conflitti/retry su dispositivi reali. Vedere [handoff](../../docs/HANDOFF.md) e [runbook Android](../../docs/android-troubleshooting.md).

## Design inline-first e stato piattaforme

Le schermate Flutter condivise adottano ora il comportamento descritto in [audit UI](../../docs/ui-design-audit.md): attributi semplici direttamente editabili (liste, attività, sottotask, note, tag, descrizioni), componenti Forui per selezioni/menù/sheet e conferme distruttive. Persistenza invariata SQLite/outbox.

**Regola aggiornata 24/10:** niente sfondi sugli input inline. La sottolineatura segue soltanto i glifi del testo o del placeholder (non tutta la riga), con ~1 px per il cursore; il placeholder usa `NotesPalette.placeholder` semitrasparente. `InlineTextMetrics.fieldWidth` misura in modo coerente titoli, descrizioni, note, sottotask e input rapido task. Restano controlli distinti la ricerca Forui e i form avanzati multi-campo.

**Web browser non ancora disponibile:** l'app corrente usa `dart:io` + Drift Native e OAuth desktop/Android, quindi questa UI non basta per una build web funzionante. Serve un adattamento separato con Drift web/SQLite WASM e OAuth web; non presentare `flutter run -d chrome` come supportato. Windows/Android restano i target attuali.

## Cronologia — T2/Drift V5 (schema superato da V8)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Build
```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
dart run build_runner build
flutter analyze && flutter test
flutter run -d windows --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID
flutter run -d android --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```
Il backend è raggiungibile in HTTPS. Google Cloud OAuth (client Desktop, Android e Web) creati dall'utente. Il **secret Desktop** resta solo su Coolify: MAI aggiungerlo agli argomenti Flutter o al repository.

Su Windows occorrono gli strumenti C++ di Visual Studio e **C++ ATL** (`atlstr.h`) per `flutter_secure_storage_windows`. Su Android verificare `applicationId` e impronta SHA-1 della firma con il client OAuth Android. Le APK CI possono avere un certificato debug diverso; la configurazione CI non integra ancora gli OAuth reali.

## Configurazione Android versionata

La configurazione Android ora è presente **direttamente in Git**:
- `android/app/build.gradle.kts`: package e namespace definitivi `it.andreadada.simplenotes`, configurazione Java allineata alla JDK di Gradle (17 o 21) senza estensione `kotlin { compilerOptions { ... } }`. **`enableKotlin = false` solo nel modulo `:app`**, perché `MainActivity.java` è Java; alcune versioni Flutter registrano comunque `compileDebugKotlin`. Per evitare la validazione `Java (17) / Kotlin (21)` la `compileOptions` Java usa `JavaVersion.current()`, che vale 17 oppure 21 come la JDK che esegue Gradle. La CI testa entrambe (run `39955667440`, riuscita).
- `android/gradle.properties`: disattiva la compilazione incrementale Kotlin per evitare `this and base files have different roots` quando il progetto sta su E: e PUB_CACHE su C:.
- `android/app/src/main/java/it/andreadada/simplenotes/MainActivity.java`: Activity nel namespace definitivo.
- La CI controlla package e namespace prima della build Android; esegue la build sia con **JDK 17 sia con JDK 21**: [run 39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440) **riuscita**. Pubblica un APK **debug**. Non equivale a prova di login Google sull'APK CI.

**Primo pull sui PC dove Flutter aveva già generato file Android:** `git pull` può fermarsi con `untracked working tree files would be overwritten`. È normale: salva una copia *fuori dalla repo* dei due file generati e spostali prima del pull. Non cancellare l'intera cartella Android. Dalle volte successive `git pull origin main` basterà.

Il Client OAuth Android Google Cloud deve avere package `it.andreadada.simplenotes` e lo **SHA-1 della firma debug del PC**. La build CI è firmata da un certificato diverso e non è garantito che il login Google funzioni su quell'APK.

### Errore d'installazione `INSTALL_FAILED_USER_RESTRICTED`

Se Flutter mostra `✓ Built ... app-debug.apk` ma ADB dice `Install canceled by user`, **la compilazione è riuscita**. Lo smartphone ha bloccato l'installazione tramite USB; su Xiaomi/Redmi/POCO controllare in *Opzioni sviluppatore* le opzioni **Debug USB** e **Installa tramite USB**, lasciare lo schermo sbloccato e accettare la richiesta d'installazione. Questa restrizione **non è risolvibile dal codice GitHub**. In alternativa è possibile trasferire l'APK sul telefono e installarlo manualmente, confermando le autorizzazioni del sistema.

Per cronologia degli errori locali (Gradle Java 8, Kotlin incremental, JDK 17/21, installazione USB) consultare il [runbook dedicato](../../docs/android-troubleshooting.md).

## Debug Google Login Android: `[16] Account reauth failed`

Questo errore può essere restituito da Google Credential Manager come `canceled` **anche se l'utente non ha annullato il login**. Verificare prima i tre elementi OAuth, senza cambiare il backend funzionante:

1. Dal terminale nella cartella `apps/flutter`, eseguire `Select-String -Path android\\app\\build.gradle.kts -Pattern 'applicationId'`. Il risultato deve coincidere **esattamente** con il package name del client Google Cloud Android.
2. Eseguire `cd android` e `.\\gradlew.bat signingReport`. Nel blocco **Variant: debug**, leggere `SHA1` e confrontarlo con l'impronta registrata sul client Google Cloud Android. Questa impronta, relativa al certificato effettivamente usato da Gradle, è preferibile a copiare manualmente l'output localizzato di `keytool`.
3. Tornare alla cartella `apps/flutter`. Passare a Flutter con `--dart-define=GOOGLE_WEB_CLIENT_ID=...` **il Client ID di tipo Web application**, non l'ID Android. Controllare che il test user sia autorizzato se l'app OAuth è in Testing.
4. Dopo aver corretto package/SHA-1/client, se l'errore continua, **disinstallare solo l'app di test Android** e reinstallarla (avviso: la disinstallazione cancella i dati locali dell'app non sincronizzati). In alternativa diagnosticare il logcat di Google Play Services. Non cancellare i dati di Google Play Services.

Il logout su Android ora esegue anche `GoogleSignIn.instance.signOut()`: Google Credential Manager altrimenti può conservare una sessione precedente e fallire la riautenticazione. Il primo login Android non è ancora verificato, quindi questa correzione non garantisce da sola di eliminare il codice 16.

## Account Google e avatar

Nella sidebar desktop e nell'AppBar Android c'è un unico **avatar circolare** con menu profilo per **Accedi con Google**, **Sincronizza ora** ed **Esci da Google**; rimossi i due pulsanti originali. Se Google rilascia il claim OpenID `picture`, la UI usa la foto autentica HTTPS; altrimenti mostra un'icona persona. Il backend ora include `photoUrl` nella risposta auth e lo conserva con Flyway `V4__google_profile_photo.sql`. **Serve un redeploy Coolify** per avere la foto anche al ripristino della sessione Windows; per gli utenti già registrati occorre rifare login almeno una volta.

## Sincronizzazione automatica foreground

La nuova `AutoSyncHost` sincronizza quando si effettua login/ripristino sessione, dopo modifiche locali (debounce 900 ms), al ritorno in primo piano, quando torna la connettività e con pull periodico ogni 60 secondi. Gli errori di rete usano backoff di 5–80 secondi; conflitti 409 interrompono il retry automatico e preservano l'outbox. Il menu account mantiene **Sincronizza ora**.

Non è un servizio Android in background con app chiusa; lo stato della connessione non garantisce accesso a Internet, quindi i timeout HTTP restano necessari. I test reali PC↔Android, conflitti e offline/retry sono ancora da verificare.

## Limiti storici (23/10/2026)
La sync **è automatica in foreground** (login/ripristino, modifica, ritorno online, resume, poll ogni 60 s); la sync manuale rimane disponibile. Note PC↔Android e task Android→Windows sono confermati dall'utente, mentre conflitti reali, logout/refresh su entrambi, delete e recovery offline restano da verificare. Le **liste, priorità, tag e sottotask esistono e hanno test CI**, ma richiedono Flyway V6 deployata e prova fisica. Rimangono da sviluppare scadenze con orari robusti, ricorrenze, reminder/notifiche native, filtri salvati, packaging e hardening. **Non installare client nuovi prima che il server sia compatibile; non cancellare dati locali.** Vedere [P0-STATUS.md](../../docs/P0-STATUS.md).

## Diagnostica sincronizzazione note (23/10/2026)

- **Menu profilo Google su Windows e Android**: mostra sempre l'esito della sync, l'errore con codice HTTP/end-point e il numero di modifiche in attesa (`pendingMutations`); indicatore arancione nell'avatar se errore/conflitto. Prima il messaggio era visibile solo in sidebar desktop.
- Se la nota non compare sull'altro device: eseguire `Sincronizza ora` **su entrambi** e leggere i messaggi e il conteggio in coda. Codice `400` su `/sync/apply` poteva dipendere da titolo nota vuoto; il backend lo accetta dopo aggiornamento e **redeploy Coolify** (test JUnit nuovo).
- Non cancellare i dati locali, non eseguire `flutter clean` sull'app installata come "rimedio", non disinstallare: l'outbox SQLite contiene dati non ancora sincronizzati.
- Serve E2E manuale con due client e medesimo utente; la CI e il test backend con due chiamate simulate non equivalgono a test remoto di Coolify.

### Modali Forui (23/10/2026)

Modifica attività, modifica nota e scelta scadenza utilizzano ora `showFDialog`, `FDialog`, `FTextField`, `FButton` e `FCalendar.grid`. Il layout è riutilizzabile in `lib/ui/notes_dialogs.dart` e non dipende dal backend. Consultare [UI Forui](../../docs/ui-forui.md). Il bottom sheet dettagli attività rimane da convertire.

## Incrementi P0 — conflitti e descrizione attività

- `ui/sync_conflict_dialog.dart` mostra un FDialog per confrontare locale/server quando la sync ottiene 409; accessibile dal menu avatar. Nessuna cancellazione senza doppia conferma. Recupera latest da endpoint JWT protetto (richiede backend aggiornato a Flyway V5).
- `data/models.dart` include `LocalTask.description`; `data/app_database.dart` migra Drift a schema v3 con la colonna SQLite non nullable e default vuoto, mantenendo i dati precedenti. Campo descrizione Forui nell'editor task, visualizzazione nel pannello dettagli, sync nel payload già supportato da Spring Boot.
- Test `test/sync_conflict_test.dart` simulano due SQLite indipendenti, conflitti, scelta utente e rete assente. **Non** sono test hardware. [Stato completo](../../docs/P0-STATUS.md).

## Organizzazione attività (Drift v4 storico; ora v5 nel codice)

Liste con create/rename/delete, priorità P1–P3, tag, sottotask, filtri e ricerca; SQLite/outbox e sync implementate. V6 già presente nel database reale (V1–V7 verificate); funzionalità sui due client aggiornati da collaudare.

**T4.2:** versione Flutter `0.4.0+4` destinata al collaudo Windows/Android. Il menu avatar include `Verifica sincronizzazione` e la diagnostica read-only, i test e la procedura sono in [T4-DEVICE-SYNC.md](../../docs/T4-DEVICE-SYNC.md).

**T4.2 build `0.4.1+5`:** per build Windows + Android dalla stessa revisione senza esporre ID OAuth nei commit usare [`tools/t4-build-devices.ps1`](../../tools/t4-build-devices.ps1) e la procedura in [`docs/T4-DEVICE-SYNC.md`](../../docs/T4-DEVICE-SYNC.md). La verifica completa di `taskDueSchema:1` prima dell'upload delle nuove scadenze preserva l'outbox con server parzialmente compatibili. Nessuna installazione o prova hardware è stata eseguita dalla CI.

**Cestino note (0.4.2+6):** eliminazione logica con vista Cestino e ripristino versionato dello stesso UUID. Il server deve esporre `noteRestoreSchema:1`: in caso contrario il client blocca l'upload di restore, mantenendo la coda locale. Una nuova build non è un deploy dell'API. La pulizia volontaria dei dati di test sui tre archivi è descritta in [RESET-TEST-DATA.md](../../docs/RESET-TEST-DATA.md); **non** è stata eseguita automaticamente.

## P1.10 — Pomodoro (main, PR #11)

Timer focus 25/5/15 con stato salvato su SharedPreferences, isolato per account Google, statistiche locali (non cloud) e UI Forui. Config Flutter `0.15.0+17`; integrazione server nulla. [Specifica](../../docs/P1-POMODORO.md).

## P1.11 — Abitudini (branch)

Flutter `0.16.0+18` candidato: abitudini quotidiane con check-in, streak, dashboard oggi/7/30 giorni, archivio e restore. Solo SharedPreferences per Google owner; nessuna migrazione server, senza sync fra dispositivi. [Specifica](../../docs/P1-HABITS.md).

## P1.12 — Countdown (main, PR #13)

Flutter `0.17.0+19` con data civile/IANA da editor TaskDue condiviso, card Forui, editing inline, archivio e SharedPreferences owner-bound. Nessuna migrazione Drift/Flyway né nuova sync. [Specifica](../../docs/P1-COUNTDOWNS.md).

## P1.13 — Weekly Habit Goals (branch)

Flutter `0.18.0+20` candidato. `LocalHabit.weeklyTarget` 1–7 con default retrocompatibile 7 sui vecchi dati. `HabitWeek` calcola progressi/streak secondo calendario lunedì–domenica; menu Forui sulla card, senza server/Drift migration o delete preferenze. [Specifica](../../docs/P1-WEEKLY-HABITS.md).

## P1.14 — Sticky Notes Windows

`desktop_multi_window ^0.3.1` crea una finestra indipendente per nota Windows; `flutter_window.cpp` registra i plugin nel nuovo engine, che non apre AppDatabase né OAuth. Tutte le modifiche passano dal LocalStore/outbox principale con optimistic guard. Android resta invariato. Nuova build Flutter candidata 0.19, CI/real-device in verifica. [Specifica](../../docs/P1-STICKY-WINDOWS.md).

## P1.15 — Scorciatoie Windows (branch)

Flutter `0.20.0+22` candidata. `DesktopShortcutPolicy` gestisce Ctrl+1..5, Ctrl+Shift+T/N, Ctrl+/; `NotesHome` riutilizza la navigazione e LocalStore esistenti, con help Forui. Nessuna API, DB migration o plugin OS. [Specifiche](../../docs/P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Responsive layout candidate

`NotesResponsivePolicy` centralizza sidebar viewport 950px e dettagli 1200px, e colonne card per larghezza contenuto: 1 sotto 700px, 2 da 700px, 3 da 1120px. `Wrap` mantiene l'altezza intrinseca delle card e gli editor inline. Test Flutter a 320/390/1110/1600 px, nessun nuovo backend o storage. [Specifiche](../../docs/P1-RESPONSIVE.md).

## P1.17 — System tray Windows candidata

`tray_manager ^0.8.0`, `window_manager ^0.5.2`; `WindowsTray.initialize` solo main, `TrayClosePolicy` fail-open; click/menu Apri ed Esci, X/hide. L'engine Sticky e Android non hanno tray. Flutter `0.22.0+24`, nessuna migration. [Specifica](../../docs/P1-WINDOWS-TRAY.md).

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](../../docs/P1-APPEARANCE.md) · [Stato](../../docs/CURRENT-STATUS.md).

## P2.1 — Import/export dati (main, PR #20)

`lib/data/portable_archive.dart` definisce il formato JSON 1 e la validazione; il menu account usa `file_selector` per l'apertura su Android/Windows e il salvataggio su Windows, `share_plus` per l'export Android. Importazione confermata in `NotesDialog` Forui, transazione tramite `LocalStore.importPortable` e outbox; `test/portable_archive_test.dart` copre il round-trip, i limiti e il merge additivo. Flutter `0.24.0+26` integrata su main, CI completa verde (152 test, Android JDK17/21, Windows EXE/MSIX, Markdown); collaudo reale aperto. Non equivale a un backup di SQLite/SharedPreferences né preserva ID e tombstone. [Specifica](../../docs/P2-PORTABLE-ARCHIVE.md).

## P2.2 — ICS read-only (main, PR #21)

`ui/ics_calendar.dart` contiene parser RFC5545 limitato, calendario versionato e proiezione per giorno; `ui/ics_calendar_controls.dart` gestisce file nativi, preview Forui e archivio SharedPreferences hash-owner; `calendar_board.dart` mostra gli eventi esterni senza azioni editabili in giorno/settimana/mese. `test/ics_calendar_test.dart` verifica date, UTC/IANA/DST, fold/unfold, limiti e owner isolation. Flutter `0.25.0+27` integrata su main, CI completa verde (162 test, Windows EXE/MSIX, Android JDK17/21, Markdown); nessun sync/SQLite/outbox; test reali ancora aperti. [Specifica](../../docs/P2-ICS.md).

