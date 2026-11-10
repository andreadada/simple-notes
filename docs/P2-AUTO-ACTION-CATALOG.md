# P2 — Sync automatica conservativa delle regole task

**10 novembre 2026 — [PR #62](https://github.com/andreadada/simple-notes/pull/62) in verifica. Non dichiarare merge/CI finché non sono confermati.** [Stato canonico](CURRENT-STATUS.md).

## Funzionamento

Le regole di azione di [PR #60](P2-TASK-ACTIONS.md) restano eseguite **solo localmente** su eventi espliciti creazione/completamento. Il catalogo cloud versionato [PR #61](P2-CLOUD-ACTION-CATALOG.md) viene ora riconciliato automaticamente dal client **solo mentre l'app è aperta e in primo piano**: all'avvio, all'accesso, alla riconnessione, al ritorno in primo piano, dopo le modifiche locali e mediante controllo periodico di 60 secondi. Usa le API GET/PUT JWT con CAS già introdotte in V12, **senza nuove migrazioni o job server**. Non significa sincronizzazione in background Android a processo chiuso.

Per ogni account il client salva in SharedPreferences un checkpoint separato con **catalogo e versione cloud già confermati**; la chiave contiene solo l'hash SHA-256 dell'owner. Il checkpoint non contiene token, task né dati di altri account. Formato v1 validato; file malformati non vengono ricreati silenziosamente.

### Regole di riconciliazione

| Stato | Azione automatica |
|---|---|
| Cataloghi locale e cloud identici | Allinea il checkpoint, non esegue alcun PUT |
| Prima installazione senza preferenza locale, catalogo cloud esistente | Scarica le definizioni dopo verifica owner |
| Regole locali offline con cloud mai pubblicato (versione 0) | Pubblica una volta con CAS 0; successivi retry non duplicano |
| Solo il locale è cambiato rispetto al checkpoint | Pubblica con CAS della revisione cloud corrente |
| Solo il cloud è cambiato rispetto al checkpoint | Scarica e salva le regole sul dispositivo |
| Entrambi sono cambiati in modo differente | **Conflitto**: nessun upload/download automatico, conservazione di entrambi |
| Preferenza locale esplicitamente vuota e cloud non vuoto senza checkpoint | **Conflitto**: la lista vuota potrebbe essere una cancellazione intenzionale |
| JSON incompatibile, checkpoint corrotto, cambio owner, backend 404/426, rete o errore CAS 409 | Fail-closed: nessuna cancellazione dati né modifica a task/outbox |
| Revisione server inferiore al checkpoint, oppure stessa revisione ma catalogo differente | **Conflitto**: rifiuta il rollback/lo stato incoerente senza sovrascrivere le regole |

L'ordine delle regole è rilevante: per evitare fusioni arbitrarie, **non viene realizzato un merge automatico di modifiche contemporanee**. L'utente risolve dal pannello **Strumenti → Automazioni** scegliendo **Pubblica** o **Scarica** con conferma; prima del download manuale si ripete il GET, per rifiutare una conferma diventata obsoleta. Il PUT deve restituire una revisione incrementata e un catalogo coerente; al termine, il checkpoint registra la revisione scelta. Se il pannello di modifica è aperto, l'auto-sync rimane temporaneamente sospesa per evitare corse con dialog, salvataggi e conferme. Alla sua chiusura viene pianificato un controllo.

### Garanzie operative

- Nessuna attività viene creata o modificata durante la riconciliazione: **zero nuovi operationId e zero record outbox** per lo scambio dei cataloghi. L'API cloud delle regole è separata da /api/v1/sync.
- Si usa l'owner autenticato soltanto se corrisponde al boundOwnerId SQLite, e il gate di recupero/restore autorizza la normale sync. La verifica viene ripetuta prima delle scritture dopo ogni GET; anche le preferenze lette all'inizio vengono ricontrollate per evitare modifiche sopravvenute.
- Un PUT cambia la revisione server con CAS; un 409 non trasforma mai l'errore in last-writer-wins. Il download salva prima il catalogo locale e poi il checkpoint; l'upload salva il checkpoint solo dopo l'ACK server. Un crash tra i due passi è recuperabile attraverso il confronto dei cataloghi successivo.
- Errori nel canale regole **non devono bloccare la sincronizzazione ordinaria** di note, task e liste. Nessun backup o restore scrivente viene attivato.
- Anche dopo merge e CI, **la VPS non è automaticamente aggiornata**. Ultima evidenza di produzione: Flyway V10 al 03/11; V11/V12 esistono nel repository, ma vanno verificate attraverso il deploy separato.

## Test / gate

Unit test TaskActionCatalogMirror: primo bootstrap, pubblicazione offline con CAS, download aggiornamento remoto, anti-loop, conflitto su modifiche concorrenti, preferenza vuota intenzionale, cambio account, edit durante GET, checkpoint corrotto e risoluzione manuale. Test per rollback server, catalogo alterato a revisione invariata, ACK PUT non incrementato e conferma di download obsoleta. Test Flutter complessivi e build Android/Windows sono obbligatori prima del merge.

Restano esclusi: esecuzione server di azioni, trigger a orario, dedup di eventi simultanei su dispositivi diversi, test E2E Windows↔Android reali, deploy Coolify, OAuth Calendar/Outlook, liste ACL, allegati S3 e restore live. [Matrice P2](P2-DELIVERY-MATRIX.md) · [Prove differite](DEVICE-ACCEPTANCE-DEFERRED.md).
