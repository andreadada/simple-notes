# Coolify deployment

1. Crea un'app Docker Compose da GitHub usando `infra/compose.yaml` (verifica build context su Coolify).
2. Imposta `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` tramite variabili sicure Coolify.
3. Configura il reverse proxy HTTPS per API: per ora il compose espone **solo 127.0.0.1:8080** e richiede adattamento al routing Coolify.
4. Configura backup PostgreSQL fuori dal VPS, retention e prova di restore.
5. Prima di rendere pubblica l'API, implementa accesso Google e rate limiting.

**Attenzione:** questo compose è uno scaffold, NON una configurazione pronta per la produzione. L'API e la sincronizzazione non sono ancora implementate.
