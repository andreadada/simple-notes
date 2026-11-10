# Guida operativa — Simple Notes

> **Stato verificato 10/11/2026:** [PR #61](https://github.com/andreadada/simple-notes/pull/61) integrata `bf16cba`: definizioni regole task cloud con JWT, CAS e Flyway V13 nel repository (VPS attestata V10). [Flutter CI #42821851199](https://github.com/andreadada/simple-notes/actions/runs/42821851199) **success** (399 test, Windows EXE/MSIX/recovery e Android JDK17/21); [Backend CI #42821851073](https://github.com/andreadada/simple-notes/actions/runs/42821851073) **success** (Spring/PostgreSQL 17), [Markdown #42821851207](https://github.com/andreadada/simple-notes/actions/runs/42821851207) **success**. Flutter `0.31.0+33`; V13 nel repo, VPS V10 attestata al 03/11. Nessun deploy, migrazione su dati reali, restore live o collaudo hardware. Scheduler server, notifiche multi-device e resto P2 ancora aperti. [Stato canonico](CURRENT-STATUS.md).

**Fonte operativa** per checkout Windows, CI, Coolify, Android e Windows ZIP/MSIX. Lo stato canonico aggiornato è in [CURRENT-STATUS.md](CURRENT-STATUS.md); le versioni precedenti qui riportate costituiscono cronologia, non conferme di deploy.

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

Lo schema VPS **confermato dal proprietario il 03/11/2026** è Flyway V10. Non è necessario ripetere una migrazione o un deploy solo per adeguare un riferimento storico del runbook. Prima dell'aggiornamento conservare backup e piano di ripristino appropriati; l'ultimo restore isolato attestato è storico e non protegge automaticamente nuovi dati. Solo il proprietario esegue **Redeploy** sulla stessa risorsa esistente. In caso di errore della migration, STOP senza `flyway repair` o cancellazione volumi.

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

## P2.4B1 — Backup locale cifrato, nessun ripristino live

Nel menu account si può creare il .snb con password Forui e verificarlo nello stesso account senza modificare i dati. Questa preview autentica il file ma **non è un restore**. Non provare sostituzioni del file SQLite, import di pending outbox, reset di secure storage o reinstallazione: la fase P2.4B2 richiede checkpoint verificato, cold-start, sync sospesa e rollback. PostgreSQL VPS Flyway V10 è già stato attestato; nessun deploy server è necessario per P2.4B1. Prove save/share su dispositivi reali restano rinviate. [Runbook](P2-FULL-BACKUP.md).

**Stato codice P2.4B1:** PR #28 merged su `main`, Flutter `0.31.0+33`, CI 204 test e build Windows/Android verdi. Nessun backup/restore sui dati reali eseguito in questo incremento; **funzione di restore ancora assente** (P2.4B2). [Specifica](P2-FULL-BACKUP.md).


## P2.4B2A — Rehearsal senza impatto operativo

FullBackupRestoreRehearsal ricostruisce SQLite V8 in un database temporaneo in memoria, dopo la verifica .snb. Non apre il SQLite installato, non modifica preferenze, non contatta Coolify o AutoSync e non espone un pulsante di restore. I test automatici coprono rollback e retry dopo fault. Questo risultato **non** autorizza il replay delle operazioni pendenti: il gate cold-start, checkpoint e anti-replay resta aperto. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2B1 — Checkpoint su directory esplicita, senza restore operativo

Il nuovo FullBackupCheckpointPreflight cifra e verifica uno snapshot locale e prova a ricostruirlo in SQLite temporaneo. La prova di scrittura usa esclusivamente una directory specificata dal chiamante (test: directory temporanea), file .snb nuovo e read-back. Nessun comando Coolify, nessuna azione per l'utente finale e nessuna scrittura dell'archivio installato. Un receipt valido **non consente** ancora restore o replay outbox; fsync directory, compensazione preferenze, rollback reale e controllo versioni cloud sono obbligatori prima dell'attivazione. [Contratto](P2-FULL-BACKUP.md).


## P2.4B2B2 — Compensazione isolata

La prova cross-store di P2.4B2B2 è una funzione interna che decifra checkpoint e backup target .snb, simula SQL e preferenze in memoria, inietta errori e **ripristina in sandbox** lo snapshot originario. Non usare dati reali né rimuovere file del client per provarla; il profilo Windows/Android, la VPS e la sync restano immutati. Non equivale a recovery su disco né abilita il restore nell'interfaccia. I test fisici sono differiti. [Contratto](P2-FULL-BACKUP.md).


## P2.4B2C1 — Prova cold-start, nessun comando operativo

Il guard crea e rilegge marcatori di fase in una directory temporanea esplicitamente passata dai test. La sola funzione di recovery richiama una simulazione su database SQLite **in memoria**; non tocca il file `simple_notes.sqlite` installato, preferenze dell'utente, credenziali, Coolify o cloud. L'outbox di un backup importato resta sempre in quarantena, inclusi i casi senza modifiche in coda. **Non utilizzare** il prototipo di journal per ripristinare un profilo reale: assenti lock multiprocesso, fsync directory e recovery cross-store persistente. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2C2 — Protezione runtime e controlli cloud di sola lettura

Su Windows/Android, il controllo `ApplicationSupport/simple-notes-recovery-v1` viene effettuato all'avvio **prima del DB**. Se il percorso esiste o non è verificabile, l'app non apre il profilo e mostra la schermata di recupero sospeso. Non eliminare manualmente marker o directory sospette e non usare gli script di reset: è prevista una recovery controllata successiva. La semplice assenza della directory preserva il normale comportamento in installazioni precedenti. Il cloud preflight è esclusivamente GET e richiede un client esplicito, ma non è collegato alla UI o ad alcuna procedura automatica. Non modifica VPS/Coolify né dati reali. Test manuali su profili fisici ancora da pianificare dopo il completamento delle gate.

Il reader client `RestoreServerInventoryReader` è intenzionalmente opt-in e in sviluppo: finché la PR backend #34 non è rilasciata, un 404 viene trattato come **blocco** (mai come permesso di usare il vecchio cursor). Nessun endpoint nuovo è stato distribuito su Coolify.


## P2.4B2C3 — API inventory non ancora su VPS

La PR introduce `GET /api/v1/sync/inventory` senza modifiche DB, dati o nuove migrazioni. Nessun comando shell o deploy Coolify richiesto in questa fase; il backend in esecuzione sulla VPS potrebbe restituire 404 finché la release non è stata eseguita. NON usare l'endpoint in un restore reale fino a verifica contratto, autorizzazione deploy e riconciliazione esplicita. [Documentazione](api.md).


## P2.4B2D — Recovery su file di test, non procedura utente

La prova persistente crea una directory nuova sotto `Directory.systemTemp`. Le credenziali .snb, le preferenze simulate e SQLite risiedono solo lì; i test eliminano la propria cartella quando terminano. Nessun comando operativo, reset, invocazione Coolify o modifica dati sul PC/dispositivo è richiesto. Non reindirizzare il sandbox al percorso SQLite reale e non usare i suoi metodi per correggere un'installazione in errore; mancano fsync multipiattaforma, backup in caso di crash fisico, rollback SharedPreferences reali e compatibilità installazione. [Contratto](P2-FULL-BACKUP.md).


## P2.4B2E — Confronto non distruttivo

Su app autenticata, la nuova opzione **«Confronta backup con questo dispositivo»** legge il .snb selezionato e lo confronta con lo stato del profilo corrente. La password non viene persistita; se la verifica fallisce o l'account differisce, non si applica alcuna modifica. Il riepilogo non comprende testo delle note o dati sensibili. Non utilizzare il report come autorizzazione di ripristino: il cloud non è interrogato e la sincronizzazione importata rimane vietata. Nessun intervento su VPS o Coolify. [Specifica](P2-FULL-BACKUP.md).

## Esecuzioni CI senza duplicati
Le build automatiche sui branch feature sono lanciate tramite `pull_request`; `push` continua a scattare su `main`. Un commit successivo sulla stessa PR interrompe solo la pipeline precedente e avvia quella per il nuovo HEAD. Quando si valuta un merge, controllare lo SHA **corrente** della PR e tutti i job: un vecchio verde non basta. I test non sono stati disabilitati o ridotti. Nessun effetto su Coolify/VPS.


## P2.4B2F — Confronto remoto non distruttivo

La voce «Confronta backup con questo dispositivo» continua a funzionare senza rete. Se l'utente preme «Consulta inventario cloud», Simple Notes legge **solo** `GET /api/v1/sync/inventory`; non usa operazioni di sync e non salva la risposta. Un 404 è normale quando il backend non è stato ancora distribuito dopo il merge della PR #34 e lascia il restore disabilitato. L'access token non viene registrato in log o memorizzato nel report. Il confronto non è una prova transazionale del cloud e non consente ripristino di dati reali. Nessun deploy Coolify, migration o reset DB compiuto.


## P2.4B2G — Pianificazione dei conflitti (visualizzazione)

Dal confronto `.snb`, la consultazione cloud è esplicita e GET-only. Una volta caricati metadati remoti, il report mostra una matrice aggregata e il pulsante «Simula altra strategia». Le preferenze sono **unicamente scenari esplicativi**; nessuna selezione viene persistita e nessuna richiesta cloud successiva viene inviata dalla simulazione. Un report senza rischi non garantisce correttezza di un restore: server e dispositivo possono cambiare. Non usare fingerprint della bozza o preferenza ipotetica per sbloccare il profilo, rimuovere marker, importare file o riattivare AutoSync. Nessuna modifica reale a VPS/Coolify/DB.


## P2.4B2H — Scelte per conflitto solo temporanee

Da «Confronta backup» → «Consulta inventario cloud» → «Esamina conflitti», l'utente vede gli elementi e può alternare una scelta *ipotetica* per ciascuno. La revisione richiede la stessa sessione proprietaria e non effettua altre richieste HTTP, né scrive su SQLite/SharedPreferences. L'opzione cloud non corrisponde a un download o all'autorizzazione di replay. Chiudendo il dialog nessuna scelta resta memorizzata; una nuova versione dell'inventario invalida la vecchia scheda. Oltre 500 entità la scheda dettagliata rifiuta di mostrarsi invece di simulare una revisione incompleta. Non usarla come procedura per sbloccare un restore reale.

## P2.4B2I — Contratto backend non ancora deployato

Il nuovo preflight usa POST ma è **sola lettura** e JWT-scoped. Non include contenuti delle note, non muta `sync_change` o `sync_operation` e rifiuta più di 100 revisioni o ID ripetuti. Il `expectedAccountCursor` facoltativo evita overwrite con cursore stale quando il chiamante lo fornisce; 409 richiede nuovo confronto, non replay automatico. Non attivare restore o invio di outbox importate, non eseguire deploy o migrazioni in questa fase.

## P2.4B2J — Pulsante ricontrolla revisioni

«Confronta backup» → «Consulta inventario cloud» → «Ricontrolla revisioni» richiede una singola POST **senza effetti** all'endpoint backend. Non utilizzare questo percorso per importare dati o forzare una sincronizzazione. Se il server non è stato deployato e risponde 404, la vecchia bozza deve essere rifiutata, non considerata coerente. Un esito positivo non è una autorizzazione di restore. Nessun comando deploy VPS/Coolify o modifica database svolti in questo milestone.


## P2.4B2K — Protezione preflight e 409

Se `/sync/reconciliation/check` restituisce 409 anche con revisioni apparentemente corrette, un possibile motivo sono modifiche effettuate dalle API legacy senza eventi `sync_change`. Non ripetere automaticamente importazioni, non abbassare il cursore e non azzerare dati. Il controllo non scrive nulla: l'interfaccia segnala che l'inventario non è verificabile e richiede un nuovo confronto. Nessuna migrazione, operazione manuale DB o deploy eseguiti.


## P2.4B2L — Errore 409 nel preflight completo

Il check owner-wide può segnalare 409 anche se tutti gli elementi elencati nell'inventario sembrano allineati, perché una nota o attività legacy **fuori inventario** può essere discordante. È intenzionale: non azzerare dati, non forzare replay/cursore e non interpretare il risultato come perdita dati. Recuperare un nuovo inventario e valutare la riconciliazione solo quando esistono garanzie più forti; il restore reale resta disabilitato. Nessuna procedura manuale DB o aggiornamento Coolify eseguito.


## P2.4B2M — Mutazioni legacy ora visibili nella sync

Le chiamate ai vecchi endpoint note/task generano eventi `sync_change` nell'account senza richiedere interventi DB. Un client con cursore vecchio vede correttamente 409 quando usa `expectedAccountCursor`. In caso di HTTP 409/426, non forzare replay di backup: aggiornare l'app o effettuare nuova consultazione. I record storicamente non tracciati devono essere valutati separatamente e restano bloccati dal preflight owner-wide. Nessuna migrazione, backfill automatico, cleanup, deploy o operazione distruttiva.


## P2.4B2N — Inventory 409 non implica reset

Un errore 409 da `GET /sync/inventory` può segnalare incoerenze fra righe reali e cronologia sync anche quando nessun elemento atteso appare errato. Il client deve considerare l'inventario **non verificabile**, senza memorizzare un esito `complete=true`, ricalcolare cursor o rigiocare mutazioni importate. La diagnosi SQL o il recupero di dati storici richiedono un processo separato, con backup verificato e autorizzazione esplicita: non farlo automaticamente durante deploy. Nessun aggiornamento Coolify eseguito.


## P2.4B2O — Migrazione additiva V11, non applicata

Al prossimo rilascio backend, Flyway potrebbe applicare `V11__sync_operation_intent_fingerprint.sql` per aggiungere `request_fingerprint VARCHAR(64) NULL` su `sync_operation`. Lo schema attuale della produzione non va modificato anticipatamente: **nessun comando DB, rollback, reset o deploy eseguito in questa sessione**. Nessuna riga storica è alterata. Le operazioni nuove salvano una impronta e rifiutano riuso con intento diverso tramite 409; verificare staging con backup ripristinato, Flyway success/failed_migrations=0 e assenza di regressioni sync prima di qualsiasi rollout. Non usare il fingerprint come prova di recupero dei vecchi operation ID o sblocco della sincronizzazione importata.

## P2.4B2P — Gate di verifica V11, senza deploy

Il runbook [RELEASE-V11-READINESS.md](RELEASE-V11-READINESS.md) separa il vecchio gate V10 dal nuovo `bash infra/release-v11-readiness.sh`, che **non migra** il DB e rifiuta V10, V11 incompleta o fingerprint in formato non valido. `DB_CONTAINER` e JWT di prova devono essere definiti solo dall'amministratore dopo una decisione di rilascio; il token non deve essere riportato in chat né salvato. Il PASS V11 non autorizza restore, writer di riconciliazione, installazione dei dispositivi o presume che il backend runtime sia aggiornato. Nessuna azione su Coolify effettuata.


## P2.4B2Q — 409 strutturato non risolvibile col normale rebase

Se il client segnala che l'operation ID è già stato registrato con contenuto differente, fermare la risoluzione ordinaria del conflitto. **Non azzerare SQLite, outbox o account**, non cambiare arbitrariamente l'operation ID e non forzare il replay. Lo stato e tutte le modifiche locali vengono preservati; il problema richiede una diagnosi del retry e delle versioni, eventualmente un recupero guidato con backup verificato. `SYNC_OPERATION_ID_REUSE` viene emesso solo dal backend aggiornato; le versioni vecchie possono non distinguerlo. [Guida](P2-SYNC-INTENT-CONFLICTS.md).

## P2.4B2R — Doppia evidenza V11 senza modifiche

Per il rilascio V11, il controllo read-only richiede **sia** la colonna Flyway `request_fingerprint VARCHAR(64) NULL` **sia** la capability API autenticata `syncOperationFingerprintSchema:1`. Se una sola manca, il gate si interrompe prima di qualsiasi fase sul client. Non correggere la discrepanza manualmente sul DB: serve una decisione separata di rollout e backup verificato. Le vecchie verifiche V10 restano utilizzabili senza richiedere V11. [Runbook](RELEASE-V11-READINESS.md).

## P2.4B2S — Confronto backup invalidato da modifiche locali

Se durante «Confronta backup con questo dispositivo» cambiano note, task, liste, outbox, cursor, impostazioni locali o account, le revisioni cloud e le scelte visualizzate non possono essere considerate attuali. Il client ricattura il profilo in sola lettura attorno a ciascuna consultazione cloud e prima della revisione manuale; in caso di differenza scarta la bozza e richiede di chiudere e ricominciare. Questo non comporta reset, modifica del backup o replay: la sincronizzazione ordinaria continua secondo le policy esistenti e il restore live resta disabilitato. Non usare un esito positivo per avviare migrazioni/deploy o per considerare atomico il confronto SQLite/SharedPreferences.

## P2.4B2T — Riepilogo di revisione NON eseguibile

Dopo «Consulta inventario cloud», «Ricontrolla revisioni» ed eventuali scelte «Esamina conflitti», il client mostra una ricevuta **informativa**: quante decisioni sono state esaminate e se il controllo remoto è riferito all'inventario corrente. Se il preflight non copre l'intero inventario, le versioni cambiano, manca la sessione o sono rimaste scelte, il riepilogo segnala che la revisione non è completata. Anche quando indica `Revisione informativa completata`, è vietato dedurre che sia autorizzato il restore: nessun pulsante ripristino, nessun resume AutoSync e nessun replay del backup. La ricevuta non viene salvata e non contiene dati dell'utente.

## P2.4B2U — Esecuzione solo nei test sandbox

Non usare `SandboxRestoreOrchestrator` su `ApplicationSupportDirectory`, SQLite installato o preferenze reali: `create()` alloca una directory temporanea del sistema. Il consenso richiede `SIMULA RIPRISTINO` e due acknowledgement, è legato a ciphertext e owner, e viene consumato prima dello staging. Dopo crash simulati, il nuovo processo di prova deve ripristinare il checkpoint leggendo il journal; non eliminare file incomplete per proseguire. Verificare con `flutter test test/full_backup_sandbox_orchestrator_test.dart` e il test precedente `full_backup_disk_recovery_rehearsal_test.dart`; Flutter CI ora esegue entrambi anche su Windows e include una guardia anti-import in `apps/flutter/lib/`. Né questo test né una ricevuta `reviewComplete` autorizzano il deploy o il ripristino live.

## P2.4B2V — Verifica concorrente e journal solo nella sandbox

Per i test sul disco usa `flutter test test/sandbox_restore_file_lease_test.dart test/full_backup_disk_recovery_rehearsal_test.dart test/full_backup_sandbox_orchestrator_test.dart`. Anche la CI Windows esegue questi tre test. Un secondo processo o una seconda invocazione durante il recupero devono essere rifiutati, non aspettare indefinitamente; lock file inatteso, journal symlink, SQLite/preferenze symlink e marcatori incompleti devono bloccare il recovery senza rimuovere il journal. Non cancellare il lock file persistente mentre altre istanze potrebbero usarlo. Il lock è advisory; il journal non ha fsync garantito della directory, quindi **non** usare questi meccanismi su database e preferenze reali, e non attivare sync o replay di operazioni importate.

## P2.4B2W — Test del claim isolate e fsync Linux

Su Linux, `flutter test test/sandbox_restore_file_lease_test.dart test/recovery_directory_barrier_test.dart test/full_backup_disk_recovery_rehearsal_test.dart` prova lock nello stesso processo, in processi distinti e sync della directory padre e journal. Windows CI esegue il fallback (non dichiarare fsync Windows), mentre Android CI compila APK Java 17/21. Il barrier `UnavailableRecoveryDirectoryBarrier` deve rifiutare `append` prima di creare file; una failure di fsync dopo rename deve far fallire l'operazione anche se il marker è visibile. Vedere [P2-RESTORE-DURABILITY.md](P2-RESTORE-DURABILITY.md). Nessuna esecuzione su profili reali o VPS.

## P2 — Test funzionalità locali e scope di release (09/11/2026)

Eseguire flutter analyze e flutter test nell'app; verificare test/task_insights_test.dart, test/task_timeline_board_test.dart, test/task_template_persistence_test.dart, e build Windows/Android CI. I preset devono scrivere una normale mutation nella stessa transazione task; l'analisi task deve restare locale e non includere telemetria. Timeline mostra una scadenza senza ora come milestone, non pianifica una mezzanotte UTC; la UI deve restare read-only per i blocchi esistenti. Le integrazioni server calendar OAuth/S3/ACL e restore live richiedono percorsi separati con permessi, gate di sicurezza e test reali. [Matrice P2](P2-DELIVERY-MATRIX.md).

## P2 — Verifiche ICS/modelli/widget Android (09/11/2026)

Eseguire flutter analyze e flutter test; suite portable_task_calendar_test.dart, user_task_templates_test.dart, user_template_backup_test.dart, android_widget_navigation_test.dart. Android JDK17/21 deve compilare Java AppWidgetProvider, manifest e risorse. In test reale, aggiungere il widget dalla galleria e verificare le tre destinazioni senza bypass del restore startup gate. Un file .ics non è cifrato: condividerlo soltanto per azione esplicita. Verificare un vecchio .snb v1 senza la preferenza templates e un nuovo backup con chiave templates dell'owner giusto. Nessuna operazione reale di restore o deploy. [Contratto](P2-LOCAL-INTEGRATIONS.md).

## P2 azioni task — note operative (PR #60 integrata)

Build verificate in CI: [Flutter #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) (392 test, Android JDK17/21, Windows EXE/MSIX e recovery). Nessuna nuova configurazione backend, Flyway/Drift o permesso OAuth. Le regole sono locali al dispositivo/account e vengono applicate soltanto alla creazione/completamento manuali; trasferirle fra dispositivi mediante sync non è disponibile. Non eseguire un deploy né prove scriventi/restore live in base alla sola CI; il batch fisico rimane differito. [Specifica](P2-TASK-ACTIONS.md).

## P2 — Catalogo cloud automazioni (PR #61 integrata, nessun deploy)

Il nuovo endpoint autenticato /api/v1/automations/task-actions richiede **Flyway V12** dopo V11. **Non usare la sua sola presenza in GitHub come prova che V12 sia stata migrata sulla VPS**: la verifica reale al 03/11/2026 attesta V10. Su un backend ancora senza endpoint il client mostra incompatibilità (404), senza riscrivere dati locali; una scrittura concorrente restituisce 409 CAS. Prima di autorizzare qualunque deploy sono obbligatori i runbook preesistenti di backup verificato, readiness e controllo migrazione, senza restore scrivente live. [Contratto](P2-CLOUD-ACTION-CATALOG.md).

## P2 — Regole task auto-sync foreground (PR #62 integrata)

Inizia soltanto con account autenticato, boundOwnerId locale coerente, restore-sync gate aperto e app in primo piano. Usa il catalogo API V12 già integrato nel repository, ma **non risulta deployata sulla VPS** (V10 attestata il 03/11). Una risposta 404/426 lascia le regole locali intatte; errori di rete, checkpoint malformati o 409 non bloccano la normale sync di note/task/liste. I conflitti di regole si risolvono manualmente con conferma. Nessun processo automatico Android a app chiusa; nessun job server, migrazione aggiuntiva o restore live. [Contratto](P2-AUTO-ACTION-CATALOG.md).

## P2 — Catalogo modelli cloud (PR #63 integrata)

Il client Forui effettua soltanto trasferimenti espliciti Pubblica/Scarica, non sync automatica. Il nuovo endpoint richiede Flyway **V13** sul backend: 404 sulla VPS non aggiornata non deve azzerare i modelli. PUT con revisione `expectedVersion` e 409 per concorrenza; Scarica ricontrolla la revisione dopo il dialog. Non avviare automaticamente Coolify. Il post-deploy, se autorizzato, ha il gate **read-only** `infra/release-v13-readiness.sh` con DB_CONTAINER e JWT effimero in variabili di ambiente, senza stamparlo. [Contratto](P2-CLOUD-TEMPLATES.md).
