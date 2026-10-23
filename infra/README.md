# Backend — Coolify

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
DB_CONTAINER=<container-id-postgres-simplenotes> BACKUP_DIR=/percorso/sicuro/backup \\
  bash infra/backup-postgres.sh
# Usare il nome effettivo del file prodotto:
bash infra/verify-restore.sh /percorso/sicuro/backup/simple-notes-AAAA*.dump
```

**Importante:** backup e restore-check **non scrivono nel DB originale**; il restore-check usa un container PostgreSQL 17 **temporaneo e isolato**, poi lo elimina. Sono stati testati automaticamente con dati sintetici in GitHub Actions ([Compose CI](https://github.com/andreadada/simple-notes/actions)). Occorre ancora testare il dump **reale** e conservarne una copia cifrata **fuori dal VPS** con policy di retention (il dump include dati personali). Le due operazioni sono da eseguire esplicitamente sul VPS, non sono un backup automatico già configurato.

Dopo verifica backup, distribuire `main` da Coolify, verificare log Flyway V5 e `/actuator/health`. Se l'API non risponde, non modificare il database manualmente. Confronto conflitti Forui nel nuovo client richiede l'endpoint latest nel server aggiornato.

## Nuove liste e metadati attività — Flyway V6 (23/10/2026)

La nuova versione Flutter usa `entityType:list` e campi `listId/priority/tags/subtasks`. **Prima di installare/avviare questa versione su dati reali**, effettuare backup PostgreSQL verificato con i comandi precedenti, poi redeploy API da `main`. Controllare log Flyway `V5__sync_conflict_latest_index.sql` e `V6__task_organization.sql`, health HTTPS e login. La migrazione V6 aggiunge soltanto colonne/versioni/indice, preservando dati storici. Non rinominare/azzerare volumi o PostgreSQL. I client non aggiornati possono non preservare tutti i metadati nuovi quando modificano una copia vecchia: aggiornare Windows e Android entrambi. Consultare [organizzazione attività](../docs/task-organization.md).
