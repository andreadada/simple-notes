# Flutter client — P0

Client Flutter Windows/Android con UI dark, task/note, **ricerca e modifica task**, Drift/SQLite e outbox transazionale. Sync manuale sperimentale con delta pull. Google Android/Windows PKCE richiede credenziali reali e test.

## Build
```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_ID
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```
Android Release richiede HTTPS. Configurare in Google Cloud Console gli OAuth client desktop, Android e Web; il secret desktop resta solo sul backend/Coolify.

## Limiti
La sync non è automatica; le credenziali Google non sono presenti nelle build CI; nessun test E2E con account reali. Mancano conflitti assistiti, promemoria, liste, tag e notifiche.
