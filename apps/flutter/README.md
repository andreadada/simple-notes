# Client Windows + Android (P0)

Protótipo UI task/note **locali**; autenticazione Google integrata in codice, **non ancora collaudata con OAuth client reali**. Sincronizzazione automatica ancora da implementare.

## Generazione, test e build
```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
flutter analyze
flutter test
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_ID.apps.googleusercontent.com
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_ID.apps.googleusercontent.com
```

## OAuth Google (obbligatorio per il cloud)
- In Google Cloud Console configura la schermata di consenso e un client OAuth **Desktop app** per Windows, più client Android (package+SHA-1) e Web client ID per `google_sign_in`.
- Server Coolify: `GOOGLE_CLIENT_IDS` ammette entrambi gli ID token; imposta `GOOGLE_DESKTOP_CLIENT_ID` e **`GOOGLE_DESKTOP_CLIENT_SECRET` sul server**. Mai distribuire il secret nella build.
- Windows: browser di sistema, loopback `127.0.0.1:<porta>/oauth/callback`, PKCE S256 e state random; token exchange tramite API.
- Android: login nativo Google e ID token validato dal server.
- `API_BASE_URL` in produzione deve essere HTTPS. Senza queste impostazioni l'app resta in modalità locale.

## Limitazioni attuali
- Task/note ancora salvati in SharedPreferences: da migrare a Drift/SQLite **prima** della sincronizzazione.
- Il login cloud non sincronizza ancora contenuti. Non considerare completa la fase P0.
- Build automatiche: GitHub Actions → Flutter CI → Artifacts.
