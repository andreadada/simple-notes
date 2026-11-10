# P2 — Allegati privati per le note con storage S3 (PR #64)

**10 novembre 2026. [PR #64](https://github.com/andreadada/simple-notes/pull/64) in verifica**, non in produzione. [Stato canonico](CURRENT-STATUS.md) · [Matrice P2](P2-DELIVERY-MATRIX.md).

## Obiettivo e limiti

Una nota già sincronizzata su un account Google può avere allegati cloud privati. Il client Flutter/Forui mostra un pulsante **Allegati** sulla card e un dialog con lista, **Aggiungi file**, **Apri**, **Elimina** (con conferma). L'allegato non è inserito nel corpo della nota, non modifica task/SQLite/outbox e non viene incluso nel backup `.snb`. Il caricamento **richiede connessione** e la nota deve essere già disponibile lato backend.

Formati ammessi: `image/png`, `image/jpeg`, `application/pdf`, `text/plain` (estensioni PNG/JPG/JPEG/PDF/TXT). Ogni file: 1 byte–10 MiB; per account: max 100 file attivi e 200 MiB di metadata dichiarati totali. La UI rifiuta file troppo grandi **prima di leggerli in memoria**. Non sono permessi SVG, HTML, JS o path nel nome file.

## Contratto backend

Migrazione **Flyway V14__note_attachments.sql**: tabella additiva `note_attachment` con UUID `id`, FK `owner_id` e `note_id`, chiave oggetto opaca, nome, content-type, size, stato `PENDING` o `READY`, creazione e scadenza pending. Gli indici supportano letture per owner/nota e gestione staging. Nessun dato delle migrazioni V1–V13 è riscritto; Drift rimane V8.

Tutte le route richiedono JWT dell'utente e la nota **attiva e di sua proprietà**. Le note non sincronizzate, cancellate o di altri utenti non sono accessibili (404).

| Endpoint | Semantica |
|---|---|
| `GET /api/v1/notes/{noteId}/attachments` | Elenco metadata `READY`, senza URL S3 |
| `POST /api/v1/notes/{noteId}/attachments` | `{"name":"lezione.pdf","contentType":"application/pdf","sizeBytes":1024}` → HTTP 201 `{id,uploadUrl,headers,expiresAt}` |
| `PUT {uploadUrl}` | Upload bytes diretto verso S3, solo header firmati, **senza** JWT dell'app |
| `POST /api/v1/notes/{noteId}/attachments/{id}/complete` | HEAD S3 verifica dimensione, content-type ed ETag; COPY condizionale `If-Match` da `staging/` a `files/`, modifica stato `READY`. Ripetere la conferma dopo successo è idempotente |
| `GET /api/v1/notes/{noteId}/attachments/{id}/download` | URL GET S3 firmato per 5 minuti; nessun dato binario nel JSON della API |
| `DELETE /api/v1/notes/{noteId}/attachments/{id}` | Rimuove oggetto permanente e metadata dopo autorizzazione |

La quota è calcolata per owner su file pronti più pending non scaduti, sotto advisory lock account. I presigned URL PUT e GET durano **5 minuti**; il ticket pending dura 15 minuti. Le chiavi sono generate esclusivamente sul server, senza usare il nome fornito dall'utente. Un PUT non è un allegato visibile fino alla fase `complete`; se HEAD rileva mismatch (dimensione/MIME) la conferma fallisce con 409 e non viene pubblicato.

Il PUT è su `staging/{ownerId}/{attachmentId}`; dopo HEAD il server **copia con precondizione ETag in una nuova chiave `files/`** per impedire a un precedente PUT firmato ancora valido di sovrascrivere un file già confermato. Oggetti staging orfani devono essere eliminati da una **policy lifecycle S3**, non da un reset applicativo.

## Configurazione privata Coolify — non attivata

L'API è **fail-closed**: `APP_ATTACHMENTS_ENABLED=false` per impostazione predefinita, risposta HTTP 503 sugli endpoint di archiviazione quando il bucket non è configurato. Non si imposta alcun valore nel repository.

Variabili da predisporre **solo nel pannello segreti Coolify**, dopo verifica manuale del bucket:

- `APP_ATTACHMENTS_ENABLED=true`
- `APP_ATTACHMENTS_BUCKET=<bucket privato>`
- `APP_ATTACHMENTS_REGION=eu-central-1` (o regione del provider)
- `APP_ATTACHMENTS_ENDPOINT=https://storage.example` (opzionale su AWS, richiesto quando l'endpoint è compatibile e diverso da AWS)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (o ruoli/credentials provider equivalenti, senza loggare le chiavi).

Configurare bucket **privato**, Public Access Block/nessuna ACL pubblica, credenziali minime ai prefissi `staging/*` e `files/*` (PUT/HEAD/GET/COPY/DELETE), TLS, backup/retention separati e **lifecycle obbligatorio per `staging/*`**. Proteggere endpoint API e hostname S3 con HTTPS. Verificare eventuale CORS secondo piattaforma; le build native Windows/Android non usano un browser per l'upload.

Non includere URL presigned in log, screenshot, report o backup: sono token di accesso temporanei. Le credenziali S3 non arrivano al client Flutter.

## Test e controlli

- Backend Testcontainers PostgreSQL 17: JWT obbligatorio, note di terzi nascoste, create/list/confirm/download/delete, conferma idempotente, mismatch HEAD e note nel cestino, nessun `sync_change` generato.
- Flutter HTTP: JWT soltanto sull'API, ticket S3 senza token, limite 10 MiB, MIME consentiti, URL HTTPS richiesti, 404/409/503 e JSON non valido.
- Widget Forui: elenco, consenso alla cancellazione, errore account/server.
- Test migrazione V6→V14 non tocca dati storici; inspector `infra/t4-inspect-db.sh` supporta V14 e `infra/release-v14-readiness.sh` verifica read-only schema e capability `attachmentSchema=1`, `attachmentStorageEnabled=true` **dopo un deploy separatamente autorizzato**.

**Gate non coperti dalla CI:** nessun bucket reale creato o verificato, nessun deploy Flyway V11–V14, nessun caricamento reale con provider S3, nessun test Windows/Android, niente scan antivirus/content sniffing, TTL di GET già emessi non revocabile immediatamente, rimozione oggetti dopo cancellazione/soft-delete della nota non ancora automatizzata, lifecycle staging e backup file non attestati, assenza di coda upload offline. **Non dichiarare allegati P2 rilasciati** prima di chiudere questi gate.

## Regole di sicurezza e recupero

- Non creare il bucket automaticamente, non eseguire `flyway migrate` o upload live sulla VPS. Non aggiungere S3 a restore live della base locale.
- Se upload fallisce, conservare l'archivio locale e lasciare il pending a scadenza; non creare record visibili senza HEAD/COPY validi.
- Se S3 non è configurato, gli allegati non sono utilizzabili: errore esplicito e nessuna alterazione della nota.
- Se la nota viene spostata nel cestino, l'autorizzazione all'elenco e al download impedisce nuove URL. La cancellazione fisica degli oggetti relativi a note eliminate richiede un job dedicato e una retention definita.

Restano P2 generali: Google Calendar/Outlook OAuth, liste condivise/ACL, scheduler server e promemoria multi-device, restore live verificato e collaudi release. [Operazioni](OPERATIONS.md) · [Test dispositivi](DEVICE-ACCEPTANCE-DEFERRED.md).
