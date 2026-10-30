# P2.1 — Archivio JSON portabile, non distruttivo

**Stato al 30/10/2026:** branch `feature/p2-1-portable-import-export`, candidato Flutter `0.24.0+26`. CI e merge da attestare. Nessun deploy o modifica ai dati reali. [Stato](CURRENT-STATUS.md).

## Scopo

- **Export:** nel menu account, «Esporta dati JSON», scegli percorso/nome nel dialog Salva con nome di Windows; su Android scegli la destinazione dalla condivisione di sistema. Il documento UTF-8 contiene `format=simple-notes-portable`, `schemaVersion=1`, `exportedAt`, e tre array `data.lists`, `data.tasks`, `data.notes`.
- **Campi inclusi:** liste, task (descrizione, scadenze civili/timed/legacy, IANA, ricorrenze, time slots, priorità, tag, subtasks, completed e timestamp), note **attive** (titolo, corpo, timestamp).
- **Esclusi:** cestino/tombstone, SQLite/Drift binario, modifiche pending/outbox, remoteVersion, delta cursor, owner, credenziali OAuth/token e impostazioni di sessione, preferenze tema, Pomodoro, Habit, Countdown, reminder, dati protetti da secure storage. **Non è un backup completo né un restore**. Il JSON è in chiaro e può contenere dati personali: conservarlo in luogo sicuro.
- **Import:** «Importa dati JSON», apri file, validazione prima di ogni scrittura, anteprima conteggi e conferma Forui. Copia su SQLite locale corrente con UUID nuove (comprese subtasks e slots) e ricostruisce i riferimenti alle liste; nessun aggiornamento/cancellazione preesistente. Ripetere produce duplicati; dopo la conferma la normale outbox invierà i nuovi dati all'account collegato. Cancellare il dialog non scrive nulla.

## Sicurezza e compatibilità

- Massimo **8 MiB** per archivio, **10.000** record; schema e data obbligatori, sezioni liste/task/note obbligatorie, identificativi univoci, riferimenti alle liste presenti; controlli titolo, priorità/tag/sottotask e parsing coerente di due/recurrence/slots.
- Il formato **versionato** rifiuta versioni future sconosciute; niente import implicito di oggetti arbitrari o di metadata di sync.
- Inserimento ordinato liste→task→note dentro **una transazione SQLite**; rollback su errore; snapshot e UI ricaricati dopo commit. Nessuna nuova migration Drift/Flyway, endpoint o capability.
- Import via `file_selector` su Windows/Android; export via `file_selector`/Salva con nome su Windows, via `share_plus`/condivisione sistema su Android. Verifiche CI non attestano permessi e comportamento delle UI di sistema.
- Import in un database legato a un account Google è un'azione esplicita dell'utente: i nuovi elementi diventano dati di **quell'account**, non di quello da cui proviene il file. Nessuna provenienza/ACL si trasferisce.

## Test e release gate

1. Codec round-trip, date-only/ricorrenze/slot/tag/sottotask, esclusione cestino e identificativi nuovi con mapping corretto.
2. JSON invalido, schema sconosciuto, liste orfane, limite dimensione → nessuna scrittura.
3. Import SQLite memory: righe e outbox preesistenti invariati, nuove operazioni in ordine, reimport con nuove UUID; all-or-nothing.
4. CI Flutter analyze/test, Android JDK 17/21, Windows EXE/MSIX, Markdown **sullo SHA finale**.
5. Solo in seguito: Windows/Android veri, cancel picker, salva/riapri, riavvio, import offline e sync protetta dal gate V10.
6. Non confondere il JSON portabile con un backup completo di SQLite + SharedPreferences + secure storage; [runbook](P1-RELEASE-BATCH.md).

**Incrementi successivi distinti:** ICS read-only / CSV, poi backup/ripristino reale con conflict policy e isolation esplicite.
