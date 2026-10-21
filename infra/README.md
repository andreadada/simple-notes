# Deployment locale / Coolify — WIP (P0)

## Locale
1. Copia `.env.example` in `.env` nella root e genera password/PostgreSQL/JWT key reali.
2. Registra in Google Cloud Console gli OAuth client ID per Android e Windows, quindi imposta `GOOGLE_CLIENT_IDS`.
3. Esegui dalla root: `docker compose --env-file .env -f infra/compose.yaml up --build`.
4. Controlla `http://localhost:8080/actuator/health`. Le altre API richiedono Bearer token.

## Coolify (da completare/testare)
- Importa il repository GitHub; usa Compose da `infra/compose.yaml`.
- Imposta le variabili come **segreti** nel pannello Coolify.
- **Non** esporre Postgres, e collega la porta API 8080 soltanto al reverse proxy HTTPS.
- Il file Compose per ora usa `127.0.0.1:8080:8080` per sviluppo locale: per il proxy Coolify usa un routing interno adeguato, non dare per scontato che questo binding sia raggiungibile.
- Abilita backup remoti, retention, health check e verifica del ripristino.
- Prima del deployment pubblico: refresh token/revoca, rate limiting, test login reali, audit sicurezza.

**Non è stato effettuato alcun deploy reale su Coolify.**
