# P2 — Scanner malware allegati S3 (ClamAV INSTREAM)

**14 novembre 2026 — hardening del backend.** La scansione completa e fail-closed viene eseguita prima della conferma: il file fino a 10 MiB è letto con GET S3 condizionale rispetto all'ETag verificato da HEAD, quindi analizzato tramite un daemon privato ClamAV (clamd, protocollo INSTREAM). L'allegato diventa READY solo dopo una risposta esattamente «stream: OK».

## Garanzie

- Nessun allegato READY prima di HEAD S3 coerente (dimensione, MIME, ETag), controllo firme iniziale, GET completo condizionale, verifica lunghezza, antivirus, e COPY finale con precondizione ETag.
- Scanner mancante, disconnesso, lento, non CLEAN o malware FOUND: la conferma è rifiutata e non viene pubblicato un link di download.
- Gli oggetti PENDING non confermati restano invisibili, i metadati scadono nel job esistente, e il lifecycle privato di S3 deve cancellare staging.
- Trasmissione a clamd dei soli byte del file, non di URL firmati, chiavi S3, nomi file o credenziali.
- Massimo 10 MiB, lettura S3 bounded size+1, timeout connessione clamd 3 secondi, risposta 30 secondi, massimo 256 byte per il verdetto.

## Configurazione futura Coolify

**Mantenere APP_ATTACHMENTS_ENABLED=false fino ai collaudi.** Serve un servizio clamd privato, collegato alla rete interna Docker di Coolify, senza pubblicare la porta 3310 su Internet. Il suo database firme deve essere aggiornato, con risorse e limiti adeguati.

Variabili aggiuntive in Coolify:

- APP_ATTACHMENTS_SCANNER_HOST: nome DNS INTERNO del servizio clamd raggiungibile dall'API, mai un host pubblico.
- APP_ATTACHMENTS_SCANNER_PORT: numero porta TCP del daemon, predefinita 3310.
- APP_ATTACHMENTS_ENABLED=false: non attivare sino all'accettazione.

Restano necessari anche bucket S3 privato, HTTPS, credenziali minime, CORS ristretto, lifecycle del prefisso staging, politiche backup e prove di ripristino. Se manca la configurazione dello scanner, il backend rifiuta già l'inizio dell'upload. Se la connessione cade dopo l'upload, la conferma viene rifiutata e non diventa READY.

## Test, limiti e responsabilità

Test unitari con un finto daemon ClamAV su localhost verificano lo streaming INSTREAM e i verdetti OK/FOUND/ERROR. I test integrati PostgreSQL/S3 mock verificano che un file infetto non venga promosso. Test con un bucket S3 e un daemon clamd REALI non sono stati svolti da ChatGPT.

La scansione antivirus non garantisce l'assenza di ogni minaccia: serve mantenere le firme aggiornate, monitorare il servizio e applicare difese ulteriori. Restano codice e collaudi per pulizia definitiva degli oggetti di note cancellate (senza perdere gli allegati delle note nel cestino), coda di upload offline, test fisici Windows/Android e configurazione/backup reali.

[Allegati](P2-NOTE-ATTACHMENTS.md) · [Checklist manuale](CHECKLIST-MANUALE-P2.md) · [Stato](CURRENT-STATUS.md).
