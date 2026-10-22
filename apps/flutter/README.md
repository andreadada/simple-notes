# Flutter client — P0

Client Flutter Windows/Android con UI dark, task/note, **ricerca e modifica task**, Drift/SQLite e outbox transazionale. Sync manuale sperimentale con delta pull. **Windows + login Google reale** avviati e verificati manualmente (21 ottobre 2026); **Google Android** e sync su due dispositivi ancora da testare.

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

## Debug Google Login Android: `[16] Account reauth failed`

Questo errore può essere restituito da Google Credential Manager come `canceled` **anche se l'utente non ha annullato il login**. Verificare prima i tre elementi OAuth, senza cambiare il backend funzionante:

1. Dal terminale nella cartella `apps/flutter`, eseguire `Select-String -Path android\\app\\build.gradle.kts -Pattern 'applicationId'`. Il risultato deve coincidere **esattamente** con il package name del client Google Cloud Android.
2. Eseguire `cd android` e `.\\gradlew.bat signingReport`. Nel blocco **Variant: debug**, leggere `SHA1` e confrontarlo con l'impronta registrata sul client Google Cloud Android. Questa impronta, relativa al certificato effettivamente usato da Gradle, è preferibile a copiare manualmente l'output localizzato di `keytool`.
3. Tornare alla cartella `apps/flutter`. Passare a Flutter con `--dart-define=GOOGLE_WEB_CLIENT_ID=...` **il Client ID di tipo Web application**, non l'ID Android. Controllare che il test user sia autorizzato se l'app OAuth è in Testing.
4. Dopo aver corretto package/SHA-1/client, se l'errore continua, **disinstallare solo l'app di test Android** e reinstallarla (avviso: la disinstallazione cancella i dati locali dell'app non sincronizzati). In alternativa diagnosticare il logcat di Google Play Services. Non cancellare i dati di Google Play Services.

Il logout su Android ora esegue anche `GoogleSignIn.instance.signOut()`: Google Credential Manager altrimenti può conservare una sessione precedente e fallire la riautenticazione. Il primo login Android non è ancora verificato, quindi questa correzione non garantisce da sola di eliminare il codice 16.

## Limiti
La sync non è automatica; le credenziali Google non sono presenti nelle build CI. **Login reale Windows verificato dall'utente**, ma nessun test E2E tra Windows e Android né validazione completa della persistenza sessioni. Mancano conflitti assistiti, promemoria, liste, tag e notifiche.
