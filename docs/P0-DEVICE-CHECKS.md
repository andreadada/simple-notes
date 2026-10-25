> **Stato 25/10/2026:** tutti i dati di test Simple Notes server/Windows/Android sono stati azzerati e il server confermato con contatori 0. Non riavviare un reset. P1.1 su main `0.5.0+7`; P1.2 su branch `feature/p1-2-time-blocking` `0.6.0+8`, non rilasciato. **Prima di client P1.2** eseguire rollout backend V8 controllato e controllare capabilities `timeBlockSchema:1`; poi due dispositivi offline/online, blocco inizio-fine, DST e cancellazione blocco indipendente dalla scadenza. Vedi [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). I check storici più sotto rimangono come riferimento per P0, non come invito a ricancellare dati. 

# P0 — Checklist operativa Coolify, Windows e Android

## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](T4-DEVICE-SYNC.md).


## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


**Aggiornato: 24 ottobre 2026.** Questa checklist NON certifica alcun deploy. L'obiettivo è raccogliere prove reali distinguendole dai test automatici. Non inserire token/password nei log condivisi.

## T4.1 — Primo controllo operativo (read-only)

- [x] **Verificato sul VPS (24/10)**: identificato e controllato il DB reale; comando `DB_CONTAINER='<ID>' EXPECTED_POSTGRES_DB=simplenotes bash infra/t4-inspect-db.sh`.
- [x] Registrato l'esito read-only: PostgreSQL 17.11, Flyway V7 riuscita, 5 colonne scadenza e conteggi senza contenuti personali.
- [ ] Solo per un futuro rilascio formale, verificare di nuovo la validità temporale della ricevuta `.restore-ok` e i gate preflight. Non rifare il backup per la verifica T4.2.
- [ ] Confermare che CI sintetiche e strumenti in repository NON certificano il database Coolify.

## Gate obbligatorio prima del redeploy
- [ ] Identificare esplicitamente il container PostgreSQL del progetto Simple Notes (NON altri database).
- [x] Dump reale creato con `infra/backup-postgres.sh`, verifica SHA256 riuscita (24/10).
- [x] `infra/verify-restore.sh` eseguito **sul dump reale** nel PostgreSQL 17 isolato senza rete: SUCCESS e ricevuta `.restore-ok`. La copia esterna resta distinta.
- [ ] Conservare e controllare una copia del dump cifrata **fuori dal VPS**, con policy di retention; eseguire il gate `infra/t4-preflight.sh` con attestazione offsite esplicita.
- [x] Flyway V1–V7 **già presente e riuscita** nel database reale; non è necessario ripeterla.
- [ ] Verificare API autenticata `taskDueSchema:1` da Windows e Android con la nuova diagnostica; confermare health e sync reale, senza un nuovo redeploy.
- [ ] Verificare login Google/refresh sulle nuove build senza presupporre un redeploy.

Comandi esatti e precauzioni in [infra/README.md](../infra/README.md). **Non usare mai `docker compose down -v` o disinstallazione dell'app come soluzione ai problemi di sync.**

## Test obbligatori T3 prima del rilascio

- [x] Backup PostgreSQL reale, checksum, restore isolato e Flyway V7 verificati; **copia offsite non eseguita**, scelta esplicita dell'utente.
- [ ] API capability autenticata `taskDueSchema:1` e sync Windows/Android da verificare sul client aggiornato.
- [ ] Windows → Android e viceversa: data-only 26/10 rimane 26/10 anche cambiando fuso del dispositivo.
- [ ] Scadenza esplicita `00:00` resta datetime con timezone IANA e istante UTC corretto; rename non tocca `due`.
- [ ] Europe/Rome 29/03/2026 02:30: nessun salvataggio (gap DST); 25/10/2026 02:30: mostra prima (+02) e seconda (+01) occorrenza e conserva la scelta.
- [ ] Oggi e Prossimi 7 giorni: test oltre il cambio ora e scaduti; filtri coerenti dopo riavvio.
- [ ] Offline / restart / 409 / 426: mutazioni in coda non perse, server obsoleto non riceve `date/datetime`.
- [ ] Validazione visiva input, tastiera, Forui modal, layout touch e accessibilità su Windows/Android.

## Test con lo stesso account su due dispositivi aggiornati
- [ ] Nuova lista vuota da Windows → Android; rinominare toccando il titolo in Android → Windows.
- [ ] Task dentro lista: cambiare priorità, tag, descrizione e sottotask su un device → verificare sull'altro.
- [ ] Modificare/completare un sottotask su Android → Windows; completare un task su PC → Android.
- [ ] Riavviare le due app: dati e sessione persistono (senza re-login inatteso).
- [ ] Creare task/nota offline su telefono → tornare online → visualizzare su Windows senza perdita di outbox.
- [ ] Modificare contemporaneamente la stessa nota su PC e Android → compare scelta esplicita 409, nessun overwrite automatico; testare entrambe le scelte con elementi di prova.
- [ ] Eliminare lista contenente task → gli elementi restano in Inbox; confermare stesso stato sull'altro device.
- [ ] Eliminare task e nota di prova → nessuna riapparizione dopo re-sync/riavvio; verificare isolamento cambiando account in ambiente di test.

## Registrazione prove
Per ogni test annotare data, commit/API deployata, build installata, device/OS, risultato, eventuale codice HTTP e foto/log senza dati sensibili. Esempio:

`2026-10-23 | backend SHA: ... | Windows SHA: ... | Android SHA: ... | test: lista vuota | OK/FAIL | note: ...`

Finché non tutti i gate sono verificati, **P0 in corso**, non production-ready. Se il restore non è riuscito, fermare il redeploy e correggere il backup in ambiente isolato.
