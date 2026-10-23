# Simple Notes — Passaggio di consegne (handoff)

> **Aggiornato al 23 ottobre 2026.** Documento operativo per sviluppatori e assistenti AI che aprono la repository senza conoscere le chat precedenti. Verificare sempre il codice e gli ultimi workflow, non usare questo testo come sostituto dei test reali.

## TL;DR: che cos'è e a che punto siamo

- **Obiettivo:** app originale di produttività per Windows 11 e Android, con note, attività, futuro calendario/promemoria e moduli avanzati ispirati funzionalmente a TickTick, non una copia.
- **Architettura:** Flutter/Dart + Riverpod; Drift/SQLite per dati offline; Spring Boot Java 21 + PostgreSQL/Flyway per account e sincronizzazione; deploy Docker Compose su Coolify.
- **Server:** `https://api.notes.ddone.it` — `/actuator/health` ha restituito `{"status":"UP"}` secondo verifica manuale dell'utente. Non confondere servizio raggiungibile con produzione pronta.
- **Windows:** compilazione ed esecuzione reali, login Google Desktop completato manualmente (21/10/2026).
- **Android:** dispositivo fisico rilevato (`2412DPC0AG`), installazione e avvio iniziali verificati; dopo la correzione finale Gradle/JVM (23/10) l'utente riferisce **«funziona»**. Non è stato però confermato esplicitamente, dopo quest'ultima correzione, **se funziona anche il login Google Android**: richiedere/effettuare quella verifica prima di considerarlo completato.
- **CI:** [Flutter CI run 39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440) riuscita: analisi e test Flutter, build Windows, build Android con **JDK 17 e JDK 21**. Sono build tecniche, non prove di autenticazione/sync reali.
- **Sync:** implementata lato client come **azione manuale sperimentale**, con outbox SQLite e push/pull delta; **nessun test end-to-end Windows↔Android confermato**.
- **Stato del prodotto:** **P0 IN CORSO, non pronto per release pubblica**. La roadmap e i criteri di completamento sono in [../project.md](../project.md).

## Percorso di lettura per chi inizia da zero

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
| Sync manuale | `CloudSync.synchronize()` e API delta | Implementato, test PC↔Android mancante |
| Sync automatica e UI conflitti | Non implementati | Da fare |
| Backup/ripristino, rate limit, notifiche, release firmata | Non verificati o mancanti | Da fare |

## Prossima sessione: ordine di lavoro

1. **Accertare login Android** sul dispositivo fisico con Google (dopo il fix package/gradle) e testare restore sessione dopo riavvio. Se fallisce, usare [android-troubleshooting.md](android-troubleshooting.md), non modificare alla cieca Coolify.
2. **Test manuale sync a due device** con lo stesso account: creare `Test PC → Android` in Windows → `Sincronizza ora` Windows → sync Android e verificare; creare `Test Android → PC` sul telefono, sync Android → sync Windows; ripetere con una nota.
3. **Verificare offline/retry e conflitti**: creare item offline e sincronizzare al ritorno della rete; una collisione deve **preservare l'outbox**, non sovrascrivere contenuti silenziosamente. Controllare isolamento dati al cambio account.
4. Solo dopo E2E stabile, sviluppare **sync automatica** (all'avvio, riconnessione, dopo modifica, retry/backoff) con test; poi reminder/notifiche e altre P0 secondo [../project.md](../project.md).
5. Prima di pubblicare: firma Android **release** (attualmente debug per test), backup e prova restore PostgreSQL, rate limiting auth, sicurezza e validazione completa dei flussi.

## Convenzioni per chi implementa

- Lavorare in piccoli commit, testare il comportamento e annotare il risultato in `project.md` → `Edit Timespan`. Aggiornare le checklist **solo dopo verifica**.
- L'utente preferisce le correzioni **direttamente nel repository GitHub** e poi `git pull` sul PC; evita istruzioni per modifiche manuali permanenti quando puoi committare la correzione. Non sovrascrivere lavoro locale o forzare operazioni distruttive.
- Non modificare secret Coolify o Google Cloud per risolvere una semplice build Gradle.
- Il codice deve rimanere offline-first: salvare prima su SQLite/outbox, non perdere modifiche locali per conflitto o rete non disponibile.
- Non dichiarare `P0 completato`, `sync verificata`, `Google Android verificato` o `produzione pronta` senza prove esplicite.
- Distinguere **fatti da codice**, **successo della CI**, **conferma manuale dell'utente** e **lavoro ancora in sospeso**.
