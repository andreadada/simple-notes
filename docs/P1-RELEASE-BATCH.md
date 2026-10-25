# Rollout coordinato — Simple Notes P1.6 (V10)

**Stato:** runbook preparato in repository; nessun deploy né installazione device eseguiti dalla PR #5. L'utente ha scelto di effettuare personalmente il deploy Coolify **dopo** il gruppo di incrementi. I comandi sono istruzioni di sola lettura salvo il pulsante **Redeploy** esplicitamente indicato.

## Prima di agire

- Controllare `main` e il commit esatto da distribuire. **Non distribuire un branch in bozza o una PR con CI rossa.**
- Coolify: risorsa **Simple Notes** Docker Compose già esistente, file root `docker-compose.yml`, database `simplenotes` con volume persistente esistente. Non creare una seconda risorsa DB.
- Conservare volumi, utenti, segreti e cache offline esistenti. **Non eseguire** `docker compose down -v`, `adb uninstall`, `pm clear`, reset dati o rebootstrap non necessario.
- V8 è l'ultima versione *verificata realmente* in chat; il codice P1.5 include V9 e P1.6 aggiunge V10, ma Coolify può avere una diversa versione se auto-deploy è attivo. Non dedurre l'attuale schema da GitHub.
- Le migrazioni V9/V10 sono additive ma non prive di rischio operativo. Backup prima del cambiamento è raccomandato; il proprietario ha scelto di rinviarlo e accetta il rischio residuo.

## 1 — Inventario pre-deploy, VPS

```bash
cd ~/simple-notes
git pull --ff-only origin main
docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep gs0yzfz42hpriybaxcfbtjnk

# Usare l'ID PostgreSQL corretto mostrato sopra, non un segnaposto letterale.
DB_CONTAINER=<ID_DB_REALE> EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-inspect-db.sh
```

Il controllo deve passare in sola lettura, per V8, V9 o V10 effettive. Se fallisce STOP, leggere l'errore senza forzare Flyway né cancellare volumi. Verificare che esistano i segreti applicativi invariati in Coolify.

## 2 — Deploy backend con Flyway prima di Flutter

In Coolify, aprire la **risorsa preesistente** Simple Notes, branch `main`; verificare il commit e usare **Redeploy** solo se la risorsa non è già alla versione approvata. Non fare modifiche manuali al volume o alle variabili. Flyway esegue V9 e V10 in sequenza automaticamente quando ancora mancanti, utilizzando i lock standard.

## 3 — Conferme obbligatorie

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep gs0yzfz42hpriybaxcfbtjnk
DB_CONTAINER=<ID_DB_AGGIORNATO> EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-inspect-db.sh
curl -fsS https://api.notes.ddone.it/actuator/health
```

Valori attesi per P1.6:

```text
T4_SOURCE_INSPECTION=PASS
POSTGRES_MAJOR=17
FLYWAY_LATEST=10
DUE_COLUMNS=5
BLOCK_COLUMNS=3
BLOCKS_JSON_COLUMNS=1
RECURRENCE_COLUMNS=1
FAILED_MIGRATIONS=0
```

Health deve restituire `{"status":"UP"}`. Su endpoint autenticato `/api/v1/capabilities` verificare **`taskDueSchema:1`**, **`timeBlockSchema:1`**, **`timeBlocksSchema:1`** e **`recurrenceSchema:1`**, usando JWT in locale: **non inserire token nei messaggi, screenshot o log**. Il semplice health UP non dimostra tutte le capability.

## 4 — Client soltanto quando backend è compatibile

Sul PC con repository aggiornato su `main`:

```powershell
cd E:\dev\simple-notes
git status --short
git pull --ff-only origin main
.\tools\t4-build-devices.ps1 -Target both
```

Lo script rispetta i file locali, ma stampa un warning se ci sono modifiche tracciate; non fare `git reset --hard` né `stash` automatizzato. Richiede la configurazione OAuth locale. La compilazione non installa né ripristina SQLite; controllare manifest SHA, versione Flutter e output.

Installare Windows conservando tutte le librerie nella directory dell'archivio ZIP. Su Android usare `adb install -r` con la firma compatibile, **non disinstallare** se c'è errore di firma.

## 5 — Unico collaudo di batch

Verificare con lo **stesso account Google**: dati Windows↔Android, note e cestino, task/list/tag/subtask, scadenza date-only e timed fuso IANA, multi-block 2+ slot e drag, ricerca/filter/quick plan, ricorrenze daily/weekly/monthly (stesso UUID dopo completamento), offline→online e outbox pending=0, doppia modifica/conflitto 409, protezione vecchio client 426. Verificare DST gap/fold su casi di prova non distruttivi. Non segnare «deploy completato» fino a queste conferme.

## Limiti

- P1.6 **non** include notifiche native o generazione automatica a client chiuso; promemoria P1.7 restano un incremento distinto.
- Un downgrade del codice **non** annulla in sicurezza migrazioni Flyway già applicate. Non tentare di tornare a V8 cancellando manualmente le colonne.
- In caso di migration ERROR o HTTP426 fermarsi e diagnosticare, mantenendo i dati/operazioni in coda: evitare azioni distruttive.
