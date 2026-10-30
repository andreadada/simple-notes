# Release storica P1.2 + P1.3 — Simple Notes 0.7.0+9

> **Stato operativo 30/10/2026:** P2.1 import/export JSON portabile integrata su `main` ([PR #20](https://github.com/andreadada/simple-notes/pull/20), Flutter `0.24.0+26`, CI Flutter/Markdown verde: 152 test e build Windows/Android). Collaudi fisici e rilascio cumulativo non attestati. Backend repo Flyway V10, ultima VPS verificata V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Archivio](P2-PORTABLE-ARCHIVE.md).

<!-- CURRENT-STATUS-REF -->
> **Snapshot storico 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. Le sezioni originali sottostanti restano storiche; vedere lo stato canonico. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).


**Data:** 25 ottobre 2026 · **Codice integrato su `main`**. PR #1 (P1.2) e PR #2 (P1.3) merged. **NON attestare come distribuito:** Coolify, Flyway V8 reale, app Windows/Android reali e prova E2E restano da verificare. Il lavoro GitHub è terminato; il deploy Coolify richiede accesso all'installazione del proprietario.

## Cosa contiene

- Time blocking indipendente dalla scadenza: intervallo UTC start/end (massimo 24h), fuso IANA, editor Forui, un blocco per task.
- Drag e resize di 15 minuti, trasferimento fra giorni e timeline giorno/settimana con supporto DST e sovrapposizioni.
- Backend Spring Boot capability `timeBlockSchema:1` e `noteRestoreSchema:1`, gestione dei client precedenti senza cancellare silenziosamente i blocchi.
- Flyway V8 **additiva**: 3 colonne nullable e vincolo sull'intervallo in `task`. Drift V6 additiva. Nessuna cancellazione di task, note, utenti, account o volumi.
- Widget/unit tests e build Windows/Android su GitHub Actions. CI pre-merge P1.2 e P1.3 verdi; controllare anche la CI dell'ultimo commit in `main`.

## Procedura di rollout (ordine obbligatorio)

### 1. Identificazione e controllo PRIMA dell'aggiornamento

Sul VPS:

```bash
cd ~/simple-notes
git pull --ff-only origin main
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
# Sostituire ID con il container DB verificato Simple Notes Postgres 17.
DB_CONTAINER='<ID_POSTGRES_SIMPLE_NOTES>' EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-inspect-db.sh
```

Prima del deploy è normale avere `FLYWAY_LATEST=7` e `BLOCK_COLUMNS=0`; quando V8 è già attiva si devono vedere `FLYWAY_LATEST=8` e `BLOCK_COLUMNS=3`. Rifiuti/colonne parziali significano **STOP**, non rimuovere volumi. Conservare gli attuali secret Coolify e il volume `postgres_data` intatto. Nessun reset dei dati è necessario. È consigliato effettuare backup verificato prima della migrazione V8; gli script `infra/backup-postgres.sh` e `infra/verify-restore.sh` esistono. Il vecchio backup verificato del 24 ottobre era antecedente a questa modifica e non va scambiato per una nuova verifica.

### 2. Coolify (necessario solo se l'auto-deploy non ha già aggiornato)

Aprire il progetto Simple Notes già esistente su Coolify, resource **Docker Compose**, branch `main`, file root `/docker-compose.yml` e versione Git `d9bcd2b` o commit successivo che lo contenga. Fare **Redeploy** della risorsa esistente, senza creare un nuovo database o alterare secret/password. Il volume PostgreSQL va conservato anche se Compose ricrea il container. Non scegliere Delete/Reset/Remove Volumes.

Attendere che l'API risulti healthy e che Flyway segnali la migrazione `V8__task_time_blocks.sql` riuscita. In caso di errore, non aggiornare i client: leggere i log e diagnosticare prima. Il codice non avvia alcuna cancellazione di test. Se Auto Deploy su `main` è attivo, il backend potrebbe essersi già aggiornato: eseguire comunque i controlli del punto 3.

### 3. Verifica API/DB DOPO il deploy

```bash
# Rideterminare l'ID: il deploy può ricreare il container.
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_POSTGRES_SIMPLE_NOTES>' EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-inspect-db.sh
curl --fail --silent --show-error https://api.notes.ddone.it/actuator/health
```

Esiti richiesti: `POSTGRES_MAJOR=17`, `FLYWAY_LATEST=8`, `DUE_COLUMNS=5`, `BLOCK_COLUMNS=3`, `FAILED_MIGRATIONS=0`, HTTP health `{"status":"UP"}`. La capability `timeBlockSchema:1` è **autenticata**; per provarla tramite shell con JWT breve già disponibile, usare `REQUIRE_TIME_BLOCK_SCHEMA=1 API_BASE_URL=https://api.notes.ddone.it T4_BEARER_TOKEN=<JWT_BREVE> bash infra/t4-check-api.sh`, evitando di copiare il token nei log o nella chat. In alternativa verificare nell'app la diagnostica **Compatibile (scadenze 1 + blocchi 1)** dopo login.

### 4. Windows e Android (SOLO dopo i controlli backend)

Sul PC:

```powershell
cd E:\dev\simple-notes
git pull --ff-only origin main
.\tools\t4-build-devices.ps1 -Target both
```

Richiede `.t4-device-build.json` locale già esistente con gli OAuth Client ID pubblici (non segreti). Lo script **compila soltanto**, senza installare, fare reset o perdere database. I nomi file includono ancora la sigla storica `t4.2`, ma il contenuto dipende dal commit HEAD e deve mostrare Flutter `0.7.0+9`. Il file `build/t4-device-acceptance/MANIFEST.txt` contiene HEAD/SHA256.

Per Windows, chiudere prima l'app, estrarre `build/t4-device-acceptance/simple-notes-t4.2-windows.zip` in una cartella nuova e avviare `simple_notes.exe` da lì (non solo l'eseguibile senza DLL). Per Android con il debug USB già configurato, mantenere la stessa firma debug e usare `adb install -r` sulla APK costruita. **Non eseguire adb uninstall, pm clear, reset SQLite, né cambiare account Google**; in caso di errore di firma o aggiornamento, indagare invece di cancellare dati.

### 5. Smoke test reale su stesso account Google

- [ ] Diagnostica Windows e Android: backend compatibile, stesso account, pending 0 dopo sync.
- [ ] Task con data-only non spostato alla mezzanotte; aggiungere blocco 09:00–10:00 senza modificare scadenza.
- [ ] Sincronizzare Windows → Android → Windows, verificando blocco/ora/durata.
- [ ] Drag +15 minuti e resize +15 minuti: una operazione per gesto e propagazione su altro dispositivo.
- [ ] Trascinare un blocco su altro giorno; verificare scadenza immutata e corretta gestione DST.
- [ ] Nota: creazione → Cestino → ripristino su secondo dispositivo senza perdite.
- [ ] Ripetere una modifica offline e riprendere sync; controllare pending/conflitti senza azzerare dati.

**Gate di chiusura:** soltanto con controlli dal server e prova su dispositivi si può segnare la release come **distribuita e collaudata**. Non inferirlo dai job GitHub.

## Stato di codice e rollback

- `main` è il ramo da costruire su entrambi i dispositivi.
- Flyway V8 è applicata automaticamente all'avvio della nuova API; una migrazione DB **non si annulla** tornando semplicemente a un'immagine precedente. Non eseguire downgrade manuali senza piano/backup.
- In caso di errore client, conservare SQLite e outbox; non ripristinare utenti/DB alla cieca. In caso di errore API, prima diagnosticare con log Health/Flyway e tenere i client precedenti fermi.
- Non installare client `0.7.0+9` con backend precedente senza accettare che le mutazioni task restino in coda finché non è aggiornato.

## Stato registrato dall'assistente

**GitHub: integrato. Coolify: non attestato. Flyway V8 su VPS: non attestata. Client Windows/Android: non installati da questa chat.** La convalida finale richiede osservazioni reali e non può essere sostituita da GitHub Actions.
