# Simple Notes

> **Stato operativo 06/11/2026:** `main` integra fino a **P2.4B2U** ([PR #53](https://github.com/andreadada/simple-notes/pull/53), merge `afa835d6`); Flutter `0.31.0+33`, Drift V8 e backend Flyway **V11 nel codice**. [Flutter CI #42239264547](https://github.com/andreadada/simple-notes/actions/runs/42239264547) **success** (322 test, Android Java 17/21, Windows EXE/MSIX e recovery sandbox Windows); [Markdown CI #42239264424](https://github.com/andreadada/simple-notes/actions/runs/42239264424) **success**. Backend e Compose erano verdi su [PR #50](https://github.com/andreadada/simple-notes/pull/50). **VPS attestata solo a Flyway V10 (03/11); V11/API strict e prove fisiche non attestati.** Restore live, replay outbox importata e deploy restano fuori scope. [Stato](docs/CURRENT-STATUS.md) · [Backup](docs/P2-FULL-BACKUP.md) · [V11](docs/RELEASE-V11-READINESS.md).

App offline-first per **Windows 11 e Android** dedicata ad attività, note e pianificazione. Flutter/Forui con Drift SQLite locale, Google OAuth e sincronizzazione con Spring Boot/PostgreSQL su Coolify.

<!-- CURRENT-STATUS-REF -->

## Funzionalità presenti nel codice

- Login Google, note e task, liste/priorità/tag/sottotask, modifica direttamente sul testo visualizzato, cestino note e sincronizzazione offline-first con coda persistente.
- Calendario giorno/settimana/mese, scadenze civili e date-time con fuso IANA e DST.
- Blocchi orari multipli e drag/resize, riepilogo del tempo, slot liberi, ricerca e filtri.
- Ricorrenze giornaliere/settimanali/mensili (P1.6). P1.7 aggiunge promemoria opt-in Android e Windows **solo MSIX** (non su EXE/ZIP); funzionamento reale ancora da collaudare.

- Matrice Eisenhower P1.8: quattro quadranti da priorità/scadenza, adattiva e con modifica diretta dei task.
- Kanban P1.9 per liste con drag/drop, aggiunta rapida e spostamento accessibile: **integrato su main**.
- Pomodoro P1.10 (**main**): timer 25/5/15 e statistiche locali, **non sincronizzate tra dispositivi**.
- Habit Tracker P1.11 (**main**, PR #12): abitudini quotidiane, streak, check-in, storico/archivio locali, senza cloud sync.
- Countdown P1.12 (**main**, PR #13): eventi a data civile o ora IANA, titolo inline e archivio; locale, non sincronizzato.
- P1.13 (**main**, PR #14): obiettivi Habit 1–7 giorni alla settimana e streak settimanali, storico locale preservato.
- P1.14 (**main**, PR #15): apri note sincronizzate in finestre Windows indipendenti, editing inline attraverso il processo principale.
**Implementato su GitHub ≠ distribuito.** Prima di installare client aggiornati verificare su Coolify Flyway V10 e le capability autenticate. Nessun reset, cancellazione di volumi o migrazione manuale per una normale verifica. Il deploy resta un'operazione distinta e controllata dall'utente.

## Percorso rapido

- [Stato canonico e prossimi gate](docs/CURRENT-STATUS.md), [guida operativa](docs/OPERATIONS.md), [Kanban P1.9](docs/P1-KANBAN.md), [Pomodoro P1.10](docs/P1-POMODORO.md), [Habit Tracker P1.11](docs/P1-HABITS.md), [Countdown P1.12](docs/P1-COUNTDOWNS.md), [P1.13 Weekly Habit](docs/P1-WEEKLY-HABITS.md)
- [Roadmap P0–P3](project.md), [regole per agenti](AGENTS.md), [design](design.md)
- [Handoff e cronologia](docs/HANDOFF.md)
- [Architettura](docs/architecture.md), [API](docs/api.md), [sync](docs/sync.md)
- [Client Windows/Android](apps/flutter/README.md), [backend/Coolify](infra/README.md)
- [P1.6: ricorrenze](docs/P1-RECURRENCE.md), [P1.8: Matrice Eisenhower](docs/P1-EISENHOWER.md), [P1.7: Android](docs/P1-REMINDERS-FOUNDATION.md), [Windows MSIX](docs/P1-WINDOWS-MSIX.md)
- [Runbook di rilascio V10](docs/P1-RELEASE-BATCH.md) e [check E2E](docs/T4-DEVICE-SYNC.md)

## Regole UX e dati

La UI usa **Forui**, preferisce campi testuali editabili *inline* senza pulsanti "Rinomina", e un underline che segue soltanto i glifi; il campo conserva margine per cursore/selezione. Le modifiche passano sempre da SQLite/outbox, non solo dallo stato grafico. Preservare versioni, cursor e pending mutation; non trattare HTTP 426 come conflitto 409.

## Verifiche

Le GitHub Actions coprono Flutter, backend, Compose e link Markdown. I test automatici **non** certificano la versione realmente distribuita, OAuth sui dispositivi, né la sync E2E. Tutte le procedure di reset e le versioni P0/T2/T3/P1.1–P1.5 sono documentate nelle specifiche storiche, non costituiscono istruzioni di rollout aggiornate.

La fase Sticky Windows P1.14 è documentata in [P1-STICKY-WINDOWS.md](docs/P1-STICKY-WINDOWS.md); non è ancora attestata su hardware.

## P1.15 — Scorciatoie (main, PR #16)

Windows: `Ctrl+1..5` navigazione, `Ctrl+Shift+T` nuova attività, `Ctrl+Shift+N` nuova nota, `Ctrl+/` guida Forui. Android invariato; nessuna migrazione. [Specifica](docs/P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Responsive (main, PR #17)

Le note si dispongono in **1, 2 o 3 colonne** secondo lo spazio del contenuto Windows/Android, senza tagliare il corpo né cambiare lo storico o la sincronizzazione. Flutter candidata `0.21.0+23`; CI/merge/device da verificare. [Specifiche](docs/P1-RESPONSIVE.md).

## P1.17 — Tray Windows (main, PR #18)

X→nascondi nell'area di notifica, click/menu→riapri, **Esci** dal menu per chiudere. Solo Windows, nessuna nuova API o sincronizzazione. Candidata Flutter `0.22.0+24`. [Specifica](docs/P1-WINDOWS-TRAY.md).

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](docs/P1-APPEARANCE.md) · [Stato](docs/CURRENT-STATUS.md).

## P2.1 — Archivio portabile JSON (integrata, PR #20)

Menu account → **Esporta dati JSON** oppure **Importa dati JSON**. Esporta liste, attività (comprese scadenze/ricorrenze/blocchi/sottotask) e note attive. Importa copie con nuovi ID senza sovrascrivere alcun elemento, tramite SQLite e outbox standard. Non è un backup completo: esclude cestino, cronologia sync, impostazioni, dati Focus locali, credenziali e sessioni. Flutter `0.24.0+26` integrata in `main` dopo CI completa verde (152 test, Windows/Android, Markdown); nessun deploy. [Specifica](docs/P2-PORTABLE-ARCHIVE.md).

## P2.2 — Calendario ICS esterno (main, PR #21)

Nella schermata Calendario si possono importare fino a 5 file ICS in sola lettura per account/dispositivo; compaiono in giorno, settimana e mese senza essere convertiti in task. Nessuna nuova API o migrazione; ricorrenze ICS e timezone non IANA sono rifiutati con un errore esplicito. Integrata su `main` con [PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI completa verde (162 test, Windows e Android), collaudo fisico ancora aperto. [Specifica](docs/P2-ICS.md).

## P2.3A — Modello sorgenti ICS (main, PR #22)

Integrato su `main` con [PR #22](https://github.com/andreadada/simple-notes/pull/22) è il modello di identità stabile delle sorgenti ICS: archivio locale schema 2 con lettura schema 1, tipologia file/URL (URL ancora inattivo), rimozione per ID e protezione nei cambi account durante import. Flutter `0.26.0+28`, CI verde (166 test, Windows EXE/MSIX, Android JDK17/21, Markdown); nessun deploy o sync cloud. Prima di utilizzare client meno recenti, considerare che P2.2 non può leggere lo schema 2 scritto dopo una nuova modifica. [Specifica](docs/P2-ICS-SOURCES.md).

## P2.3B — Ricorrenze ICS (main, PR #23)

Flutter `0.27.0+29`: le serie RRULE importate da file possono mostrare ripetizioni ed eccezioni RDATE/EXDATE/RECURRENCE-ID, generate solo per il giorno visualizzato. Archivio locale schema 3 con lettura versioni 1/2, senza cloud o feed URL; nessun deploy. [Specifica](docs/P2-ICS-RECURRENCE.md).

## P2.3C — Feed ICS da URL (main, PR #24)

Aggiunta di un URL HTTPS nella vista calendario, download solo su conferma, proiezione read-only offline con refresh manuale e cache conservata su errore. I link privati con query-token non vengono mostrati nell'interfaccia. Nessun server o OAuth aggiuntivo. [Specifica](docs/P2-ICS-FEEDS.md).

## P2.3D — Gestione calendari esterni (main, PR #25)

La vista Calendario ha un pannello **Sorgenti** richiudibile: mostra file e feed HTTPS, conta eventi/serie, indica l'ultimo refresh riuscito, permette aggiornamento manuale e rimozione con conferma. Il titolo di ciascuna sorgente è modificabile subito, inline; non cambia il filename né il link usato per l'import. I feed con token non mostrano il loro URL. Nessun nuovo backend o OAuth. [Specifica](docs/P2-ICS-SOURCE-MANAGEMENT.md).

## Gate server-first per il collaudo cumulativo

Integrato in `main` (PR #26) il controllo di sola lettura `infra/release-readiness.sh` per Flyway V10, health e capability API autenticate. Non installa o distribuisce: l'utente ha confermato VPS Flyway V10 in sola lettura il 03/11/2026; API strict e prove Windows↔Android restano aperte. Versione corrente Flutter `0.31.0+33`. [Runbook](docs/RELEASE-V10-READINESS.md).

## P2.4A — CSV locale (main, PR #27)

Nel menu profilo **Esporta CSV** consente di scegliere attività, note attive o liste; su Windows salva un file tramite la finestra di sistema, su Android usa la condivisione. File UTF-8 con BOM, escaping di virgole/apici/righe e protezione contro formule di fogli di calcolo. Non è un backup né un formato importabile. [Specifica](docs/P2-CSV-EXPORT.md). Test real-device Windows/Android rinviati esplicitamente dall'utente al batch finale: [Registro](docs/DEVICE-ACCEPTANCE-DEFERRED.md).

## P2.4B1 — Backup cifrato del profilo (main, PR #28)

`Avatar → Crea backup cifrato` salva un file .snb protetto da password; `Avatar → Verifica backup` controlla integrità, account e conteggi **senza ripristinare**. Include tutti i dati locali SQLite con cestino/outbox, e preferenze ICS, Pomodoro, Habit, Countdown e tema; esclude i token Google. **Il ripristino operativo è previsto in P2.4B2, non ancora disponibile**. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2A (sviluppo):** prova di restore .snb in SQLite isolato in memoria con confronto integrale e rollback su errori. Nessun ripristino del profilo installato o riavvio della sync autorizzato: [specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2B1 (sviluppo):** checkpoint .snb cifrato su file dedicato, con verifica dopo il salvataggio e prova isolata in SQLite; non ancora collegato all'interfaccia né al restore del profilo attivo. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2B2 (sviluppo):** prova interna e non distruttiva del rollback di SQLite e preferenze locali *simulate* in memoria, con errore iniettato anche dopo commit. Il ripristino del profilo reale non è disponibile. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2C1 (sviluppo):** guard di avvio isolato con registro di recupero append-only, simulazioni di crash e blocco anti-replay per outbox/cursore importati. È una prova su directory temporanea e SQLite in memoria: nessun ripristino live o sospensione effettiva di AutoSync. [Dettagli](docs/P2-FULL-BACKUP.md).


**P2.4B2C2 (sviluppo):** protezione all'avvio su Windows/Android: un recovery pendente blocca il profilo prima di SQLite/OAuth e vieta la sincronizzazione. Disponibile anche un preflight cloud solo GET, senza autorizzare il replay delle vecchie modifiche. Non è ancora disponibile il restore dei dati reali. [Contratto](docs/P2-FULL-BACKUP.md).

Il client include anche il lettore sperimentale di inventario cloud, con validazione stretta e confronto di sole versioni; richiede una API non ancora deployata e non può applicare modifiche.


**P2.4B2C3 (API in sviluppo):** endpoint autenticato di sola lettura per consultare revisioni cloud e tombstone senza contenuti privati, pensato per il futuro confronto prima di ripristinare. Non presente sulla VPS finché non avviene un deploy separato. [API](docs/api.md).


**P2.4B2D (sviluppo):** test di recupero dopo interruzione anche su file SQLite e preferenze simulati su disco, all'interno di una directory temporanea dedicata. Il restore operativo non è disponibile: nessuna scrittura al profilo installato, nessun deploy e nessuna sincronizzazione di backup importati. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2E (sviluppo):** nuova azione nel menu account per confrontare un backup `.snb` con i dati del dispositivo e visualizzare differenze senza ripristinarle. Il riepilogo non mostra contenuti privati e non avvia la sincronizzazione. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2F (sviluppo):** durante «Confronta backup con questo dispositivo» è possibile consultare, su richiesta, l'inventario versioni cloud (GET, senza sincronizzare). Il riepilogo indica solo rischi di conflitti, con privacy e blocco di ogni restore reale. Il backend deve contenere `/sync/inventory`, non ancora necessariamente distribuito. [Specifiche](docs/P2-FULL-BACKUP.md).


**P2.4B2G (sviluppo):** nel confronto backup/cloud è disponibile una simulazione dei rischi e di quattro strategie di gestione dei conflitti, senza applicare modifiche. La matrice mostra soltanto conteggi e non sblocca ripristino o sincronizzazione. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2H (sviluppo):** dopo il confronto con il cloud, l'opzione «Esamina conflitti» permette di rivedere singole note, attività e liste e simulare una preferenza per ciascuna. È una bozza in memoria: non modifica dati, non sincronizza e non abilita il ripristino. [Specifica](docs/P2-FULL-BACKUP.md).

**P2.4B2I (backend in sviluppo):** nuovo controllo read-only delle revisioni cloud e possibilità di CAS per account sulle mutazioni future, senza abilitare il ripristino operativo. Nessun deploy eseguito. [Specifiche](docs/P2-FULL-BACKUP.md).

**P2.4B2J (sviluppo):** nel dialog di confronto backup, il pulsante facoltativo «Ricontrolla revisioni» consulta il nuovo endpoint server di sola lettura per rilevare conflitti recenti. Non modifica dati né sblocca ripristini. [Specifiche](docs/P2-FULL-BACKUP.md).


**P2.4B2K (backend in verifica):** il controllo cloud rifiuta anche divergenze tra registro sync e righe realmente salvate (possibili con endpoint legacy), anziché considerarle sicure. Nessun restore reale abilitato. [Specifiche](docs/P2-FULL-BACKUP.md).


**P2.4B2L (backend in verifica):** la verifica preflight include tutte le note, task e liste dell'account, anche record legacy invisibili nel registro sync, senza cambiare dati o attivare restore. [Specifiche](docs/P2-FULL-BACKUP.md).


**P2.4B2M (backend, in verifica):** le API REST storiche note/task condividono il percorso di sincronizzazione, lo stesso lock per account e gli eventi necessari al cloud. Il restore vero rimane disabilitato; nessun deploy eseguito. [Specifiche](docs/P2-FULL-BACKUP.md).


**P2.4B2N (backend in verifica):** l'inventario cloud controlla anche la coerenza dell'intero account prima di dichiararsi completo; eventuali dati legacy non tracciati producono un errore non distruttivo. [Specifica](docs/P2-FULL-BACKUP.md).


**P2.4B2O (backend, in verifica):** i nuovi operation ID sono vincolati al payload e all'azione da un fingerprint canonico per impedire ACK idempotenti su mutazioni diverse; Flyway V11 è soltanto additiva e non deployata. [Specifica](docs/P2-FULL-BACKUP.md).

**P2.4B2P (rilascio in preparazione):** gate V11 **read-only** con controllo Flyway e della colonna fingerprint, prova automatica PostgreSQL sintetica e runbook separato; V10 storico preservato. [Verifica V11](docs/RELEASE-V11-READINESS.md).


**P2.4B2Q (in sviluppo):** i conflitti di riuso dell'operation ID hanno un codice distinto; Flutter interrompe la sincronizzazione e conserva outbox/SQLite anziché proporre un rebase errato. [Dettagli](docs/P2-SYNC-INTENT-CONFLICTS.md).

**P2.4B2R (in sviluppo):** il gate V11 verifica anche la capability autenticata del backend, impedendo un PASS solo perché le colonne DB sono aggiornate. Nessun deploy o test su dati reali. [Runbook V11](docs/RELEASE-V11-READINESS.md).
