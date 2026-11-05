
# P2.4B2Q — Conflitti di intenzione, risposta distinta e protezione outbox

**Stato 05/11/2026:** questo sviluppo riguarda un codice di errore esplicito dal backend per un `operationId` riutilizzato con un'intenzione differente. Non autorizza il ripristino di backup e non modifica dati di produzione.

## Due condizioni diverse con HTTP 409

1. **Conflitto ordinario di versione/entità:** due dispositivi aggiornano lo stesso record con versioni attese differenti. Il backend continua a rispondere 409 ordinario; il client può mostrare il confronto fra versione locale e remota, con decisione esplicita dell'utente.
2. **ID operativo già legato a contenuto diverso:** dopo Flyway V11, un'operazione già salvata con fingerprint diverso non può essere semplicemente ribasata. Il backend risponde HTTP 409 con un corpo minimale JSON:
   
   ```json
   {"code":"SYNC_OPERATION_ID_REUSE"}
   ```

   Non contiene owner, ID di nota/task/lista, titolo, body, token, hash o payload. La verifica del proprietario precede l'errore tipizzato: collisioni tra account non rivelano metadati di un altro utente.

## Comportamento Flutter

Quando `POST /sync/apply` restituisce il codice esplicito, Flutter **interrompe il ciclo**, conserva ogni riga di `pending_mutations` e il database SQLite e imposta uno stato di conflitto **senza opzioni Keep local / Keep remote**. Nel menu account visualizza il motivo anziché un generico “modifica non inviata”. L'AutoSync resta sospesa finché permane lo stato di conflitto; la risoluzione manuale del normale 409 **non** viene proposta per l'intento immutabile.

L'HTTP 409 ordinario, una risposta JSON assente/ignota o un backend precedente sono gestiti dal percorso di conflitto già esistente, senza nuovi permessi e senza cancellare automaticamente dati. Il parser della risposta è limitato a 2 KiB, non mostra né registra il corpo HTTP. L'API di ripristino reale rimane disabilitata.

## Validazione e confini

Test PostgreSQL 17/Testcontainers verificano collisione tipizzata, differenza dal classico version conflict e assenza di contenuti privati nella risposta. I test Flutter verificano classificazione con JSON esatto, malformed, HTML, unknown code e risposta eccessiva. Non è stato creato un bottone di “forza sync”: un errore di riutilizzo ID richiede analisi e recupero guidato, non cancellazione della coda. Nessun deploy o migrazione reale.

[Specifica backup](P2-FULL-BACKUP.md) · [Stato](CURRENT-STATUS.md).
