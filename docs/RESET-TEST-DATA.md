# Reset coordinato dei soli dati di test — Simple Notes

<!-- CURRENT-STATUS-REF -->
> **Stato codice (25/10/2026):** P1.7 Android integrata su `main` (Flutter `0.11.0+13`, Flyway V10/Drift V8): promemoria nativi inexact e opt-in, CI verde, **senza collaudo reale**. Windows ZIP senza notifiche finché non è pronto MSIX. Ultimo Coolify verificato V8, V9/V10 non attestati. **Fonte unica:** [CURRENT-STATUS.md](CURRENT-STATUS.md). I riferimenti storici più sotto non documentano un deploy attuale.


**ESEGUITO E VERIFICATO DALL'UTENTE il 25 ottobre 2026. Non ripetere questa procedura per continuare lo sviluppo.** È un'operazione distruttiva, autorizzata dall'utente **solo per i dati di test** (24/10/2026). Non riutilizzare questi comandi quando ci saranno dati reali. Il reset comprende task, liste, note visibili ed eliminate, operazioni e storico sync su PostgreSQL e SQLite su entrambi i dispositivi. **Preserva** l'account Google `app_user`, le sessioni backend, lo schema e le migrazioni Flyway e gli altri database della VPS.

## Esito reale comunicato dall'utente (25/10/2026)

- PostgreSQL Simple Notes: anteprima finale **tutti 0** (task, liste, note, sync_change, sync_operation).
- Windows: `WINDOWS_LOCAL_DATA_ERASED` su `simple_notes.sqlite`, senza disinstallazione.
- Android: ADB `pm clear` **rifiutato per mancanza di permesso**; cancellazione dei dati dell'app effettuata manualmente dalle impostazioni, confermata dall'utente.
- Account Google e schema Flyway non eliminati. La revisione client corrente nella repo è `0.5.0+7` con calendario P1.1.
- Questa procedura è conservata **solo come runbook storico**. Nessuna richiesta di nuovo reset, migrazione o backup.

## Sequenza obbligatoria (storica, non rieseguire)

1. **Chiudere Simple Notes su Windows e Android**; lasciare entrambi i dispositivi con l'app chiusa fino al termine dei punti 2–4. Su Android si può anche eseguire `& $adb shell am force-stop it.andreadada.simplenotes` dal PC, dopo avere verificato il telefono. Non avviare versioni vecchie durante il reset.
2. **Solo sulla VPS, repository aggiornata e container PostgreSQL corretto**. Controllare in anteprima:

   ```bash
   cd ~/simple-notes
   git pull --ff-only origin main
   docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
   DB_CONTAINER=9e408105e59e EXPECTED_POSTGRES_DB=simplenotes bash infra/reset-test-workspace.sh --preview
   ```

   Se il container è cambiato, sostituire l'ID con quello che ha nome `db-gs0yzfz42hpriybaxcfbtjnk-...` e immagine PostgreSQL 17, dopo avere verificato di nuovo `docker ps`. Lo script **rifiuta** un DB diverso da `simplenotes`, una major diversa da PostgreSQL 17, uno schema inatteso e più di un account nel database.

3. **Solo dopo anteprima e chiusura app**, eseguire il reset server:

   ```bash
   DB_CONTAINER=9e408105e59e EXPECTED_POSTGRES_DB=simplenotes \
   CLIENTS_CLOSED=YES ERASE_TEST_WORKSPACE=ERASE_SIMPLE_NOTES_TEST_WORKSPACE \
     bash infra/reset-test-workspace.sh --execute
   ```

   Il comando esegue **una singola transazione PostgreSQL** con lock per l'account ed elimina le righe di `sync_operation`, `sync_change`, `note`, `task`, `task_list`. Non cancella `app_user`, `auth_refresh_session`, la cronologia Flyway, i container o i volumi. La sequenza è progettata per un solo account di test. Se un'app rimane attiva o un dispositivo mantiene modifiche offline non cancellate, i vecchi dati potrebbero ricomparire in futuro.
4. **Sul PC Windows, app chiusa**, aggiornare repository. Aprire PowerShell nella radice del progetto e fare anteprima di entrambi i reset locali:

   ```powershell
   git pull --ff-only origin main
   .\tools\t4-reset-local-data.ps1 -Target windows
   .\tools\t4-reset-local-data.ps1 -Target android
   ```

   Se il PC presenta più di un file `simple_notes.sqlite`, lo script si rifiuta di scegliere: passare `-DatabasePath 'PERCORSO_ESATTO\simple_notes.sqlite'` **dopo aver verificato il percorso**. Android deve essere collegato via USB/debug autorizzato. Infine:

   ```powershell
   .\tools\t4-reset-local-data.ps1 -Target windows -Execute -ConfirmText ERASE_SIMPLE_NOTES_TEST_WORKSPACE
   .\tools\t4-reset-local-data.ps1 -Target android -Execute -ConfirmText ERASE_SIMPLE_NOTES_TEST_WORKSPACE
   ```

   Windows elimina **soltanto** `simple_notes.sqlite` e gli eventuali file `-wal`/`-shm`. Android usa `adb shell pm clear it.andreadada.simplenotes`: **mantiene l'APK installato**, ma cancella tutti i dati dell'app Android, compreso il login Google locale. Il file OAuth `.t4-device-build.json` del repository non viene toccato. Eventuali dati legacy esterni alla SQLite non sono inclusi nel reset Windows: se dovessero riapparire, non ricominciare ad aggiungere dati, ma indagare l'import da SharedPreferences.
5. **Solo adesso** riaprire le app aggiornate, accedere con lo stesso account Google e sincronizzare. La diagnostica su entrambi i device deve mostrare **0 task, 0 note, 0 liste, pending 0**, e un cursor nuovo coerente (potrebbe essere `0` o un valore più alto dopo nuove operazioni).

## Miglioramento client: Cestino

La diagnostica segnala separatamente le **note visibili** e le **note nel cestino**, evitando che un semplice valore `Note locali: 0` venga scambiato per cancellazione fisica. Il report non espone titoli o corpi delle note.

Il codice Flutter `0.4.2+6` include sezione **Cestino** per le note con soft-delete, e pulsante **Ripristina**. Il ripristino mantiene l'identità della nota, usa un'azione di sync `restore` con `expectedVersion` e il backend restituisce il contenuto archiviato. Il backend espone `noteRestoreSchema:1` fra le capabilities; client vecchi o API non aggiornate **non** devono ricevere operazioni restore. Le modifiche in coda sono preservate se la capability manca.

**Importante:** questa funzione richiede l'aggiornamento sia del backend Coolify sia dei due client. Non dichiarare che il deploy è stato eseguito solo perché la CI è verde. Prima di usarla con dati reali, verificare nota creata → cestino → altro dispositivo → ripristino → sync, e i casi offline/409. Non è un cestino per i task; quello è un incremento successivo.

## Prossima fase

Dopo il reset di test e un ciclo breve di collaudo CRUD/sync/cestino, aprire **P1 — Calendario giorno/settimana/mese e time blocking**. Non dichiarare T4.2 conclusa senza questo collaudo. Non riavviare una procedura backup offsite: l'utente ha scelto di fermarla.
