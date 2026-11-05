# P2.4B2P — Gate read-only per Flyway V11

**Stato 05/11/2026:** il codice backend contiene la migrazione **additiva** V11 di \`sync_operation.request_fingerprint\`, ma il database sulla VPS è stato attestato **solo fino a Flyway V10 (03/11/2026)**. Una PR verde non equivale a un deploy. Questo gate **non** esegue migrazione, backup, restore, installazioni, reset, aggiornamenti o scritture.

## Differenza fra V10 e V11

- Il vecchio \`infra/release-readiness.sh\` resta volutamente dedicato alla verifica esatta di Flyway **V10** per i rilasci storici.
- \`infra/t4-inspect-db.sh\` ora riconosce V1–V11 e con \`REQUIRE_FLYWAY_VERSION=11\` verifica anche presenza, tipo \`VARCHAR(64)\`, nullabilità e formato delle fingerprint non nulle. Per V10 rifiuta la presenza prematura della colonna V11.
- \`infra/release-v11-readiness.sh\` richiede esattamente Flyway **V11**, PostgreSQL 17, colonne da V7 a V11 coerenti, nessuna migrazione fallita, health HTTPS \`UP\` e capability autenticata compatibile. È **solo read-only**.
- Nella CI Compose i controlli V10/V11 vengono esercitati su un **container PostgreSQL 17 sintetico**; V11 con colonna sbagliata viene rifiutato, V10 continua a funzionare.

## Prima di un futuro deploy autorizzato

Identificare il vero container con \`docker ps\` e non usare mai un ID storico senza ricontrollarlo. Verificare checkout e variazioni locali; conservare una **copia recente verificata** del DB, con prova di restore isolato e offsite quando previsto, senza toccare la base dati reale. Il gate V11 è previsto **dopo** un eventuale rollout esplicitamente approvato. Non eseguire uno schema upgrade solo per poter ottenere un PASS.

## Controllo dopo un rollout autorizzato — senza modifiche

Non incollare in chat JWT, email, ID account, dump o valori di fingerprint. Il token deve rimanere nella sessione amministrativa, non nel comando né in un file versionato.

\`\`\`bash
cd ~/simple-notes
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
# Impostare nella shell DB_CONTAINER al container PostgreSQL verificato.
# T4_BEARER_TOKEN deve essere già disponibile solo come variabile d'ambiente.
DB_CONTAINER='<ID_CONTAINER_CONFERMATO>' \
EXPECTED_POSTGRES_DB=simplenotes \
API_BASE_URL=https://api.notes.ddone.it \
  bash infra/release-v11-readiness.sh
\`\`\`

Esito richiesto: \`T4_SOURCE_INSPECTION=PASS\`, \`FLYWAY_LATEST=11\`, \`FINGERPRINT_COLUMNS=1\`, \`FAILED_MIGRATIONS=0\`, \`FLYWAY_REQUIREMENT=PASS (V11)\`, contratto API compatibile e infine \`V11_SERVER_READONLY_GATE=PASS\`. Nessuna riga di utenti o dati contenuti viene stampata: solo conteggi.

Un PASS **non** dimostra che il nuovo backend stia effettivamente applicando il fingerprint alle operazioni (il vecchio servizio potrebbe continuare a rispondere): richiede ancora un test di integrazione **separato su account di prova**, autorizzato dopo rollout, oltre al collaudo Windows↔Android e alla gestione dell'outbox. Non utilizzare la verifica per sbloccare il restore reale; restano obbligatori lock e journal locale durabili e consenso per item.
