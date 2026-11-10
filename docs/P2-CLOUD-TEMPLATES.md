# P2 — Catalogo cloud dei modelli personali (PR #63)

**10 novembre 2026 — [PR #63](https://github.com/andreadada/simple-notes/pull/63) integrata su `main`, commit `b9dd67a`.** Questo incremento **non completa l'intera P2**. [Stato canonico](CURRENT-STATUS.md).

## Contratto e comportamento

La schermata Forui **Modelli** offre *Pubblica cloud* e *Scarica cloud* soltanto con identità Google e `boundOwnerId` locale coerenti. Scambia **solo definizioni dei modelli personali**, non i cinque preset e non i task già generati dai modelli.

- Flyway **V13__user_template_catalog.sql** crea `user_template_catalog` (PK/FK `owner_id`, JSON testo, versione, timestamp). Additiva: non tocca task, note, `sync_change`, `sync_operation`, SQLite o outbox.
- `GET /api/v1/templates/catalog` JWT risponde `{"version":0,"catalog":{"schema":1,"templates":[]}}` per account senza pubblicazioni; `PUT` richiede `expectedVersion` e `catalog`, restituisce versione incrementata. Advisory lock PostgreSQL per owner + CAS impediscono last-writer-wins; revisione vecchia = 409.
- Validazione schema 1: max 50 modelli, ID `custom-` univoci, priorità 0–3, fino a 16 tag/50 sottotask per modello, lunghezze limitate e massimo JSON 128 KiB. Nessuna esecuzione sul server.
- Client HTTPS/JWT timeout 20 secondi, controllo owner prima/dopo GET/PUT, verifica che SharedPreferences non siano cambiate prima di salvare, e **secondo GET dopo conferma di download**: se versione/catalogo differiscono, nessuna sostituzione. Comandi e dialog Forui, nessuna azione automatica al login.
- 404/426 (backend vecchio), 409 (conflitto), JSON invalido, owner non corrispondente e offline non cancellano modelli locali. Restano invariati import/export JSON e backup cifrati `.snb`.

**Non è sync automatica**: dopo modifica su Windows si pubblica manualmente e su Android si scarica manualmente (o viceversa). Non usa `/sync` e non genera operazioni task. Pubblicare una lista vuota può sostituire il catalogo remoto solo dopo consenso e CAS. Scaricare sostituisce i modelli locali solo dopo consenso.

## Verifiche e release

- Test backend PostgreSQL 17 Testcontainers: JWT, isolamento account, rev 0, CAS 409, validazione schema, zero nuove `sync_change`.
- Test Dart client HTTP (HTTPS, JSON, 404/426/409) e widget Forui (consenso, GET obsoleto, owner, PUT concorrente).
- **Merge e CI Flutter/Backend/Compose/Markdown verificati verdi.** Dopo un deploy separatamente autorizzato, `infra/release-v13-readiness.sh` controlla in sola lettura schema Flyway 13, capability HTTPS/JWT e GET catalogo senza stampare dati.
- **VPS attestata Flyway V10 il 03/11/2026**. Questa PR non effettua deploy, migration live, restore o test fisici.

Restano aperti per P2: provider OAuth Calendar/Outlook, ACL liste condivise, allegati S3, scheduler server e dedup multi-device, restore live e collaudo hardware. [Matrice](P2-DELIVERY-MATRIX.md) · [Collaudi](DEVICE-ACCEPTANCE-DEFERRED.md) · [JSON manuale](P2-TEMPLATE-TRANSFER.md).

## Estensione integrata — sincronizzazione automatica foreground PR #65

La PR #63 aggiunge soltanto lo scambio manuale. [PR #65](https://github.com/andreadada/simple-notes/pull/65) implementa la riconciliazione automatica conservativa in primo piano con checkpoint, CAS e gestione esplicita dei conflitti; nessun background Android né deploy. [Contratto](P2-AUTO-TEMPLATE-CATALOG.md).
