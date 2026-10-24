# P0 — Checklist operativa Coolify, Windows e Android

**Aggiornato: 24 ottobre 2026.** Questa checklist NON certifica alcun deploy. L'obiettivo è raccogliere prove reali distinguendole dai test automatici. Non inserire token/password nei log condivisi.

## Gate obbligatorio prima del redeploy
- [ ] Identificare esplicitamente il container PostgreSQL del progetto Simple Notes (NON altri database).
- [ ] Eseguire un dump consistente con `infra/backup-postgres.sh`, verificare il file SHA256 e la leggibilità dell'archivio.
- [ ] Eseguire `infra/verify-restore.sh` sul dump **reale** in un PostgreSQL 17 temporaneo e isolato. Controllare dati/tabelle senza scrivere nel DB di produzione.
- [ ] Conservare una copia del dump cifrata **fuori dal VPS**, con policy di retention.
- [ ] Solo dopo, distribuire il backend `main` su Coolify senza modificare segreti e senza ricreare volumi. Controllare migrazioni Flyway V5 e V6 dai log (senza errori) e `https://api.notes.ddone.it/actuator/health`.
- [ ] Verificare login Google / refresh dopo il redeploy, prima di aggiornare i client.

Comandi esatti e precauzioni in [infra/README.md](../infra/README.md). **Non usare mai `docker compose down -v` o disinstallazione dell'app come soluzione ai problemi di sync.**

## Test obbligatori T3 prima del rilascio

- [ ] Backup PostgreSQL reale, checksum, ripristino isolato e copia offsite prima del deploy; confermare Flyway V7, health e `taskDueSchema:1` dopo backend Coolify.
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
