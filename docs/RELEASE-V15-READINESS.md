# P2 — Readiness Flyway V15 e cancellazione allegati S3

**11 novembre 2026.** La migrazione additiva **V15** aggiunge `attachment_object_delete_queue` per rendere durevole la cancellazione degli allegati confermati. Il database VPS è stato attestato soltanto fino a Flyway V10 (03/11/2026): **nessun deploy V11–V15 è attestato**.

## Comportamento

Una richiesta autenticata di eliminazione di un allegato READY registra la sua chiave S3 privata nella coda e rimuove il metadata **nella medesima transazione PostgreSQL**. Restituisce 204 quando la rimozione logica è confermata, non dopo il DELETE fisico. Il backend non emette nuovi URL di download per il record eliminato, ma un URL firmato emesso precedentemente può restare valido fino a cinque minuti.

Il worker (attivo soltanto con `APP_ATTACHMENTS_ENABLED=true`) legge fino a 25 chiavi con `FOR UPDATE SKIP LOCKED`, elimina con DELETE S3 idempotente e rimuove la riga della coda dopo successo. In caso di errore riprova dopo cinque minuti; un crash tra cancellazione S3 e commit DB porta a un retry sicuro. Non elimina file delle note nel cestino o oggetti staging, né effettua restore.

## Gate post-deploy di sola lettura

Usare solo dopo un deploy **esplicitamente autorizzato** e dopo il backup/restore isolato del database. Identificare il container attuale, non usare ID storici. Conservare il JWT nella sola sessione amministrativa.

```bash
cd ~/simple-notes
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_DB_VERIFICATO>' \
EXPECTED_POSTGRES_DB=simplenotes \
API_BASE_URL=https://api.notes.ddone.it \
  bash infra/release-v15-readiness.sh
```

Il risultato `V15_ATTACHMENTS_READONLY_GATE=PASS` richiede PostgreSQL 17, esatta Flyway V15, struttura della coda, health HTTPS e capacità JWT per allegati. Non verifica contenuti, policy bucket, permessi DELETE, dati reali, retry o dispositivi.

**Ancora da completare:** lifecycle effettivo `staging/*`, smaltimento degli oggetti di note eliminate definitivamente, scansione antivirus, coda upload offline, eventuali oggetti S3 promossi da transazioni poi fallite, deployment e test hardware. [Contratto](P2-NOTE-ATTACHMENTS.md) · [Matrice](P2-DELIVERY-MATRIX.md) · [Stato](CURRENT-STATUS.md).
