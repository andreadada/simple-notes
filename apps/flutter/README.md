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

## Limiti
La sync non è automatica; le credenziali Google non sono presenti nelle build CI. **Login reale Windows verificato dall'utente**, ma nessun test E2E tra Windows e Android né validazione completa della persistenza sessioni. Mancano conflitti assistiti, promemoria, liste, tag e notifiche.
