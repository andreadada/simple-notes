# P2.4B1 — Backup cifrato del profilo e verifica non distruttiva

**Stato 03/11/2026:** integrata su `main` con [PR #28](https://github.com/andreadada/simple-notes/pull/28), Flutter `0.31.0+33`. [Flutter CI #41636993011](https://github.com/andreadada/simple-notes/actions/runs/41636993011) **success** (204 test, Windows EXE/MSIX, Android JDK17/21), [Markdown #41636993004](https://github.com/andreadada/simple-notes/actions/runs/41636993004) **success**. **Il ripristino live NON è implementato né abilitato** (P2.4B2); test real-device rinviati.

## Perché due fasi

La P2.1 JSON portabile e la P2.4A CSV non conservano SQLite completo, tombstone, ID operazioni della outbox, versioni remote, cursor, cestino o preferenze locali. Non sono strumenti di restore. **Ripristinare su un database già sincronizzato può inviare nuovamente modifiche obsolete o sovrascrivere dati cloud**: non è accettabile un pulsante «Ripristina» che scriva queste informazioni mentre auto-sync, sessione Google e UI sono attive. Questa prima fase realizza l'**archivio completo dei dati locali** e la sua **verifica cifrata su profilo corretto**, senza funzioni di restore scriventi.

## Flusso utente (P2.4B1)

Dal menu profilo, solo dopo aver effettuato l'accesso Google:

1. **Crea backup cifrato** apre dialog Forui con password e conferma password (minimo 12 caratteri); il contenuto viene acquisito dallo snapshot SQLite e dalle preferenze per owner; il file `simple-notes-backup-YYYY-MM-DD.snb` viene salvato tramite Salva con nome su Windows o condivisione di sistema su Android.
2. **Verifica backup** apre un file `.snb` (limite 25 MiB), richiede la password, autentica l'archivio e verifica account/schemi/tabelle/colonne/preferenze. La preview mostra data UTC, conteggi di task, liste, note incluse quelle nel cestino, operazioni pendenti e numero delle preferenze locali.
3. La preview conclude **«Nessun dato ripristinato o modificato»**. Non esiste pulsante di import/ripristino `.snb`, né autocaricamento, estrazione in cartelle locali, contatto con backend o inserimento automatico in SQLite.

Se la password è errata, l'account è diverso, il file è corrotto o la versione non è supportata, il controllo si ferma con errore generico e nessuna modifica. Le password non vengono salvate su SQLite, SharedPreferences, file separati, log o backend. È responsabilità dell'utente custodire la password: **password dimenticata = backup non decifrabile**.

## Contenuti, consenso e limiti

Il payload **dentro la cifratura** include:
- SQLite Drift schema **V8**: **tutte** le righe delle tabelle `task_entries`, `task_list_entries`, `note_entries` (cestino e tombstone incluse), `pending_mutations` (operation IDs/payload/ordine) e `sync_settings` (owner, cursor, ultimo sync). Una transazione di sola lettura garantisce coerenza dello snapshot SQLite.
- Preferenze owner-scoped `simple_notes.ics.v1.<hash>`, `simple_notes.pomodoro.v1.<hash>`, `simple_notes.habits.v1.<hash>`, `simple_notes.countdowns.v1.<hash>` e preferenza di tema locale `simple_notes.theme_mode.v1`. Sono acquisite solo le chiavi consentite (mai valori di altri account), validate con i parser di dominio prima di cifrare.
- ID dell'owner **all'interno del payload cifrato**, versione dell'archivio e istante UTC di esportazione; l'owner deve corrispondere al login corrente prima di mostrare il contenuto verificato.
- **Nessuna credenziale OAuth**: refresh token di `flutter_secure_storage`, JWT in memoria, token Google, chiavi di firma Android/MSIX e identificativi/permessi delle notifiche native non vengono esportati. Dopo un eventuale restore sicuro sarà necessario autenticarsi nuovamente. Le notifiche native vanno riconciliate, non ripristinate da serializzazioni arbitrarie.

Limitazioni:
- **Max payload JSON decifrato 16 MiB**, **file cifrato max 25 MiB**, **massimo 250.000 righe** con limite 100.000 per tabella e schema/colonne rigorosamente whitelist. Una futura migrazione Drift o un nuovo campo di sync deve aggiornare esplicitamente lo schema del backup: **vietato omettere colonne nuove silenziosamente**.
- La cattura SQLite è coerente nella sua transazione, ma **SharedPreferences non è transazionale rispetto a SQLite**. Il file è un backup coerente per sorgente, non uno snapshot globalmente atomico di tutti i componenti se l'utente modifica dati nello stesso istante. Le modifiche generate mentre il backup viene creato possono non esservi incluse: non autorizzare ancora un restore operativo.
- Non viene copiato il file SQLite grezzo/WAL; il backup è logico e portabile soltanto se il formato/protocollo di restore è supportato. Il file è **locale e cifrato**, mai caricato a Simple Notes.
- La password è tenuta in una stringa Dart fino al termine dell'operazione e quindi non garantisce cancellazione fisica immediata dalla RAM; non viene persistita.
- La preview dei conteggi non dimostra che un backup sia stato realmente ripristinato. Il collaudo reale Windows/Android resta rinviato come richiesto.

## Formato e crittografia

Envelope JSON versione 1, senza owner in chiaro:
- `format: simple-notes-full-backup`, `schema: 1`, `cipher: AES-256-GCM`, `kdf: PBKDF2-HMAC-SHA256`, `iterations: 180000`.
- Salt 16 byte casuali e nonce GCM 12 byte casuali generati con `Random.secure()`. Chiave a 256 bit derivata dalla password con PBKDF2/HMAC-SHA256; ciphertext e tag GCM 16 byte codificati Base64. AAD fissa `simple-notes-full-backup/v1`.
- All'interno dell'AEAD, payload formato 1 con `sqliteSchema: 8`, `ownerId`, `createdAtUtc`, `tables` e `preferences`.
- Il tag GCM rileva manomissioni, password errate e troncamenti. Non è necessario un checksum SHA256 aggiuntivo per attestare integrità dei contenuti cifrati. `180000` iterazioni PBKDF2 sono la policy attuale, non un parametro controllabile dall'archivio.

**Cautela:** la cifratura protegge il file a riposo, non impedisce all'utente che conosce la password di condividerne il contenuto. Non usare password deboli/riutilizzate e non conservare nello stesso luogo file e password.

## Gate automatizzati

I test `apps/flutter/test/full_backup_test.dart` verificano con SQLite in memoria e SharedPreferences mock:
- owner associato, snapshot completo di tombstone, righe attive, outbox e sync settings, senza modifiche al database;
- solo preferenze locali dell'owner, rifiuto di preferenze malformate;
- round-trip criptografico e verifica della password, del contenuto e della provenienza; nessun dato riservato nel JSON esterno;
- rifiuto di password errata, owner differente, tag manomesso, schema futuro, tabella/colonna imprevista, token OAuth infiltrati nelle preferenze;
- Flutter static analysis/unit/widget, Windows EXE/MSIX, Android JDK17/21 e Markdown links sulla stessa revisione.

Le prove fisiche save picker Windows/Android, share sheet e riapertura del file su dispositivi restano **rinviate** insieme al batch `docs/DEVICE-ACCEPTANCE-DEFERRED.md`.

## P2.4B2 — Ripristino protetto (NON ANCORA FATTO)

Prima di abilitare un restore bisogna costruire e testare:
1. Una procedura *cold-start* offline che blocchi auto-sync, session restore, timer/richieste concorrenti, UI e plugin con handle SQLite aperti; mai sostituire un file SQLite ancora aperto né intervenire su una sessione autenticata non isolata.
2. Preflight password/AES-GCM, identità Google, versione/schema, owner, dimensioni e JSON; checkpoint indipendente del database/profilo esistente, verifica reale e piano di rollback che non elimini dati originali.
3. Ripristino SQLite delle cinque tabelle **in una transazione** senza ricreare operation ID, remoto version o cursor; staging delle preferenze con compensazione in caso di errore; senza ripristinare JWT/refresh token; re-login successivo. Evitare di rispedire outbox di un altro owner o di un vecchio snapshot cloud senza conflitti espliciti.
4. Test di *restore isolato* con SQLite reale in memoria e poi su profili di prova, file corrotti, schema incompatibile, differenze di account, interruzione a metà e retry, checkpoint e rollback, percorso Windows ZIP↔MSIX e firma Android compatibile.
5. Abilitazione UI **solo dopo** completamento dei controlli e della strategia di conflitti/rollback; mai sostituire o cancellare dati attuali per «verificare» un backup.

Prossima implementazione: **P2.4B2**. Il backup del PostgreSQL server (dump + restore isolato) è **separato** da questo backup locale; nessun comando VPS/Coolify viene eseguito per P2.4B1.

[Stato](CURRENT-STATUS.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md) · [Collaudo rinviato](DEVICE-ACCEPTANCE-DEFERRED.md) · [JSON portabile](P2-PORTABLE-ARCHIVE.md).


## P2.4B2A — Primo sottostep: rehearsal isolata (branch di sviluppo)

Il primo incremento di P2.4B2 crea un controllo effettivo di ripristinabilità senza toccare l'installazione. FullBackupRestoreRehearsal autentica il file .snb (password e account tramite il codec P2.4B1), ricostruisce tutte le cinque tabelle in un nuovo SQLite in memoria, confronta gli stessi valori grezzi in ordine canonico tramite SHA-256 e verifica anche la decodifica dei modelli Drift. Un'interruzione iniettata tra tabelle verifica il rollback atomico e un retry con un nuovo sandbox. L'outbox e il cursor vengono preservati soltanto nel sandbox, mai riprodotti verso il cloud.

**Restano obbligatori prima del restore operativo:** cold-start senza AutoSyncHost, checkpoint indipendente e verificato dell'installazione, rollback SQLite e SharedPreferences, controllo anti-replay rispetto al server, test di interruzione e di migrazione pacchetto Windows ZIP/MSIX e firma Android. In questa fase nessuna preferenza, SQLite installato, sessione, VPS o dato cloud viene scritto; non esiste un nuovo pulsante per ripristinare. Il report dichiara sempre automaticSyncAuthorized=false. Test fisici rinviati su richiesta dell'utente.


## P2.4B2B1 — Checkpoint cifrato verificato su file (branch di sviluppo, 04/11/2026)

Nuovo modulo FullBackupCheckpointPreflight: prende uno snapshot già catturato e validato del profilo corrente e un FullBackupCheckpointStore; cifra il contenuto col formato .snb già supportato, richiede scrittura **di un nuovo file**, rilettura, controllo SHA-256 byte-per-byte, decifratura autenticata dello stesso owner, confronto integrale del payload e prova di ricostruzione delle cinque tabelle in SQLite in memoria. Il receipt contiene hash e conteggi, non il contenuto delle note e nessuna credenziale. Non autorizza un restore o una sync.

FileFullBackupCheckpointStore utilizza una directory dedicata fornita esplicitamente dal chiamante, un nome casuale, file temporaneo e flush prima di rename nella stessa directory, senza sovrascrivere file di checkpoint esistenti. Nessuna directory di installazione, SQLite live, file SharedPreferences o percorso ZIP/MSIX è hard-coded. I test scrivono esclusivamente su cartelle temporanee; coprono rilettura, rifiuto di overwrite, file troncato, errore del filesystem e mismatch owner. Nessun checkpoint sulla macchina dell'utente viene generato da questo incremento.

**Gate non superati:** l'implementazione non garantisce ancora fsync della directory e durabilità completa dopo crash/power loss su tutti i filesystem, né staging/compensazione SharedPreferences, rollback cross-store, cold-start con sospensione AutoSync, gestione di vecchie outbox/cursor e migrazione ZIP→MSIX. Il checkpoint **non equivale a rollback operativo**. Nessuna voce UI «Ripristina»; test fisici e deploy rinviati.


## P2.4B2B2 — Prova di rollback SQLite + preferenze (branch, 04/11/2026)

`FullBackupRollbackRehearsal` autentica **due file .snb per lo stesso account**: un checkpoint dello stato da preservare e un archivio da ripristinare. Utilizza esclusivamente una **nuova istanza SQLite in memoria** e una `Map<String, String?>` privata che simula le preferenze, senza aprire SharedPreferences reali. Lo stato del checkpoint viene caricato e confrontato prima della prova.

La sostituzione simulata delle cinque tabelle avviene in una transazione SQLite. Le preferenze, che non partecipano alla transazione SQLite, vengono modificate separatamente nel sandbox. Dopo un completamento normale o una interruzione iniettata il modulo **ripristina sempre il checkpoint nel sandbox** e verifica mediante fingerprint canonico SHA-256 l'equivalenza esatta di righe, metadati sync, outbox, tombstone e preferenze. Controlla anche la decodifica Drift. Sono presenti prove per errori dopo diverse tabelle, durante le preferenze e **dopo il commit SQLite**; password e account errati sono rifiutati prima dell'apertura dell'ambiente isolato.

**Limite essenziale:** dimostra la logica di compensazione solamente in memoria. NON prova rollback sicuro di SQLite e SharedPreferences reali, crash/power loss, lock/handle aperti, notifiche native, riavvio con storage modificato o recupero da checkpoint su filesystem. Il report riporta sempre `liveRestoreAuthorized=false` e `automaticSyncAuthorized=false`; non esiste nuovo pulsante nell'app. Test fisici Windows/Android rimangono rinviati. Prossimi gate: orchestratore cold-start offline, recovery journal e verifica anti-replay contro il cloud prima dell'abilitazione di restore live.


## P2.4B2C1 — Guardia di cold-start e anti-replay (04/11/2026, branch)

`FullBackupColdStartGuard` simula il riavvio di un processo tramite una **nuova istanza** che rilegge un registro di recupero append-only in una directory di test esplicitamente fornita. Il registro scrive solo sequenza, fase e fingerprint SHA-256 di owner/checkpoint/target, senza note, password o token. Le fasi consentite sono `prepared → staging → verifying → recoveryRequired → rollbackVerified`; da `prepared` o `staging` si può anche passare direttamente a `recoveryRequired`. Interruzioni o errori simulati mantengono il registro e sono verificati ripetendo l'avvio. File temporanei incompleti, buchi nella sequenza, modifiche ai digest, transizioni abusive, password o owner differenti causano rifiuto (fail-closed).

Prima della prova di recupero devono corrispondere SHA-256 dei due file .snb, account e decifratura autenticata AES-GCM. Il guard usa la rehearsal B2B2 per simulare il ritorno al checkpoint **in SQLite in memoria + mappa preferenze**. Anche dopo `rollbackVerified`, le modifiche `pending_mutations` e il `syncCursor` dell'archivio importato rimangono *non affidabili*: `RestoreReplayRisk` rileva conteggio outbox, operationId comuni e regressione/assenza del cursor; richiede sempre un futuro snapshot remoto autenticato e riconciliazione esplicita. Nessun report autorizza auto-sync o restore live, **anche con outbox vuota e cursori uguali**.

**Rimangono gate bloccanti:** non è integrato con startup Flutter, CloudSync/AutoSyncHost, database reali o SharedPreferences; nessun meccanismo di consenso alla riconciliazione. Il registro su filesystem è un *prototipo single-writer*, non un protocollo di produzione: senza lock multiprocesso e fsync della directory non garantisce crash/power-loss safety. Non prova recovery cross-store persistente; test locali su cartelle temporanee (nessun dato utente). Prima di abilitare restore reale servono orchestratore cold-start esclusivo/offline, WAL e file lock, checkpoint con durabilità verificata, recovery del DB e preferenze su disco, snapshot cloud aggiornato e scelta dell'utente per i conflitti. Test E2E fisici rinviati.
