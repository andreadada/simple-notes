# P1.4 — Multi-block, duplicate e riepilogo focus

<!-- CURRENT-STATUS-REF -->
> **SNAPSHOT STORICO — 26/10/2026:** codice `main` fino a P1.11 Habit Tracker (Flutter `0.16.0+18`, PR #12, CI verde); P1.12 Countdown `0.17.0+19` **solo nel branch**, CI/merge/device da verificare. Pomodoro/Habits/Countdown sono locali per dispositivo/account, **non** sincronizzati. Repository Flyway V10, VPS Coolify confermata fino a V8, nessun deploy o reset. Questa specifica conserva lo storico del proprio incremento: **non usarla come runbook corrente**. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Countdown](P1-COUNTDOWNS.md).


## Funzioni implementate

- **Fino a 12 blocchi temporali per task**, ognuno con ID stabile e istanti UTC/zone IANA distinti. Le scadenze `due` continuano a essere indipendenti.
- **Pannello Forui nei dettagli attività:** aggiungi, modifica e rimuovi il singolo intervallo dall'editor esistente, oppure duplica un intervallo (sul giorno successivo come spostamento temporale UTC di 24h nella prima versione). Modificare un titolo resta inline senza comando «Rinomina».
- **Timeline giorno/settimana e mese:** proietta tutti gli intervalli della singola attività; drag, resize, drop su altro giorno, collision lanes e label operano solo sul blocco corrispondente. Una attività può apparire più volte nello stesso giorno.
- **Riepilogo giornaliero, settimanale e mensile:** conteggio intervalli, ore/minuti pianificati e ore/minuti completati. Il calcolo usa la durata effettiva entro l'intervallo visualizzato; due blocchi sovrapposti contano due sessioni (non è un'unione degli intervalli «busy»). Nessuna nuova API per il riepilogo.
- Ogni gesture produce **un singolo upsert atomico dell'intero task** in SQLite/outbox, con lo stesso conflitto versionato già presente. Nessun sottoinsieme di blocchi può essere modificato con uno snapshot locale obsoleto: `LocalStore` rilegge il task corrente per ID.

## Protocollo dati e compatibilità

| Strato | Novità |
|---|---|
| PostgreSQL Flyway **V9** | Aggiunge `task.blocks_json TEXT NOT NULL DEFAULT '[]'`. Dati V8 `block_start_at / block_end_at / block_timezone` restano intatti; `blocks_json` viene popolato al primo update attraverso API V9. Non tocca note, liste, utenti o sync history. |
| Backend | Nuovo `TaskTimeBlocks`: valida massimo 12 intervalli, UUID o `legacy`, ID univoci, fuso IANA, durata massimo 24h e precisione al minuto. Conserva **il primo blocco ordinato** come mirror nelle tre vecchie colonne V8 e in `timeBlock`. |
| Sync JSON V9 | `timeBlocks: [{"id":"UUID","start":"...Z","end":"...Z","timeZone":"Europe/Rome"}, ...]`. Resta anche `timeBlock` (il primo oppure `kind:none`) per client V8. |
| Capability | `GET /api/v1/capabilities` include `timeBlocksSchema:1`, oltre a `timeBlockSchema:1`. |
| Protezione legacy | Se un client V8 non include `timeBlocks` e il task ha **2+ blocchi**, l'API risponde **HTTP 426**, **senza modificarli**. Se ci sono 0/1 blocchi, rimane compatibile col mirror V8; nuovi client verificano il mirror se fornito. |
| Flutter Drift **V7** | Colonna `task_entries.blocks_json TEXT DEFAULT '[]'`. I record V6 preservano le vecchie tre colonne e vengono visualizzati come uno slot `legacy` finché non vengono modificati. Le mutazioni pendenti, versioni remote, cursor e utenti legati al device sono mantenuti. |
| Client moderni | Qualsiasi nuovo upsert contenente `timeBlocks` richiede `timeBlocksSchema:1`. Senza la capability l'outbox **resta intatta**, senza un falso ACK. Le operazioni già accodate in formato V8 non vengono riscritte d'autorità e saranno gestite dal backend V9 con le regole legacy. |

### Contratto ed esempi

```json
{
  "title": "Studiare Fisica",
  "due": {"kind":"date", "date":"2026-11-20"},
  "timeBlocks": [
    {"id":"ad17f5f9-3ad0-498c-a05b-e29c837a4faf",
     "start":"2026-11-01T08:00:00Z",
     "end":"2026-11-01T09:00:00Z",
     "timeZone":"Europe/Rome"},
    {"id":"6f1dd7a4-90c7-4426-ae8c-95b9fdc8ce17",
     "start":"2026-11-01T12:00:00Z",
     "end":"2026-11-01T13:00:00Z",
     "timeZone":"Europe/Rome"}
  ]
}
```

Il server risponde includendo `timeBlock` come mirror del primo intervallo. I blocchi possono sovrapporsi: il sistema non forza una rischedulazione automatica. I vecchi client visualizzano soltanto il primo e non possono cambiare task con più blocchi.

## Test e gate

- Backend Testcontainers PostgreSQL17: migrazione V6→V9 con entità già popolate, sincronizzazione 2 blocchi, versionamento, resistenza al client legacy, payload con ID duplicato.
- Flutter: migrazione da precedente schema SQLite, persistenza operazioni pending, CRUD slot, duplicazione, proiezione calendario, riepilogo minutigiorno/mese, capability fail-closed.
- GitHub Actions: backend CI + Flutter analyze/tests/build Android 17/21 + Windows + Compose. Considerare superata la CI **solo dopo** controllo ultimo SHA del branch.
- **Il collaudo hardware non è ora richiesto.** Al momento del rilascio: backup/rollback policy decisi nell'occasione, backend Flyway V9 **prima** dei client Flutter 0.8, `FLYWAY_LATEST=9`, `BLOCK_COLUMNS=3`, `BLOCKS_JSON_COLUMNS=1`, capability `timeBlocksSchema:1`; poi installazione senza disinstallazione/reset, sync incrociata, offline→online, migrazione SQLite V6→V7, guard 426 per client precedenti e DST.
- Se Coolify auto-deploya `main`, **non fare merge di questo branch durante lo sviluppo**: la modifica backend è legata a V9.

## Esclusioni

- Non sono introdotti drag multi-selezione, ricorrenze, suggerimenti automatici slot, notifiche, Outlook/Google Calendar.
- Duplica blocco applica **+24h assolute**; durante i cambi DST l'ora visualizzata può differire, mentre la durata rimane invariata. Lo spostamento manuale tra giorni continua a gestire l'ora civile IANA con verifica gap/fold.

**Next batch:** recurring/reminder o miglioramenti di calendario/filtri, senza forzare un deploy intermedio.
