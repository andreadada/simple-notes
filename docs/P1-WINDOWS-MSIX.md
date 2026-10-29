# P1.7 Windows — MSIX e promemoria opt-in

> **Stato operativo 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).

**Stato 26/10/2026:** **integrata in `main` con PR #7** (merge `34106c4`, Flutter `0.12.0+14`, [CI 40245561264 verde](https://github.com/andreadada/simple-notes/actions/runs/40245561264)); **non installata o verificata su PC reale**, non rilasciata. Backend Flyway V10 e Drift V8 invariati. La release corrente del codice su `main` è ora Flutter `0.13.0+15` (PR #8); non installare nuovi client fino a verifica dell'API Coolify e compatibilità dell'upgrade MSIX.

## Implementazione

- `flutter_local_notifications` già usato da Android ora riceve `WindowsInitializationSettings` e `WindowsNotificationDetails` su Windows. Lo stesso scheduler deterministico (14 giorni / massimo 100 reminder; 15 minuti di anticipo; nessuna data civile senza orario) e il ledger persistente sono condivisi; i promemoria sono locali per dispositivo.
- `ReminderController.supported` consente Windows **solo** quando `MsixUtils.hasPackageIdentity()` è vero. Un eseguibile ZIP non propone l'opt-in e non pianifica nulla: il plugin non può garantire l'annullamento delle notifiche senza package identity.
- Opt-in solo dal menu account, preferenza spenta per default. Non pianificare se l'account Google non corrisponde al `boundOwnerId` locale. Logout interrompe l'uscita se non riesce a cancellare gli eventi in ledger. Testo delle notifiche generico e privato.
- Package `msix` in `dev_dependencies`; `msix_config` fissa `ddone.SimpleNotes` e versione `0.12.0.0`. La CI Windows tenta il build di un MSIX **di prova** e conserva il tradizionale artifact EXE/ZIP.
- Nessuna migrazione DB, reset, deploy, modifica delle credenziali o modifica delle notifiche Android.

## Gate aperti prima del merge e dell'installazione

1. [x] Flutter analyze/test, build Windows/Android JDK17/21 e packaging MSIX CI verdi su PR #7; [ ] verificare installazione/pacchetto MSIX reale e aggiornamento coerente. Non interpretare il solo file YAML come build riuscita.
2. [ ] Installa **solo in ambiente di prova** un MSIX firmato da un certificato di test attendibile, senza promuovere un certificato auto-generato a produzione. Verifica `hasPackageIdentity` true e menu opt-in. Controlla compatibilità OAuth, SQLite/Drift e percorso dati rispetto alla vecchia installazione ZIP **prima** di trasferire utenti reali: MSIX può usare un percorso differente.
3. [ ] Verifica notifica su Windows con app chiusa, riavvio, risveglio e lock screen; modifica/completa/elimina task e conferma cancellazione nativa e mancanza duplicati; prova logout/cambio account e disattivazione.
4. [ ] Verifica lo stato inattivo per EXE/ZIP senza package identity e per ogni piattaforma non supportata.
5. [ ] Scegli firma e publisher reale stabile per la distribuzione finale; **non** rilasciare un MSIX con certificato di prova o firma assente. Installazioni MSIX con identità/certificati differenti non hanno upgrade garantito.
6. [ ] Coolify: conferma Flyway V10 e capability prima dei nuovi client; poi un solo test E2E Windows↔Android, senza reset dati.

## Comandi di sviluppo (su Windows)

```powershell
cd E:\dev\simple-notes
git fetch origin
git switch feature/p1-7-windows-msix-reminders
cd apps\flutter
flutter pub get
flutter create --platforms=windows --project-name simple_notes .
dart run build_runner build
flutter analyze
flutter test
flutter build windows --release
dart run msix:create --build-windows false
```

Il comando MSIX è **packaging, non installazione**. I valori `publisher`, `identity_name` e `guid` sono stabili e devono essere rivisti insieme prima di una release firmata. Evitare `Add-AppxPackage` sui profili contenenti dati prima di validare i percorsi dei file e la persistenza delle sessioni. La CI non esegue alcun deploy.

**Fonti di verità:** [CURRENT-STATUS.md](CURRENT-STATUS.md), [P1-REMINDERS-FOUNDATION.md](P1-REMINDERS-FOUNDATION.md), [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md).

## P1.16 — Gate visuale e dati per ZIP→MSIX

Verificare note a 1/2/3 colonne, editor inline e sticky pop-out con resize, oltre alla continuità SQLite/outbox, secure storage, SharedPreferences e identità MSIX. La P1.16 modifica soltanto layout Flutter; non autorizza reinstallazioni o reset. [Specifiche](P1-RESPONSIVE.md).

## P1.17 — Nuova icona tray su ZIP/MSIX

Verificare X→tray, click/menu→riapri, Esci→processo terminato e nessuna icona orfana con ZIP completo/MSIX di test. Preservare identità/publisher, SQLite/outbox, secure storage e SharedPreferences; il ZIP non ottiene toast MSIX grazie alla sola icona. [Specifica](P1-WINDOWS-TRAY.md).
