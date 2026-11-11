# P2 — Readiness Flyway V16, liste condivise read-only

**11 novembre 2026, in revisione.** La VPS risulta attestata a **Flyway V10 il 03/11/2026**. Nessun deploy, migrazione, account di produzione, dato reale o collegamento di condivisione è stato creato.

## Gate read-only dopo rollout esplicitamente autorizzato

Il codice contiene `infra/release-v16-readiness.sh`, che richiede PostgreSQL 17, **esattamente Flyway V16**, le strutture delle due tabelle ACL, HTTPS health UP e capability autenticata `sharingReadSchema:1`. Non crea inviti né esegue mutazioni. Identificare il container corretto con `docker ps` e assicurare backup recente con SHA256 e verifica di restore isolato; mantenere il JWT solo in una variabile della sessione.

```bash
cd ~/simple-notes
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_CONTAINER_POSTGRES_VERIFICATO>' \
EXPECTED_POSTGRES_DB=simplenotes \
API_BASE_URL=https://api.notes.ddone.it \
  bash infra/release-v16-readiness.sh
```

Risultato previsto: `T4_SOURCE_INSPECTION=PASS`, `FLYWAY_LATEST=16`, `FLYWAY_REQUIREMENT=PASS (V16)`, capability conforme e `V16_SHARING_READONLY_GATE=PASS`. Questo non prova la condivisione in pratica: richiede test separato su account fittizi, due dispositivi e inviti monouso, con una lista di test isolata.

Il gate storico V15 richiede **esattamente V15** e non deve essere forzato su un V16. Non eseguire deploy per soddisfare uno script. Per l'API/limiti vedere [P2-LIST-SHARING](P2-LIST-SHARING.md); per altri test pendenti [DEVICE-ACCEPTANCE-DEFERRED](DEVICE-ACCEPTANCE-DEFERRED.md).
