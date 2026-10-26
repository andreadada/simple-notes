# T4 — Rilascio controllato Simple Notes (Coolify/PostgreSQL)

<!-- CURRENT-STATUS-REF -->
> **SNAPSHOT STORICO / GATE 26/10/2026:** `main` include P1.11 Habit Tracker (Flutter `0.16.0+18`, PR #12, CI verde); Countdown P1.12 `0.17.0+19` è **solo su branch**. Funzioni Pomodoro/Habits/Countdown **device-only**, nessuna sync o nuova migration; repo Flyway V10, server Coolify ultimo attestato V8. Nessun deploy/reset. Le istruzioni precedenti descrivono verifiche e versioni storiche, **non** l'attuale rilascio. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Countdown](P1-COUNTDOWNS.md).


## Stato reale verificato e T4.2 (24 ottobre 2026)

**PostgreSQL Simple Notes sulla VPS:** l'utente ha verificato direttamente `simplenotes` (PostgreSQL **17.11**), Flyway **V1–V7 tutte riuscite**, colonne V7 presenti e conteggi in quel momento: **1 utente, 5 task, 4 note, 25 sync_change, 25 sync_operation**. Il dump PostgreSQL reale `simple-notes-20261024T132857Z-271921.dump` ha superato **SHA256 e restore isolato**; il restore non ha toccato produzione. **Copia offsite non eseguita per scelta dell'utente**: non marcarla completata e non riaprire automaticamente la procedura backup.

**Prossimo gate — T4.2 hardware:** verificare il nuovo contratto API autenticato e la sincronizzazione Windows ↔ Android con due build Flutter aggiornate. È disponibile dall'avatar il nuovo dialog Forui **Verifica sincronizzazione**: legge solo SQLite locale e `GET /api/v1/capabilities` con JWT, indica compatibilità `taskDueSchema:1`, modifiche in coda, conteggi locali, cursor e ultimo successo. **Non invia né elimina dati** e consente di copiare un report privo di titoli, note, token o ID account. Dopo sync completa si registra l'ultimo successo; su 426 l'app avvisa e sospende il retry automatico, conservando l'outbox. Test automatizzati dedicati e CI non sostituiscono prove real-device.

La V7 è **già applicata** sul database reale: non ripetere migrazioni o fare Redeploy per questo motivo. La compatibilità **API** e la nuova sync bidirezionale sono ancora da provare. Procedura breve in [T4-DEVICE-SYNC.md](T4-DEVICE-SYNC.md).


**Ultimo aggiornamento: 24 ottobre 2026. DB reale V7, backup SHA256 e restore isolato PASS; copia offsite non eseguita per scelta; API e test hardware da verificare.**

Questo runbook è un gate per la migrazione Flyway V7 delle scadenze T1–T3, non un comando per fare deploy. Le prove in CI utilizzano **soltanto dati sintetici**. Non usare il loro esito come attestazione che il database reale è recuperabile. Backend API di test già su Coolify, stato operativo attuale non verificato da questa procedura.

## T4.1 — Inventario sorgente e prova recente (24/10/2026)

L'incremento T4.1 aggiunge `infra/t4-inspect-db.sh`: **sola lettura**, si esegue sul VPS dopo aver identificato esattamente il container PostgreSQL Simple Notes. Rifiuta un DB differente, PostgreSQL diverso dalla major 17, schema inatteso, migrazioni Flyway fallite/versioni sconosciute e uno stato V7 incompatibile con le colonne realmente presenti. Mostra soltanto versione DB, versione Flyway, conteggi di righe per tabella e presenza delle cinque colonne `due_*`, non email o righe di utenti.

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_DEL_POSTGRES_SIMPLE_NOTES>' \
EXPECTED_POSTGRES_DB='simplenotes' \
  bash infra/t4-inspect-db.sh
```

**Stato 24/10:** backup SHA256 e restore isolato con ricevuta `.restore-ok` già eseguiti. Offsite non effettuata per scelta: resta requisito distinto della release formale, non condizione per iniziare T4.2. Il gate `t4-preflight.sh` ora richiede una verifica di restore **recente (24 ore)**, controlla data UTC non futura e rifiuta ricevute scadute. Per finestre più lunghe è possibile `T4_MAX_RESTORE_AGE_HOURS` da 1 a 168; non usarlo per eludere il restore. Questi controlli sono verificati in CI con **dati sintetici**, non rappresentano la prova del VPS.

## Fonti tecniche verificate

- [Coolify: Backups PostgreSQL e S3](https://coolify.io/docs/databases/backups) — database anche dentro uno stack Service, scope e retention separati.
- [Coolify: import/restore](https://coolify.io/docs/databases/restore) — attenzione: un import può sostituire dati; **non fare prove sul database operativo**.
- [PostgreSQL 17: pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html) — `--single-transaction`, `--exit-on-error`, controllo della struttura.
- [Flyway: validate](https://documentation.red-gate.com/flyway/reference/commands/validate) — confronta checksum e storia delle migrazioni applicate.

## T4 già implementato

| File | Scopo | Effetti sul DB operativo |
| --- | --- | --- |
| `infra/backup-postgres.sh` | Verifica nome DB/container e tabelle; `pg_dump -Fc`, catalogo, SHA256, permessi 600 | Lettura soltanto |
| `infra/verify-restore.sh` | SHA256 richiesto; PostgreSQL 17 temporaneo `--network none`, restore transazionale, query alle tabelle e attestato `.restore-ok` | **Nessuna connessione** |
| `infra/t4-preflight.sh` | Confronta dump, manifest, receipt, attestazione offsite e SHA Git approvato | Nessuna connessione |
| `infra/t4-check-api.sh` | HTTPS health UP e capability autenticata `taskDueSchema:1` | GET soltanto |
| `.github/workflows/compose-ci.yml` | Smoke test restore con fixture sintetica e prove di rifiuto di file modificati / attestazione assente | Nessuno |
| `T4MigrationRehearsalTest.java` | PostgreSQL Testcontainers V6→V7: conserva task, note, liste, sync outbox/id/versioni, vincoli | Nessuno |

Il receipt `.restore-ok` certifica un restore **locale** eseguito con successo su un dump avente lo SHA indicato, non la conservazione offsite, l'esistenza attuale del file in S3, o lo stato del database di produzione. Il gate `T4_OFFSITE_CONFIRMED=yes` è una dichiarazione **manuale**; non usare `yes` se la copia offsite non è stata controllata.

## 0. Sicurezza e preparazione

- Evitare qualsiasi `docker compose down -v`, `DROP DATABASE`, `pg_restore --clean` sul DB reale, rimozione o modifica dei volumi, esposizione di PostgreSQL sulla rete pubblica.
- Verificare se Coolify ha auto-deploy su `main`; per il rollout coordinato **sospenderlo** temporaneamente e mantenere l'API al commit attuale finché non hai verificato backup/restore.
- Annotare **SHA Git attuale backend** e applicativo, versione PostgreSQL (attesa 17), nomi reali dei container, Flyway attuale e che l'outbox su Windows e Android sia sincronizzata o preservata.
- Definire una finestra di manutenzione. Nessun cambio segreti, OAuth, volume o immagine PostgreSQL major in T4.
- Non mettere dump, log con dati personali o token in GitHub Actions artifacts, issue, screenshot, chat o repository.

## 1. Dump corretto sul VPS

Da una copia della repository alla revisione che si vuole rilasciare (con permessi Docker):

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
# Individuare IL container PostgreSQL di Simple Notes, non uno di altri servizi.
DB_CONTAINER='<ID_O_NOME_POSTGRES_SIMPLE_NOTES>' \
EXPECTED_POSTGRES_DB='simplenotes' \
BACKUP_DIR='/percorso/privato/backup' bash infra/backup-postgres.sh
```

Lo script rifiuta DB con nome inatteso o schema Simple Notes mancante. Produce `simple-notes-...dump` e `simple-notes-...dump.sha256`. **Non considera recuperabile** il file solo perché esiste. Per DB con nome diverso, impostare espressamente `EXPECTED_POSTGRES_DB` dopo la verifica manuale del container. L'archivio è un backup di dati personali: proteggere la cartella e gli accessi.

Usare inoltre Coolify → Service → componente PostgreSQL → **Backups** per impostare il backup programmato con retention e caricamento **S3 compatibile**, se la versione della tua installazione supporta la funzione. Controllare la pagina **Executions**: il backup riuscito non equivale a prova di restore. Una copia **cifrata** offsite è necessaria; controllarne realmente scaricabilità e checksum.

## 2. Copia offsite e ripristino in isolamento

Trasferire in modo cifrato il file e il manifest, e ripetere la verifica preferibilmente sul sistema che detiene la copia:

```bash
# Per un archivio scelto ESPLICITAMENTE: sostituire il percorso segnaposto.
ARCHIVE='/percorso/privato/backup/simple-notes-AAAA-MM-GG.dump'
(cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE").sha256")
bash infra/verify-restore.sh "$ARCHIVE"
test -s "$ARCHIVE.restore-ok"
```

Il nome nel manifest è relativo alla cartella che contiene il dump: in caso di spostamento, usare `(cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE").sha256")`. Il restore usa un container PostgreSQL **nuovo e temporaneo**, rete disabilitata, senza porte, volumi condivisi o collegamenti al DB originale. Verifica almeno `app_user`, `task`, `note`, `sync_change`, `sync_operation`; scrive nel receipt SHA256, identificativi delle tabelle e **conteggi numerici ripristinati** (non dati personali), e rifiuta un archivio con `app_user` vuoto. I conteggi sono evidenza strutturale, non confronto transazionale con dati nel frattempo cambiati sul server. Se il restore fallisce, **NON procedere**.

## 3. Preflight bloccante (senza deployment)

```bash
T4_ARCHIVE="$ARCHIVE" \
T4_OFFSITE_CONFIRMED=yes \
T4_APPROVED_COMMIT="$(git rev-parse HEAD)" \
bash infra/t4-preflight.sh
```

Usare `yes` **solo** se hai controllato una copia offsite distinta e sicura. La preflight blocca file, checksum, ricevuta, commit e working tree non coerenti. Non invoca Coolify, non migra e non interrompe servizi.

## 4. Deployment manuale e verifiche immediate

1. Dal dashboard Coolify selezionare il progetto/Service Simple Notes e confrontare **il commit deployato** con `T4_APPROVED_COMMIT`, senza cambiare variabili d'ambiente o volumi.
2. Dopo conferma backup e preflight, eseguire **Redeploy** del solo stack configurato, monitorando Deployment Logs e startup. Flyway deve applicare `V7__task_due_semantics.sql` **una sola volta**; Flyway validate non deve segnalare checksum invalidi. Se compare qualsiasi errore, fermare il rollout e conservare i dati; non usare `flyway repair` per nascondere un problema.
3. Verificare `https://api.notes.ddone.it/actuator/health` e usare un **token utente di test a breve vita** (non scriverlo nei log):
   ```bash
   API_BASE_URL='https://api.notes.ddone.it' \
   T4_BEARER_TOKEN='<TOKEN_DI_TEST_VALIDO>' \
   bash infra/t4-check-api.sh
   ```
4. Verificare la storia Flyway nel container DB con una **SELECT in sola lettura** e il DB esatto:
   ```bash
   docker exec '<ID_POSTGRES_SIMPLE_NOTES>' sh -c \
     'exec psql -X -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
       -c "SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank;"'
   ```
5. Controllare login Google, refresh, creazione e sincronizzazione con account di test, senza modificare dati personali di altri utenti.

**Rollback:** se il nuovo client/backend non funziona, mettere in pausa scritture e analizzare i log. Re-deploy dell'immagine applicativa precedente **non annulla Flyway V7**: lo schema è additivo, ma i vecchi client non supportano tutte le nuove scadenze. Non provare downgrade automatico del DB e non ripristinare un dump sopra la produzione mentre ci sono scritture: ciò perderebbe le modifiche successive al backup. Il ripristino reale richiede una procedura di incidente e decisione esplicita.

## 5. Device acceptance e chiusura

Eseguire [checklist operativa](P0-DEVICE-CHECKS.md) con due dispositivi aggiornati e stesso account: data-only, `00:00`, DST gap/fold Europe/Rome, filtri Oggi/7 giorni, modifica titolo e sottotask, avvio offline/online, outbox, conflitto 409, backend incompatibile 426. Registrare data, commit, versione client, esito, screenshot/log senza dati sensibili.

**Criterio di chiusura T4:** (1) dump SHA256 e restore reale PASS, (2) Flyway V7 nel DB PASS, (3) offsite/preflight quando si pianifica una release formale ancora non completati, (4) API health/capability da verificare, (5) test Windows/Android reali da eseguire. **T4 IN CORSO**; T4.2 non richiede ripetere backup o migrazioni.
