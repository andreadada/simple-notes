# P1.2 — Time blocking sincronizzato (prima implementazione)

**Data:** 25 ottobre 2026 · **Branch di sviluppo:** `feature/p1-2-time-blocking` · Flutter `0.6.0+8`.

> Stato: implementazione del contratto e delle interfacce nella repository; **non ancora rilasciata/deployata su Coolify né installata sui dispositivi fisici**. Le verifiche CI e quelle real-device sono gate distinti. Questo documento è un riferimento corrente rispetto agli appunti storici pre-reset.

## Funzioni implementate

- Ogni task può avere **un** intervallo pianificato `timeBlock` con `start`, `end`, `timeZone` IANA, indipendente da `due` (scadenza). Le attività senza blocco restano senza blocco, senza inferenze da `dueAt`.
- Apertura editor Forui **Pianifica blocco di tempo** dai dettagli del task e dal calendario. Data, ora di inizio/fine e fuso selezionabili; modifica e **Rimuovi blocco** non cambiano la scadenza.
- Calendario giorno/settimana/mese con sezioni esplicite **Blocchi di tempo** e **Scadenze**. Le attività senza scadenza possono essere pianificate dal pannello **Da pianificare**.
- Creazione/edit/block removal nel percorso già esistente `LocalStore → Drift SQLite → pending_mutations → /sync/apply → PostgreSQL → /sync/changes`. Il task mantiene ID e versionamento, il blocco non è una nuova entità da deduplicare.
- Campi inline dei titoli invariati (regola di design); l'editor dedicato è appropriato a un intervallo composto da più valori.
- Calcolo durata dagli istanti UTC; proiezione del giorno/ora nel fuso del dispositivo per il calendario e visualizzazione dell'orario originale nel fuso IANA associato al blocco. Non usare `due` come orario di inizio.
- Orari locali inesistenti durante salto DST **rifiutati**; per orari ripetuti (fold) l'utente deve scegliere esplicitamente l'occorrenza/offset. Sono possibili intervalli di durata `0 < durata <= 24h` nel contratto backend; l'editor **prima versione** seleziona inizio e fine nello *stesso giorno civile*.

## Protocollo e migrazioni

| Parte | Cambiamento |
|---|---|
| PostgreSQL | `V8__task_time_blocks.sql`: `task.block_start_at`, `block_end_at`, `block_timezone` (nullable), CHECK atomicità/ordine/durata <= 24h, indice sui blocchi attivi. Migrazione **additiva**, senza reset/backfill. |
| JPA | `TaskEntity` con 3 campi opzionali; `TaskTimeBlock` valida instanti, durata e IANA. |
| Sync JSON | `timeBlock: {"kind":"none"}` oppure `{"kind":"range","start":"...Z","end":"...Z","timeZone":"Europe/Rome"}`. |
| API capabilities | `GET /api/v1/capabilities` aggiunge `timeBlockSchema:1`. |
| Server compatibility | Client legacy senza `timeBlock` può aggiornare task **solo se il task non ha già blocchi**; se esiste un blocco, l'API restituisce 426 anziché cancellarlo silenziosamente. |
| Flutter/Drift | `schemaVersion=6`: tre colonne SQLite nullable, nessun cambiamento alle note, alle scadenze o all'outbox. |
| Client compatibility | Il nuovo client invia `timeBlock` esplicitamente su ogni upsert e **richiede `timeBlockSchema=1` prima di inviare**. Su API vecchia conserva la coda in SQLite, segnala aggiornamento necessario, non simula successo. Le operazioni legacy già accodate prive di `timeBlock` restano compatibili, salvo che il server protegga un blocco esistente. |

### Sicurezza e rollout

1. **Non effettuare deploy automatico** solo perché il codice è pushato. Usare un branch per isolare P1.2 finché non è convalidato.
2. Backend con Flyway V8 deve essere rilasciato e controllato **prima** di installare client `0.6.0+8`. Con client nuovo e server precedente, le modifiche ai task rimangono in coda, anche quando `timeBlock` è `none`.
3. Dopo backup/restore verificati secondo le normali politiche di rilascio, eseguire rollout API e controllare `GET /api/v1/capabilities` autenticato (`timeBlockSchema:1`), più stato Flyway e health. **Nessuno di questi passaggi è stato eseguito nella sessione di sviluppo.**
4. Installare le nuove build senza `adb uninstall` o azzerare SQLite; migrazione Drift V5→V6 preserva dati/versioni/cursori.
5. Verificare su due dispositivi reali: creare un task senza scadenza, aggiungere un blocco, controllare arrivo su altro dispositivo, modificare il blocco, confermare che la scadenza rimane indipendente, eliminare il blocco, provare offline→online e conflitti 409.
6. Verificare calendario su mobile stretto, Windows ridimensionato, transizioni DST e cambio fuso.

## Non incluso in questa prima implementazione

- Più blocchi per singola attività; un task ha al massimo un blocco.
- Intervalli con date distinte nell'editor (overnight) e drag/drop/ridimensionamento diretto sulla griglia; la struttura backend è già in grado di rappresentare gli intervalli fino a 24h.
- Collision avoidance automatica, slot suggeriti e ricorrenze.
- Notifiche, Google Calendar, Outlook, sincronizzazione Android a app chiusa e calendario web.

## Test

- `TimeBlockSyncIntegrationTest`: ciclo upsert→pull→clear, scadenza conservata, protezione vecchio client e input invalidi PostgreSQL 17/Testcontainers.
- `time_block_sync_test.dart`: SQLite/sync PC→Android e ritorno, fail-closed backend senza capability, validazione durata/DST fold.
- `task_due_migration_test.dart`: precedente fixture V4 conservata, copre passaggi automatici fino a Drift V6.
- CI GitHub Actions è la verifica automatizzata; **non** una prova di deploy o hardware.

**Passaggio successivo:** P1.3 drag & drop dei blocchi e pianificazione multi-intervallo, dopo test/distribuzione coordinata P1.2.
