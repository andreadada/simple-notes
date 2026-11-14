# Simple Notes — checklist delle operazioni manuali P2

**14 novembre 2026.** Questa guida distingue quello che devi configurare TU da quello che deve ancora essere implementato nel software. L'ultimo deploy verificato sulla VPS è Flyway **V17**; il repository contiene V18 (OAuth calendari) e la PR #79 sviluppa V19 (inbox promemoria). Nessuna migrazione successiva a V17 è stata eseguita da ChatGPT.

## 1. Backup obbligatorio prima di ogni nuovo deploy

- [ ] Controlla repository pulito e commit di main.
- [ ] Identifica ogni volta il container PostgreSQL 17 di Simple Notes, non coolify-db (gli ID Docker cambiano dopo redeploy).
- [ ] Esegui i seguenti comandi sulla VPS:

    cd ~/simple-notes
    git status --short
    git pull --ff-only origin main
    git rev-parse HEAD
    docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
    export DB_CONTAINER='<ID_DB_SIMPLE_NOTES_CORRENTE>'
    export EXPECTED_POSTGRES_DB=simplenotes
    export BACKUP_DIR=/root/simple-notes-backups
    bash infra/t4-inspect-db.sh
    bash infra/backup-postgres.sh
    bash infra/verify-restore.sh /root/simple-notes-backups/NOME_DUMP.dump

- [ ] Verifica SUCCESS sul restore isolato e conserva i file dump, sha256 e restore-ok.
- [ ] Copia il backup **cifrato fuori dalla VPS**, non soltanto su un altro percorso dello stesso disco.
- [ ] Dopo aver approvato il commit completo di 40 caratteri e verificato l'offsite, esegui:

    T4_ARCHIVE=/root/simple-notes-backups/NOME_DUMP.dump \
    T4_OFFSITE_CONFIRMED=yes \
    T4_APPROVED_COMMIT='<SHA40_DEL_COMMIT>' \
    bash infra/t4-preflight.sh

Non fare reset/riparazioni Flyway, eliminazioni volume, restore live o comandi distruttivi a tentativi.

## 2. Coolify — deploy approvato

- [ ] Usa la risorsa Coolify già esistente: andreadada/simple-notes, branch main, Docker Compose /docker-compose.yml, API pubblicata HTTPS e DB PostgreSQL 17 privato con volume postgres_data.
- [ ] Mantieni i segreti esistenti: POSTGRES_PASSWORD, GOOGLE_CLIENT_IDS, GOOGLE_DESKTOP_CLIENT_ID, GOOGLE_DESKTOP_CLIENT_SECRET, APP_JWT_SECRET_BASE64.
- [ ] Solo dopo backup/restauro e CI verdi esegui un normale redeploy del commit approvato. Flyway applica automaticamente V18 e V19: non lanciare migrator manuali.
- [ ] Recupera l'ID NUOVO del database ed esegui:

    curl -sS -w '\nHTTP_STATUS=%{http_code}\n' https://api.notes.ddone.it/actuator/health
    DB_CONTAINER='<ID_DB_CORRENTE>' \
    EXPECTED_POSTGRES_DB=simplenotes \
    REQUIRE_FLYWAY_VERSION=19 bash infra/t4-inspect-db.sh

  Aspettati HTTP 200 e UP, FLYWAY_LATEST=19 e FAILED_MIGRATIONS=0 **solo se hai effettivamente distribuito V19**.
- [ ] Con il JWT temporaneo emesso da Simple Notes, impostato solo in shell come T4_BEARER_TOKEN, verifica:

    DB_CONTAINER='<ID_DB_CORRENTE>' \
    EXPECTED_POSTGRES_DB=simplenotes \
    API_BASE_URL=https://api.notes.ddone.it \
    bash infra/release-v19-readiness.sh

Non confondere JWT access token con token Google o segreto di firma APP_JWT_SECRET_BASE64. Non incollare credenziali o JWT in chat. Crea un nuovo backup anche dopo la migrazione.

## 3. Google Calendar

- [ ] Crea in Google Cloud un nuovo client OAuth 2.0 di tipo **Web application**, separato dal login Google già attivo.
- [ ] Configura consent screen, scope eventi calendario **solo lettura** e utenti di test. Verifica policy Google per pubblicazione e refresh token.
- [ ] Registra il redirect URI esatto:

    https://api.notes.ddone.it/api/v1/calendars/oauth/google/callback

- [ ] Salva esclusivamente come segreti Coolify: APP_CALENDAR_PUBLIC_ORIGIN=https://api.notes.ddone.it, APP_CALENDAR_GOOGLE_CLIENT_ID, APP_CALENDAR_GOOGLE_CLIENT_SECRET.
- [ ] Genera una chiave separata di 32 byte con **openssl rand -base64 32** e conservala stabilmente nel secret store come APP_CALENDAR_TOKEN_KEY_BASE64. Non riutilizzare JWT secret e non ruotarla senza migrazione dei token.
- [ ] Con calendario di prova, verifica consenso, cancellazione consenso, eventi all-day/orario, rinnovo e Scollega.

## 4. Microsoft Outlook

- [ ] In Microsoft Entra registra un'app Web con tipi di account compatibili con endpoint common (personali e/o organizzativi).
- [ ] Configura questo redirect URI esatto:

    https://api.notes.ddone.it/api/v1/calendars/oauth/microsoft/callback

- [ ] Permessi Graph **delegated Calendars.Read** e offline_access; non usare accessi applicativi globali o scrittura.
- [ ] In Coolify imposta APP_CALENDAR_MICROSOFT_CLIENT_ID e APP_CALENDAR_MICROSOFT_CLIENT_SECRET; conserva la scadenza del secret.
- [ ] Con account di prova verifica approvazione/negazione, eventuale admin consent, eventi, refresh e disconnessione.
- [ ] Nascondi query OAuth code/state e header Authorization dai log del proxy/telemetry.

**V18 è in sola lettura** sul calendario principale, non sincronizza eventi bidirezionalmente e non seleziona più calendari.

## 5. S3 allegati — NON ATTIVARE ANCORA

- [ ] Prepara un bucket privato S3 compatibile con blocco accesso pubblico, TLS, permessi minimi e lifecycle per staging/.
- [ ] Verifica CORS ristretto, costi, versioning, retention, backup e delete su files/.
- [ ] Quando la scansione malware sarà completa, saranno richiesti APP_ATTACHMENTS_ENABLED, APP_ATTACHMENTS_BUCKET, APP_ATTACHMENTS_REGION, APP_ATTACHMENTS_ENDPOINT, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, eventuale AWS_SESSION_TOKEN.
- [ ] Mantieni adesso **APP_ATTACHMENTS_ENABLED=false**. Il controllo MIME/prime centinaia di byte non è una scansione antivirus.
- [ ] Test finali con oggetti fittizi, file fino a 10 MiB, upload interrotto, quota, URL scaduto, ETag, eliminazione, accessi cross-account e lifecycle.

## 6. Collaudi Windows e Android

- [ ] Installa build e firme associate al commit verificato. Su Windows le notifiche native sono supportate tramite MSIX installato, non ZIP/EXE.
- [ ] Prova Google login, upgrade app senza perdita dati, note/task/liste/time blocks/ricorrenza, offline/resume, sync e cambio account.
- [ ] Testa inviti fra due account, VIEWER/EDITOR, revoca, conflitto CAS 409 e isolamento degli account.
- [ ] Per l'inbox V19: OFF iniziale, attiva con account fittizio, crea task datetime, aspetta scansione, premi Aggiorna, conferma da PC e verifica scomparsa da Android dopo refresh. **Non aspettarti notifiche push**.
- [ ] Prova i restore dei backup dell'app esclusivamente in sandbox; non sovrascrivere il profilo installato con dati veri finché il restore live non è sicuro.
- [ ] Conserva i risultati dei test e gli errori senza esporre JWT, email private, file o URL firmati.

## 7. Manutenzione

- [ ] Backup cifrato offsite e prova periodica del restore.
- [ ] Pianifica rinnovo dei client secret Google/Microsoft; non ruotare la chiave AES dei token senza migrazione.
- [ ] Controlla health, Flyway, errori HTTP, condivisione, job e S3; elimina dai log query OAuth, token e link firmati.

## 8. NON sono operazioni manuali: software ancora incompleto

- [ ] Consegna **push remota vera** (registrazione device, FCM/APNs/Windows, dedup e retry). V19 aggiunge soltanto inbox online e ack condiviso.
- [ ] Collaborazione offline multi-owner: modifiche in coda, revoche, merge/assegnazioni e conflitti sicuri.
- [ ] Calendario bidirezionale e selezione multi-calendario con risoluzione dei conflitti.
- [ ] Allegati S3: scanner malware intero file fail-closed, gestione oggetti legati a note eliminate, upload offline e collaudi reali.
- [ ] Restore live dei profili installati con lease, backup rollback, recupero power-loss e consenso.
- [ ] Collaudo finale, firme, pubblicazione e release di produzione.

Queste voci non si risolvono cambiando segreti o deployando. **La P2 non è ancora dichiarabile completata.**

[Stato attuale](CURRENT-STATUS.md) · [Matrice P2](P2-DELIVERY-MATRIX.md) · [OAuth V18](P2-CALENDAR-OAUTH.md) · [Inbox V19](P2-SERVER-REMINDER-INBOX.md) · [Gate V19](RELEASE-V19-READINESS.md) · [Allegati](P2-NOTE-ATTACHMENTS.md).
