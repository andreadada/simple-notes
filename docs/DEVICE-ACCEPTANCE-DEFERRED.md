# Collaudo cumulativo rinviato — evidenze reali al 3 novembre 2026

**Decisione dell'utente (03/11/2026):** rimandare i test manuali Windows ↔ Android e continuare gli incrementi della roadmap. I test unitari, l'analisi statica e le build di GitHub Actions **continuano a essere gate tecnici per ogni PR**; le prove fisiche e la release pubblica non sono completate. Nessun reset, reinstallazione, import di prova o deploy eseguito da ChatGPT per questa decisione.

## Evidenze già raccolte (senza deduzioni)

### VPS reale — ispezione read-only riuscita (03/11/2026)

Eseguito dall'utente sul server `ddone-01`:

```text
T4_SOURCE_INSPECTION=PASS
DB_NAME=simplenotes
POSTGRES_MAJOR=17
FLYWAY_LATEST=10
DUE_COLUMNS=5
BLOCK_COLUMNS=3
BLOCKS_JSON_COLUMNS=1
RECURRENCE_COLUMNS=1
FAILED_MIGRATIONS=0
ROW_COUNT_app_user=1
ROW_COUNT_task=3
ROW_COUNT_note=1
ROW_COUNT_sync_change=57
ROW_COUNT_sync_operation=57
```

Il server aveva mostrato la coppia API/DB Simple Notes durante `docker ps` con immagine API dal commit `215bb8e`. L'ispezione certifica **schema Flyway V10 coerente e nessuna migrazione fallita** nel container PostgreSQL selezionato, non l'accessibilità HTTPS, la correttezza delle capability autenticate o la replica applicativa end-to-end. Gli ID dei container Docker sono temporanei, non hardcodarli in nuovi script.

### Windows reale — diagnostica read-only fornita dall'utente

```text
Simple Notes · Diagnostica sincronizzazione
API: Compatibile (scadenze 1 + blocchi multipli 1)
Google: connesso
Archivio/account: coerente
Modifiche in attesa: 0
Task locali: 0
Note locali: 1
Note nel cestino: 0
Liste locali: 0
Cursor sync: 91
Ultima sync riuscita (locale): 2026-11-03 02:24:58
```

Queste sono **evidenze locali del client Windows**: sessione Google attiva, diagnosi API `compatible` secondo il controllo implementato nel client, associazione owner coerente, coda pending pari a zero e ultimo sync registrato. Il report non elenca il risultato del check completo `RELEASE_SERVER_GATE=PASS` (che richiede un access token applicativo nella sessione amministrativa) e non dimostra che tutte le capability aggiuntive siano passate. Non è stato fornito un report Android.

**Differenza di conteggi non risolta:** PostgreSQL conta 3 task nelle righe fisiche mentre il client mostra 0 task locali. Il conteggio server può includere record soft-deleted/visibilità e gli ID delle operazioni di sync possono avere salti: `ROW_COUNT_sync_change=57` e `cursor=91` **non sono direttamente confrontabili**. Non dedurre perdita o disallineamento dal solo confronto. Registrare il tema per l'audit read-only/visibilità del batch, senza modificare dati.

### JWT e verifica strict

L'utente ha tentato il comando `infra/release-readiness.sh`, che si è **fermato** perché `T4_BEARER_TOKEN` non era valorizzato. Non è stato riportato `RELEASE_SERVER_GATE=PASS`; non generare/copiare token dal database, logs, secure storage o HTTP per bypassare il gate. La diagnostica del client è parziale rispetto alla modalità server strict. In futuro si può aggiungere alla UI diagnostica la validazione di tutte le capability con il token già gestito in memoria, senza esporlo.

## Test rinviati, senza scadenza automatica

- **API live strict:** health HTTPS `UP` e capability autenticate per `taskDueSchema`, `noteRestoreSchema`, `timeBlockSchema`, `timeBlocksSchema` e `recurrenceSchema`. La VPS è già verificata a Flyway V10; non ripetere migration/deploy semplicemente per un report mancante.
- **Android ↔ Windows:** stesso account, snapshot di partenza, liste/task/note e cestino, sync bidirezionale, offline/online, 409 conflitti, 426 incompatibilità, cursor/outbox e preservazione dati.
- **Interfaccia:** calendari, ricorrenze, file/feed ICS, CSV, editor inline, focus/Habit/Countdown, promemoria, notifiche Android, tray e Sticky Windows, temi e layout accessibile.
- **Persistenza e packaging:** profili di prova senza cancellare dati, firma Android compatibile, Windows ZIP→MSIX solo dopo audit di SQLite/outbox/secure storage/SharedPreferences; nuovi client non equivalgono a installer sicuri.
- **Backup/offsite:** restore isolato del 24 ottobre è una prova *storica*, non un backup recente. La policy offsite rimane non confermata. Non creare automaticamente nuovi backup o reinstallare l'app.

## Criterio di chiusura futura

Il gate manuale si chiude soltanto con prove reali documentate da utente/operatori, su versioni e dispositivi identificati, senza dati/token nel report. `CI PASS` prova il codice testato, non l'installazione, il backend live o la conservazione dati. La scelta di rimandare il collaudo **non** vale come autorizzazione a deploy, reset o rilascio pubblico.

[Stato](CURRENT-STATUS.md) · [Runbook R1](RELEASE-V10-READINESS.md) · [Piano batch](P1-RELEASE-BATCH.md) · [Roadmap](../project.md).

## Stato codice P2.4A dopo il rinvio

[PR #27](https://github.com/andreadada/simple-notes/pull/27) integrata su `main`, Flutter `0.30.0+32`: [CI Flutter #41562133925](https://github.com/andreadada/simple-notes/actions/runs/41562133925) **success** (198 test + Windows/Android), [Markdown #41561797719](https://github.com/andreadada/simple-notes/actions/runs/41561797719) **success**. Questo conferma solo codice/build automatizzati, non picker CSV o sincronizzazione cross-device su hardware. Il rinvio delle verifiche manuali resta in vigore.

## P2.4B1 — Verifiche .snb rinviate

Nel batch fisico finale provare salvataggio Windows e condivisione Android del backup cifrato, password/confirm, controllo stessa password/account, rifiuto account diversi, file alterati o futuri, e assenza di scritture in verifica. Le credenziali OAuth non devono essere esportate. **Nessun restore live in P2.4B1**; implementazione P2.4B2 condizionata da cold-start, sync sospesa, checkpoint e rollback. [Contratto](P2-FULL-BACKUP.md).

**Aggiornamento codice 03/11/2026:** P2.4B1 [PR #28](https://github.com/andreadada/simple-notes/pull/28) integrata in `main`, Flutter `0.31.0+33`, 204 test automatici e build Windows/Android verdi ([CI #41636993011](https://github.com/andreadada/simple-notes/actions/runs/41636993011)). Questo **non è** un test fisico della creazione/apertura del file, né prova un ripristino; P2.4B2 rimane da implementare.

## Verifiche differite per il trasferimento dei modelli P2 (PR #58)

Il codice per esportare/importare modelli JSON è integrato su `main` (`e926a5a`) e ha superato [Flutter CI #42688444850](https://github.com/andreadada/simple-notes/actions/runs/42688444850): 369 test, analisi, build Android JDK17/21 e Windows EXE/MSIX. **Non è stato ancora collaudato** il picker su Windows, lo share sheet Android, il trasferimento di un file fra dispositivi o il cambio account durante il picker. Restano anche i test launcher/cold-start/logout del widget Android della PR #57. Il JSON dei modelli è non cifrato, locale e additivo; non autorizza il restore `.snb` live o alcuna modifica cloud. [Specifiche](P2-TEMPLATE-TRANSFER.md) · [Matrice](P2-DELIVERY-MATRIX.md).

## Regole promemoria P2 — prove fisiche differite (PR #59 integrata, CI verde)

Verificare con il build realmente installato: creazione/modifica/disabilitazione/cancellazione regole, permessi Android, cancellazione di notifiche già programmate, DST, scadenze date-only, cambio account, logout, riavvio, app chiusa, Android idle e Windows MSIX con package identity. ZIP/EXE non deve mostrare un opt-in. Niente test hardware o permessi OS attestati dalla sola CI. [Specifica](P2-REMINDER-AUTOMATIONS.md).

**Nota CI (09/11/2026):** [Flutter #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) supera 377 test, build Android JDK17/21 e Windows EXE/MSIX; questo **non certifica** notifiche consegnate su hardware Android o Windows. Nessuna prova fisica eseguita.

## P2 azioni task (PR #60 integrata, CI verde): prove hardware differite

Con il client reale verificare regole su creazione/completamento manuali, spostamento su lista, match titolo case-insensitive, ricorrenza, undo, account/guest e passaggio Windows ↔ Android; nessuna azione deve partire dal pull cloud o dall'import. Nessuna prova su dispositivi reali eseguita. [Specifica](P2-TASK-ACTIONS.md).

**Verifica CI (09/11/2026):** [Flutter #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) supera 392 test e build Windows EXE/MSIX, Android JDK17/21; la riuscita non certifica esecuzione o sincronizzazione cross-device su dispositivi fisici. Nessun test fisico e nessun deploy effettuati.

## P2 — Catalogo cloud regole task (PR #61 integrata): prove manuali differite

Dopo un deploy **autorizzato** con Flyway V12, provare su Windows e Android con lo stesso account: pubblicazione, download con conferma, annullamento, modifica concorrente con 409 CAS, backend pre-migrazione 404, cambio account durante la richiesta, perdita rete e conferma che non vengano modificati task/outbox. Ripetere con due owner e liste mancanti. Le definizioni NON sono sincronizzate automaticamente, né esiste un job di esecuzione server. Nessun collaudo fisico o deploy in questa fase. [Contratto](P2-CLOUD-ACTION-CATALOG.md).

**CI confermata il 10/11/2026:** [Flutter CI #42821851199](https://github.com/andreadada/simple-notes/actions/runs/42821851199) verde (399 test e build Windows/Android); [Backend CI #42821851073](https://github.com/andreadada/simple-notes/actions/runs/42821851073) verde (PostgreSQL 17), [Markdown #42821851207](https://github.com/andreadada/simple-notes/actions/runs/42821851207) verde. Nessuna prova di deploy, migrazione V12 su VPS o test Windows↔Android fisico. Il server attualmente attestato (V10 al 03/11) non deve essere considerato compatibile con l'API del catalogo finché non verificato.
