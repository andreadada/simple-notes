# Simple Notes client — Flutter

Target: Windows 11 + Android. L'app Flutter **non è ancora generata**.

Bootstrap da eseguire da questa directory con Flutter SDK installato:

```bash
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub add flutter_riverpod go_router drift sqlite3_flutter_libs path_provider path
flutter pub add --dev drift_dev build_runner
flutter analyze
flutter test
```

Da realizzare: design system responsive, autenticazione Google (flussi separati Windows/Android), SQLite locale e sync engine. **Non** salvare token in chiaro e non aggiungere credenziali reali al Git.
