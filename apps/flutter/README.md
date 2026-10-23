# Flutter client — P0

Client Flutter Windows/Android con UI dark, task/note, **ricerca e modifica task**, Drift/SQLite e outbox transazionale. Auto-sync foreground sperimentale con delta pull, outbox e retry con backoff; sync manuale ancora disponibile dal menu profilo. **Windows + Google Login Desktop** verificati manualmente (21/10/2026); **Android avviato e segnalato funzionante** dopo il fix JVM del 23/10 (CI JDK 17/21 riuscita). **Google Login Android dopo il fix e sync fra due dispositivi ancora da verificare esplicitamente.** Vedere [handoff](../../docs/HANDOFF.md) e [runbook Android](../../docs/android-troubleshooting.md).

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

## Limiti
La sync non è automatica; le credenziali Google non sono presenti nelle build CI. **Login reale Windows verificato dall'utente**, ma nessun test E2E tra Windows e Android né validazione completa della persistenza sessioni. Mancano conflitti assistiti, promemoria, liste, tag e notifiche.
