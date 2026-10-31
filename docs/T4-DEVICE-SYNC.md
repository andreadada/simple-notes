## Cronologia — rilascio 0.7.0+9 (superato da P1.6)

> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI Flutter/Markdown verde: 162 test, Windows EXE/MSIX, Android JDK17/21). Test fisici e deploy cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [ICS](P2-ICS.md).

<!-- CURRENT-STATUS-REF -->
> **Snapshot storico 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. Le sezioni originali sottostanti restano storiche; vedere lo stato canonico. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).


**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.

> **Cronologia 25/10/2026 — stato dopo reset (non versione attuale):** l'utente ha confermato **tutti i conteggi server a 0** e l'eliminazione dati locali Windows/Android. Gli eventi 25–34 e l'analisi delle note più sotto sono **precedenti al reset**. La revisione Flutter corrente nel repository è `0.5.0+7` (nuovo calendario P1.1), ma il collaudo su dispositivi delle nuove build e del Cestino resta **aperto**. Non resettare di nuovo per completare T4.2. [Procedura storica del reset](RESET-TEST-DATA.md).

> **Aggiornamento 24/10/2026 — test reali:** Windows e Android avevano API `taskDueSchema:1`, cursor entrambi 34 e pending 0, ma 0 note visibili dopo due cancellazioni arrivate al backend fra gli eventi 33 e 34. Audit read-only PostgreSQL ha mostrato **5 note soft-deleted** e i payload storici ancora presenti. L'utente conferma che sono tutti dati di test e sceglie un reset volontario dell'intero workspace di test, non il recupero. Procedura e garanzie: [RESET-TEST-DATA.md](RESET-TEST-DATA.md). Nuova app `0.4.2+6` include Cestino note, ripristino versionato e protezione stale-sync; funzionalità e reset **non ancora verificati sui device aggiornati**. Backend `noteRestoreSchema:1` richiede deploy dell'API, non una migrazione DB.

# T4.2 — Verifica reale della sincronizzazione Windows ↔ Android

**Stato:** strumenti diagnostici e build locali riproducibili implementati nel client Flutter. Prova fisica **non ancora eseguita** da questa chat.

## Evidenze già raccolte dall'utente (24 ottobre 2026)

- Container PostgreSQL di Simple Notes identificato come `db-gs0yzfz42hpriybaxcfbtjnk-20261024T114255` (ID temporaneo `9e408105e59e`; può cambiare nei deploy successivi).
- **PostgreSQL 17.11**, database `simplenotes`, Flyway **V1–V7** con `success=true` e **5 colonne V7**.
- Inventario reale: 1 utente, 5 attività, 4 note, 25 cambiamenti e 25 operazioni di sync, nessuna migrazione fallita.
- Backup reale: `simple-notes-20261024T132857Z-271921.dump`; manifest SHA256 valido e **restore isolato realmente riuscito** nel container temporaneo (`.restore-ok`).
- Copia cifrata offsite **non effettuata**; l'utente ha chiesto di fermare ulteriori attività di backup. Questo non viene considerato un gate completato.
- La presenza della V7 in PostgreSQL **non dimostra da sola** che l'API in esecuzione esponga il nuovo contratto: la diagnostica T4.2 verifica la capability autenticata.

## Funzione integrata — Diagnostica sincronizzazione

Dopo aver installato su entrambi i dispositivi una build Flutter aggiornata:

1. Accedere con **lo stesso account Google** su PC e telefono.
2. Aprire l'avatar → **Verifica sincronizzazione** (menu Forui disponibile su Windows e Android).
3. L'app esegue **solo** una GET autenticata di `/api/v1/capabilities` e letture del proprio database SQLite. **Non crea, invia, modifica o elimina task e note.**
4. Verificare `Backend scadenze: Compatibile (taskDueSchema 1)`, `Archivio/account: Coerente`, `Modifiche in attesa: 0` e `Ultima sincronizzazione` non vuota **dopo** una sincronizzazione riuscita.
5. Premere **Copia report** per condividere solo stato backend, conteggi, cursor e ultimo sync. **Non** contiene token, ID account, titoli, corpi delle note o URL segreti.

Se appare **Versione backend incompatibile** o il client riceve HTTP **426**, **non cancellare dati e non reinstallare l'app**: la coda locale rimane salvata; controllare che il backend API sia aggiornato. Se appare **API non raggiungibile**, verificare rete e login. Se appare **Archivio locale associato a un altro account**, non forzare la sincronizzazione.

La data di ultima sincronizzazione viene registrata **solo dopo upload e pull entrambi riusciti**. Una GET diagnostica non aggiorna mai quel valore. In caso di 426 la UI segnala l'upgrade e sospende il retry automatico fino a un comando manuale o a una nuova sessione; le modifiche non vengono scartate.


**Build precedente T4.2:** `0.4.0+4`; **nuova build di collaudo:** `0.4.1+5` (versione Flutter in `pubspec.yaml`); installare sul PC e su Android una build ottenuta dallo stesso commit. L'APK CI è di test e non incorpora automaticamente i parametri OAuth; non disinstallare la vecchia applicazione per aggiornare.

## Build T4.2 in un comando (Windows, senza reinstallazione)

È disponibile `tools/t4-build-devices.ps1`. Il comando genera **APK debug Android e ZIP Windows dallo stesso checkout locale** con i client ID Google già in uso, annota SHA256 e commit e **non installa né cancella nulla**. La configurazione locale è esclusa da Git. Se sono presenti modifiche tracciate non ancora committate, la build prosegue con un avviso e viene etichettata come **non riproducibile dal solo commit**; nessun `stash`, `reset` o ripristino automatico.

Dal terminale PowerShell nella radice del progetto:

```powershell
Copy-Item tools/t4-device-build.example.json .t4-device-build.json
# Compilare i due ID Google OAuth pubblici nel JSON locale, senza Client Secret.
./tools/t4-build-devices.ps1 -ValidateOnly
./tools/t4-build-devices.ps1 -CheckOnly
./tools/t4-build-devices.ps1 -Target both
```

I risultati sono in `build/t4-device-acceptance/` (APK, ZIP Windows e `MANIFEST.txt`). Si può usare `-Target android` o `-Target windows`. **Non è un installer**: non esegue `adb install`, `flutter run`, `pg_restore` o redeploy. La build Android debug usa la **keystore locale**; se la firma dell'app già installata è diversa, un normale aggiornamento sarà rifiutato. In quel caso **non disinstallare l'app**: conservare SQLite/outbox e usare una build con la firma corretta. Una build CI generica può avere una firma diversa da quella locale.

Se sul PC sono presenti file modificati, **non eseguire `git reset --hard`, `git clean`, `stash` o reinstallazioni** per sbloccare lo script. `-CheckOnly` verifica ora il checkout senza modificare file; `-RequireClean` resta disponibile per un controllo rigoroso facoltativo. La build salta `flutter create` quando lo scaffold richiesto esiste già e non usa `--delete-conflicting-outputs` di build_runner. Se uno scaffold manca, Flutter può generare i file mancanti: controllare con `git status --short` dopo l'esecuzione.

La versione di collaudo dopo l'hardening è **Flutter `0.4.1+5`**. Annotare lo SHA contenuto nel manifest e verificare sul secondo dispositivo lo stesso commit. La CI automatica controlla anche la struttura del comando senza usare credenziali reali. I test reali T4.2 restano indispensabili.

## Compilare i client con la vera configurazione cloud (alternativa manuale)

Nella PowerShell del PC, in `apps/flutter` della repository aggiornata:

```powershell
git pull origin main
cd apps/flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_DESKTOP_CLIENT_ID=TUO_CLIENT_ID_DESKTOP
```

Per Android, con `flutter devices` ricavare l'ID corretto e scegliere il **client ID Web** (non Android e non un secret):

```powershell
flutter devices
flutter run -d ID_DEL_TUO_ANDROID --dart-define=API_BASE_URL=https://api.notes.ddone.it --dart-define=GOOGLE_WEB_CLIENT_ID=TUO_CLIENT_ID_WEB
```

Sostituire i segnaposto con gli identificativi OAuth già configurati localmente; non condividerli in chat se includono segreti. Non inserire mai **Client Secret**, refresh token o password nelle opzioni Flutter, nei commit o nei report. La build generica di GitHub Actions **non contiene le opzioni OAuth reali**; il successo CI non basta per il test di accesso.

**Importante:** non disinstallare/azzerare i dati delle vecchie app: operazioni offline potrebbero essere ancora nella SQLite locale. Usare il medesimo package Android `it.andreadada.simplenotes` e la chiave debug Google OAuth compatibile con l'APK locale. L'app Flutter Web non è attualmente operativa.

## Indagine T4.2 — Nota scomparsa dopo cursor 25 → 34 (24/10/2026)

**Osservato sui dispositivi:** Android inizialmente 1 nota al cursor 25; dopo la sync Android e Windows mostravano 0 note al cursor 34, pending 0 e stesso account. Questo prova l'allineamento del *conteggio visibile*, non prova l'assenza fisica dei dati. Nel client `snapshot()` nasconde le note con `deletedAt != null`; `applyRemote(deleted: true)` imposta quel flag senza cancellare titolo e corpo dalla SQLite. Il backend usa `note.deleted_at` e lo storico `sync_change` mantiene le operazioni. Una tombstone server nell'intervallo 26–34 è un'ipotesi da verificare, non un fatto già accertato.

**Prima di qualsiasi recupero, eseguire solo la lettura metadata sul VPS.** Identificare il container attuale: l'ID precedente può essere cambiato. Nessuna operazione su dispositivi o PostgreSQL:

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_O_NOME_POSTGRES_SIMPLE_NOTES>' EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-audit-note-loss.sh
```

Lo script verifica esplicitamente PostgreSQL 17, il DB e le tabelle; attiva il parametro PostgreSQL `default_transaction_read_only=on` su **ogni** connessione. Esegue solo `SELECT`/`SHOW`, restituisce conteggi `visible/soft_deleted`, riferimenti anonimi delle note (hash UUID), `version`, tempi UTC, cambiamenti per le note e gli eventi 26–34. **Non legge o stampa testi, titoli, e-mail, ID grezzi o payload** e non genera nuovi dump. L'output si può condividere per l'analisi. Se un account possiede più di 100 note/eventi, le tabelle di dettaglio mostrano solo le 100 più recenti.

Interpretazione:
- evento `entity_type=note`, `operation=DELETE` tra 26 e 34 e stato `soft_deleted` per la stessa `note_ref`: supporta l'ipotesi di tombstone remota recepita da Android; non identifica chi l'abbia inviata (il log non registra il dispositivo);
- nota `soft_deleted`: la riga e il contenuto **possono essere ancora presenti** su PostgreSQL e SQLite, da verificare separatamente senza ripristino in produzione;
- nessuna tombstone per la nota: non attribuire la scomparsa automaticamente al backend. Controllare la cronologia completa, eventuali dati locali e l'interfaccia;
- nessuna riga nella tabella `note`: lo storico `sync_change` può ancora conservare un payload precedente. Non dedurre recuperabilità certa dai soli conteggi.

**Non** eseguire `UPDATE note`, `DELETE`, `pg_restore`, reset SQLite, logout con cancellazione dati, `adb uninstall` o un import automatico. Un eventuale ripristino della nota deve essere progettato solo dopo aver identificato la causa, salvaguardando gli altri dati e i cursori.

## Sequenza di collaudo non distruttiva

Usare **una sola attività nuova di prova**, per evitare di toccare i dati personali precedenti.

| # | Dispositivo | Azione | Risultato atteso |
|---|---|---|---|
| 1 | Windows | Aprire diagnostica, poi **Sincronizza ora**, riaprire diagnostica | Backend compatibile, ultimo successo visibile, pending 0 |
| 2 | Android | Ripetere diagnostica e **Sincronizza ora** | Stesso stato compatibile e pending 0 |
| 3 | Windows | Creare attività `T4-verifica-PC` con **Solo giorno, 27/10/2026** | Nella diagnostica pending scende a 0 dopo sync |
| 4 | Android | **Sincronizza ora**, aprire `T4-verifica-PC` | Stessa attività e data **27/10**, senza ora |
| 5 | Android | Sul task di prova selezionare **Data e ora**, `27/10/2026 · 00:00 · Europe/Rome` | Modalità `datetime`, mezzanotte esplicita |
| 6 | Windows | **Sincronizza ora**, aprire task | Data+ora e fuso corretti, non convertiti in `legacy` |
| 7 | Windows | Modificare **solo il titolo** del task di prova | Alla sync Android conserva stesso tipo/ora/fuso |
| 8 | Android | Mettere il dispositivo offline e creare nota `T4-prova-offline`; riavviare app | Nota presente localmente, pending positivo, nessuna perdita |
| 9 | Android → Windows | Riattivare rete, sincronizzare Android e poi Windows | Nota ricevuta dal PC e pending 0 su entrambi |

La verifica di **ora ripetuta** è aggiuntiva: sullo stesso task di prova selezionare `25/10/2026 02:30 Europe/Rome`, scegliere la prima (+02:00) o la seconda (+01:00) occorrenza, sincronizzare e verificare la stessa scelta sull'altro dispositivo. L'orario inesistente `29/03/2026 02:30 Europe/Rome` deve essere rifiutato. Eseguire entrambe solo se si vuole completare l'intera matrice DST; nessun test di questo tipo deve alterare gli altri task.

**Non cancellare la nota o il task di prova prima di aver verificato il risultato su entrambi i dispositivi.** Non eseguire test di conflitto 409 su note importanti; utilizzare dati di prova e seguire la checklist completa solo in modo intenzionale.

## Scheda rapida del risultato

```text
Data test: ____________
Flutter commit Windows/Android: ____________
API/backend: taskDueSchema 1 verificato?  SI / NO
PC: pending ____ | ultimo sync ____ | backend ____________
Android: pending ____ | ultimo sync ____ | backend ____________
Solo giorno PC → Android: PASS / FAIL / NON TESTATO
Data+ora Android → PC: PASS / FAIL / NON TESTATO
Rinomina senza modifica della scadenza: PASS / FAIL / NON TESTATO
Offline → online: PASS / FAIL / NON TESTATO
DST gap/fold: PASS / FAIL / NON TESTATO
Note (senza credenziali o dati privati): __________________
```

**Criterio di completamento T4.2:** screenshot o diagnostiche copiate dai **due dispositivi aggiornati**, insieme al risultato della sequenza; passaggio test offline e riconciliazione cloud. La CI simulata è distinta dalla prova reale e non basta da sola.

Non occorre alcun nuovo deploy PostgreSQL: **Flyway V7 è stata verificata sul database reale**. Il contratto API va comunque controllato con il nuovo comando diagnostico autenticato.
