# Infrastruttura — Coolify (P0 WIP)

## Sviluppo locale
1. Copia `.env.example` in `.env` e genera credenziali sicure (PostgreSQL, chiave JWT).
2. In Google Cloud Console crea un client **Desktop**, un client **Android** (package+SHA) e un **Web OAuth client** usato da Android.
3. Inserisci `GOOGLE_CLIENT_IDS` (ID dei token accettati), `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET` (solo server), `APP_JWT_SECRET_BASE64` nel file locale non tracciato.
4. Da root: `docker compose --env-file .env -f infra/compose.yaml up --build`.
5. Health check: `http://127.0.0.1:8080/actuator/health`; le API sono protette con Bearer JWT.

## Coolify — da validare
- Importa `andreadada/simple-notes` e il Compose `infra/compose.yaml`.
- Imposta ogni segreto in Coolify; non pubblicare PostgreSQL.
- Il Compose punta a `127.0.0.1:8080` per uso locale: adatta la rete/proxy Coolify HTTPS prima del deploy.
- Abilita backup PostgreSQL **fuori dal VPS**, retention e prova di ripristino.
- Proteggi endpoint auth (rate limiting/abuse detection), verifica login Windows/Android su dispositivi reali e controlla segreti e logging.

**NON ancora deployato su Coolify.** I refresh token sono ora implementati, ma rate limiting e procedure di release non sono completati.
