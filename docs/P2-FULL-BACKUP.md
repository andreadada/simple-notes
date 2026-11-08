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


## P2.4B2C2 — Interlock di avvio e osservazione cloud read-only (04/11/2026)

### Blocco di avvio **reale, conservativo**

`main.dart` ora invoca `probeRestoreStartup()` **prima** di migrazione SQLite, apertura archivio e avvio di Google OAuth/AutoSync. Su Windows/Android il probe legge esclusivamente lo stato filesystem in `<ApplicationSupport>/simple-notes-recovery-v1`, senza modificare file: percorso assente = avvio normale; presenza di directory (anche vuota), file, link simbolico, marker incoerenti o errore I/O = schermata statica di recovery protetto, senza aprire il profilo. Nessun restore reale crea attualmente tale directory: installazioni esistenti non dovrebbero risentirne. Su web, che non supporta il restore SQLite nativo, si usa uno stub esplicito, senza probe filesystem.

Lo stato `RestoreSyncGate` viene iniettato nel `ProviderScope` prima di inizializzare CloudSync. `AutoSyncHost` controlla il gate sia nel pianificatore sia nella routine di invio; `CloudSync.synchronize()` rifiuta le operazioni **prima** di bind account/database e verifica ancora il gate mentre processa la coda. `resolveConflict` rifiuta l'esecuzione quando il gate è bloccato. Per compatibilità con test in-memory, un ProviderContainer fuori dal bootstrap usa il default ready: è **obbligatorio** sovrascrivere il gate nell'unico entrypoint di produzione, come fa main.dart. Il gate non concede mai permesso di restore live o replay importato.

**Limite operativo:** il check è di startup (non un lock multiprocesso), non interrompe richieste già in volo e non costituisce autorizzazione di ripristino. La rimozione/risoluzione dei marker e il recovery di SQLite + preferenze persistenti non sono implementati; con directory di recovery presente l'app deliberatamente resta bloccata per proteggere i dati. Non introdurre un restore writer senza lock esclusivo, durabilità e procedura di sblocco testata.

### Ricognizione cloud senza scritture

`RestoreCloudReadOnlyPreflight.inspect()` può leggere *solo* `GET /api/v1/sync/changes?cursor=...&limit=100` attraverso un client HTTP esplicito e token fornito dal chiamante; rifiuta endpoint HTTP pubblici, status diversi da 200, JSON/scansione non validi, paginazione stagnante, versioni regredite e scansioni oltre 100 pagine / 10.000 eventi. Non invia POST, non lega account locali e non persiste credenziali. `RestoreCloudReview.compare()` valuta la differenza tra versioni osservate, identificativi dell'outbox importata, record cloud non osservati e regressioni del cursore, mantenendo **sempre** `canWriteToCloud=false` e `canReplayOperations=false`.

**Il feed eventi non garantisce uno snapshot completo del cloud** (compattazione e possibili modifiche concorrenti). In questa fase il lettore non viene chiamato né da main né dal guard del ripristino; serviranno un protocollo server-side coerente, scope autenticato, deduplica/decisione conflitti e un rilascio controllato del blocco prima di usarlo per un restore reale.

Test aggiunti per marker mancanti/invalidi, embargo CloudSync prima di qualunque accesso DB/token, client cloud solo GET, paginazione, rifiuto errori e review senza replay. Restano differiti gli E2E fisici Windows/Android e le prove di durabilità dopo crash.


### Addendum P2.4B2C2 — Parser inventario coerente con il contratto backend P2.4B2C3

Oltre al lettore del feed eventi, `RestoreServerInventoryReader` acquisisce esplicitamente tramite GET `/api/v1/sync/inventory` l'inventario metadata-only della PR backend #34. Valida risposta completa, cursor, limiti 10k, identità uniche, versione, tombstone e changeId, rifiutando proprietà extra (es. payload), HTTP non-200, endpoint non ancora deployato o origini insicure. `RestoreServerInventoryReview` confronta outbox e versioni remote con backup target e checkpoint, segnalando revisioni sconosciute/conflittuali e cursori regrediti. I risultati **non autorizzano mai** restore o sincronizzazione importata. Il client non invoca questo endpoint durante il normale avvio; la compatibilità backend si testa con MockClient, e la VPS corrente non è stata aggiornata.


## P2.4B2C3 — Inventario cloud coerente solo lettura (04/11/2026, PR backend)

Nuovo endpoint owner-scoped `GET /api/v1/sync/inventory`: lista di versioni/deleted/changeId per ogni entità, più cursore massimo, acquisiti in transazione `REPEATABLE_READ`; **nessun payload** di note/task. Esclude altri account grazie al JWT; HTTP 413 invece di inventario parziale per più di 10.000 entità. Test Testcontainers che verificano autorizzazione, isolamento A/B, assenza di testo riservato e assenza di nuove righe sync per letture.

**Non autorizza il ripristino live.** Un inventario è puntuale, non una transazione lunga con lock di tutte le future scritture cloud; il confronto locale ha ancora bisogno di una policy di collisioni e versioni condizionali. L'API non è stata deployata e il client non la usa finché non viene verificato il contratto completo. Nessuna migrazione V11 né alterazione dei dati.


## P2.4B2D — Recovery persistente *solo su sandbox temporanea* (04/11/2026)

`DiskRestoreRehearsal` aggiunge una verifica su file fisici senza aprire un profilo installato. Il metodo di costruzione genera **soltanto una nuova directory sotto `Directory.systemTemp`**, non accetta il percorso della SQLite di produzione: `sandbox.sqlite`, `preferences.json`, `checkpoint.snb`, `target.snb` e `journal/` rimangono confinati nella directory temporanea. Un lock OS consultivo sul file `exclusive.lock` serializza gli accessi al sandbox. Lo staging conserva il checkpoint cifrato autentico (same-owner) e scrive le cinque tabelle SQLite in una singola transazione; le preferenze vengono scritte separatamente con file temporaneo, flush e rename.

I test simulano interruzioni dopo commit SQLite, sostituzione preferenze e fase verifying, quindi creano una **nuova istanza** sopra gli stessi file temporanei e applicano la compensazione da checkpoint. Simulano anche un secondo crash durante recovery (dopo marcatura, compensazione SQL, compensazione preferenze), doppio avvio, file di backup manomesso, password/account errati e journal corrotto. Dopo ogni recovery valida SQLite e preferenze direttamente da disco (inclusi outbox e tombstone), oltre alla decodifica Drift. Un nuovo crash non segna falsamente `rollbackVerified`; lo stato è riavviabile. Nessuna sync viene mai autorizzata.

**Confini importanti:** questo test dimostra la compensazione a livello di file in una sandbox controllata; non dimostra durabilità dopo power-loss, fsync della directory su Windows/Android, supporto di due engine SQLite in concorrenza, isolamento da backup automatici OS, lock portabili affidabili, recovery dell'installazione ZIP/MSIX o sicurezza del refresh OAuth. Il rename di un file già esistente e i lock hanno semantiche da verificare su piattaforme diverse. `DiskRestoreReceipt` mantiene `liveRestoreAuthorized=false`, `automaticSyncAuthorized=false` e outbox importata in quarantena. **Nessun writer viene collegato al client live, non compare un tasto «Ripristina» e non si modificano database o preferenze dell'utente.** I test fisici Windows↔Android rimangono rinviati.


## P2.4B2E — Confronto backup locale senza restore (04/11/2026, PR)

Il menu account di Flutter include una nuova voce **«Confronta backup con questo dispositivo»** (solo account Google autenticato). Apre il file `.snb`, impone il limite dimensioni dell'archivio, richiede la password nel dialog Forui già disponibile e autentica contenuto/account con `FullBackupCodec.inspect`. `FullBackupSource.capture` legge **soltanto** lo stato SQLite e le preferenze dell'account corrente, senza importare dati o scrivere nel profilo. Dopo una seconda verifica dell'account, `FullBackupCompare.preview` confronta gli snapshot validati e mostra un report locale di sole metriche.

Il report, senza titoli, body, payload, token o owner ID, mostra attività/liste/note nuove nel backup, mancanti rispetto ai dati attuali e divergenti (inclusi tombstone), operazioni pending di entrambi gli snapshot e ID di operazione in comune, preferenze differenti e cursor locale vs archivio. **Non effettua richieste API, non prova lo stato cloud né autorizza replay/cancellazione/ripristino**. La lista corrente potrebbe evolvere durante la lettura; il confronto è informativo, non un lock transazionale su SQLite+SharedPreferences. `canRestoreLive`, `canReplayImportedOutbox` e `automaticSyncAuthorized` restano sempre `false`, anche per backup identici.

Test inclusi: backup identico, precedente con note/tombstone mancanti, record solo nel backup, regressione cursor, preferenze diverse, rifiuto account e schema incompatibili, assenza di effetti sugli input e nessuna perdita di contenuti riservati nel summary. Nessuna modifica allo startup, API, VPS o modalità di sincronizzazione. Test manuali sui dispositivi fisici rinviati; i controlli CI restano gate per il merge.


## P2.4B2F — Consultazione cloud *facoltativa*, solo GET (04/11/2026, PR)

Nella schermata Forui «Confronta backup con questo dispositivo», dopo aver autenticato il file `.snb` e confrontato localmente i dati, compare il comando **«Consulta inventario cloud»**. Non è automatico e non modifica la sincronizzazione. Richiede sessione Google con access token ancora valido, stesso owner e gate recovery libero; non esegue neppure il POST di refresh token. La consultazione crea un client HTTP temporaneo ed effettua **solo** `GET /api/v1/sync/inventory` tramite `RestoreServerInventoryReader`, poi lo chiude. Rifiuta endpoint non HTTPS (salvo localhost), 404/non-200, risposte incomplete, revisioni/cursori incoerenti, payload extra e account cambiato prima di mostrare l'esito. In caso di API non ancora deployata, mostra un errore generico senza cambiare i dati.

`BackupCloudSafetyReviewer` confronta **tre osservazioni**: checkpoint del dispositivo, archivio importabile e inventario remoto owner-scoped. Il report contiene soltanto **conteggi**: entità backup non osservate, revisioni cloud più recenti, versioni non confrontabili, differenze dei tombstone, elementi visibili solo sul cloud, mutazioni importate in conflitto o non osservate e cloud cursor più avanzato. Non espone nomi, ID, body, payload, account o token.

**Fail-closed invariabile:** `canRestoreLive=false`, `canApplyImportedOperations=false`, `canTrustImportedCursor=false`, `canResumeAutoSync=false`, anche quando tutte le versioni coincidono. Un inventario è una vista puntuale e potrebbe omettere dati mai presenti nel ledger; non autorizza scritture né garantisce assenza di aggiornamenti concorrenti. L'intero flusso è visualizzazione *read-only*, senza nuovo endpoint e senza deploy. Test per owner differente, tombstone, versioni nuove, cursori impossibili, ID non osservati, dati sensibili e immutabilità input; E2E fisici ancora rinviati.


## P2.4B2G — Matrice di riconciliazione e simulazione strategie (04/11/2026, PR)

`ReconciliationDryRunPlanner.preview` analizza in memoria tre osservazioni già validate: snapshot locale, backup `.snb` autenticato dello stesso owner e inventario cloud GET-only. Usa l'unione degli ID di note, task e liste presenti nei tre insiemi, compresi gli ID citati dalle code di operazioni, e produce **solo conteggi**. Ogni entità può avere più rischi indipendenti: non osservata nel registro cloud, assente nel backup o nel dispositivo, presente solo sul cloud, contenuto locale differente dal backup, tombstone in conflitto, versione remota maggiore/minore oppure non verificabile, mutazioni pendenti in una delle due outbox. Il report distingue `totalEntities`, `entitiesNeedingReview`, `observedEntities` e il conteggio di ogni rischio; non espone ID, titoli, body, payload, password o token.

Nel dialog Forui di confronto backup, dopo aver premuto «Consulta inventario cloud», è mostrata anche la simulazione. Il pulsante «Simula altra strategia» fa ruotare **quattro preferenze puramente ipotetiche**: rimanda decisioni, conserva dispositivo, preferisci backup, preferisci cloud. Non seleziona record, non costruisce richieste API, non salva preferenze e non cancella o modifica nulla. Se il backend non risponde o l'account cambia, non si crea alcun piano. Il digest SHA-256 `sourceFingerprint` lega una *bozza locale* ai dati e alle versioni consultate, ma **non** è una firma né una prenotazione del server e non appare nell'interfaccia.

**Gate inderogabili:** `canRestoreLive=false`, `canWriteToCloud=false`, `canReplayImportedOutbox=false`, `canResumeAutoSync=false` e `isExecutable=false` per tutte le strategie, **anche senza rischi rilevati**. Un inventario può essere incompleto e cambiare subito dopo il GET; le vecchie mutazioni non sono mai autorizzate al replay. Per l'applicazione reale servono ancora protocollo CAS/snapshot server-side atomico, consenso record per record, lock multiprocesso e recovery persistente sui file installati con garanzie OS. Test: dati uguali, divergenti, tombstone, ID solo cloud/locali, versioni, outbox, autenticazione owner, digest, immutabilità e privacy; test fisici rinviati.


## P2.4B2H — Scheda di revisione per entità (04/11/2026, PR)

Il nuovo `ReconciliationWorksheetBuilder.preview` costruisce una scheda temporanea **solo dopo** la verifica del backup stesso-account e dopo la consultazione cloud opt-in. Include soltanto entità note/task/liste con indizi di divergenza (assenza in una sorgente, versione/tombstone differenti, contenuto diverso o mutazione locale/importata in coda). Se la vista richiede più di 500 elementi, blocca la scheda dettagliata senza troncarla: resta utilizzabile il report aggregato del planner. Ogni elemento viene riferito internamente tramite un token opaco SHA-256 dipendente dal fingerprint delle tre sorgenti, mai tramite il vero ID nel riepilogo.

L'utente apre «Esamina conflitti» dal confronto Forui ed esamina **in locale** tipo e titolo degli elementi, presenza su dispositivo/backup/inventario cloud e una scelta *ipotetica*: non deciso, preserva dispositivo, backup o cloud. Le origini mancanti non sono selezionabili. Il pulsante «Cambia» alterna solo le opzioni in memoria; chiudendo la scheda le scelte vengono scartate. Il dialog mantiene anche la simulazione aggregata delle quattro strategie, senza nuove GET/POST. Se l'account è cambiato prima di aprire la scheda, i dati di revisione sono invalidati.

**Privacy:** i titoli sono visibili **solo nel dialog locale autenticato**, mai nel report riassuntivo, in log, richieste API, token opachi o documentazione; non vengono mostrati i body delle note o payload. **Sicurezza:** `canRestoreLive=false`, `canWriteCloud=false`, `canReplayImportedOutbox=false`, `canResumeAutoSync=false`, `isExecutable=false` qualunque scelta venga simulata, anche con 0 conflitti. `isBoundTo()` richiede stesso fingerprint delle osservazioni; aggiornamenti locali o remote invalidano la bozza. Nessun dato o scelta persistito, nessun endpoint nuovo, backup applicato o deploy.

Test coprono bozza vuota, scelte per elemento, sorgenti non disponibili, token falsificati, cambiamento fingerprint, owner differente, limite 500, immutabilità e assenza PII nel summary. I test fisici e il reale workflow di consenso/applicazione rimangono differiti.

**Raffinamento UX:** `DraftConflictItem.warnings` mantiene motivi descrittivi per ogni record (assenza, cambiamento di contenuto, versione cloud non allineata, tombstone discordante o mutazione pendente). Sono stringhe fisse senza testo delle note/ID; la lista Forui mostra i motivi sotto il titolo solo nel dialog aperto dall'utente. Le scelte restano esclusivamente ipotetiche.

## P2.4B2I — Gate API per la riconciliazione (05/11/2026)

Backend: `POST /api/v1/sync/reconciliation/check` confronta una versione attesa del cursore e fino a 100 revisioni per entità con uno snapshot coerente e **soltanto in lettura**, protetto dallo scope JWT. Segnala match/versioni/tombstone senza esporre contenuto privato. La compatibilità e le forme incomplete/malformate vengono rifiutate.

Per qualunque nuova scrittura del normale `/sync/apply` è ora possibile fornire `expectedAccountCursor`: il controllo avviene sotto lock dell'account, prima di nuove mutazioni; stato cambiato = 409 e **nessun effetto**. Anche le singole `expectedVersion` rimangono rilevanti. Test integrati per owner distinti, revisioni assenti, idempotenza e due scritture concorrenti con una sola ammessa.

**Non è restore live:** il check non prenota il cloud, non equivale al consenso, non fa il backup SQLite, non consente di applicare un worksheet, non rigioca code importate. Restano obbligatori lock/durabilità del profilo installato, riconciliazione item-specific e consenso formale. Nessuna migrazione PostgreSQL o deploy Coolify.

## P2.4B2J — Ricontrollo remoto facoltativo dal dialog backup (05/11/2026, PR)

Nel dialog Forui di confronto .snb, dopo «Consulta inventario cloud», compare «Ricontrolla revisioni». Solo su click e con owner invariato, access token non scaduto e recovery gate libero, il client invia una **POST read-only** con revisioni e cursore attesi a `/api/v1/sync/reconciliation/check`. Non invia nota/body/payload/password, non esegue refresh delle credenziali e non chiama `/sync/apply`. La risposta viene verificata integralmente (metadata-only, shape e corrispondenza ID/versione/tombstone/cursor); riepilogo soltanto numerico.

Se il server rileva revisione/cursore differente, il client invalida inventario, worksheet e piano di riconciliazione precedente: serve nuova consultazione cloud. Se HTTP 404/401/409, token scaduto, formato errato oppure inventario >100 entità, **fallisce chiuso** e non effettua alcuna modifica. Anche quando `consistent=true`, la verifica non blocca scritture concorrenti future e **non** sblocca restore, applicazione delle scelte, replay dell'outbox o AutoSync.

Test MockClient: una POST metadata-only, risposta coerente, variazioni di versione/cursor, payload extra non previsti, ID diversi, 404, HTTPS, limiti 100 e token assente. Nessun deploy Coolify e nessun restore reale.


## P2.4B2K — Guardia di coerenza materiale (05/11/2026, PR)

Il controllo read-only delle revisioni sul backend ora verifica in uno stesso snapshot PostgreSQL anche che la **riga corrente** sia coerente col latest event del ledger. Se le API legacy hanno creato una nota non presente nel log, cambiato il numero di versione oppure cancellato un'entità senza appendere un evento, la consultazione restituisce 409 invece di un falso esito di sicurezza. Dati di un altro account sono filtrati dal JWT e non devono emergere nel confronto. Test Testcontainers sulle tre condizioni, più isolamento owner.

**Limite fondamentale:** versione/tombstone coerenti non provano uguaglianza dei payload, né assenza di dati legacy non richiesti o di una race successiva. Il risultato continua a non autorizzare un restore, un upload o il replay di operazioni importate. Non sono state introdotte nuove scritture, migrazioni o azioni su produzione.


## P2.4B2L — Preflight completo dell'account prima delle scelte (05/11/2026)

Per evitare falsi “coerente” quando una vecchia API crea/aggiorna una nota o task non presente nel ledger, il server controlla ora **tutte** le righe note/task/liste dello stesso owner, anche quelle non selezionate per la revisione. Rifiuta una riga non tracciata, una versione o tombstone differente e un latest event attivo senza riga. Il delete sintetico già previsto dal protocollo non viene classificato come errore. Il client B2J già tratta HTTP 409 come ricontrollo non riuscito e scarta la scheda di revisione.

**Non è un controllo transazionale futuro:** il check non è un lease e le API legacy possono ancora cambiare il database dopo la risposta. Nessuna lettura dei body e nessun ripristino live, CAS aggiuntivo, schema DB o deploy è stato introdotto. Test Testcontainers owner isolati, note e task non elencati, riga materializzata mancante e tombstone sintetico.


## P2.4B2M — Eliminato il bypass dei nuovi write legacy (05/11/2026)

Le API REST storiche di note/task non possono più modificare direttamente righe senza emettere un evento sync: chiamano il percorso canonico `SyncService.apply` nella stessa transazione owner-locked. Il lock viene ottenuto prima di leggere versioni per update/delete/completion; il CAS del cursore vede anche gli update legacy, i conflitti di versione risultano 409 e i tombstone sono tracciati. Il completamento legacy di task con scadenze avanzate preserva tutte le proprietà moderne; l'editor vecchio continua a rifiutare modifiche unsafe su scadenze civili (426).

Test di integrazione PostgreSQL coprono note create/modificate/cancellate via REST, task CRUD/complete, campi `due`/recurrence preservati, CAS obsoleto e race fra vecchio PUT e sync/apply. I test fail-closed già esistenti simulano ora bypass diretti SQL per mantenere coperti anche i dati storici incoerenti.

**Non è restore live**: non ripara automaticamente dati legacy già presenti, non cancella outbox e non sblocca importazione. Nessun deploy, reset o migrazione.


## P2.4B2N — Inventario cloud rigoroso (05/11/2026)

Per evitare che Flutter mostri una situazione rassicurante derivata da un registro di sincronizzazione incompleto, l'endpoint inventory GET **rifiuta l'intero account** con 409 quando note/task/liste reali divergono dal latest ledger. L'audit è owner-scoped, read-only, nel medesimo snapshot PostgreSQL, ed è riutilizzato dal preflight versione. Test PostgreSQL coprono nota legacy fuori inventario, differenze di versione, riga attiva mancante, account altrui isolato, REST legacy ora tracciato e tombstone sintetico. Non c'è auto-correzione né modifica dei dati.

Questa protezione non autorizza restore/replay: serve solo a non fornire un inventario falso. Non distribuita su Coolify in questa sessione.


## P2.4B2O — Sicurezza contro operation ID riutilizzati (05/11/2026)

Per prevenire falsi ACK, il server lega ciascuna **nuova** mutazione a un'impronta dell'intento (action, expectedVersion, entityId/type, payload JSON in ordine canonico). Uno stesso operation ID con contenuto diverso restituisce 409 anche se owner e ID entità corrispondono; nessuna nuova scrittura. I retry esatti restano idempotenti dopo l'avanzamento del cursore. I dati precedenti non vengono cancellati né reinterpretati: la nuova colonna nullable di Flyway V11 è inizialmente NULL per le operazioni storiche e mantiene la precedente compatibilità.

Test Testcontainers includono payload cambiato, versioni/azioni diverse, campi JSON riordinati inclusi nested objects, cursore cambiato, record storici senza fingerprint e richieste concorrenti sul medesimo operation ID. Questo non autorizza restore live, approvazione dei conflitti o reinvio delle vecchie code: servono ancora consenso e controlli CAS/durabilità. Nessun deploy DB o Coolify eseguito.


## P2.4B2Q — Un operation ID già committato non si reinterpreta

La protezione fingerprint V11 dispone ora di un HTTP 409 machine-readable per il riuso con intento differente. Il client blocca il sync e non mostra la risoluzione ordinaria di conflitti, preservando il DB locale e le outbox. Un risultato di preflight positivo **non** autorizza a trattare tale codice come un rebase sicuro né a forzare il restore. [Dettagli](P2-SYNC-INTENT-CONFLICTS.md).

## P2.4B2R — No release PASS con backend V10 e DB V11

Oltre a verificare la colonna V11, la release readiness richiede che l'API autenticata annunci `syncOperationFingerprintSchema=1`. La capability è sola lettura: né la sua presenza né il PASS del gate autorizzano il restore live o il replay di una outbox importata. La versione backend distribuita dovrà comunque essere provata separatamente e la UI non si abilita da questo flag. [Runbook](RELEASE-V11-READINESS.md).

## P2.4B2S — Rifiuto delle revisioni locali obsolete (06/11/2026)

Il confronto backup/cloud ora lega la bozza a uno **snapshot del dispositivo** e lo ricontrolla in sola lettura prima e dopo ogni richiesta remota esplicita (GET inventario e POST di preflight non mutante), oltre che prima di mostrare o modificare una simulazione per-entità. `BackupReviewSnapshotGuard` valida due snapshot owner-scoped e confronta un digest canonico SHA-256 delle cinque tabelle SQLite V8 (incluse tombstone, outbox e cursor) e delle preferenze, ordinando i record per chiave. Esclude solo l'ora di cattura, che non rappresenta una modifica ai dati. Account diverso, dati/tema/cursor/outbox cambiati o snapshot non valido causano invalidazione senza scritture.

Questa protezione **non blocca le scritture concorrenti**: SQLite e SharedPreferences non formano una transazione comune, e una modifica può avvenire subito dopo il controllo. Non è una prova di stabilità cloud, una firma persistente, un consenso, un lease o una procedura di restore. In caso di invalidazione si deve **chiudere e ripetere il confronto**; nessun replay delle operazioni importate, riavvio AutoSync o restore live è abilitato. Test unitari coprono timestamp/ordine irrilevanti, variazioni dei dati, cursor, outbox, account, preferenze e input malformato.

## P2.4B2T — Ricevuta informativa delle scelte e del preflight (06/11/2026)

Una nuova `ReconciliationReviewReceiptBuilder` combina in **sola lettura** snapshot autenticati dello stesso owner, worksheet di revisione e risultato dell'esplicito preflight cloud. Verifica che il worksheet sia ancora legato al fingerprint delle tre sorgenti, che tutte le scelte siano state esaminate e che il preflight copra **l'intero inventario ammesso (1–100 entità)** con cursore e revisioni coerenti. Inventario vuoto, troppo grande, preflight assente/parziale, sorgenti mutate o account diverso **non** costituiscono una revisione completata.

Il dialog mostra soltanto un riepilogo senza owner, ID, titoli, body, password, token o payload, aggiornato dopo inventory, preflight e scelta per entità. Se la sessione cambia o uno snapshot è stantio, scarta ricevuta e opzioni; il sottodialog restituisce le scelte **solo in memoria**, mai a SQLite, API o preferenze. **`reviewComplete=true` indica esclusivamente completamento della revisione informativa**: non è un consenso scrivente, un lease cloud, né abilita restore, sincronizzazione o replay di operation ID importati. L'outbox importata rimane in quarantena anche se il report è coerente. Test puri coprono mancate scelte, versioni/cursori cambiati, batch parziali, owner errato e privacy del riepilogo. Nessun deploy, migrazione o dato installato viene modificato.

## P2.4B2U — Orchestrazione sandbox con consenso monouso (06/11/2026, PR)

`SandboxRestoreOrchestrator` orchestra `prepare → applyTargetForTest → recoverAfterColdStart` **solo su directory OS temporanea generata da `DiskRestoreRehearsal.create()`**; non accetta path di produzione, non è importato da `main.dart`, startup o CloudSync. Lavora su SQLite e preferenze sacrificabili, verifica rollback persistente al checkpoint originale, non adotta il target e non rilascia la coda importata.

`SandboxRestoreConsent.confirm` richiede la frase esatta `SIMULA RIPRISTINO` e conferma indipendente sia della sostituzione locale simulata sia della quarantena outbox. Il consenso è **solo in RAM e monouso**, legato a hash domain-separated dell'owner e SHA-256 di entrambi i ciphertext: viene consumato **prima** di qualunque scrittura. Account, byte o password errati rifiutano il flusso, senza autorizzare la produzione. Recovery dopo interruzione può ripartire sul journal di prova senza un secondo consenso; i test coprono crash durante commit SQLite, sostituzione preferenze, verifica e rollback multiplo.

Ogni risultato mantiene `canRestoreLive=false`, `canWriteCloud=false`, `canReplayImportedOutbox=false`, `canResumeAutoSync=false`. **Non** è un writer reale: mancano fsync directory cross-platform, lock robusto fra processi, atomicità coordinata SQLite/SharedPreferences, recovery startup operativo, isolamento permanente outbox e prove fisiche. Nessuna migrazione, deploy o modifica cloud.

## P2.4B2V — Lease cooperativo e journal fail-closed nella sola sandbox (08/11/2026)

`SandboxRestoreFileLease` sostituisce il semplice lock interno di `DiskRestoreRehearsal`: rifiuta directory sandbox non temporanee, tipi non regolari e contenuto inatteso del lock, usa `RandomAccessFile.lock(FileLock.exclusive)` **non bloccante** per i processi cooperanti e una guardia per le invocazioni concorrenti nello stesso isolate. Il file `exclusive.lock` resta sul disco dopo il rilascio; non viene cancellato per evitare che una seconda istanza acquisisca un inode diverso. L'operazione di preparazione ricontrolla la directory sotto il lock. SQLite e preferenze rifiutano link simbolici prima dell'apertura; nessun percorso del profilo installato è configurabile.

`FileRestoreJournal.read` e `append` rifiutano la sostituzione della directory journal con link/file e, dopo rename di un marker, eseguono un **read-back integrale della sequenza** per confermarne fase, hash e contatore. File temporanei orfani, transizioni vietate, sequenze mancanti e contenuti alterati rimangono fail-closed. I test includono concorrenza nello stesso isolate, un **secondo processo Dart** che detiene il lock, link simbolici malevoli (Linux), crash e ripresa del rollback. La CI Linux esegue i test ordinari; Windows esegue esplicitamente anche i test del lease.

**Limitazione fondamentale:** `FileLock` è cooperativo/advisory e non coordina writer non partecipanti; controlli tipo/path non eliminano tutte le race TOCTOU o gli hardlink. `flush + rename + read-back` **non garantisce fsync della directory padre né persistenza dopo perdita di alimentazione**. Non è una transazione atomica SQLite+SharedPreferences e non certifica Android/Windows reali. Questa fase rimane **solo sandbox test**: restore live, upload, replay delle mutation importate e riattivazione AutoSync sempre disabilitati.

## P2.4B2W — Gate isolate e fsync directory Linux *solo in sandbox* (08/11/2026, PR)

La nuova registrazione atomica cooperativa `IsolateNameServer` nel lease impedisce che isolate Flutter distinti nello **stesso processo** riutilizzino in parallelo la stessa directory di prova; resta presente il lock OS non bloccante per processi separati. La chiave del claim deriva dal digest SHA-256 del percorso della sandbox e viene rimossa al rilascio. Il meccanismo **non** blocca writer esterni che ignorano il lease né rappresenta una barriera di sicurezza contro codice ostile.

`PosixSandboxDirectorySync` usa via FFI `opendir/dirfd/fsync/closedir` **solo su Linux**. `FileRestoreJournal` permette un `RecoveryDirectoryBarrier` opzionale: prima di un primo marker sincronizza la directory padre dopo la creazione della directory journal; dopo `flush + rename` sincronizza la directory journal e ne ricontrolla integralmente il contenuto. Le esercitazioni Linux usano tale barriera anche dopo creazione degli archivi di prova e rename delle preferenze. Se una barriera richiesta non è supportata, l'append fallisce **prima della scrittura**. Su Windows/Android la sandbox mantiene la modalità non attestata e continua a non autorizzare restore.

Test: contesa tra isolate/processi, barriere iniettate che falliscono prima/dopo rename, fsync Linux reale e fallback unsupported, recovery dopo crash. **Non è una prova di power loss** su hardware reale e non risolve transazione SQLite+preferenze, sync dei volumi Android/Windows, race su hardlink/path o writer non cooperanti. Vietato estendere a produzione senza un nuovo gate e collaudi dedicati. Runbook: [P2-RESTORE-DURABILITY.md](P2-RESTORE-DURABILITY.md).
