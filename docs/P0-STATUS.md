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

## Rimane da fare per dichiarare P0 completo

- **Prove hardware**: aggiornare API Coolify solo dopo backup; verificare Google session refresh/logout, task completati, cancellazioni, sync offline → online, conflitti Forui e data delle attività su Windows e Android, compresi riavvii.
- **Organizzazione delle attività**: liste personalizzate, tag, sottotask, priorità, filtri avanzati.
- **Ricorrenze e promemoria**: date e ore, timezone IANA, cambio ora DST, snooze, notifiche Android e Windows verificate anche con app in background; evitare notifiche duplicate. Nessuna promessa di reminder a PC spento.
- **Sync avanzata**: risoluzione delle cancellazioni remote con recupero/duplicazione; test cambio account; strategia di rebootstrap e integrazione degli endpoint REST legacy nel change log. Background sync se previsto.
- **Qualità UI**: componenti Material residui, accessibilità, test su diverse dimensioni e DPI, UI mobile e test di navigazione.
- **Sicurezza/operatività**: rate limiting auth, audit controllato, backup automatici cifrati fuori dal VPS, test di restore **dei dati veri su ambiente isolato**, firma release Android, packaging Windows, verifiche di sicurezza e monitoraggio.

P1, P2 e P3 rimangono **non avviati** come fasi complete; la presenza di un componente UI non equivale a feature di prodotto finita.

## Ordine consigliato dei prossimi incrementi P0

1. Ripristino affidabile degli elementi cancellati in conflitto e test e2e a due dispositivi.
2. Liste, priorità, tag e sottotask sincronizzati; modellare le entità con schema/migrazioni e test, non solo UI.
3. Scadenze con orari, ricorrenze e notifiche native, compresi timezone/DST.
4. Backup offsite, rate limit, sicurezza, test restore reale, packaging e prova dei rilasci.

## Deploy / sicurezza dati

- L'endpoint `/sync/latest` e Flyway V5 richiedono **redeploy del backend su Coolify**. Prima produrre un backup verificabile del database. Mai cancellare dati app/SQLite per risolvere errori di sync.
- Le modifiche Flutter si installano con `git pull origin main`, `flutter pub get` e la normale build; eseguire `dart run build_runner build` dopo migrazioni Drift se necessario.
- [Playbook operativo](../infra/README.md) · [Protocollo](sync.md) · [Roadmap](../project.md).
