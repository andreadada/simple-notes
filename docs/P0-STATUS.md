# P0 — Stato verificabile e piano di chiusura

## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](T4-DEVICE-SYNC.md).


## T4.1 — Inventario database preparato

`infra/t4-inspect-db.sh` ispeziona il container del database selezionato **solo con query SELECT**: verifica PostgreSQL 17, schema Simple Notes, stato Flyway e colonne delle nuove scadenze. CI sintetica include casi di identità sbagliata. `t4-preflight.sh` ora blocca ricevute di ripristino con verifica più vecchia di 24 ore (configurabile fino a sette giorni). Inventario reale VPS, backup SHA256 e restore isolato **già eseguiti il 24/10**; API e test hardware ancora non verificati. T4 resta aperto. [Runbook](T4-RELEASE-RUNBOOK.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Scadenze Forui, IANA e DST (24/10/2026)

**Implementato nel codice su main, non distribuito.** Un unico editor `ui/task_due_editor.dart` gestisce scadenze solo-giorno e data/ora, calendario Forui, HH:mm, fuso IANA e scelta esplicita delle due occorrenze in un cambio d'ora. Gli orari inesistenti sono rifiutati, la mezzanotte scelta rimane `datetime`, e le scadenze `legacy` non sono reinterpretate in automatico. Il fuso OS viene rilevato se disponibile, altrimenti richiesto esplicitamente.

`data/task_due_clock.dart` usa `timezone ^0.11.2` e `flutter_timezone ^5.1.0`; `data/task_due_view.dart` presenta label e filtri Oggi/7 giorni secondo **giorni civili**, evitando il calcolo sbagliato di 168 ore attorno all'ora legale. Aggiunta rapida, dettagli ed editor avanzato salvano `TaskDue` con SQLite/outbox; una rinomina non muta `date/datetime` in `legacy`. Test per gap/fold, visualizzazione, filtri e modifica avanzata. **V7 già verificata sul database reale**, backup SHA256 e restore isolato PASS. Mancano capability API `taskDueSchema:1` e prove Windows/Android; non ripetere deploy senza un'incompatibilità accertata. Ricorrenze, notifiche e browser web restano fuori da T3.

Dettagli e checklist: [specifica T3](T3-SCADENZE.md). CI: [Flutter Actions](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml).


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

> **Aggiornato il 23 ottobre 2026.** Questo documento è la fonte aggiornata per P0 (e prevale su dichiarazioni storiche obsolete nel vecchio handoff). I check manuali sono distinti da test automatici e da attività che richiedono accesso a un telefono o a Coolify.

## Verificato

- Backend Spring Boot, PostgreSQL/Flyway e /actuator/health HTTPS sono operativi secondo la verifica dell'utente.
- Login Google Windows confermato, Android in uso con **lo stesso account** del PC.
- **Note sincronizzate realmente PC ↔ Android**: confermato dall'utente.
- **Attività create da telefono visualizzate su Windows**: confermato dall'utente. Completamento, cancellazione e conflitti su dispositivi reali ancora da provare.
- Sync foreground implementata: modifiche locali, accesso/ripristino sessione, riconnessione e ritorno in primo piano, pull ogni 60 secondi. Outbox in SQLite persistente.
- Forui è il design system principale; editor attività/nota e calendario migrati a dialog Forui. CI precedente dei modali [39977182371](https://github.com/andreadada/simple-notes/actions/runs/39977182371) riuscita.

## Implementato in questo incremento (richiede nuova verifica sul dispositivo)

1. **Conflitti di sincronizzazione**: `GET /api/v1/sync/latest?entityType=note&entityId=UUID` legge soltanto il change log dell'utente JWT corrente, inclusi tombstone. Nuovo indice Flyway `V5__sync_conflict_latest_index.sql`.
2. Il client conserva le modifiche in coda su HTTP 409, recupera le due versioni e presenta un **FDialog Forui** raggiungibile dal menu avatar con *Tieni locale* oppure *Usa server*. Quest'ultima richiede una **seconda conferma** ed elimina soltanto le operazioni in coda dell'elemento in conflitto. La versione server viene letta di nuovo prima di risolvere: una modifica successiva riapre il conflitto.
3. **Protezione contro dati persi**: scelta locale ricalcola l'expectedVersion prima di inviare; se l'elemento remoto è stato eliminato non viene forzata una creazione sulla stessa UUID. Non vengono azzerati il DB, la coda globale o l'account. Il limite sul recupero di una cancellazione concorrente resta aperto (serve duplicazione/recupero in una nuova entità).
4. **Descrizione attività**, dal dialog Forui fino a SQLite/outbox/backend, con migrazione locale Drift `schemaVersion 3`. Il server già memorizza `description`; il contratto esistente continua a funzionare con i vecchi client.
5. **Backup PostgreSQL**: `infra/backup-postgres.sh` (dump custom, controllo catalogo, SHA256) e `infra/verify-restore.sh` (restaura un backup soltanto in un container PostgreSQL 17 temporaneo e lo elimina); prova su dataset sintetico in GitHub Actions. **Restore isolato del vero DB Coolify riuscito il 24/10**; copia offsite non effettuata per scelta.
6. Test automatici dedicati: due DB SQLite separati, modifiche simultanee e due modalità di risoluzione, perdita e ritorno di rete, più test HTTP per la privacy dell'endpoint latest/tombstone.

## Nuovo incremento — organizzazione attività (23 ottobre 2026)

- Liste personalizzate vere (compresa lista vuota) sincronizzate come `entityType: list`, con creazione/rinomina/eliminazione dalla sidebar Forui.
- Priorità, tag e sottotask del task; ricerca e filtro; modifiche da client e server tramite outbox e delta.
- Drift schema **v4**, PostgreSQL/Flyway **V6**; nessuna istruzione di reinstallazione/cancellazione SQLite.
- Test Backend CI [39990997833](https://github.com/andreadada/simple-notes/actions/runs/39990997833) riuscita; analyze/test Flutter [39991667611](https://github.com/andreadada/simple-notes/actions/runs/39991667611) riusciti. Build native da confermare nell'ultima run.
- **Non provato su infrastruttura reale**: Coolify aggiornato e sync di questi campi Windows/Android. Vedere [task-organization.md](task-organization.md) per procedura e limiti.

## Primo incremento orari delle scadenze (23 ottobre 2026)

- L'editor attività Forui ora consente **HH:mm opzionale** insieme alla data. Il valore usa il campo `dueAt` già presente, senza nuove migrazioni, ed è visibile nelle liste attività quando diverso da mezzanotte.
- La validazione richiede ore 0–23 e minuti 00–59 e rifiuta le ore locali inesistenti durante la transizione DST. Nessun cambiamento al protocollo sync; il client continua a convertire l'istante in UTC per il server.
- **Limite storico del primo editor HH:mm, superato nel codice T3:** mezzanotte e scadenza «solo giorno» ora distinguibili nel modello. La separazione esplicita `dueDate` / `dueTime` / `timezone` con migrazioni incrementali e test DST resta da realizzare **prima** di ricorrenze e notifiche. Il campo HH:mm è il primo incremento UI, non il completamento del sottoprogetto promemoria.
- La build CI di questo incremento va controllata; non dichiarare test hardware superati senza prova.

## T2 — Flutter e SQLite v5 (implementato nel repository, non distribuito)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Piano precedente T2/T3 (ora codice implementato, gate operativi aperti)

- Piano dettagliato: [due-dates-timezones.md](due-dates-timezones.md). T1 backend e T2/T3 Flutter implementati; V7 già presente nel database reale. Rimangono controllo API autenticata e hardware. L'attuale UI HH:mm ha superato le CI Flutter [40011701417](https://github.com/andreadada/simple-notes/actions/runs/40011701417) e [40011789270](https://github.com/andreadada/simple-notes/actions/runs/40011789270): non equivale a test real-device.
- Gate attuale: backup reale e restore isolato PASS, Flyway V1–V7 sul DB; offsite non effettuata per scelta. Ora verificare API e test fisici.

## Avanzamento T1 backend (solo repository)

- Nel commit [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26) sono stati introdotti `TaskDue`, `V7__task_due_semantics.sql`, capability backend e protezione 426 vecchi client, con test Java. La [CI backend 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) è **riuscita** e **Flyway V7 è stata poi verificata sul DB reale; l'API in esecuzione resta da controllare**.
- Flutter usa Drift v5 e `TaskDue` con UI T3 nel codice; test API e hardware ancora da fare. Non installare un nuovo client che scriva `due` senza prima verificare che il backend aggiornato supporti `taskDueSchema=1` dopo un backup PostgreSQL verificato.

## Rimane da fare per dichiarare P0 completo

- **Prove hardware:** con build `0.4.0+4` verificare account Google/sessioni, attività/note PC↔Android, offline→online, conflitti Forui, date/ora/DST e riavvii; verificare prima capability API.
- **Organizzazione delle attività**: liste, tag, sottotask e priorità implementati e testati in CI (vedi `task-organization.md`); restano verifica su device e filtri avanzati.
- **Ricorrenze e promemoria**: date e ore, timezone IANA, cambio ora DST, snooze, notifiche Android e Windows verificate anche con app in background; evitare notifiche duplicate. Nessuna promessa di reminder a PC spento.
- **Sync avanzata**: risoluzione delle cancellazioni remote con recupero/duplicazione; test cambio account; strategia di rebootstrap e integrazione degli endpoint REST legacy nel change log. Background sync se previsto.
- **Qualità UI**: componenti Material residui, accessibilità, test su diverse dimensioni e DPI, UI mobile e test di navigazione.
- **Sicurezza/operatività**: rate limiting auth, audit controllato, backup automatici cifrati fuori dal VPS, restore reale isolato **già riuscito** (ripetere solo quando necessario per futura release), firma release Android, packaging Windows, verifiche di sicurezza e monitoraggio.

P1, P2 e P3 rimangono **non avviati** come fasi complete; la presenza di un componente UI non equivale a feature di prodotto finita.

## Ordine corretto dei prossimi incrementi P0

1. **Gate dati verificato 24/10:** V1–V7, backup SHA256 e restore isolato PASS; offsite non effettuata per scelta. Prossimo gate API e hardware T4.2.
2. **Verifica fisica:** Windows ↔ Android con due client aggiornati: liste (incluse vuote), priorità, tag, sottotask, cancellazioni sicure, sessioni dopo riavvio, operazioni offline e conflitti 409. Le funzioni dell'organizzazione sono già implementate e testate in CI: **non reimplementarle**.
3. **Dopo T4.2:** ricorrenze, reminder/notifiche native e filtri. Date-only/ora/IANA/DST T3 già implementati nel codice.
4. **Chiusura P0:** recupero edit-vs-delete remoto, rebootstrap e compatibilità REST legacy, rate limiting auth, restore reale periodico, packaging/firma, test accessibilità e release.

Checklist operativa con prove da registrare: [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md).

## Allineamento UI (24/10/2026)

Refactoring inline-first nelle schermate Flutter esistenti: titoli task/note/sottotask e descrizioni direttamente modificabili, tag, priorità e lista senza dialog di modifica generico, Forui account menu/sheet mobile, conferme delete. Tutti i salvataggi passano tramite SQLite/outbox. Stato dell'audit e limitazioni per runtime web: [ui-design-audit.md](ui-design-audit.md). **Le build web e la verifica visuale dei dispositivi non sono implicate dall'adozione dei componenti Forui.**

## Regola UI esatta: underline e placeholder (24/10/2026)

- Codice commit [7303d45](https://github.com/andreadada/simple-notes/commit/7303d45c34eda2d38f3442080b0959c69ab1bbf0): tutti i campi inline misurano la larghezza del **valore o placeholder** con `TextPainter` e `MediaQuery.textScalerOf`, invece della larghezza del contenitore; nessun minimo fisso e nessuna banda lunga nei task, descrizioni, tag, note, sottotask e quick-add.
- Sotto il valore `A`, la linea segue il singolo carattere (spazio tecnico di ~1px per il cursore). Placeholders resi meno opachi tramite token `NotesPalette.placeholder` (~72% alpha). Focus accent blu; background trasparente.
- Test widget aggiunti per confrontare titoli corti/lunghi, descrizioni vuote, aggiunta rapida e opacità del placeholder. **La CI e la prova visiva su Windows/Android devono essere valutate separatamente**; il browser web rimane fuori dal runtime esistente. Audit: [ui-design-audit.md](ui-design-audit.md).

## Deploy / sicurezza dati

- Il client richiede API compatibile con liste, `TaskDue` e `taskDueSchema:1`. **Flyway V1–V7 e backup/restore isolato sono già verificati.** Controllare il contratto API prima di valutare deploy. Mai cancellare dati app/SQLite per risolvere errori di sync.
- Le modifiche Flutter si installano con `git pull origin main`, `flutter pub get` e la normale build; eseguire `dart run build_runner build` dopo migrazioni Drift se necessario.
- [Playbook operativo](../infra/README.md) · [Protocollo](sync.md) · [Roadmap](../project.md).
