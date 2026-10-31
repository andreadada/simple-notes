# Backend — Coolify

<!-- CURRENT-STATUS-REF -->
> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI Flutter/Markdown verde: 162 test, Windows EXE/MSIX, Android JDK17/21). Test fisici e deploy cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](../docs/CURRENT-STATUS.md) · [ICS](../docs/P2-ICS.md).


## Cronologia — rilascio 0.7.0+9 (superato da P1.6)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](../docs/P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](../docs/T4-DEVICE-SYNC.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](../docs/T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T4.1 — Read-only DB inspection e restore recente

L'incremento T4.1 aggiunge `infra/t4-inspect-db.sh`: **sola lettura**, si esegue sul VPS dopo aver identificato esattamente il container PostgreSQL Simple Notes. Rifiuta un DB differente, PostgreSQL diverso dalla major 17, schema inatteso, migrazioni Flyway fallite/versioni sconosciute e uno stato V7 incompatibile con le colonne realmente presenti. Mostra soltanto versione DB, versione Flyway, conteggi di righe per tabella e presenza delle cinque colonne `due_*`, non email o righe di utenti.

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_DEL_POSTGRES_SIMPLE_NOTES>' \
EXPECTED_POSTGRES_DB='simplenotes' \
  bash infra/t4-inspect-db.sh
```

**Stato attuale:** dump SHA256 e restore isolato con `.restore-ok` già riusciti. Offsite non effettuata per scelta; non ripetere automaticamente backup per T4.2. Il gate `t4-preflight.sh` ora richiede una verifica di restore **recente (24 ore)**, controlla data UTC non futura e rifiuta ricevute scadute. Per finestre più lunghe è possibile `T4_MAX_RESTORE_AGE_HOURS` da 1 a 168; non usarlo per eludere il restore. Questi controlli sono verificati in CI con **dati sintetici**, non rappresentano la prova del VPS.

## Coolify (scelta consigliata)
- Repository: `andreadada/simple-notes`, branch `main`.
- Build Pack: **Docker Compose**.
- **Base Directory:** `/`
- **Docker Compose Location:** `/docker-compose.yml` (file nella radice).
- Services: `api` e `db`. Dominio HTTPS SOLO sul servizio `api`, porta interna **8080**.
- **Non attivare Raw Compose**. Non pubblicare le porte di PostgreSQL.

Variabili da impostare come secret su Coolify:
- `POSTGRES_DB=simplenotes`
- `POSTGRES_USER=simplenotes`
- `POSTGRES_PASSWORD` (password casuale forte)
- `GOOGLE_CLIENT_IDS` (OAuth Web e Desktop, separati da virgola)
- `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET` (solo server)
- `APP_JWT_SECRET_BASE64` (eseguire `openssl rand -base64 32`)

Coolify deve leggere il file Compose e generare i campi per le variabili. **Imposta i segreti prima di deploy.**

### Se compare `required variable POSTGRES_PASSWORD is missing a value`
Il vecchio Compose con `${POSTGRES_PASSWORD:?}` obbligava l'interpolazione dei segreti durante `docker compose build`. Il file root corrente usa `${POSTGRES_PASSWORD:-}`, così la build non richiede la password. La password **deve comunque essere presente a runtime**, altrimenti PostgreSQL e l'API non si avviano.

- In Coolify mantieni `Build time = Not available during build` e `Runtime = Available in the container` per **POSTGRES_PASSWORD**, **APP_JWT_SECRET_BASE64** e **GOOGLE_DESKTOP_CLIENT_SECRET**.
- Premi **Load Compose** e quindi **Redeploy** per prendere il commit aggiornato.
- Verifica che il log inizi dal nuovo commit e che il servizio `db` sia healthy.
- Mai usare un secret inventato o default nel Compose per aggirare la validazione.
 Una volta configurato il dominio usa `/actuator/health` per verificare l'API.

## Locale
Il vecchio `infra/compose.yaml` resta disponibile per sviluppo locale, con bind su 127.0.0.1. Il Compose di Coolify è `docker-compose.yml` nella root.
In locale:
```sh
cp .env.example .env
# Modifica .env con password, chiave JWT e OAuth ID reali.
docker compose --env-file .env -f infra/compose.yaml up --build
```

## Aggiornamento avatar Google (23 ottobre 2026)

Il backend include ora `AuthResponse.photoUrl` ricavato dal claim Google OpenID `picture` (quando presente), persistito con Flyway `V4__google_profile_photo.sql` nella tabella `app_user`. Dopo il `git pull` lato client occorre **redeploy del servizio API su Coolify** dal branch `main`. La migrazione aggiunge una colonna nullable e conserva i dati esistenti; per visualizzare la foto dopo un refresh su Windows, gli utenti già registrati devono effettuare un nuovo Google Login una volta. Non modificare alcun Client Secret o variabile d'ambiente. Verificare `/actuator/health` e i log Flyway prima di considerare il deploy riuscito.

## Da completare prima della produzione
- Rate limiting e protezione anti-abuso sugli endpoint di autenticazione.
- Test OAuth Windows/Android con client reali e firma Android coerente.
- Test sync fra due dispositivi e risoluzione dei conflitti.
- Backup PostgreSQL fuori dal VPS e prova effettiva di ripristino.
- Confermare periodicamente dominio DNS, rinnovo certificato TLS HTTPS e stato health.

**Stato aggiornato (23/10/2026):** l'utente ha confermato **deployment effettivo su Coolify** e health HTTPS `UP` su `https://api.notes.ddone.it/actuator/health`. La pipeline Compose valida solo la sintassi. Il server è utilizzato come **ambiente operativo di test** e NON va considerato production-ready finché non esistono hardening, backup e test di ripristino.

## Backup e test di ripristino prima del redeploy

È stato aggiunto un endpoint per confrontare conflitti di sync con indice Flyway **V5**: **prima di aggiornare Coolify effettuare un backup**.

Sul VPS, con repo disponibile e accesso Docker, individuare *esplicitamente* il container PostgreSQL Simple Notes (non usare il nome di altri DB):

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
# Sostituire <container-id-postgres-simplenotes> con quello corretto.
DB_CONTAINER='<container-id-postgres-simplenotes>' EXPECTED_POSTGRES_DB=simplenotes BACKUP_DIR=/percorso/sicuro/backup \\
  bash infra/backup-postgres.sh
# Usare il nome effettivo del file prodotto:
bash infra/verify-restore.sh /percorso/sicuro/backup/simple-notes-AAAA*.dump
```

**Importante:** backup e restore-check **non scrivono nel DB originale**; il restore-check usa un container PostgreSQL 17 **temporaneo e isolato**, poi lo elimina. Sono stati testati automaticamente con dati sintetici in GitHub Actions ([Compose CI](https://github.com/andreadada/simple-notes/actions)). Occorre ancora testare il dump **reale** e conservarne una copia cifrata **fuori dal VPS** con policy di retention (il dump include dati personali). Le due operazioni sono da eseguire esplicitamente sul VPS, non sono un backup automatico già configurato.

**Storico, non ordine di redeploy:** V1–V7 già verificate sul DB reale; controllare health e capability API prima di qualsiasi aggiornamento motivato. Se l'API non risponde, non modificare il database manualmente. Confronto conflitti Forui nel nuovo client richiede l'endpoint latest nel server aggiornato.

## Nuove liste e metadati attività — Flyway V6 (23/10/2026)

La nuova versione Flutter usa `entityType:list` e campi `listId/priority/tags/subtasks`. **Al 24/10:** backup/restore reale e V1–V7 già verificati; controllare prima API, senza redeploy automatico. Controllare log Flyway `V5__sync_conflict_latest_index.sql` e `V6__task_organization.sql`, health HTTPS e login. La migrazione V6 aggiunge soltanto colonne/versioni/indice, preservando dati storici. Non rinominare/azzerare volumi o PostgreSQL. I client non aggiornati possono non preservare tutti i metadati nuovi quando modificano una copia vecchia: aggiornare Windows e Android entrambi. Consultare [organizzazione attività](../docs/task-organization.md).

## Promemoria comando T4

Il receipt `.restore-ok` è creato SOLO dopo un ripristino completo su PostgreSQL 17 temporaneo. Conservare il dump e `.sha256` insieme e proteggere la cartella (`0600`). Dopo verifica della copia **cifrata fuori dal VPS** eseguire `T4_ARCHIVE="$ARCHIVE" T4_OFFSITE_CONFIRMED=yes T4_APPROVED_COMMIT="$(git rev-parse HEAD)" bash infra/t4-preflight.sh`. Controllare poi endpoint health e capability con `T4_BEARER_TOKEN` tramite `infra/t4-check-api.sh`. Per un nuovo sistema consultare il runbook completo, non copiare i vecchi comandi senza leggere le condizioni di sicurezza. Non è stato effettuato alcun restore o redeploy sul DB operativo.

**T4 controllo rafforzato:** `verify-restore.sh` salva `ROW_COUNT_<tabella>` nella ricevuta e rifiuta dump senza utenti esistenti. `t4-preflight.sh` impone conteggi numerici coerenti e almeno un record in `app_user`. Sono conteggi su database *isolato*; NON attestano che il VPS sia aggiornato, né sostituiscono il confronto operativo dei dati prima del rilascio.

## T4.2 — Audit sola lettura su note scomparse

`DB_CONTAINER='<id_postgres>' EXPECTED_POSTGRES_DB=simplenotes bash infra/t4-audit-note-loss.sh`

Verifica soft delete e storico degli eventi sincronizzati (compreso il gap cursor 25→34). Esegue esclusivamente SELECT/SHOW in sessioni PostgreSQL read-only. Non stampa contenuti delle note o credenziali; non modifica il DB. Vedi `docs/T4-DEVICE-SYNC.md`.

## Reset VOLONTARIO dei dati di test (distruttivo)

Per un solo account di test, `DB_CONTAINER=<container-postgres-simple-notes> EXPECTED_POSTGRES_DB=simplenotes bash infra/reset-test-workspace.sh --preview` mostra le quantità senza scrivere. L'esecuzione reale richiede esplicitamente `--execute`, `CLIENTS_CLOSED=YES`, `ERASE_TEST_WORKSPACE=ERASE_SIMPLE_NOTES_TEST_WORKSPACE`; non elimina utenti, sessioni, Flyway, schema o altri database. **Prima chiudere entrambi i client e dopo azzerare entrambe le SQLite.** Guida completa: [RESET-TEST-DATA.md](../docs/RESET-TEST-DATA.md).

## Storico — deploy P1.2/V8 (per nuovo rilascio usare batch V10)

Il branch `feature/p1-2-time-blocking` contiene `V8__task_time_blocks.sql` (3 colonne nullable su `task`, CHECK, indice). La migrazione **non** è stata applicata da questa sessione. Non effettuare reset o restore del database di produzione. Prima della nuova app Flutter `0.6.0+8`, il backend deve esporre `timeBlockSchema:1`, altrimenti la nuova outbox task si conserva offline. La checklist di rollout separata è in [P1-TIME-BLOCKING.md](../docs/P1-TIME-BLOCKING.md).

## P1.2/P1.3 — rilascio coordinato (25/10/2026)

Dopo il merge di P1.2 e P1.3 in `main`, **la presenza del codice non dimostra un deploy Coolify**. Verificare la versione Flyway con `infra/t4-inspect-db.sh`: ora riconosce sia V7 pre-deploy sia V8 dopo il rollout e verifica la presenza delle 3 colonne opzionali del time blocking. Per controllare la capability HTTPS post deploy occorre un token JWT reale e `REQUIRE_TIME_BLOCK_SCHEMA=1 API_BASE_URL=https://api.notes.ddone.it T4_BEARER_TOKEN='TOKEN' bash infra/t4-check-api.sh`. Non pubblicare il token nei log.

Sul VPS, identificare il container PostgreSQL da `docker ps`, mai assumere l'ID storico. Il deploy consigliato usa l'app esistente Coolify Docker Compose (root `docker-compose.yml`, servizi `api` e `db`), senza rimuovere/reinizializzare il volume PostgreSQL. Flyway V8 viene applicato automaticamente al boot della nuova API: controllare log Flyway e health. **Eseguire un backup verificato prima della migrazione**, conservare i segreti Coolify invariati, poi fare smoke test di creazione, spostamento, modifica, sync, Cestino note e scadenze. Nessun reset dati richiesto.

## Gate P1.11 (26 ottobre 2026)

Habit Tracker P1.11 usa soltanto SharedPreferences lato Flutter e non aggiunge variabili, migrazioni PostgreSQL, job né servizi Compose. L'app nel repository continua a richiedere Flyway V10 per le funzioni P1.6; la VPS è attestata fino a V8. Non far partire un deploy per il solo tracker e non cancellare volume, DB o stato locale in preparazione. [Guida operativa](../docs/OPERATIONS.md).

## P1.12 — Nessuna migrazione da applicare

La fase Countdown V1 è solo UI Flutter/SharedPreferences. Non aggiunge risorse Coolify, credenziali, Compose, backend, endpoint, Flyway o volumi. La verifica Flyway V10 sulla VPS resta richiesta per il rilascio cumulativo delle funzioni cloud precedenti (ultima attestazione V8). Nessun reset o deploy automatico. [Operazioni](../docs/OPERATIONS.md).

## Gate P1.13 — Nessuna nuova migrazione

Gli obiettivi settimanali Habit sono solo Flutter/SharedPreferences e restano device-only. Non aggiungere Compose, nuove risorse, variabili, backup distruttivi o migrazioni. Per il rilascio cumulativo verificare comunque Flyway V10 sul server reale (ultima attestazione V8), senza deploy/volumi automatici. [Guida](../docs/OPERATIONS.md) · [P1.13](../docs/P1-WEEKLY-HABITS.md).

## P1.14 — Nessuna risorsa server aggiuntiva

Le finestre Windows separate usano le note sincronizzate attraverso LocalStore del processo principale; nessun processo sync secondario, tabella, API, Compose service, variabile, backup o volume aggiuntivo. Il gate per release resta Flyway V10 realmente applicato (ultima attestazione V8). [Specifica](../docs/P1-STICKY-WINDOWS.md).

## P1.15 — Nessun intervento su Coolify

Le scorciatoie sono solo UI Flutter Windows, senza servizi, migrazioni, chiavi Google, variabili o volumi. Il server reale va confermato Flyway V10 separatamente prima dell'installazione cumulativa dei client (ultima attestazione V8). Niente deploy/reset per P1.15. [Specifica](../docs/P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Nessun cambio infrastrutturale

Adaptive notes è solo disposizione Flutter senza backend, compose/env, nuove migration, credenziali, storage o volumi. Resta necessario confermare Flyway V10 sulla VPS prima di distribuire il client cumulativo (ultima attestazione V8). Niente deploy/reset per questa fase. [P1.16](../docs/P1-RESPONSIVE.md).

## P1.17 — Nessuna modifica Coolify

Tray è solo client Windows: nessuna nuova risorsa server, volume, Compose env, key, API o migration. Per il rollout cumulativo controllare comunque Flyway V10 reale (ultima attestazione V8). Nessun deploy/reset per questa fase. [Specifica](../docs/P1-WINDOWS-TRAY.md).
