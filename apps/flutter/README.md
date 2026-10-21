# Simple Notes — Flutter client (P0 local prototype)

Flutter source exists in `lib/` and a widget test in `test/`. Because platform-generated scaffolds are not yet committed, initialize Android/Windows templates before building:

```bash
cd apps/flutter
flutter create --platforms=android,windows --project-name simple_notes .
flutter pub get
flutter analyze
flutter test
flutter run -d windows
# or flutter run -d <android-device-id>
```

**Working scope:** dark adaptive UI, local tasks and simple notes persisted using SharedPreferences. **Not yet implemented:** Google login UI, sync with backend, Drift database, reminders, signed installers, generated platform projects. SharedPreferences is TEMPORARY; data must be migrated to Drift before production.

To configure Google login later you will need registered Android and Windows Google OAuth clients. Do not commit credential files.
