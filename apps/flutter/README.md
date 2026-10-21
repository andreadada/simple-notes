# Flutter Windows/Android — P0

**Client ora basato su Drift/SQLite** (task, note e outbox locale transazionale), con import una tantum dal primo prototipo SharedPreferences. Google login è presente, ma richiede configurazione OAuth e test reali. La sync server NON è ancora attiva: le operazioni restano nella outbox SQLite.

## Build
```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_ID
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_ID
```

Per le credenziali Google configura OAuth desktop, Android SHA-1/package e Web client ID; **client secret desktop solo su Coolify** come `GOOGLE_DESKTOP_CLIENT_SECRET`.

## Stato
- SQLite, tabelle e outbox create; migrazione dal prototipo preserva le attività.
- Login Windows PKCE / Android nativo implementato nel codice; real OAuth non ancora verificato.
- Outbox non viene ancora spedita; conflitti e delta sync sono il prossimo milestone.
- Le build automatiche sono su GitHub Actions.
