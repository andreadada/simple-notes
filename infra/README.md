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

## Da completare prima della produzione
- Rate limiting e protezione anti-abuso sugli endpoint di autenticazione.
- Test OAuth Windows/Android con client reali e firma Android coerente.
- Test sync fra due dispositivi e risoluzione dei conflitti.
- Backup PostgreSQL fuori dal VPS e prova effettiva di ripristino.
- Configurazione dominio DNS e TLS HTTPS.

**Nota:** la pipeline GitHub valida la sintassi Compose, non equivale a un deployment Coolify verificato. Non è stato effettuato alcun deployment in produzione.
