# Guida operativa — Simple Notes

> **Stato operativo (26/10/2026):** P1.13 obiettivi settimanali su `main` (PR #14, Flutter `0.18.0+20`, CI verde). P1.14 finestre Sticky Windows è **solo nel branch** `feature/p1-14-sticky-windows` (`0.19.0+21`, CI/merge/device da verificare). Repo Flyway V10; ultima VPS attestata V8. Nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [P1.14](P1-STICKY-WINDOWS.md).

**Fonte operativa** per il checkout locale Windows, CI, Coolify, Android e Windows ZIP/MSIX. **Ultimo stato verificabile (26/10/2026):** Flutter 0.18.0+20 P1.13 su `main`, CI verde; backend repository Flyway V10/Drift V8; **ultima VPS confermata Flyway V8**. L'incremento P1.14 Sticky Windows è in sviluppo nel branch `feature/p1-14-sticky-windows` (Flutter 0.19.0+21); una PR e una build non sono un deploy. Leggere sempre [CURRENT-STATUS.md](CURRENT-STATUS.md) per lo stato successivo.

## 0. Regola fondamentale

**Codice nel repo → CI → deploy API/database Coolify → verifica → build/installazione client → test su dispositivi.** Non confondere i passaggi.

- Non eliminare o ricreare database, volumi, SQLite, outbox, account Google o installazione Android. Mai `docker compose down -v`, `adb uninstall`, `pm clear`, `git reset --hard` o pulizie automatiche.
- Un build Windows ZIP **non** è un MSIX. Le notifiche su Windows richiedono **package identity MSIX** e un installer firmato attendibile, oltre alla verifica di percorso SQLite/secure storage/OAuth. Il pacchetto CI è **solo di sviluppo**, non di produzione.
- Se l'auto-deploy Coolify è attivo, verificare il commit e lo schema realmente applicati, non presumere che una PR abbia migrato la VPS.

## 1. Allineare il PC Windows senza perdere modifiche

Da PowerShell, nella directory già presente:

```powershell
cd E:\dev\simple-notes
git status --short
git branch --show-current
git fetch origin
git log -1 --oneline origin/main
```

Se `git status --short` è vuoto e sei su `main`, aggiorna con:

```powershell
git pull --ff-only origin main
```

Se hai modifiche tracciate, **fermarsi e confrontarle**; il pull può rifiutare l'operazione, ma non cancellare, stasciare né resettare automaticamente. Se stai preparando una release, non compilare una PR o un branch in sviluppo pensando che sia `main`.

## 2. Avviare Flutter Windows (sviluppo)

Presupposti: Flutter SDK, Visual Studio con Desktop development with C++, Git e Dart. I due ID Google OAuth pubblici devono essere configurati localmente (nessun secret nel repository):

```powershell
cd E:\dev\simple-notes
if (-not (Test-Path -LiteralPath .t4-device-build.json)) {
  Copy-Item tools\t4-device-build.example.json .t4-device-build.json
}
# Compila .t4-device-build.json solo al primo setup, senza segreti.
# Se il file esiste già, non sovrascriverlo.
.\tools\t4-build-devices.ps1 -Target windows -ValidateOnly
.\tools\t4-build-devices.ps1 -Target windows -CheckOnly
```

Per la compilazione riproducibile e l'archivio Windows ZIP:

```powershell
.\tools\t4-build-devices.ps1 -Target windows -RequireClean
```

Lo script crea l'archivio sotto `build/t4-device-acceptance/` e un `MANIFEST.txt` con commit e SHA256. Non installa né cancella dati. Per eseguire in sviluppo da un checkout già predisposto, la build usa `apps/flutter`; i comandi Flutter manuali devono ricevere gli stessi dart-defines di OAuth/API del manifest, altrimenti il login può risultare non configurato. I comandi della sezione build sono il percorso raccomandato per una versione verificabile.

## 3. Creare Windows e Android da uno stesso checkout

```powershell
cd E:\dev\simple-notes
.\tools\t4-build-devices.ps1 -Target both -RequireClean
```

- **Windows ZIP:** estrarre l'intera cartella e conservare tutte le DLL assieme all'EXE. Questa distribuzione **non attiva notifiche Windows**. Non spostare/riscrivere SQLite/secure storage manualmente.
- **Android:** su telefono già configurato, l'aggiornamento preservante dati richiede `adb install -r <PERCORSO_APK>` con **firma compatibile**. Se la firma non coincide, fermarsi: **non disinstallare**.
- **Windows MSIX:** il job Flutter CI produce un pacchetto di **prova**; prima di usarlo su un PC reale servono firma/publisher coerenti e un test di migrazione dati ZIP→MSIX in profilo di prova. `dart run msix:create --build-windows false` non installa. Non presentare `CN=DDone` in `pubspec.yaml` come certificato di produzione verificato.

## 4. Test prima di distribuire

Verificare sullo **stesso commit**: Flutter `analyze`, `test`, APK Android JDK 17/21, Windows EXE/MSIX e CI Markdown. La CI attesta la compilazione ma non l'accesso Google sui dispositivi, la delivery degli allarmi, la migrazione dei dati MSIX o la sync reale.

Per lo stato aggiornato usare [GitHub Actions](https://github.com/andreadada/simple-notes/actions), scegliere il run associato al commit corretto e verificare i job. Nessuna installazione viene eseguita dal workflow.

## 5. Coolify — solo dopo una decisione esplicita del proprietario

La risorsa preesistente è Simple Notes, Compose root `docker-compose.yml`, database `simplenotes` su PostgreSQL 17 con volume persistente. **Non creare una seconda risorsa DB**. Il runbook completo è [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md).

Sulla VPS, prima del deploy, inventory **read-only**:

```bash
cd ~/simple-notes
git status --short
docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep gs0yzfz42hpriybaxcfbtjnk
# Sostituire il valore con il vero container PostgreSQL corrente:
DB_CONTAINER=<ID_DB_REALE> EXPECTED_POSTGRES_DB=simplenotes bash infra/t4-inspect-db.sh
```

L'ultimo schema **confermato dal proprietario** è Flyway V8; `main` contiene V9 e V10 ma **questo non è una prova di applicazione reale**. Prima dell'aggiornamento conservare backup e piano di ripristino appropriati; l'ultimo restore isolato attestato è storico e non protegge automaticamente nuovi dati. Solo il proprietario esegue **Redeploy** sulla stessa risorsa esistente. In caso di errore della migration, STOP senza `flyway repair` o cancellazione volumi.

Dopo il redeploy, eseguire le verifiche read-only:

```bash
DB_CONTAINER=<ID_DB_CORRENTE> EXPECTED_POSTGRES_DB=simplenotes bash infra/t4-inspect-db.sh
curl -fsS https://api.notes.ddone.it/actuator/health
```

Per i client P1.8–P1.13 si attendono `FLYWAY_LATEST=10`, `FAILED_MIGRATIONS=0`, health `UP` e capability autenticate `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`. Usare JWT solo localmente, senza incollarli nei log/chat. Un health `UP` non basta.

## 6. Un solo collaudo batch Windows ↔ Android

Su **stesso account Google**, dopo aver attestato la compatibilità server:

1. Note, cestino, attività, liste, tag, sottotask e modifica inline; verifica pending=0 e cursor dopo sync.
2. Offline su un dispositivo → modifiche → online → compare sull'altro; conflitto HTTP 409 distinto da blocco upgrade 426, senza outbox persa.
3. Calendario, più blocchi, ricorrenze, Eisenhower e Kanban (cambio lista trascinando) sincronizzati; nessun reset.
4. Pomodoro, Habit Tracker e Countdown: dati **locali per account/dispositivo**, timer che sopravvive alla navigazione/riavvio, streak e check-in su date civili; statistiche non sincronizzate; verificare che i profili Google differenti non condividano i dati.
5. Promemoria Android opt-in, permesso negato, uscita, riavvio e inexact. Promemoria Windows **solo se MSIX** firmato e validato in profilo di prova.
6. Verificare che entrambi i client conservino i dati dopo l'upgrade; su MSIX **non** procedere sui profili reali finché non è dimostrata la compatibilità del percorso locale.

**Non segnare rilasciato o test hardware riuscito senza evidenze concrete.** Nessun passaggio di questa guida autorizza installazione o deploy automatico.

## Note P1.10 (non distruttive)

Il timer Pomodoro persiste in `SharedPreferences` con chiave locale per owner. Non eseguire reset/clear storage per testarli; usare un profilo di prova. Non trattare statistiche del Pomodoro come sincronizzate né come dati del database PostgreSQL. Vedere [specifica P1.10](P1-POMODORO.md).

## P1.11 (main): verifiche non distruttive

Provare sul profilo di test: una abitudine, check-in/undo, streak ieri/oggi, archivio/restore, re-login e cambio account, fuso DST e giorno civile. Le abitudini salvate in SharedPreferences non sono dati cloud. Non cancellare preferenze/SQLite di un profilo reale, specialmente nel passaggio ZIP→MSIX; verificare la continuità di entrambi. [Dettagli](P1-HABITS.md).

## P1.12 — Countdown e integrità dei dati

Countdown riutilizza l'editor `TaskDue` e salva solo SharedPreferences device/owner: **non** è una nuova funzionalità cloud. Per i test verificare data civile vs istante IANA/DST, modifica titolo inline, cambio data, archivio/restore, login e riapertura. Nessun reset dati, nessuna notifica quando l'app è chiusa. Prima di ZIP→MSIX verificare anche la persistenza di preferenze e secure storage, non solo SQLite. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Obiettivi settimanali senza perdita dati

Il JSON `simple_notes.habits.v1.<ownerHash>` usa sempre schema 1: le abitudini precedenti senza `weeklyTarget` devono rimanere leggibili con default 7. Prima di aggiornare su dispositivi reali, testare su profilo di prova almeno una vecchia abitudine, cambiare obiettivo 3/7, verificare che tutte le date e l'archivio restino identici; verificare il rollover della settimana e DST. **Mai azzerare SharedPreferences per risolvere incompatibilità.** [P1.13](P1-WEEKLY-HABITS.md).

## P1.14 — Prova Windows Sticky non distruttiva

Aprire dalla sezione Note due finestre diverse, verificare che editor e outbox del main siano aggiornati al salvataggio, provare due aperture della stessa nota e un conflitto su titolo/corpo. Le finestre detached non aprono un secondo DB. ZIP Windows deve contenere EXE, DLL, plugin; MSIX solo in profilo di prova con firme e path verificati. Android non offre il pop-out. Non reinstallare/reset SQLite per riparare problemi multiwindow. [Specifica](P1-STICKY-WINDOWS.md).
