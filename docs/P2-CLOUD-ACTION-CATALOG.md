# P2 — Catalogo cloud delle regole task (PR #61)

**10 novembre 2026 — [PR #61](https://github.com/andreadada/simple-notes/pull/61) integrata su `main` (`bf16cba`), non deployata.** [Flutter CI #42821851199](https://github.com/andreadada/simple-notes/actions/runs/42821851199) **success** (399 test e build Windows/Android), [Backend CI #42821851073](https://github.com/andreadada/simple-notes/actions/runs/42821851073) **success** (test backend PostgreSQL 17), [Markdown CI #42821851207](https://github.com/andreadada/simple-notes/actions/runs/42821851207) **success**. [Stato attuale](CURRENT-STATUS.md).

## Obiettivo e sicurezza

Il batch rende **trasferibili con controllo di versione** le definizioni delle regole di azione task fra Windows e Android per lo stesso account. Non introduce ancora sincronizzazione automatica, un motore di esecuzione lato server, scheduler o trigger temporali. Un catalogo cloud non equivale all'esecuzione remota delle azioni.

### Backend Spring / PostgreSQL 17

- Migrazione **Flyway V12**, additiva: tabella task_action_catalog con owner UUID PK/FK, testo JSON, versione incrementale, timestamp e limite di **32 KiB UTF-8**. Nessuna modifica a task, note, outbox o tabelle esistenti.
- **GET /api/v1/automations/task-actions**, autenticato JWT: risponde {"version":0,"catalog":{"schema":1,"rules":[]}} se nessun catalogo è stato pubblicato. Altrimenti restituisce la revisione e il catalogo dell'owner. Non espone account altrui.
- **PUT /api/v1/automations/task-actions** con {"expectedVersion":N,"catalog":{...}}: valida rigorosamente schema 1, massimo 20 regole, ID unici, campi, trigger, azione, tag, priorità, lista UUID e dimensione. Dopo lock transazionale per owner esegue **compare-and-swap** e restituisce la nuova revisione; versione differente = **409 Conflict**, nessuna scrittura. Invalidità = **400**. Nessuna azione viene eseguita dal server e nessuna riga sync_change viene generata.
- Accesso tramite token dell'utente e scope owner ricavato esclusivamente dal JWT server-side. Nessun nuovo permesso OAuth.

### Flutter / Forui

**Strumenti → Automazioni → Azioni automatiche sulle attività** mostra, solo con account Google, endpoint configurato e archivio locale coerente, i comandi:

1. **Pubblica sul cloud:** legge il catalogo remoto e presenta il numero di regole/versione per conferma. Prima di inviare controlla che owner e preferenze locali non siano cambiati. Usa PUT CAS sulla versione letta. Se un altro dispositivo pubblica intanto, il server risponde 409 e nessun dato remoto viene perso.
2. **Scarica dal cloud:** legge e valida il catalogo per owner; se sul server non è mai stato pubblicato nulla, non cancella le regole locali. In caso diverso presenta **conferma esplicita di sostituzione**, controlla ancora owner e dati locali, poi salva la preferenza sul dispositivo. Non tocca task o outbox.
3. Un server precedente senza endpoint risponde 404; la UI segnala che serve il deploy V12 **senza alterare i dati**. Risposte incompatibili/errore rete/409 sono fail-closed. Nessun token viene salvato nelle preferenze né mostrato nei messaggi.
4. **Nessun trasferimento automatico**: dopo modifiche locali bisogna usare «Pubblica», e sull'altro dispositivo «Scarica». Regole non ancora pubblicate possono divergere; il confronto è esplicito. L'archivio resta incluso come preferenza locale opzionale nel backup cifrato .snb, mentre il server ne mantiene una copia separata.

## Test e rilascio

- **Server**: TaskActionCatalogIntegrationTest con Testcontainers PostgreSQL 17 (autenticazione, owner isolamento, versione zero, upload, 409, schema/filtro non validi, nessuna operazione task/sync). JDK21/Gradle backend CI.
- **Flutter**: task_action_cloud_api_test.dart (GET, PUT, JWT, CAS, 404/426, formato e URL sicuro) e task_action_cloud_widget_test.dart (conferma download, 409 publish, owner mismatch). Suite Flutter, analyze e build Android/Windows nel workflow del repository.
- **Deploy separato, non autorizzato da questa PR:** la VPS aveva Flyway V10 attestata al 03/11; le V11/V12 sono nel repository e non vanno descritte come applicate. Prima di distribuire la V12 serviranno i gate esistenti: backup verificato, readiness e verifica schema/database post-deploy. Il nuovo client non deve considerare 404 come successo.
- **Restano aperti:** distribuzione automatica del catalogo e merging conflitti, job temporali server, deduplica di eventi su più device, sicurezza operativa restore live, prove reali Windows↔Android, OAuth Calendar/Outlook, ACL e allegati S3.

Consulta [Matrice P2](P2-DELIVERY-MATRIX.md) e [Collaudo differito](DEVICE-ACCEPTANCE-DEFERRED.md).
