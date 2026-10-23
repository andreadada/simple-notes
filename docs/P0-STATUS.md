# P0 — Stato verificabile e piano di chiusura

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
5. **Backup PostgreSQL**: `infra/backup-postgres.sh` (dump custom, controllo catalogo, SHA256) e `infra/verify-restore.sh` (restaura un backup soltanto in un container PostgreSQL 17 temporaneo e lo elimina); prova su dataset sintetico in GitHub Actions. **Non** è stata ancora effettuata una prova di ripristino del vero DB Coolify né configurata una destinazione offsite.
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
- **Limitazione importante:** mezzanotte e una scadenza «solo giorno» non sono ancora distinguibili nel modello. La separazione esplicita `dueDate` / `dueTime` / `timezone` con migrazioni incrementali e test DST resta da realizzare **prima** di ricorrenze e notifiche. Il campo HH:mm è il primo incremento UI, non il completamento del sottoprogetto promemoria.
- La build CI di questo incremento va controllata; non dichiarare test hardware superati senza prova.

## Prossima implementazione progettata, non sviluppata

- Piano dettagliato: [due-dates-timezones.md](due-dates-timezones.md). T1 backend + Flyway V7 **introdotti nel repository**, non deployati. Il prossimo incremento **T2 Flutter** introduce Drift v5 e poi la UI T3; test hardware e gestione 426 ancora necessari. L'attuale UI HH:mm ha superato le CI Flutter [40011701417](https://github.com/andreadada/simple-notes/actions/runs/40011701417) e [40011789270](https://github.com/andreadada/simple-notes/actions/runs/40011789270): non equivale a test real-device.
- Gate preliminare immutato: backup PostgreSQL reale e restore isolato/offsite, deploy V5+V6 se non già effettuato, poi verifica fisica dei flussi attuali.

## Avanzamento T1 backend (solo repository)

- Nel commit [1bafec0](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26) sono stati introdotti `TaskDue`, `V7__task_due_semantics.sql`, capability backend e protezione 426 vecchi client, con test Java. La [CI backend 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) è **riuscita** e **Coolify non è stato aggiornato**.
- Flutter continua a usare Drift v4 / `dueAt`; T2 e T3 ancora da fare. Non installare un nuovo client che scriva `due` senza prima verificare che il backend aggiornato supporti `taskDueSchema=1` dopo un backup PostgreSQL verificato.

## Rimane da fare per dichiarare P0 completo

- **Prove hardware**: aggiornare API Coolify solo dopo backup; verificare Google session refresh/logout, task completati, cancellazioni, sync offline → online, conflitti Forui e data delle attività su Windows e Android, compresi riavvii.
- **Organizzazione delle attività**: liste, tag, sottotask e priorità implementati e testati in CI (vedi `task-organization.md`); restano verifica su device e filtri avanzati.
- **Ricorrenze e promemoria**: date e ore, timezone IANA, cambio ora DST, snooze, notifiche Android e Windows verificate anche con app in background; evitare notifiche duplicate. Nessuna promessa di reminder a PC spento.
- **Sync avanzata**: risoluzione delle cancellazioni remote con recupero/duplicazione; test cambio account; strategia di rebootstrap e integrazione degli endpoint REST legacy nel change log. Background sync se previsto.
- **Qualità UI**: componenti Material residui, accessibilità, test su diverse dimensioni e DPI, UI mobile e test di navigazione.
- **Sicurezza/operatività**: rate limiting auth, audit controllato, backup automatici cifrati fuori dal VPS, test di restore **dei dati veri su ambiente isolato**, firma release Android, packaging Windows, verifiche di sicurezza e monitoraggio.

P1, P2 e P3 rimangono **non avviati** come fasi complete; la presenza di un componente UI non equivale a feature di prodotto finita.

## Ordine corretto dei prossimi incrementi P0

1. **Gate di deployment e dati:** backup PostgreSQL reale, restore isolato, copia offsite; solo dopo redeploy Flyway V5+V6 e controllo log/health. Nessun deploy automatico da questa checklist.
2. **Verifica fisica:** Windows ↔ Android con due client aggiornati: liste (incluse vuote), priorità, tag, sottotask, cancellazioni sicure, sessioni dopo riavvio, operazioni offline e conflitti 409. Le funzioni dell'organizzazione sono già implementate e testate in CI: **non reimplementarle**.
3. **Prossimo sviluppo:** scadenze con orario opzionale e date-only robuste, timezone/DST; poi ricorrenze e reminder/notifiche native con deduplicazione. Filtri combinati/salvati a seguire.
4. **Chiusura P0:** recupero edit-vs-delete remoto, rebootstrap e compatibilità REST legacy, rate limiting auth, restore reale periodico, packaging/firma, test accessibilità e release.

Checklist operativa con prove da registrare: [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md).

## Deploy / sicurezza dati

- Il nuovo client richiede API con supporto `entityType:list` e migrazioni Flyway **V5+V6**: **redeploy del backend su Coolify**. Prima produrre un backup verificabile del database. Mai cancellare dati app/SQLite per risolvere errori di sync.
- Le modifiche Flutter si installano con `git pull origin main`, `flutter pub get` e la normale build; eseguire `dart run build_runner build` dopo migrazioni Drift se necessario.
- [Playbook operativo](../infra/README.md) · [Protocollo](sync.md) · [Roadmap](../project.md).
