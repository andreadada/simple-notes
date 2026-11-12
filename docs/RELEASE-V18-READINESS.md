# P2 — Readiness Flyway V18 / Calendar OAuth

**12 novembre 2026.** La [PR #77](https://github.com/andreadada/simple-notes/pull/77) introduce una migrazione V18 additiva e la prima integrazione OAuth Google Calendar/Outlook read-only. Il redeploy dell'utente ha portato la VPS a **Flyway V17**, verificato direttamente tramite cronologia delle 17 migrazioni riuscite e immagine backend 3c904a0. I controlli applicativi successivi sono stati riferiti come riusciti. **V18 non è distribuita su Coolify.**

## Procedura di upgrade futura, da autorizzare separatamente

1. Identificare il container PostgreSQL 17 corrente, confermare che è Simple Notes, fare dump completo con SHA256, copia offsite cifrata e ripristino di prova in un contenitore isolato. Non resettare volumi.
2. Approvare il commit esatto; solo allora eseguire il nuovo redeploy dalla risorsa Coolify esistente. Flyway applica V18 al boot, senza eseguire migrazioni manuali.
3. Sul VPS aggiornato e **dopo** il deploy, impostare T4_BEARER_TOKEN al JWT temporaneo Simple Notes **esclusivamente nella shell** e avviare il gate strettamente read-only:

    cd ~/simple-notes
    docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
    DB_CONTAINER='<POSTGRES_17_CORRENTE>' EXPECTED_POSTGRES_DB=simplenotes API_BASE_URL=https://api.notes.ddone.it bash infra/release-v18-readiness.sh

Il gate controlla PostgreSQL 17, **esattamente V18**, entrambe le tabelle token/stato, Flyway senza errori, HTTPS health e capability JWT **calendarReadSchema:1**. Non invia richieste OAuth né modifica dati. Può superarsi con provider disabilitati; non autorizza la loro attivazione.

4. Prima di abilitare segreti Google/Microsoft: registrare le due applicazioni OAuth e i redirect esatti descritti in [P2-CALENDAR-OAUTH.md](P2-CALENDAR-OAUTH.md). Usare account e calendari fittizi; controllare approvazione/negazione consenso, state scaduto e replay, lettura date-only e orari, refresh, disconnessione, cambio account e privacy nei log.

Nessun deploy, backup, grant live, restore su dispositivo o configurazione credenziali viene eseguito automaticamente da questo documento. Le prove provider reali e Windows/Android non sono sostituite dalla CI.

[Stato P2](CURRENT-STATUS.md) · [Contratto](P2-CALENDAR-OAUTH.md).