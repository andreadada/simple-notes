# Guida operativa — Simple Notes

> **Stato operativo 02/11/2026:** R1 gate server-first integrato su `main` ([PR #26](https://github.com/andreadada/simple-notes/pull/26), commit [`f19ee8b0`](https://github.com/andreadada/simple-notes/commit/f19ee8b0a5bea2cb2c2231d85b3e8ad10a5233a7); [Compose CI](https://github.com/andreadada/simple-notes/actions/runs/41523319857) **success** con PostgreSQL 17 sintetico, [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41523319860) **success**). Flutter resta `0.29.0+31` e 191 test già attestati. **VPS reale V10, health/capability live, backup recente e collaudo hardware non verificati**; ultimo stato VPS attestato V8. Nessun deploy o intervento su dati. [Stato](CURRENT-STATUS.md) · [R1]( RELEASE-V10-READINESS.md).

**Fonte operativa** per il checkout locale Windows, CI, Coolify, Android e Windows ZIP/MSIX. **Baseline `main` verificata al 31/10/2026:** P2.2 ICS (Flutter `0.25.0+27`) integrata con CI verde. **Incremento P2.3A integrato:** PR #22 su `main`, Flutter `0.26.0+28`, CI verde (166 test, Windows/Android/Markdown); hardware ancora da collaudare. Backend repository Flyway V10 / Drift V8, **ultima VPS confermata Flyway V8**; release e collaudo device non attestati. Leggere sempre [CURRENT-STATUS.md](CURRENT-STATUS.md).

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

Per il client cumulativo fino a P1.18 si attendono `FLYWAY_LATEST=10`, `FAILED_MIGRATIONS=0`, health `UP` e capability autenticate `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1`. Usare JWT solo localmente, senza incollarli nei log/chat. Un health `UP` non basta.

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

## P1.15 — Verifica scorciatoie Windows

Su Windows testare `Ctrl+1..5`, `Ctrl+Shift+T` (focus nuovo task senza inserimento), `Ctrl+Shift+N` (nota creata in LocalStore/outbox), `Ctrl+/` e tasto icona tastiera (help Forui). Verificare Ctrl+C/V/Z/A mentre si modifica un titolo, tastiera italiana, dialoghi e rientro in sticky pop-out. Android deve restare invariato. No deploy/reset per la P1.15. [Specifica](P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Collaudo viewport non distruttivo

Su PC Windows: creare tre note con titoli e corpi diversi, verificare passaggio da una a due e tre colonne al ridimensionamento senza taglio o cambio ID, continuando a modificare inline, aprendo una sticky e verificando la sync normale delle note. Android: larghezze 320 e 390 px, landscape, tastiera aperta e task input/due. La griglia non salva niente al resize. Nessun reset, deploy o cambi di schema: [P1.16](P1-RESPONSIVE.md).

## P1.17 — Verifica tray Windows non distruttiva

Nel ZIP completo con EXE/DLL: X→tray senza uscire, click/menu Apri→stessa finestra, menu Esci→terminazione completa senza icona orfana. Provare insieme a una Sticky senza seconda tray; se il plugin non si avvia, X deve funzionare normalmente. In MSIX usare profilo di prova e preservare SQLite, outbox, secure storage, SharedPreferences, firma/identity. Nessun deploy/reset. [Specifica](P1-WINDOWS-TRAY.md).

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](P1-APPEARANCE.md) · [Stato](CURRENT-STATUS.md).

## Gate P2.1 (main, CI verde, nessun deploy)

Android e Windows usano il picker file di sistema; verificare un JSON salvato, apertura, annullamento, test import con profilo di prova e persistenza dopo riavvio. Importare su account connesso crea **nuove** operazioni outbox; non importare dataset reali durante prova. Prima di sincronizzare copie importate con Coolify, attestare Flyway V10 e capability. Il JSON non sostituisce il backup/restore isolato di PostgreSQL o il backup SQLite. [Specifica](P2-PORTABLE-ARCHIVE.md).


## Gate P2.2 — File ICS esterni (main, CI verde, dispositivo reale da collaudare)

Collaudo reale Windows/Android: file UTC, all-day, fuso Europe/Rome, DST, import/reimport/revoke, annullamento picker, cambio account e riavvio. Confermare che l'overlay non scrive SQLite, outbox, API o token; condividere un file ICS può includere dati personali, usare sorgenti di prova. File non supportati **devono essere rifiutati** senza modifiche parziali. [Specifica](P2-ICS.md).

## Gate P2.3A — Migrazione locale ICS

Nel client Flutter `0.26.0+28`, leggere i dati P2.2 `schema=1` non deve modificarli finché l'utente non conferma import/rimozione. Dopo la prima modifica l'archivio è in `schema=2`, che i client P2.2 precedenti non leggono: **non eseguire downgrade senza una strategia di conservazione dati**. Verificare su dispositivo file importato, ri-import e rimozione corretta quando sorgenti hanno etichette uguali, cambio account durante dialog e assenza di mutazioni cloud. Non aggiornare Coolify per la sola P2.3A; per il **batch cumulativo** resta il gate backend V10. [Specifica](P2-ICS-SOURCES.md).

## Gate P2.3B — Test senza perdita dati

Con file di prova Windows/Android verificare import/reimport, RDATE/EXDATE, override e cancellazioni, fusi IANA/DST, rilettura vecchi schema 1/2, riavvio e cambio account. File non supportati devono fallire senza alterare l'archivio. Non tornare a client 0.26 dopo scrittura schema 3. Nessun deploy per questa feature locale. [Runbook](P2-ICS-RECURRENCE.md).

## Gate P2.3C — Test feed HTTPS

Verificare con URL HTTPS di prova: import confermato, riavvio offline, refresh, errore rete/redirect/ICS invalida senza perdita cache, rimozione per ID e account isolation. URL e query token non devono apparire nel testo delle card o nei log. Nessun deploy necessario per i soli feed locali. [Specifica](P2-ICS-FEEDS.md).

## Gate P2.3D — Etichetta ICS e prova fisica

Usare file e feed di test: rinominare il titolo direttamente, salvare con Enter/blur e annullare con Esc, chiudere/riaprire la pagina e riavviare l'app. Reimportare lo stesso file/aggiornare feed HTTPS: non perdere etichetta, UID, eventi o ID; cancellare per ID e cambiare account senza dati visibili dell'altro. Non visualizzare mai token URL; ultimo refresh deve rappresentare l'ultimo **successo**, non un errore. Test Android/Windows prima del rilascio cumulativo, dopo gate V10 del backend. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## R1 — Gate V10 di sola lettura, non un deploy

Da VPS identificare esattamente il container Simple Notes con `docker ps`, leggere l'inventario con `DB_CONTAINER=... EXPECTED_POSTGRES_DB=simplenotes bash infra/t4-inspect-db.sh`. Un server ancora V8 non abilita il client completo. **Soltanto dopo** un eventuale upgrade Coolify autorizzato e protetto usare `DB_CONTAINER=... T4_BEARER_TOKEN=<JWT_TEMPORANEO_NELL_ENV> bash infra/release-readiness.sh`: richiede Flyway V10, `FAILED_MIGRATIONS=0`, colonne V7–V10, health UP e capability JSON autenticata complete. Il token non va mai copiato in chat o messo nella cronologia. Il comando è read-only e non effettua backup/restore/deploy. [Procedura](RELEASE-V10-READINESS.md).

## 03/11/2026 — V10 realmente verificata; test manuali posticipati

Sulla VPS l'utente ha eseguito `t4-inspect-db.sh` in lettura: PostgreSQL 17, Flyway **V10**, tutte le colonne previste, `FAILED_MIGRATIONS=0`. Il client Windows ha riportato API compatibile secondo diagnostica integrata, account coerente, Google connesso, pending=0, ultima sync 02:24:58; **non** rappresenta il gate API strict che richiede JWT né Android E2E. I 3 task nella tabella server contro 0 task visualizzati Windows richiedono eventuale audit futuro: i conteggi non sono equivalenti a perdita di dati. Su richiesta dell'utente, rimandare E2E manuale, non eseguire reset/uninstall/redeploy solo per questo. [Registro](DEVICE-ACCEPTANCE-DEFERRED.md).

P2.4A: esportazione CSV locale per attività, note, liste; collaudo native save/share rinviato allo stesso batch, test automatici obbligatori. [Specifica](P2-CSV-EXPORT.md).

