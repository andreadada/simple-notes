# Simple Notes — Passaggio di consegne (handoff)

> **Stato sviluppo 26/10/2026:** P1.7 Windows **integrata su `main`** (PR #7, Flutter `0.12.0+14`, [CI verde](https://github.com/andreadada/simple-notes/actions/runs/40245561264)); package MSIX/non-EXE, **nessun test hardware/installazione**. P1.8 Matrice Eisenhower sviluppata su branch `feature/p1-8-eisenhower-matrix` (Flutter `0.13.0+15`, [specifica](P1-EISENHOWER.md)), **CI e merge da verificare**. Ultimo Coolify attestato Flyway V8; V9/V10 reali non verificati; nessun deploy/reset in questa attività.

<!-- CURRENT-STATUS-REF -->


## Cronologia — rilascio 0.7.0+9 (superato da P1.8)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


## Cronologia — P1.3 (ora integrata)

**Su branch `feature/p1-3-calendar-interactions` (non su `main`): Flutter `0.7.0+9`, timeline interattiva giorno/settimana, move/resize a step 15 minuti, drag su intestazioni giornaliere e celle del mese, supporto DST e corsie sovrapposizioni; test dedicati.** Non richiede nuove tabelle oltre Flyway V8 di P1.2 e Drift V6. *CI e test hardware da verificare; nessun deploy/merge di P1.2 e P1.3 né modifica ai dati reali*. P1.2 `feature/p1-2-time-blocking` ha CI backend e Flutter completamente verde ma resta draft, non distribuito. P1.3 è documentato in [P1-CALENDAR-INTERACTIONS.md](P1-CALENDAR-INTERACTIONS.md). Multi-blocco per task resta fuori ambito, per successiva revisione di modello.


## Cronologia — P1.2 in sviluppo (ora integrata)

**Branch `feature/p1-2-time-blocking`, Flutter `0.6.0+8`.** Introdotto intervallo `timeBlock` indipendente dalla scadenza, con editor Forui, blocchi nel calendario e percorso di sincronizzazione versionato. **Backend V8/Drift V6 sono solo codice: nessun deploy Coolify, migrazione reale, nuova pulizia dati o installazione sui dispositivi effettuata.** `timeBlockSchema:1` è un gate obbligatorio prima di inviare nuovi task. I test CI automatici e l'accettazione PC↔Android sono ancora da verificare. Non confondere codice implementato con feature già rilasciata. Specifica e piano: [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). La versione su `main` resta `0.5.0+7` fino a merge autorizzato/dopo verifiche.


## Cronologia — snapshot del 25 ottobre precedente a P1.2–P1.6

**Reset del workspace di test concluso dall'utente:** PostgreSQL `simplenotes` verificato con **0 task, 0 liste, 0 note, 0 eventi e 0 operazioni di sync**; SQLite Windows eliminata dallo script, dati Android cancellati dalle impostazioni del dispositivo dopo che ADB `pm clear` era stato rifiutato dal sistema. Il reset è stato confermato dall'utente: **non va ripetuto** per avviare P1. `app_user`, sessioni backend, schema e Flyway restano conservati. I conteggi storici (5 note soft-deleted, cursor 34, backup e restore PASS) descrivono lo stato **prima** del reset, non quello corrente.

**Codice:** Flutter `0.5.0+7` introduce **P1.1 Calendario** (giorno/settimana/mese, agenda, scadenze date-only e timed, edit inline, aggiunta rapida) tramite proiezione dei task già sincronizzati, **senza migrazioni DB né nuove API**. Vedi [P1-CALENDAR.md](P1-CALENDAR.md) (oppure [specifica P1.1](P1-CALENDAR.md) per i documenti in `docs/`). Cestino note/restore versionato già implementato in `0.4.2+6`, ma **non verificato sui dispositivi** e per il ripristino cloud richiede l'API aggiornata `noteRestoreSchema:1`; il deploy Coolify non è attestato. P1.2 time blocking, P0 reminder/ricorrenze/hardening e test E2E restano **aperti**, non vengono segnati completati.

**CI:** la revisione precedente `d29d2f3` (0.4.2+6) è verde su Flutter e backend; per P1.1 citare la **nuova CI** dopo averne verificato l'esito. **Nessun nuovo deploy, backup o ulteriore reset eseguito da ChatGPT.**

> Le sezioni datate 23–24 ottobre più in basso sono **cronologia**, non istruzioni operative correnti; prevale questo stato e [RESET-TEST-DATA.md](RESET-TEST-DATA.md) per la storia del reset.

## Evidenza storica — T4.2 del 24 ottobre

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](T4-DEVICE-SYNC.md).


## Checklist storica T4.2 — consolidare nel batch P1.6

1. Compilare stessa revisione Flutter `0.4.1+5` per Windows e Android senza cancellare dati.
2. Accedere allo stesso account e aprire avatar → **Verifica sincronizzazione**, controllando API `taskDueSchema:1` e pending.
3. Completare [T4-DEVICE-SYNC.md](T4-DEVICE-SYNC.md): PC→Android, Android→PC, offline e DST.
4. Non ripetere backup/restore né migrare V7 o ridistribuire automaticamente; copia offsite non effettuata per scelta.

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Scadenze e fusi orari (24/10/2026)

Il client Flutter ha ora un editor scadenze Forui riutilizzato in creazione rapida, pannello dettagli e editor avanzato (`ui/task_due_editor.dart`). Supporta `date` senza ora, `datetime` con HH:mm + timezone IANA, scelta del fold DST e rifiuto del gap; non converte automaticamente `legacy`. Il rilevamento OS fallibile non produce una UTC inventata: l'utente sceglie un fuso valido. `task_due_view.dart` centralizza l'etichetta (mostra il fuso) e i filtri Oggi/7 giorni in giorni civili; gli aggiornamenti rimangono offline-first.

**Stato aggiornato:** T3 implementato nel codice, Flyway V7 già nel DB reale, backup SHA256 e restore isolato riusciti. Rimangono verifica API autenticata e test hardware Windows↔Android. Esecuzione web, ricorrenze e notifiche non sono supportate in T3. Leggere [T3-SCADENZE.md](T3-SCADENZE.md) e verificare le [CI Flutter](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml) per l'esito esatto.


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

> **Documentazione storica aggiornata al 23 ottobre 2026.** Per lo stato P0 più recente e le conferme di sync hardware usare [P0-STATUS.md](P0-STATUS.md). Documento operativo per sviluppatori e assistenti AI che aprono la repository senza conoscere le chat precedenti. Verificare sempre il codice e gli ultimi workflow, non usare questo testo come sostituto dei test reali.

## Vincolo obbligatorio stile inline — aggiornamento 24/10/2026

Nel commit [7303d45](https://github.com/andreadada/simple-notes/commit/7303d45c34eda2d38f3442080b0959c69ab1bbf0) è stato sostituito il dimensionamento per righe/moduli con una misurazione dei **caratteri effettivi** (`InlineTextMetrics.fieldWidth`). Sottolineatura senza background, larga quanto valore o placeholder (+~1px cursore); nessun minimo fisso 84/120px, né extra 22/26px. Hint semitrasparente `NotesPalette.placeholder` (~72%). Comprende titoli, descrizioni, tag, note, sottotask, aggiunta task/sottotask. Regola documentata in [design.md](../design.md), [Forui](ui-forui.md), [audit](ui-design-audit.md); conservare in tutti i futuri refactor Flutter (Windows/Android, UI riutilizzabile in futuro per web). Conserverà sempre il salvataggio offline-first. Nessun deploy Coolify necessario.

## Aggiornamento UX shared Flutter (24 ottobre 2026)

Il client ha esteso `InlineEditableTitle` a task/note/sottotask/tag, aggiunto `InlineEditableBody` per descrizioni e note e un quick-add inline dei sottotask. Proprietà lista/priorità sono menu Forui, profilo ora popover Forui e dettaglio mobile sheet Forui; eliminazioni di task/note richiedono conferma. Le modifiche persistono in SQLite/outbox con i metodi `LocalStore`. L'editor avanzato resta per i cambi multi-campo. **Web runtime ancora non operativo**: database nativo e auth platform-specific. Leggere [ui-design-audit.md](ui-design-audit.md).

## Cronologia — T2/Drift V5 (schema superato da V8)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Cronologia — proposta del 23 ottobre (già implementata)

Per intervenire su scadenze, SQLite, Flyway o sync leggere **[due-dates-timezones.md](due-dates-timezones.md)**: pianifica il tipo `none/date/datetime/legacy`, la migrazione PostgreSQL V7 e Flutter Drift v5, timezone IANA/DST, protezione dei client precedenti e test. **T1/T2/T3 implementati nel codice** e Flyway V7 confermata nel DB reale; API e dispositivi ancora da collaudare. Le CI per l'editor HH:mm già esistente sono verdi ([40011789270](https://github.com/andreadada/simple-notes/actions/runs/40011789270)). Backup/restore reale già riusciti; restano verifica API e prova hardware in [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md).

## T1 backend introdotto nel repository (23 ottobre 2026)

Commit [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26): aggiunti migrazione Flyway V7, validazione `TaskDue` incl. DST, `GET /api/v1/capabilities` autenticato e blocco HTTP 426 `CLIENT_UPGRADE_REQUIRED` per vecchi client che tentano di sovrascrivere nuove scadenze. **Flyway V7 verificata sul DB reale, API da controllare**; Flutter T2 include Drift v5, `TaskDue` e gestione 426 nel codice. CI ed E2E distinti. Leggere [due-dates-timezones.md](due-dates-timezones.md) per T2, T3 e procedure di backup.

## TL;DR: che cos'è e a che punto siamo

- **Obiettivo:** app originale di produttività per Windows 11 e Android, con note, attività, futuro calendario/promemoria e moduli avanzati ispirati funzionalmente a TickTick, non una copia.
- **Architettura:** Flutter/Dart + **Forui (design system)** + Riverpod; Drift/SQLite per dati offline; Spring Boot Java 21 + PostgreSQL/Flyway per account e sincronizzazione; deploy Docker Compose su Coolify.
- **Server:** `https://api.notes.ddone.it` — `/actuator/health` ha restituito `{"status":"UP"}` secondo verifica manuale dell'utente. Non confondere servizio raggiungibile con produzione pronta.
- **Windows:** compilazione ed esecuzione reali, login Google Desktop completato manualmente (21/10/2026).
- **Android:** dispositivo fisico rilevato (`2412DPC0AG`), installazione e avvio iniziali verificati; dopo la correzione finale Gradle/JVM (23/10) l'utente riferisce **«funziona»**. Non è stato però confermato esplicitamente, dopo quest'ultima correzione, **se funziona anche il login Google Android**: richiedere/effettuare quella verifica prima di considerarlo completato.
- **CI della configurazione Android precedente:** [Flutter CI run 39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440) riuscita: analisi e test Flutter, build Windows, build Android con **JDK 17 e JDK 21**. Sono build tecniche, non prove di autenticazione/sync reali.
- **Sync:** auto-sync foreground; l'utente ha successivamente confermato note PC↔Android e attività Android→Windows. Conflitti real-device ancora aperti; restore del DB reale riuscito il 24/10 (vedere P0-STATUS.md).
- **Account:** avatar Google (claim opzionale `picture`) e menu compatto al posto dei due pulsanti; backend Flyway V4 conserva la foto. **Richiede redeploy Coolify** e nuovo login per valorizzare la foto di utenti preesistenti.
- **Stato del prodotto:** **P0 IN CORSO, non pronto per release pubblica**. La roadmap e i criteri di completamento sono in [../project.md](../project.md).

## Percorso di lettura per chi inizia da zero (stato in CURRENT-STATUS)

1. [../README.md](../README.md) — panoramica e stato.
2. **Questo file** — contesto recente, blocchi risolti, prossime azioni.
3. [../project.md](../project.md) — priorità P0–P3 e `Edit Timespan` (registro modifiche).
4. [../design.md](../design.md) — requisiti di prodotto, incluse funzioni *future* non implementate.
5. [architecture.md](architecture.md), [api.md](api.md), [sync.md](sync.md) — struttura e contratti.
6. [../apps/flutter/README.md](../apps/flutter/README.md) e [android-troubleshooting.md](android-troubleshooting.md) — avvio locale e risoluzione problemi Android.
7. [../infra/README.md](../infra/README.md) — ambiente Coolify e variabili server.

## Mappa del codice

| Area | Percorso | Ruolo |
| --- | --- | --- |
| Flutter UI | `apps/flutter/lib/main.dart` | Schermate, navigazione, interazione |
| Autenticazione client | `apps/flutter/lib/auth/cloud_auth.dart` | Android Google Sign-In; Windows OAuth browser+PKCE; refresh/logout |
| DB locale | `apps/flutter/lib/data/app_database.dart` | Drift/SQLite, migrazioni, outbox, cursor, ownership |
| Modello e store | `apps/flutter/lib/data/models.dart`, `local_store.dart` | Modelli e stato locale |
| Sync client | `apps/flutter/lib/sync/cloud_sync.dart` | Invio operazioni pendenti, delta pull, errori/conflitti |
| Config Android | `apps/flutter/android/app/build.gradle.kts`, `android/gradle.properties` | Package OAuth, JVM, Kotlin incremental |
| Android Activity | `apps/flutter/android/app/src/main/java/it/andreadada/simplenotes/MainActivity.java` | Entry point Flutter |
| API | `services/api/src/main/java/it/ddone/simplenotes/` | Controller e servizi auth, task, note, sync |
| SQL | `services/api/src/main/resources/db/migration/` | Migrazioni Flyway |
| Deploy | `docker-compose.yml` | Stack Coolify API + DB (non esporre PostgreSQL) |
| CI | `.github/workflows/` | Backend, Compose, Flutter/JDK |

**Non confondere le specifiche col software disponibile:** `design.md` descrive anche liste, tag, ricorrenze, reminder, calendario, Pomodoro, habit e altre funzionalità ancora da costruire.

## Avvio locale: Windows / Android

Da PowerShell, repository locale `E:\dev\simple-notes` (percorso storico dell'utente; adattarlo su altri PC):

```powershell
cd E:\dev\simple-notes
git pull origin main
cd apps\flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Lato Android, con telefono collegato e autorizzato per debug/installazione USB:

```powershell
flutter devices
flutter run -d 2412DPC0AG `
  --dart-define=API_BASE_URL=https://api.notes.ddone.it `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

Per Windows:

```powershell
flutter run -d windows `
  --dart-define=API_BASE_URL=https://api.notes.ddone.it `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_OAUTH_CLIENT_ID
```

`flutter create` serve a completare lo scaffold delle piattaforme non interamente versionato; **non sovrascrivere a mano** `build.gradle.kts`, `gradle.properties` o il package OAuth: ora sono file tracciati da Git. Evitare `git reset --hard` se sono presenti modifiche locali non salvate. Client ID OAuth non sono segreti, ma **Client Secret, password, refresh token e keystore NON vanno in Git né nei comandi client**.

## Configurazione cloud e Google

- Coolify: repository `andreadada/simple-notes`, `main`, Compose root `/docker-compose.yml`. Dominio HTTPS sul servizio API con porta interna 8080. PostgreSQL solo in rete privata Docker.
- Secrets/runtime da configurare **su Coolify**, non hardcodare: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `GOOGLE_CLIENT_IDS` (Web + Desktop consentiti dal backend), `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET`, `APP_JWT_SECRET_BASE64`. Vedere [../infra/README.md](../infra/README.md) e [../.env.example](../.env.example).
- Sono stati configurati tre client Google OAuth: **Web**, **Desktop**, **Android**. Su Android si passa come `serverClientId` l'ID **Web**, non il client Android.
- **Package Android definitivo:** `it.andreadada.simplenotes`. L'OAuth Android in Google Cloud deve avere esattamente questo package e l'impronta **SHA-1 della firma APK effettivamente usata**. Non confondere la firma debug locale con quella degli artifact CI.
- Windows usa browser di sistema e authorization code + PKCE loopback; il Desktop OAuth client secret viene utilizzato soltanto nel server.
- Su Windows è stato necessario installare **Visual Studio C++ ATL** per compilare `flutter_secure_storage_windows` (`atlstr.h`).

## Problemi affrontati 22–23 ottobre 2026: cronologia e soluzioni

1. **Android non appariva in `flutter devices`**; dopo configurazione debug USB/ADB è stato rilevato il dispositivo `2412DPC0AG`.
2. **Kotlin incremental cache / `this and base files have different roots`** tra `C:\Users\...\Pub\Cache` e repository su `E:\`. Workaround versionato: `kotlin.incremental=false` in `apps/flutter/android/gradle.properties`; ripulire con `flutter clean` e `flutter pub get`.
3. **Google Android `[16] Account reauth failed`** durante un tentativo iniziale: era stato rilevato un **mismatch di package** (`com.example.simple_notes` nel progetto generato, `it.andreadada.simplenotes` nel client OAuth Android di Google Cloud). Corretto `applicationId` e `namespace` su Git; il logout Android ora chiama anche Google `signOut()`. **Non attribuire con certezza l'errore soltanto al package finché non è confermato un login reale dopo la correzione.**
4. **`gradlew.bat signingReport` rifiutava Java 8** quando eseguito direttamente in PowerShell, pur funzionando `flutter run`: Gradle richiede JDK 17+. Verificare `JAVA_HOME`/Gradle JDK; vedere la guida Android.
5. **`Unresolved reference compilerOptions` / `jvmTarget`** dopo tentativo di blocco top-level `kotlin { compilerOptions { ... } }`: quel DSL non era disponibile nella configurazione AGP/Flutter generata. Il blocco è stato eliminato; evitare di reintrodurlo senza verificare compatibilità.
6. **`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`**: APK compilato, installazione USB rifiutata dal sistema del telefono. Su Xiaomi/POCO/HyperOS controllare **Installa tramite USB** nelle opzioni sviluppatore e confermare il prompt; questo **non si risolve con un commit Git**.
7. **JVM bytecode mismatch:** `compileDebugJavaWithJavac (17)` contro `compileDebugKotlin (21)` su JDK 21. La sola `enableKotlin=false` non eliminava il task Kotlin. Soluzione finale versionata: `sourceCompatibility` e `targetCompatibility` Java impostate su `JavaVersion.current()` per seguire la JDK usata da Gradle. **CI run 39955667440 completamente riuscita su JDK 17 e JDK 21**; l'utente segnala poi funzionamento Android.
8. I file `android/app/build.gradle.kts`, `android/gradle.properties` e `MainActivity.java` sono ora **tracciati da Git**. Prima erano generati solo sul PC, quindi cambiando macchina o ricreando lo scaffold si perdevano correzioni.

Per istruzioni dettagliate e controlli SHA-1 consultare [android-troubleshooting.md](android-troubleshooting.md).

## Stato funzionale storico: NON usare per lo stato corrente

> Questa tabella descrive un momento precedente all'introduzione dei dialoghi conflitto Forui, dell'auto-sync e delle liste. Lo stato corrente è in [P0-STATUS.md](P0-STATUS.md) e la prova manuale è in [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md). Le sezioni storiche seguenti non devono guidare nuove implementazioni.

## Stato funzionale: non promuovere un test in una release

| Funzionalità | Evidenza | Stato |
| --- | --- | --- |
| Health API Coolify | Confermato manualmente dall'utente | Verificato, non hardened |
| Login Google Windows | Confermato manualmente il 21/10 | Verificato |
| Build Windows | GitHub Actions | Verificato CI |
| Android debug APK JDK 17/21 | CI run 39955667440 | Verificato CI |
| Android avvio dopo ultimi fix | «Perfetto funziona», 23/10 | Segnalato funzionante dall'utente |
| Login Google Android dopo ultimi fix | Nessuna conferma esplicita distinta dall'avvio | Da verificare |
| Creazione task/note locali | Codice e test Flutter | Implementato, test E2E da estendere |
| Auto-sync foreground + manuale | `AutoSyncHost` + `CloudSync.synchronize()`, outbox/REST delta | Implementato, test PC↔Android mancante |
| Sync automatica e UI conflitti | Non implementati | Da fare |
| Backup/ripristino, rate limit, notifiche, release firmata | Backup/restore reale PASS; offsite, rate limit, notifiche e release firmata ancora aperti | Da fare per release |

## Prossima sessione: ordine di lavoro (storico, sostituito da P0-STATUS)

> Non eseguire questa sequenza alla lettera: include test e sviluppi ora già conclusi. Per le nuove sessioni seguire la checklist corrente.

1. **Nota storica 23/10 (non comando attuale di redeploy):** verificare la migrazione V4 per foto profilo (non cambiare segreti), poi **accertare login Android** sul dispositivo fisico con Google (dopo il fix package/gradle) e testare restore sessione dopo riavvio. Se fallisce, usare [android-troubleshooting.md](android-troubleshooting.md), non modificare alla cieca Coolify.
2. **Test manuale sync a due device** con lo stesso account (menu avatar mostra esito e operazioni in coda su Android e Windows): creare `Test PC → Android` in Windows → `Sincronizza ora` Windows → sync Android e verificare; creare `Test Android → PC` sul telefono, sync Android → sync Windows; ripetere con una nota.
3. **Verificare offline/retry e conflitti**: creare item offline e sincronizzare al ritorno della rete; una collisione deve **preservare l'outbox**, non sovrascrivere contenuti silenziosamente. Controllare isolamento dati al cambio account.
4. L'**auto-sync foreground è ora implementata**: verificarne il comportamento a due dispositivi, gestione di errori e conflitti, poi introdurre eventuale background sync e reminder/notifiche secondo [../project.md](../project.md).
5. Prima di pubblicare: firma Android **release** (attualmente debug per test), backup e prova restore PostgreSQL, rate limiting auth, sicurezza e validazione completa dei flussi.

## Convenzioni per chi implementa

- Lavorare in piccoli commit, testare il comportamento e annotare il risultato in `project.md` → `Edit Timespan`. Aggiornare le checklist **solo dopo verifica**.
- L'utente preferisce le correzioni **direttamente nel repository GitHub** e poi `git pull` sul PC; evita istruzioni per modifiche manuali permanenti quando puoi committare la correzione. Non sovrascrivere lavoro locale o forzare operazioni distruttive.
- Non modificare secret Coolify o Google Cloud per risolvere una semplice build Gradle.
- Il codice deve rimanere offline-first: salvare prima su SQLite/outbox, non perdere modifiche locali per conflitto o rete non disponibile.
- Non dichiarare `P0 completato`, `sync verificata`, `Google Android verificato` o `produzione pronta` senza prove esplicite.
- Distinguere **fatti da codice**, **successo della CI**, **conferma manuale dell'utente** e **lavoro ancora in sospeso**.

## Diagnostica sincronizzazione note: 23 ottobre 2026
- Segnalazione: note non visibili fra Windows e Android pur usando lo stesso account Google.
- Problema certo UI: esiti/HTTP della sync non erano visibili su Android, impedendo la diagnosi. Nuovo menu account con esito e numero di operazioni locali pendenti, badge errore.
- Problema certo contratto: l'editor accettava titoli vuoti, mentre il backend li rifiutava con HTTP 400, bloccando l'outbox; la nuova validazione backend accetta titoli vuoti e limita a 255 caratteri. Richiede **redeploy Coolify**.
- Test server aggiunto: crea nota su device A, device B legge delta, aggiorna, A rilegge.
- **La causa esatta della mancata sync sul dispositivo non è stata ancora verificata**: leggere esiti dopo aggiornamento su entrambe le piattaforme. Non eliminare alcun dato locale.

## Valutazione libreria grafica (23 ottobre 2026)
Richiesta confronto Forui (duobaseio/forui) vs alternative: Forui è candidata per futuro restyle (cross-platform, shadcn-like, resizable panels; richiede Flutter 3.47+ nelle release 0.26+). Alternative shadcn_ui e fluent_ui. **Non integrata**, in attesa della verifica end-to-end della sincronizzazione. Dettagli e link in `project.md`.

## UI Forui — decisione del 23 ottobre 2026

Forui `^0.27.6` è stata adottata come base UI ufficiale. Tema centralizzato `apps/flutter/lib/ui/notes_theme.dart`, `FTheme` per tutto il Navigator, `FSidebar` e `FSidebarItem` in navigazione, `FTextField` per ricerca, `FCard` e `FButton` in note/dettaglio. Restano ancora componenti Material come bridge, inclusi inserimento rapido, date picker e dialoghi. **Per migrazioni future leggere [ui-forui.md](ui-forui.md)** e conservare logica offline-first e test. Nessuna dipendenza backend aggiunta.

## Modali Forui (23/10/2026)
I vecchi `AlertDialog` Material di modifica attività/nota e `showDatePicker` per le scadenze sono stati sostituiti da `showFDialog` + `NotesDialog` e `FCalendar.grid`. Vedere `apps/flutter/lib/ui/notes_dialogs.dart`, `apps/flutter/lib/main.dart`, test widget. Persistenza locale e sync non modificate. Il bottom sheet dettagli mobile è ancora Material.

## Incremento P0 — conflitti, descrizioni e backup
Per la nuova sessione consultare **[P0-STATUS.md](P0-STATUS.md)**: backend latest con scope utente e Flyway V5; scelta conflitti in Forui senza cancellazioni automatiche; descrizione attività con Drift schema V3; script dump + restore isolato, verificati con database sintetico. I precedenti paragrafi su mancanza della UI di conflitto sono storici e sostituiti dal documento P0.

## Organizzazione attività — prossimo blocco implementato (23/10/2026)
Nuova guida [task-organization.md](task-organization.md): liste sincronizzate con versione e owner, priorità/tag/sottotask, editor Forui, ricerca/filtro e cancellazione sicura della lista. Drift v4 e Flyway V6. Backend CI e analyze/test Flutter automatici riusciti; prove Coolify e dispositivi fisici ancora aperte. **Aggiornamento 24/10:** Flyway V6 e V7 già presenti nel database; verificare API e sync hardware. Leggere [P0-STATUS.md](P0-STATUS.md).

## Vincolo UI deciso il 23 ottobre 2026 — inline editing first
Per titoli e altri valori testuali semplici, **preferire la modifica direttamente sul testo** a pulsanti `Rinomina`/dialog. Il titolo lista è editabile in header grazie a `InlineEditableTitle`; Invio/blur salvano, Esc annulla, SQLite/outbox invariati. Non reintrodurre la rinomina tramite modal salvo necessità motivata. Specifiche aggiornate in `design.md`, `docs/ui-forui.md`, `AGENTS.md`.
