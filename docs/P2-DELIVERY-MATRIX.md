# P2 — Matrice di consegna e criteri di chiusura

> **P2 12/11/2026:** la VPS Simple Notes è stata aggiornata dall'utente al backend `3c904a0`, con Flyway **V17 (17/17 migrazioni riuscite)**. La [PR #77](https://github.com/andreadada/simple-notes/pull/77) introduce Google Calendar / Outlook OAuth read-only e Flyway **V18**, in revisione e **non deployata**. Nessun provider live configurato; restano collaudi con account reali e backup/offsite da attestare. [Specifiche](P2-CALENDAR-OAUTH.md) · [Gate](RELEASE-V18-READINESS.md).

Aggiornato 11 novembre 2026. **PR #74 (backend EDITOR V17) e #75 (Flutter Forui EDITOR) integrate in `main`. CI Backend/Compose/Markdown #74 verdi e Flutter analyze/widget #75 superati; native/post-merge in verifica. CI verde non equivale a deploy Coolify o collaudo fisico.**

**Decimo incremento P2 integrato su `main` (`ed45d0e`):** [PR #65](https://github.com/andreadada/simple-notes/pull/65), sync foreground dei modelli utente V13 con checkpoint per account, CAS, risoluzione conflitti manuale e editor lock. Nessuna migrazione o modifiche alla outbox; **Merge e Flutter CI complete** ([run #42887921742](https://github.com/andreadada/simple-notes/actions/runs/42887921742): analyze/test, Windows e Android JDK17/21). [Contratto](P2-AUTO-TEMPLATE-CATALOG.md).

**Nono incremento P2 integrato su `main` (`5ae2bd3`):** [PR #64](https://github.com/andreadada/simple-notes/pull/64) porta API allegati JWT per note con presigned URL PUT/GET, HEAD/COPY e delete, V14 additiva, UI Forui e test. Bucket non configurato; **nessun deploy o rilascio**, backend CI e Flutter analyze/test verdi; build native e post-merge verdi. [Contratto](P2-NOTE-ATTACHMENTS.md).

**Ottavo incremento P2 integrato nel codice (`b9dd67a`):** [PR #63](https://github.com/andreadada/simple-notes/pull/63), catalogo manuale cloud dei modelli owner-scoped con CAS e V13. Backend/test e comandi Forui; **Merge e CI finali verdi; deploy ed E2E ancora da verificare.** [Contratto](P2-CLOUD-TEMPLATES.md).

**Settimo incremento P2 integrato in `main` (`766860c`):** [PR #62](https://github.com/andreadada/simple-notes/pull/62), sync foreground conservativa catalogo regole con checkpoint owner-scoped, revisione CAS, auto-upload/pull solo senza conflitti, stato Forui e pausa editor. **Merge e Flutter CI di PR #62 verificate**, nessun deploy o scheduler server. [Specifica](P2-AUTO-ACTION-CATALOG.md).

**Sesto incremento P2 integrato:** [PR #61](https://github.com/andreadada/simple-notes/pull/61) merged `bf16cba`, [Flutter CI #42821851199](https://github.com/andreadada/simple-notes/actions/runs/42821851199) **success** (399 test Flutter, Android JDK17/21, Windows EXE/MSIX/recovery), [Backend CI #42821851073](https://github.com/andreadada/simple-notes/actions/runs/42821851073) **success** (PostgreSQL 17 e bootJar), [Markdown CI #42821851207](https://github.com/andreadada/simple-notes/actions/runs/42821851207) **success**. Catalogo cloud JWT per owner con CAS, Flyway V12 additiva, scambio esplicito Pubblica/Scarica. **Non deployata** (VPS V10 attestata), né sync automatica o esecuzione server. [Contratto](P2-CLOUD-ACTION-CATALOG.md).

**Quinto incremento P2 integrato:** [PR #60](https://github.com/andreadada/simple-notes/pull/60) merged (`e051162`), [Flutter CI #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) **success** (392 test, analisi, Android JDK17/21, Windows EXE/MSIX e recovery), [Markdown #42714514223](https://github.com/andreadada/simple-notes/actions/runs/42714514223) **success**. Azioni task locali crea/completa con filtro titolo e priorità/tag/lista, un solo upsert/outbox. Non è uno scheduler server. [Contratto](P2-TASK-ACTIONS.md).

**Quarto incremento P2 integrato:** [PR #59](https://github.com/andreadada/simple-notes/pull/59) merged (`aa17094`), [Flutter CI #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) success (377 test e build Android/Windows), [Markdown #42701809467](https://github.com/andreadada/simple-notes/actions/runs/42701809467) success. Regole locali per notifiche native, non automazioni generaliste o delivery OS garantita. [Specifica](P2-REMINDER-AUTOMATIONS.md).

**Terzo incremento P2 integrato:** [PR #58](https://github.com/andreadada/simple-notes/pull/58), merge `e926a5a`, trasferimento manuale JSON dei modelli locali. [Flutter CI #42688444850](https://github.com/andreadada/simple-notes/actions/runs/42688444850) PASS (369 test e build Windows/Android), [Markdown #42688444618](https://github.com/andreadada/simple-notes/actions/runs/42688444618) PASS. Il file è non cifrato e non realizza la sync dei modelli o il restore live.

**Secondo batch locale integrato:** [PR #57](https://github.com/andreadada/simple-notes/pull/57), merge `90e5e26a`; [Flutter CI #42634429343](https://github.com/andreadada/simple-notes/actions/runs/42634429343) PASS (365 test, Android JDK17/21 e Windows), [Markdown #42634428206](https://github.com/andreadada/simple-notes/actions/runs/42634428206) PASS.

**Batch locale integrato:** [PR #56](https://github.com/andreadada/simple-notes/pull/56) merged (`56d40317`); [Flutter CI](https://github.com/andreadada/simple-notes/actions/runs/42625648804) PASS (350 test, Android JDK17/21, Windows), [Markdown CI](https://github.com/andreadada/simple-notes/actions/runs/42625649033) PASS. **La P2 complessiva resta aperta** sulle integrazioni elencate sotto.

La roadmap P2 include funzioni implementate, estensioni non ancora realizzate e gate operativi rinviati. Questo documento impedisce che una simulazione di backup o una compilazione vengano dichiarate ripristino o rilascio reali.

## Codice già disponibile, o sviluppato nel batch di chiusura

| Area | Implementazione | Limiti |
|---|---|---|
| P2.1 JSON portabile | Import additivo, esportazione, controllo schema | Verifica picker/share fisici rinviata |
| P2.2–2.3 ICS | File/HTTPS, ricorrenze, fonti, cache read-only | Nessun OAuth o scrittura provider |
| P2.4A CSV | Esportazione locale | Prove reali del picker pendenti |
| P2.4B1 backup cifrato | AES-GCM, verifica password/owner, confronto read-only | Nessun ripristino scrivente |
| P2.4B2 recovery | Journal, checkpoint e rollback in sandbox, preflight cloud CAS | Non è un restore sul profilo installato |
| Timeline/Gantt | Vista pianificazione a 14 giorni con blocchi e milestone civili | Nessun drag-and-drop cross-device |
| Filtri avanzati | Tag, ricerca, priorità, scadenze e ordinamento | Locali/offline, nessun nuovo endpoint |
| Statistiche | Totali, completate, arretrate, priorità, prossimi 7 giorni, tempo e liste | Fotografia dello stato, non cronologia |
| Modelli attività | Cinque preset + CRUD di modelli utente, owner-scoped locali, nuovi task tramite outbox e backup .snb compatibile | Sync foreground conservativa integrata in PR #65; server V13 non ancora deployato |
| Catalogo cloud modelli (PR #63 integrata) | Pubblica/Scarica definizioni con JWT, CAS e conferma, senza task/outbox | PR #65 integra sync foreground conservativa; V13 non deployata, no background |
| Trasferimento modelli JSON | Import/export manuale definizioni con copia additiva e conferma, nessun task/outbox creato | Non cifrato, non sostituisce la sync; prove fisiche rinviate |
| Sync automatica regole (PR #62 integrata) | Riconciliazione foreground con baseline per account, upload/download CAS e protezione modifiche offline | Non background server, conflitti richiedono conferma esplicita |
| Catalogo regole cloud (PR #61 integrata) | GET/PUT owner JWT, CAS 409, catalogo versionato, scambio manuale con conferma; 399 test Flutter e backend CI verdi | V12 non applicata in VPS; nessuna sync automatica, dedup distribuita o motore server |
| Azioni task locali (PR #60 integrata) | Evento manuale crea/completa, filtro titolo, priorità/tag/lista, editor Forui, backup opzionale; 392 test e build native verdi | No scheduler server, cataloghi non sincronizzati, E2E fisici differiti |
| Regole promemoria locali (PR #59 integrata) | Tipi due/block, anticipo e priorità, editor Forui, dedup ledger e backup opzionale | Solo OS notifiche e quando l'app aggiorna il piano; non sono automazioni server generali |

Le statistiche sono calcolate sui dati locali senza telemetria. I modelli producono normali attività e operation ID distinti nella coda di sincronizzazione. Le date civili non sono riclassificate in un'ora UTC inventata.

## Gate P2 ancora aperti — non dichiararli finiti

| Area | Che cosa manca realmente |
|---|---|
| Restore live .snb | Coordinamento SQLite/preferenze installate, lock nativo, recupero dopo power loss, consenso, quarantena e riconciliazione outbox |
| Google Calendar/Outlook | PR #77: OAuth, PKCE, token cifrati, eventi read-only e UI in branch; restano provider/consenso reale, multi-calendario, sync bidirezionale ed E2E |
| Liste condivise | ACL multiowner, ruoli, assegnazioni, audit server, migrazioni, protezioni accesso e UI |
| Allegati S3 | **Parziale in PR #64**: API owner-scoped V14, signed URL PUT/GET, quote, verifica HEAD/COPY, picker/CRUD Forui | Restano bucket/lifecycle reali, file scan, cancellazione oggetti di note eliminate, coda offline, E2E fisiche |
| Widget Android | Widget nativo Oggi/Inbox/Nuova attività compilato (Java 17/21); launcher/cold-start/logout su dispositivo fisico non verificati |
| Automazioni configurabili | **Parziale:** notifiche PR #59, azioni locali PR #60, catalogo cloud PR #61 integrati; sync conservativa foreground PR #62 integrata. Restano scheduler server, dedup multi-device, gestione manuale dei conflitti, delivery affidabile. |
| Release | VPS V11–V15 (V15 solo nel codice), OAuth Android, upgrade Windows, firma, backup/offsite, E2E Windows↔Android e controlli reali |

## Criteri per dichiarare P2 completata

- Implementato = codice e test automatici verdi; rilasciato = deploy verificato e controlli sul dispositivo dove necessari.
- Nessuna funzionalità di restore può riscrivere un database reale o rigiocare operazioni importate senza prova del recupero e consenso esplicito.
- La preflight del cloud non fornisce un lease e un confronto non è un'autorizzazione alla scrittura.
- Chiudere i requisiti con un criterio verificabile e test diretto; evitare nuove micro-fasi che aggiungono solo documentazione.

**La P2 non va marcata completata finché le righe aperte restano tali.** Il trasferimento JSON non equivale alla sincronizzazione cloud dei modelli. La CI del batch locale viene registrata in CURRENT-STATUS dopo l'esecuzione.

## Batch P2: calendario, modelli e accesso rapido Android (09/11/2026, integrato PR #57)

- Esportazione manuale ICS per task non completati: date-only senza falso timestamp, istanti UTC esatti, time block, UID stabili, escaping e folding UTF-8, limite 8 MiB.
- Modelli utente in SharedPreferences per owner: CRUD e definizioni backup compatibili con vecchi archivi .snb v1; applicazione del modello come task SQLite/outbox. Definizioni locali al dispositivo, non condivise in cloud.
- Widget Android launcher: apri Oggi, Inbox, nuova attività via MainActivity/MethodChannel, senza memorizzare/esporre contenuti. Non è un widget che mostra task, né prova hardware completata.
- Resta **non implementato nel batch #57**: collegamento OAuth automatico Google/Outlook, collaborazione ACL, allegati S3, automazioni configurabili e restore live. La successiva PR #59 copre soltanto regole di notifica locali. Il collaudo fisico del widget Android resta **non eseguito**. [Contratto](P2-LOCAL-INTEGRATIONS.md).

## Incremento V15 — cancellazione fisica S3 affidabile (PR #67 integrata)

Inserimento della chiave privata in outbox PostgreSQL e rimozione dei metadata READY nel medesimo commit, poi worker multiistanza con `SKIP LOCKED`, max 25 oggetti per ciclo e retry 5 minuti. Non cancella automaticamente gli allegati delle note nel cestino; V15 integrata in `main` con CI Backend/Compose/Markdown verdi; deploy ancora da verificare. [Contratto](P2-NOTE-ATTACHMENTS.md) · [Readiness](RELEASE-V15-READINESS.md).

## Incremento V16 integrato — fondamenta collaborazione liste (PR #69)

Una nuova API Spring JWT separata da `/sync` gestisce condivisione **VIEWER** delle liste tramite inviti casuali di 256 bit, token hashati e monouso, scadenza a sette giorni, revoca e accettazione esplicita. La vista di sola lettura espone unicamente task della lista e proprietario previsti dalla membership, massimo 50 elementi per pagina. Due tabelle additive Flyway V16 e capability `sharingReadSchema:1`. **La UI Flutter VIEWER è stata aggiunta dalla PR #70; non comprende editing EDITOR, notifiche o sync multi-owner**; non segnare collaborazione P2 conclusa. Backend integrato con CI verde; nessun deploy. [Specifica](P2-LIST-SHARING.md) · [Gate V16](RELEASE-V16-READINESS.md).

### UI collaborazione VIEWER (PR #70 integrata su `main`)

Dopo backend [PR #69](https://github.com/andreadada/simple-notes/pull/69) integrato con CI verde, il client Flutter aggiunge sezione Forui **Condivise** e API HTTP JWT per creare/copiare token, accettare, consultare pagine di task, gestire/revocare inviti e membership. **La PR #75 aggiunge modifiche EDITOR online; nessuna sync offline cross-account o storage guest**. Per usarla occorre ancora distribuire il backend (V16) e verificare su dispositivi di prova. [Contratto](P2-LIST-SHARING.md).

## Incremento EDITOR Flyway V17 — backend integrato (PR #74) (11/11/2026)

Promozione/demozione **solo owner** dei membri già accettati; patch online **solo titolo, descrizione, completamento, priorità** con CAS per-versione e controllo della membership dopo lock owner. L'operazione passa dal `SyncService.apply` canonico del proprietario, senza scrivere nel ledger dell'ospite; audit immutabile annota attore, campi e changeId senza contenuti privati. V17 additiva amplia il ruolo e aggiunge `list_share_audit`; capability `sharingEditorSchema:1`. **Flutter EDITOR integrata con PR #75; mancano merge automatico, notifiche e sync offline multi-owner**. Backend CI e merge verdi, nessun deploy. [Specifica](P2-LIST-EDITOR.md) · [Readiness](RELEASE-V17-READINESS.md).

### Client Forui EDITOR (PR #75 integrata, 11/11)

Nuova vista di lista ricevuta con indicazione EDITOR, campi titolo/descrizione modificabili **inline** su selezione del task, comandi di completamento e priorità e salvataggio via PATCH HTTPS/JWT con versione prevista. Gestione esplicita owner-only dei ruoli in Forui con conferma di elevazione; 409 richiede refresh manuale, nessun retry distruttivo. Non si inseriscono task ospiti in Drift/outbox o backup del proprietario. Test API e widget superati; build native e post-merge da verificare, nessun deploy. [Specifica](P2-LIST-EDITOR.md).


## OAuth provider V18 — PR #77 (12/11/2026)

Code review in corso: prima integrazione Google Calendar/Outlook read-only con state monouso, grant separato, token AES-GCM, Flutter Forui e lettura manuale in memoria. Backend V18 non ancora deployato né configurato; non chiude la P2. [Contratto](P2-CALENDAR-OAUTH.md) · [Readiness](RELEASE-V18-READINESS.md).
