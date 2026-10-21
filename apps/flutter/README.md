# Flutter client — P0

- UI dark Windows/Android, task e note **offline-first** su SQLite/Drift.
- Le modifiche entrano in una outbox transazionale con UUID.
- Google Android nativo / Windows browser PKCE + code exchange server-side.
- Dopo l'accesso puoi scegliere **Sincronizza ora** per inviare la coda locale e scaricare delta; errore 409 interrompe la sync e conserva i dati.
- Sincronizzazione manuale **sperimentale**: non usare come backup unico.

## Build
```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_ID
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Server: segreti Google, PostgreSQL, HTTPS per la produzione (v. `../../infra/README.md`). Test login reale richiede OAuth client registrati.

### Limiti
- Sync non ancora automatica in background; non ci sono ancora UI di risoluzione conflitti e full-sync recovery.
- REST legacy task/note non genera change log; tutte le nuove operazioni cloud devono usare `/sync/apply`.
- Archivio SQLite legato al primo account sincronizzato: l'app blocca upload verso account diversi.
- Notifiche, liste/ricorrenze e gestione multi-account ancora in roadmap.
