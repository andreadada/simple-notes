# Android — build, firma, Google OAuth e installazione

<!-- CURRENT-STATUS-REF -->
> **SNAPSHOT STORICO / GATE 26/10/2026:** `main` include P1.11 Habit Tracker (Flutter `0.16.0+18`, PR #12, CI verde); Countdown P1.12 `0.17.0+19` è **solo su branch**. Funzioni Pomodoro/Habits/Countdown **device-only**, nessuna sync o nuova migration; repo Flyway V10, server Coolify ultimo attestato V8. Nessun deploy/reset. Le istruzioni precedenti descrivono verifiche e versioni storiche, **non** l'attuale rilascio. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Countdown](P1-COUNTDOWNS.md).


> Runbook basato sui problemi reali risolti il 22–23 ottobre 2026. Package Android **`it.andreadada.simplenotes`**. Per il quadro completo leggere [HANDOFF.md](HANDOFF.md).

## 1. Avvio sul dispositivo Android

Da PowerShell:

```powershell
cd E:\dev\simple-notes
git pull origin main
cd apps\flutter
flutter devices
flutter pub get
dart run build_runner build
flutter run -d 2412DPC0AG `
  --dart-define=API_BASE_URL=https://api.notes.ddone.it `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

L'identificativo `2412DPC0AG` indica il dispositivo usato nei test; su altri PC usare l'ID restituito da `flutter devices`.

Se ADB non rileva il telefono: attivare **Opzioni sviluppatore → Debug USB**, collegare con cavo dati, sbloccare il telefono, autorizzare il computer e verificare `adb devices -l`.

## 2. Firma Android per Google OAuth

Nel client Google Cloud di tipo **Android** confrontare rigorosamente:

- `applicationId` nel `android/app/build.gradle.kts` = **`it.andreadada.simplenotes`**;
- SHA-1 di **quella build** = SHA-1 registrato nel client OAuth Android.

Eseguire:

```powershell
cd E:\dev\simple-notes\apps\flutter
Select-String -Path .\android\app\build.gradle.kts -Pattern 'applicationId|namespace'
Push-Location .\android
.\gradlew.bat signingReport | Select-String 'Variant: debug' -Context 0,12
Pop-Location
```

Se l'invocazione diretta di Gradle fallisce con `Gradle requires JVM 17 or later; currently configured to use JVM 8`, controllare quale Java utilizza Flutter con `flutter doctor -v` e impostare **temporaneamente nella shell corrente** `JAVA_HOME` a una JDK 17 o 21 compatibile prima di rilanciare `gradlew.bat`. Non confondere la Java in `PATH` con quella scelta automaticamente da Flutter/Android Studio.

Nell'app Flutter il parametro `GOOGLE_WEB_CLIENT_ID` e `GoogleSignIn.initialize(serverClientId: ...)` usano invece l'**OAuth Client ID Web**. Non passare il Desktop client né un Client Secret sul telefono. Se l'auth consent screen è in modalità Testing, autorizzare l'account come test user.

L'APK artifact della CI è compilato con chiave debug del runner: **può avere SHA-1 diverso** da quello registrato per il debug locale. Non usare il successo della build CI come conferma del login Google reale.

## 3. Errori incontrati e interventi

| Errore | Diagnosi reale | Soluzione/referenza |
| --- | --- | --- |
| `this and base files have different roots`, Kotlin incremental | Pub cache su C:, app su E: | `android/gradle.properties`: `kotlin.incremental=false`; poi `flutter clean` |
| `Gradle requires JVM 17 or later ... JVM 8` | PowerShell avvia Java 8 | Impostare JDK 17 o 21 per shell/Gradle |
| `Unresolved reference compilerOptions / jvmTarget` | DSL `kotlin { ... }` non valido in quel setup | Non aggiungere blocco top-level Kotlin senza compatibilità verificata |
| `compileDebugJavaWithJavac (17)` / `compileDebugKotlin (21)` | JVM target Java/Kotlin discordanti usando JDK 21 | `compileOptions` Java ora usa `JavaVersion.current()`; verificato CI JDK 17/21 |
| `INSTALL_FAILED_USER_RESTRICTED` | Blocco autorizzazioni sul dispositivo, non errore di build | Autorizzare **Installa tramite USB** nelle opzioni sviluppatore e accettare il prompt del telefono |
| `GoogleSignInException [16] Account reauth failed` | In passato package OAuth Android diverso dall'app (`com.example.simple_notes`) e possibile sessione Google preesistente | Usare `it.andreadada.simplenotes`, SHA-1 coerente, Web serverClientId, eventuale test user; logout client chiama `GoogleSignIn.signOut()`. **Login Android dopo i fix ancora da confermare** |

La compilazione Kotlin del modulo app può comparire nonostante `enableKotlin=false`; disabilitare soltanto il flag non ha risolto il problema JDK 21. Evitare `kotlin.jvm.target.validation.mode=ignore`: maschererebbe il disallineamento invece di correggerlo.

## 4. Pulizia build e installazione

```powershell
cd E:\dev\simple-notes\apps\flutter
flutter clean
flutter pub get
flutter run -d 2412DPC0AG `
  --dart-define=API_BASE_URL=https://api.notes.ddone.it `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

`✓ Built ... app-debug.apk` dimostra la **build riuscita**, non l'installazione. Su POCO/Xiaomi/HyperOS tenere il telefono sbloccato e controllare **Debug USB** e **Installa tramite USB**. Evitare disinstallazioni o `pm clear` senza salvare le eventuali note locali non ancora sincronizzate: questi comandi **cancellano dati dell'app**.

## 5. Versionamento e risultati

File Android ora versionati:
- `apps/flutter/android/app/build.gradle.kts` — package/namespace e JVM compatibility.
- `apps/flutter/android/gradle.properties` — Kotlin incremental e configurazione AGP.
- `apps/flutter/android/app/src/main/java/it/andreadada/simplenotes/MainActivity.java`.
- `.github/workflows/flutter-ci.yml` — test JDK 17/21, analisi e Windows.

[CI run 39955667440](https://github.com/andreadada/simple-notes/actions/runs/39955667440): **successo completo** (Android JDK 17/21, Windows, analyze/test). Successivamente l'utente ha riferito che l'app **funziona** sul dispositivo; l'effettiva autenticazione Google Android e la sync a due dispositivi restano verifiche distinte.

**Non modificare package o chiavi Google senza verificare il client OAuth corrispondente.**
