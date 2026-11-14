# Simple Notes — readiness Flyway V19 (inbox server)

**14 novembre 2026.** PR #79 introduce V19 additiva; la VPS dell'utente resta all'ultima versione verificata Flyway V17. V18 (OAuth calendari) e V19 (inbox promemoria) sono indipendenti dagli account esistenti e disabilitate senza opt-in/credenziali.

## Prima del deploy (operatore)

1. Confermare CI verdi sul commit integrato e repository pulito.
2. Fare dump PostgreSQL 17 con infra/backup-postgres.sh, SHA256, copia cifrata offsite e restore isolato infra/verify-restore.sh.
3. Verificare il gate infra/t4-preflight.sh con commit esatto approvato; non ricreare container DB, volumi o credenziali.
4. Mantenere allegati S3 OFF fino a verifiche bucket/lifecycle/scanner; OAuth Calendar OFF finché non configurato.
5. Effettuare solo allora il redeploy della risorsa Coolify esistente. Flyway migra automaticamente; non fare reset o flyway repair per tentativi.

## Controlli post-deploy (read-only)

    cd ~/simple-notes
    git pull --ff-only origin main
    docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
    DB_CONTAINER='<POSTGRES_CORRENTE>' EXPECTED_POSTGRES_DB=simplenotes API_BASE_URL=https://api.notes.ddone.it bash infra/release-v19-readiness.sh

Impostare T4_BEARER_TOKEN temporaneo in shell, senza incollarlo in chat. Il gate richiede Flyway esattamente V19, FAILED_MIGRATIONS=0, health UP e capability serverReminderSchema=1. Non abilita preferenze né verifica notifiche push.

## Collaudi manuali con account di prova

Con due utenti verificare inbox OFF iniziale, attivazione per uno solo, task datetime vicino, scan e comparsa dopo Aggiorna, assenza di duplicati, conferma su Windows e scomparsa dopo Aggiorna su Android, task completato/eliminato nascosto, CAS 409 da dispositivo stale. Non usare task personali per collaudi distruttivi.

[Manuale P2](CHECKLIST-MANUALE-P2.md) · [Contratto](P2-SERVER-REMINDER-INBOX.md) · [Gate V18](RELEASE-V18-READINESS.md).