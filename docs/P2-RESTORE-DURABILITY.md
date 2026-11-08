# P2.4B2W — Durabilità e contesa del recovery in sandbox

Aggiornato: 8 novembre 2026. **Ambito esclusivo: test su filesystem OS temporaneo. Nessun restore live o consenso di produzione.**

## Problema e separazione delle garanzie

`RandomAccessFile.lock` è un lock **advisory** tra processi cooperanti. Una variabile `static` protegge un singolo isolate Dart, ma **non è condivisa fra isolate**. Inoltre, `File.writeAsBytes(flush: true)` può forzare il contenuto del file senza forzare l'entry creata da `rename` nella directory. Infine SQLite e preferenze sono due storage separati e non costituiscono un'unica transazione.

Il lavoro P2.4B2W introduce tre verifiche indipendenti:

| Livello | Controllo nella sandbox | Non garantisce |
|---|---|---|
| Accesso concorrente | Claim atomico cooperativo `IsolateNameServer` con chiave SHA-256 del path + lock OS esistente e guardia intra-isolate | Esclusione di writer che ignorano lock; isolati in engine diversi con API non condivisa; difesa da processi malevoli |
| Persistenza marker Linux | `opendir → dirfd → fsync → closedir` tramite libc Linux; sync parent dopo creazione journal e sync journal dopo rename marker; sync sandbox dopo creazione backup e sostituzione preferenze | Atomicità dei due store; semantica storage su tutti i filesystem; power-loss su device reale |
| Piattaforme non attestate | `UnavailableRecoveryDirectoryBarrier` rifiuta `append` **prima di scrivere**, se richiede una durabilità che non è disponibile. L'esercitazione Windows/Android resta esplicitamente non-durabile | Falso esito PASS di fsync Windows/Android |

## Sequenza della barriera su Linux

1. Richiedere lock sandbox; esaminare tipo directory e controllo isolate globale. Nessuna operazione sul profilo reale.
2. Autenticare gli archivi AES-GCM con l'account previsto; preparare checkpoint su storage di prova.
3. All'append di un primo journal, creare la directory e chiamare `fsync` sulla sua **directory padre**.
4. Scrivere il marker in file temporaneo con `flush`, rinominarlo nello stesso filesystem, chiamare `fsync` sulla **directory journal**, quindi rileggere e convalidare tutta la sequenza.
5. Se una delle barriere fallisce, **l'append fallisce**. Il file marker potrebbe già esistere ma **non è attestato** come durevole; non proseguire con lo staging. Il cold-start deve leggere e valutare lo stato senza normalizzazioni silenziose.
6. Anche dopo rollback verificato il flusso non concede `canRestoreLive`, `canWriteCloud`, `canReplayImportedOutbox` né `canResumeAutoSync`.

Il codice Linux usa funzioni POSIX con firma non-variadica da `libc.so.6` ed è chiamato **solo quando `Platform.isLinux`**. Non è usato in `main.dart`, nello startup gate, nel flusso OAuth o nell'API.

## Prove automatizzate

- `sandbox_restore_file_lease_test.dart`: contesa intra-isolate, **due isolate nello stesso processo Flutter**, processo Dart separato, cleanup e successiva riacquisizione.
- `recovery_directory_barrier_test.dart`: rifiuto preventivo dei sistemi unsupported; ordine dei sync parent/marker; errore prima o dopo il rename; fsync nativo Linux della directory; rifiuto di directory inesistente.
- `full_backup_disk_recovery_rehearsal_test.dart`: write/rollback SQLite e preferenze, crash/recovery ripetuti, file sospetti, ripristino solo checkpoint.
- Windows CI esegue il test di fallback *non attestato* assieme al lock; Linux CI esercita la barriera POSIX; Android CI compila entrambi i target JDK 17/21.

## Gate non soddisfatti — vietato restore live

- **Durabilità dopo vero power loss:** fsync su Linux è solo una barriera OS; serve prova di filesystem, volume e alimentazione sui dispositivi effettivi, WAL/SQLite, preferenze e directory dei backup.
- **Atomica cross-store:** una transazione SQLite non include SharedPreferences. È necessario uno schema con staging, recovery verificabile e interlock di startup in produzione.
- **Concorrenza non cooperativa:** l'API IsolateNameServer protegge solo isolate che partecipano; un processo o plugin che scrive senza lock può cambiare i dati dopo il controllo.
- **Hardlink, symlink e TOCTOU:** controlli sui path non costituiscono un sandbox nativo di sicurezza. Un writer di produzione richiederà handle OS e protezioni dedicate.
- **Portabilità:** `opendir/dirfd/fsync` Linux non è un'implementazione Windows o Android. Nessuna etichetta *durable* dev'essere inferita dalle simulazioni su quelle piattaforme.
- **Prod data:** nessuna migrazione, aggiornamento Coolify, cambio account, replay di `pending_mutations`, restore installato o sblocco di AutoSync è autorizzato da questo lavoro.
