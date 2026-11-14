# Collaudo cumulativo rinviato — evidenze reali al 3 novembre 2026

> **P2 · 14/11/2026:** backend VPS confermato V17; Flyway V18 (Calendar OAuth read-only) integrata in main, non deployata. PR #79 sviluppa V19 inbox opt-in con dedup e ack condiviso, **non push**, non deployata. Restano push, collaborazione offline, S3, restore live e prove hardware. [Checklist operatore](CHECKLIST-MANUALE-P2.md) · [V19](P2-SERVER-REMINDER-INBOX.md).

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

## P2 — Sync automatica regole task (PR #62): collaudo differito

A deploy V12 **esplicitamente autorizzato**, creare regole Windows offline e verificarne il trasferimento Android a ripresa/riapertura dell'app; provare due modifiche diverse sulla stessa base con conflitto non distruttivo, rollback di revisione cloud, nuovo PUT durante il dialog Scarica (deve rifiutare lo snapshot superato), annullamento e risoluzione manuale Pubblica/Scarica, account switch durante GET, 404/409, connessione persa e preferenze checkpoint corrotte. Verificare che nessun task e nessuna outbox siano modificati solo dalla sincronizzazione delle definizioni. Confermare la pausa mentre il pannello è aperto; Android a processo chiuso non sincronizza. Non attestato alcun test fisico o deploy. [Specifica](P2-AUTO-ACTION-CATALOG.md).

## P2 — Catalogo modelli V13 (PR #63): test fisici rinviati

Solo dopo deploy V13 autorizzato: verificare Windows/Android sullo stesso account, Pubblica e Scarica, conferma/annullamento, sostituzione e ID preservati, conflitto concorrente 409, versione cambiata durante il dialog, 404 backend vecchio, offline, cambio account/logout, limiti 50 modelli/128 KiB, e nessuna nuova operazione task/outbox. Nessun test fisico eseguito in PR. [Contratto](P2-CLOUD-TEMPLATES.md).

## P2 — Allegati S3, controlli hardware differiti (PR #64)

Solo dopo deploy autorizzato Flyway V14 e bucket privato: verificare picker Android/Windows (PDF/PNG/JPEG/TXT), file esatti 1 byte e 10MiB, file >10MiB senza read/upload, annullamento, rete interrotta fra begin/PUT/complete, 409 quota o HEAD mismatch, URL PUT/GET scaduti, 404 nota locale non ancora sincronizzata, cambio account/logout, nota nel cestino, file deletion con conferma e reinstallazione con recupero cloud. Verificare che nessun file o URL firmato compaia in .snb/outbox/log. Validare lifecycle staging, deny public access, backup bucket e cleanup degli orfani. Nessuna prova di dispositivo reale certificata dalla CI. [Specifiche](P2-NOTE-ATTACHMENTS.md).

## P2 — Auto-sync modelli Windows/Android (PR #65)

Su due installazioni loggate sullo stesso owner: creare/modificare/eliminare modelli su A, uscire dal pannello, verificare pubblicazione V13; su B avviare o tornare foreground per download. Eseguire divergenze offline e verificare che l'UI segnali conflitto senza eliminare copie; provare risoluzione manuale Pubblica/Scarica, rientro in pannello Modelli, account switch, backend V10 senza endpoint, riavvio, JSON corrotto, .snb precedente e Task/outbox invariati. Solo al termine verificare assenza di doppie pubblicazioni. Nessun collaudo device eseguito dalla CI. [Contratto](P2-AUTO-TEMPLATE-CATALOG.md).

## P2 V15 — cancellazione S3: prove fisiche differite

Dopo deploy autorizzato in un bucket privato di prova: eliminazione READY e verifica della coda, interruzione S3 e retry, crash fra DELETE e commit, due istanze concorrenti, scadenza URL firmati già emessi, controllo owner, isolamento e quota. Nessuna verifica reale è attestata dalla sola CI. [Gate V15](RELEASE-V15-READINESS.md).

## P2 V16 — collaborazione VIEWER (test post-deploy rinviati)

Dopo un rollout esplicitamente autorizzato, con **due account di prova**, verificare: segreto mostrato una sola volta; nessun token nei log o in GET; 7 giorni di TTL e revoca; impossibilità di auto-accettazione; accettazione univoca; lista e task privati mai visibili al collaboratore; owner che revoca la membership; link scaduto; perdita di rete e riconnessione. Nessuna UI Flutter per inviti disponibile in questo incremento. Non modificare dati o account reali per validarlo. [Specifica](P2-LIST-SHARING.md) · [Readiness](RELEASE-V16-READINESS.md).

## P2 Condivise — switching account (11/11)

Su Windows e Android, dopo deploy autorizzato e con due account fittizi, simulare richieste lente dell'account Alice durante logout/login Bob. Controllare che liste, token e messaggi del primo account non appaiano nel secondo; ripetere con una conferma di revoca aperta. La PR #71 include un test widget sintetico, non un collaudo reale. [Specifica](P2-LIST-SHARING.md).

## Flutter SDK pin per test successivi (11/11)

Per riprodurre la build Windows di GitHub Actions usare Flutter **3.47.9**, non lo stable più recente senza verificarne la compatibilità. Nel run con 3.50.0 la dipendenza transitiva `nativeapi 0.5.10` falliva con `Isolate.create` non disponibile. Aggiornare SDK e dipendenze insieme dopo test EXE/MSIX e APK. [Stato](CURRENT-STATUS.md).

## P2 V17 — EDITOR (prove differite)

Su due account fittizi e dispositivi di prova dopo deploy autorizzato: VIEWER sempre read-only, promozione soltanto proprietario, edit cross-owner con CAS, collisione owner/editor 409 e refresh, riconciliazione owner su Windows/Android, revoca durante edit, task fuori lista, audit senza testo, scadenze/ricorrenze e note inalterate. Nessun esperimento con dati personali live. [Specifica](P2-LIST-EDITOR.md) · [Readiness](RELEASE-V17-READINESS.md).

## P2 EDITOR — client inline Windows/Android (rinviato)

Dopo deploy V17 autorizzato: testare owner che promuove VIEWER, membro che modifica titolo/descrizione inline, priorità/completamento, cambio account durante PATCH, 409 con due dispositivi e refresh manuale, declassamento mentre l'editor è aperto, nessun task del collaboratore copiato nel database locale. Su qualsiasi errore di rete/concorrenza l'editor non deve generare una seconda write automatica. [Contratto](P2-LIST-EDITOR.md).

## P2 V17 — stato codice e prove reali (11/11)

PR #74/#75 implementano EDITOR backend e UI, ma **non costituiscono test fisici**. Resta differita la verifica con almeno due account Google e dispositivi Windows/Android, incluse revoca durante PATCH, conflitto simultaneo, autoripristino account e consistenza ledger nel proprietario, dopo deploy separatamente autorizzato. [Contratto](P2-LIST-EDITOR.md).


## Calendar OAuth V18 — test provider e dispositivi rinviati (12/11/2026)

La PR #77 aggiunge consenso separato Google Calendar/Microsoft Outlook e lettura on-demand in memoria. Restano non eseguiti i test reali con provider, tenant, refresh token e callback HTTPS su Windows/Android; nessuna credenziale è ancora attiva. Eseguire con soli calendari/account di prova dopo esplicita abilitazione. [Contratto](P2-CALENDAR-OAUTH.md) · [Readiness](RELEASE-V18-READINESS.md).


## V19 non testata su dispositivi

Servono due dispositivi con stesso account: attivazione, task datetime, refresh, ack condiviso e disconnessione; niente push OS. [Checklist](CHECKLIST-MANUALE-P2.md).
