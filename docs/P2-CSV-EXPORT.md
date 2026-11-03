# P2.4A — Esportazione CSV mirata (attività, note, liste)

**Stato 03/11/2026:** integrata su `main` con [PR #27](https://github.com/andreadada/simple-notes/pull/27), Flutter `0.30.0+32`; [Flutter CI #41562133925](https://github.com/andreadada/simple-notes/actions/runs/41562133925) **success** (198 test, Windows EXE/MSIX, Android JDK17/21), [Markdown #41561797719](https://github.com/andreadada/simple-notes/actions/runs/41561797719) **success**. Test dispositivi reali differiti. Nessun deploy, migrazione Flyway/Drift, nuova API, import CSV o modifica al database.

## Funzione utente

Dal menu profilo **Esporta CSV** si apre un dialog Forui con tre scelte esplicite: **Attività**, **Note** e **Liste**. Dopo una scelta l'app legge lo snapshot SQLite locale aggiornato, prepara **un solo file CSV**, poi offre **Salva con nome** su Windows o la **condivisione di sistema** su Android. Se annulli, non viene salvato alcun file. L'interfaccia blocca importazioni/esportazioni simultanee tramite `_archiveBusy` e visualizza errori senza riportare dati personali. Nessun CSV viene generato automaticamente al login o alla sincronizzazione.

Il file ha nome `simple-notes-<tipo>-YYYY-MM-DD.csv`, è UTF-8 con BOM (Excel), colonne separate da virgole, celle fra doppi apici, `""` per un apice doppio interno, righe terminate con CRLF. Le nuove righe interne alle note sono conservate nelle celle quotate. Per importazioni che usano un separatore diverso a seconda del locale, in Excel scegliere esplicitamente **Dati → Da testo/CSV** e il delimitatore **virgola**. I timestamp assoluti sono esportati in UTC ISO-8601; le scadenze `date-only` restano date civili, **non** vengono convertite in mezzanotte UTC.

## Contenuto per tipo

- **Attività** (anche completate, ma non soft-deleted): ID, titolo, descrizione, completed, creazione UTC, ID/nome lista, priorità, tag in JSON, tipo/data/ora/fuso/scadenza UTC/offset, tipo/intervallo ricorrenza, blocchi temporali in JSON, subtasks in JSON. `time_blocks_json` e `subtasks_json` sono **stringhe JSON dentro una cella CSV** e conservano ID, date e stato senza appiattire o moltiplicare le righe.
- **Note**: soltanto note attive con ID, titolo, corpo completo e data creazione UTC. Il cestino `trashedNotes` e le tombstone sono esclusi.
- **Liste**: ID, titolo, creazione UTC, conteggio di task attivi referenziati; non esporta corpi di note.

I tre formati non includono bearer token, refresh token, OAuth IDs, ID account, `boundOwnerId`, sync cursor, versioni remote, outbox, eventi ICS, file ICS, cache/URL con token di feed, preferenze tema, Pomodoro, Habit, Countdown, reminder o altre informazioni del dispositivo.

## Sicurezza e limiti

- Una stringa che inizia (anche dopo spazi, tab o zero-width spaces) per `=`, `+`, `-`, `@` viene prefissata con apostrofo per impedire che software di fogli di calcolo la esegua come formula. Anche i testi che iniziano con CR/LF/TAB sono trattati come potenzialmente pericolosi. I valori sono sempre quotati e gli apici raddoppiati. **Questo può alterare la visualizzazione iniziale di alcuni testi letterali**; l'originale resta in SQLite invariato.
- Massimo **10.000 righe di dati per export** e **8 MiB di CSV UTF-8**. L'esportazione che supera i limiti fallisce prima della selezione della destinazione; SQLite e la coda sync non cambiano.
- I CSV sono **in chiaro e possono contenere dati personali**. Su Android la destinazione e le autorizzazioni dipendono dalla share sheet; non vengono caricati sul server Simple Notes dall'app.
- **Non è un backup**, non è importabile nell'app, non preserva tutti i metadati o l'identità installata e non ripristina un profilo. Il formato portabile JSON P2.1 rimane il percorso di importazione additiva supportato; backup completo di profilo e protocollo di restore restano un incremento separato.
- L'esportazione prende la fotografia del *database locale del dispositivo corrente*: non garantisce di includere modifiche presenti solo sul cloud o su altri dispositivi se non sono ancora sincronizzate.

## Test automatici

`apps/flutter/test/portable_csv_test.dart` verifica:
1. UTF-8 BOM, CRLF, quoting/escaping di virgole, apici, nuove righe e testo Unicode.
2. Semantica scadenze date-only e UTC, RRULE task, slot, sottotask, tag, collegamento liste e conteggi.
3. Esclusione cestino e di metadati privati; CSV vuoto con solo intestazione.
4. Neutralizzazione di formule con prefissi `=+-@`, spazi, tab, CRLF e zero-width.
5. Rifiuto dei limiti 10.000 record/8 MiB.
6. Generazione da `AppDatabase.snapshot()` SQLite senza nuovi write o outbox.

La CI Flutter verifica analyze/test, Windows EXE/MSIX, Android JDK17/21, e i documenti Markdown. **Le prove di picker Windows/Android e le verifiche real-device sono rinviate volontariamente** al batch descritto in [Collaudo rinviato](DEVICE-ACCEPTANCE-DEFERRED.md), senza considerarle concluse.

## Seguito

P2.4B: progettazione del backup completo (SQLite, pending outbox, SharedPreferences, credenziali in secure storage **non esportabili in chiaro**, ripristino con controllo owner, versione e rollback). Non fare un finto backup JSON/CSV. Altri P2/P3: condivisione, regole intelligenti e integrazioni opzionali.

[Stato](CURRENT-STATUS.md) · [Roadmap](../project.md) · [Archivio JSON](P2-PORTABLE-ARCHIVE.md) · [Collaudo](DEVICE-ACCEPTANCE-DEFERRED.md).

## P2.4B1 — CSV non è un backup

Il CSV P2.4A è un export leggibile in chiaro e non reimportabile. P2.4B1 introduce .snb cifrato per SQLite incluse tombstone/outbox e preferenze locali, verificabile con password senza modificare dati. Il ripristino resta un lavoro distinto P2.4B2. [Specifica](P2-FULL-BACKUP.md).
