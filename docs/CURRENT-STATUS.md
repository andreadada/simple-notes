# Stato corrente — Simple Notes

> **Stato sviluppo 26/10/2026:** P1.7 Windows **integrata su `main`** (PR #7, Flutter `0.12.0+14`, [CI verde](https://github.com/andreadada/simple-notes/actions/runs/40245561264)); package MSIX/non-EXE, **nessun test hardware/installazione**. P1.8 Matrice Eisenhower sviluppata su branch `feature/p1-8-eisenhower-matrix` (Flutter `0.13.0+15`, [specifica](P1-EISENHOWER.md)), **CI e merge da verificare**. Ultimo Coolify attestato Flyway V8; V9/V10 reali non verificati; nessun deploy/reset in questa attività.

**Aggiornamento:** 26 ottobre 2026, dopo merge P1.7 Windows PR #7. P1.8 in sviluppo su branch. Questo documento è la fonte di verità per la versione del codice; i file T2/T3/T4 e P0/P1 precedenti costituiscono storico tecnico, non lo stato operativo attuale.

## Codice e distribuzione

| Contesto | Stato |
|---|---|
| `main` | P1.1–P1.6, P1.7 Android e Windows MSIX integrate (PR #6/#7, Flutter `0.12.0+14`); P1.8 in branch `feature/p1-8-eisenhower-matrix` (`0.13.0+15`), CI da verificare |
| Backend su `main` | Migrazioni Flyway fino a **V10** e capability `recurrenceSchema:1` oltre a `timeBlocksSchema:1`, oltre a time blocking e date-only |
| Drift client su `main` | Schema **V8** |
| Incremento **P1.7** | Android (PR #6) opt-in inexact; Windows (PR #7) opt-in solo con package identity MSIX. CI Android/Windows/MSIX verde sul commit di PR #7; **device reali e upgrade MSIX non collaudati**, Windows ZIP sempre disabilitato |
| VPS Coolify | **Ultima verifica effettivamente fornita dall'utente:** Flyway V8, PostgreSQL17, `BLOCK_COLUMNS=3`, `FAILED_MIGRATIONS=0`, health `UP` alle 12:02 circa del 25/10/2026. La presenza di V9/V10 sulla VPS non è stata verificata. |
| Windows/Android | CI Flutter `0.12.0+14` verde: analyze/test, Windows EXE e MSIX, APK JDK17/21 ([run 40245561264](https://github.com/andreadada/simple-notes/actions/runs/40245561264)). Installazione e verifica E2E **non confermate**. Non supporre che i client siano già alla versione di `main`. |
| Collaudo | Aggregato alla fine di più incrementi, secondo richiesta. Nessun reset dei dati; non ripetere test hardware a ogni feature. |

Le CI verificano il codice e producono artefatti, **non** dimostrano un deploy. La disponibilità di una nuova versione su `main` può innescare l'auto-deploy Coolify, se attivo: leggere il commit dell'immagine e verificare il DB prima di aggiornare i client.

## Matrice incrementi

| Fase | Implementazione | Gate ancora aperto |
|---|---|---|
| P0 | Auth Google, task/note/liste, auto-sync, outbox, protezione conflitti, Forui, edit inline e diagnostica | Test end-to-end Windows ↔ Android / hardening |
| T2/T3/T4 | Date-only/timezone IANA, Flyway V7 e health, Flyway V8 verificata | Collaudo dispositivi e compatibilità in produzione |
| P1.1 | Giorno/settimana/mese | Prova UI reale |
| P1.2–P1.3 | Singolo time block, drag/resize, DST, Flyway V8 | Prova UX sui dispositivi |
| P1.4 | Fino a 12 blocchi per task, V9/Drift V7, summary ore, API 426 legacy | Flyway V9 reale e prova multi-device |
| P1.5 | Filtri e pianificazione rapida, Flutter 0.9, nessuna migrazione | Prova UI reale |
| P1.6 | Ricorrenze giornaliere/settimanali/mensili integrate in `main`, V10/Drift V8 | Deploy Coolify e acceptance hardware |
| P1.7 Android | Opt-in, permessi Android, reminder inexact, ledger e riconciliazione integrati con PR #6; CI verde | Prove vere Android (app chiusa, Doze/reboot, permessi negati, logout, DST) |
| P1.7 Windows | MSIX+opt-in integrati su `main`; ZIP/EXE disabilitato, nessuno snooze | Prove MSIX installato, gestione SQLite/OAuth e cancel nativi su PC |\n| P1.8 Matrice Eisenhower | Quattro quadranti derivati da priorità/scadenza, editing inline, Forui responsive **solo nel branch** | CI su SHA finale, merge e device E2E |
| P2/P3 | Estensioni web/condivisione/export e ulteriori fasi | Pianificate |

## Regole vincolanti

1. **Modifica inline:** titolo e attributi visualizzati direttamente editabili dove praticabile; non introdurre schermate «Rinomina» non necessarie.
2. **Forui** come base UI, finestre e picker; non creare dialog Material incoerenti.
3. **Offline-first e account:** preservare dati locali, outbox/operation ID, remoteVersion, cursor e boundOwner; nessun reset/installazione distruttiva, mai eliminare i volumi Coolify.
4. **Backward protection:** capability autenticata prima di nuovi payload, rifiuto HTTP 426 per client legacy che eliminerebbero attributi moderni; non considerare i 409 conflitti un successo.
5. **Release:** aggiornare server Flyway/capability, verificare stato DB e API, poi client; test hardware solo in un gate batch quando richiesto.
6. Non modificare i dati di produzione dalla CI; i test PostgreSQL/Testcontainers usano DB isolati.

## Riferimenti chiave

- [Roadmap completa](../project.md)
- [Regole prodotto](../design.md), [regole agenti](../AGENTS.md)
- [P1.4 multi-block](P1-MULTI-BLOCKS.md), [P1.5 quick planning](P1-QUICK-PLANNING.md), [P1.6 recurrence](P1-RECURRENCE.md), [P1.7 reminder Android](P1-REMINDERS-FOUNDATION.md)
- [Protocollo sync](sync.md), [API](api.md), [database e VPS](../infra/README.md)
- [Runbook deploy batch P1.6 V10](P1-RELEASE-BATCH.md), [rilascio storico V8](P1-RELEASE-0.7.0.md) e [test su dispositivi](T4-DEVICE-SYNC.md)

## Compiti aperti prima del prossimo rilascio

- P1.6 integrata in repository e P1.7 Android integrata con PR #6 (CI Flutter verdi). Verificare deployment backend V10 prima di installare client 0.12/0.13.
- P1.7 Android: scheduling nativo opt-in **implementato**, **mai attestato su dispositivo**. Windows MSIX nel codice dopo PR #7, ma manca test fisico e firma release; non pubblicizzare la delivery come attestata su entrambe le piattaforme.
- Verificare automaticamente la migrazione Flyway più recente *effettivamente deployata* prima di installare la successiva versione Flutter.
- Fare un collaudo E2E Windows/Android una sola volta a fine gruppo: login, note, task, scadenze, multi-block, sync offline/online, conflitti, cancellazione/restore, ricorrenze, reminder Android se attivati, permessi, logout/cancel; verifica notifiche Windows solo su installazione MSIX firmata, senza perdita dati.
