# Stato corrente — Simple Notes

**Aggiornamento:** 25 ottobre 2026, dopo merge P1.7 Android PR #6. Questo documento è la fonte di verità per la versione del codice; i file T2/T3/T4 e P0/P1 precedenti costituiscono storico tecnico, non lo stato operativo attuale.

## Codice e distribuzione

| Contesto | Stato |
|---|---|
| `main` | P1.1–P1.6 e P1.7 Android integrate; PR #6 merge `df40b93e`, Flutter `0.11.0+13` |
| Backend su `main` | Migrazioni Flyway fino a **V10** e capability `recurrenceSchema:1` oltre a `timeBlocksSchema:1`, oltre a time blocking e date-only |
| Drift client su `main` | Schema **V8** |
| Incremento **P1.7** | **Integrato su main con PR #6**: planner, ledger, opt-in e scheduling **nativo Android inexact** con autorizzazione esplicita; **non verificato su dispositivo reale**, non ancora distribuito. **Windows ZIP: notifiche disabilitate**, serve MSIX/package identity |
| VPS Coolify | **Ultima verifica effettivamente fornita dall'utente:** Flyway V8, PostgreSQL17, `BLOCK_COLUMNS=3`, `FAILED_MIGRATIONS=0`, health `UP` alle 12:02 circa del 25/10/2026. La presenza di V9/V10 sulla VPS non è stata verificata. |
| Windows/Android | CI Flutter `0.11.0+13` verde: analyze/test, Windows release e APK JDK17/21 (run [40231569864](https://github.com/andreadada/simple-notes/actions/runs/40231569864)). Installazione `0.11.0+13` e verifica E2E **non confermate**. Non supporre che i client siano già alla versione di `main`. |
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
| P1.7 Windows e UX avanzata | Disabilitata la delivery sul client EXE/ZIP senza package identity; nessuno snooze o impostazione per task | Packaging MSIX, cancel affidabile Windows, test e rifiniture |
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

- P1.6 integrata in repository e P1.7 Android integrata con PR #6 (CI Flutter verdi). Verificare deployment backend V10 prima di installare client 0.11.
- P1.7 Android: scheduling nativo opt-in **implementato**, **mai attestato su dispositivo**. Per Windows va realizzato MSIX/package identity e cancellazione affidabile; non pubblicizzare P1.7 come completata su entrambe le piattaforme.
- Verificare automaticamente la migrazione Flyway più recente *effettivamente deployata* prima di installare la successiva versione Flutter.
- Fare un collaudo E2E Windows/Android una sola volta a fine gruppo: login, note, task, scadenze, multi-block, sync offline/online, conflitti, cancellazione/restore, ricorrenze, reminder Android se attivati, permessi, logout/cancel; nessun collaudo notifiche Windows finché il packaging non è implementato.
