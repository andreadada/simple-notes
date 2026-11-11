# Gate cumulativo R1 — Server-first Flyway V10 e capability

> **Stato attuale 11/11/2026:** Flyway V15 è nel repository dopo PR #66/#67; la VPS è attestata soltanto a V10 dal 03/11. Questo file contiene istruzioni storiche, non un permesso di migrazione. Per il rollout futuro usare [RELEASE-V15-READINESS](RELEASE-V15-READINESS.md) dopo una decisione esplicita e lo [stato corrente](CURRENT-STATUS.md).

**Cronologia al 02/11/2026:** strumenti read-only integrati su `main` con [PR #26](https://github.com/andreadada/simple-notes/pull/26). [Compose CI #41523319857](https://github.com/andreadada/simple-notes/actions/runs/41523319857) e [Markdown #41523319860](https://github.com/andreadada/simple-notes/actions/runs/41523319860) success, esclusivamente su dati sintetici. La VPS reale **non è stata interrogata** durante questo incremento: l'ultima attestazione documentata è Flyway V8; il repository contiene Flyway V10. **Nessun deploy, backup, restore, reset o installazione effettuato.**

## Obiettivo e limiti

Prima di usare su Windows e Android il client cumulativo Flutter `0.30.0+32`, verificare il **backend esistente** con identità precisa del container PostgreSQL, senza introdurre un secondo DB/volume e senza cancellare SQLite/outbox o SharedPreferences. Distinguere sempre questi tre livelli:

1. **Codice e CI:** repository `main`, backend V10 con migrazioni V8/V9/V10 e capability dichiarate.
2. **Reale VPS:** versione Flyway, colonne presenti, migrazioni fallite, health HTTPS e capability autenticate. Sono evidenze che **non** possono essere dedotte da GitHub Actions.
3. **Reali client:** OAuth e sincronizzazione offline PC ↔ Android, dati conservati, notifiche, tray, ZIP→MSIX, app riavviata. Resta gate separato.

I nuovi comandi di questo incremento **non eseguono** `docker compose up`, `docker restart`, Flyway migrate, INSERT, pg_dump, pg_restore, `git reset`, `adb install`, upgrade o disinstallazioni.

## Prima del deploy — sola lettura sulla VPS

Identificare il container giusto: gli ID Docker possono variare dopo ogni deploy.

```bash
cd ~/simple-notes
git status --short
docker ps --format '{{.ID}} {{.Names}} {{.Image}}'
DB_CONTAINER='<ID_REALE_POSTGRES_SIMPLE_NOTES>' \
EXPECTED_POSTGRES_DB=simplenotes \
  bash infra/t4-inspect-db.sh
```

L'ispezione ammette V8 nella fase **pre**-upgrade, ma la versione effettiva della VPS deve essere letta dall'output, non presunta. Deve mostrare `T4_SOURCE_INSPECTION=PASS`, `DB_NAME=simplenotes`, PostgreSQL 17, `FAILED_MIGRATIONS=0`, presenza dei campi coerente con l'ultima migrazione, e conteggi di `app_user/task/note/sync_change/sync_operation`. Non inviare in chat token, ID account, email o dump. I **soli conteggi** sono sufficienti a registrare la baseline.

**Non procedere con l'installazione client** se la VPS è ancora V8 o se le capability mancano. L'eventuale aggiornamento API/DB attraverso Coolify è una **operazione separata e autorizzata**, dopo controllo delle condizioni del servizio, backup recente verificato e politica offsite; non fa parte di questo incremento read-only. Non modificare il volume o ricreare PostgreSQL per forzare V10.

## Dopo un deploy autorizzato — gate server completo

Con il repository aggiornato sul VPS, sul container PostgreSQL corretto e con un **access token temporaneo** di un utente di prova, fornito come variabile d'ambiente **solo nella sessione amministrativa**:

```bash
cd ~/simple-notes
# Imposta DB_CONTAINER con l'ID corrente verificato da docker ps.
# T4_BEARER_TOKEN deve già essere nella sessione (mai incollarlo in chat).
DB_CONTAINER='<ID_REALE_POSTGRES_SIMPLE_NOTES>' \
EXPECTED_POSTGRES_DB=simplenotes \
API_BASE_URL=https://api.notes.ddone.it \
  bash infra/release-readiness.sh
```

`release-readiness.sh` richiede esplicitamente `DB_CONTAINER` e `T4_BEARER_TOKEN`; chiama, nell'ordine:

- `REQUIRE_FLYWAY_VERSION=10 bash infra/t4-inspect-db.sh` — database PostgreSQL 17, DB corretto, ultime migrazioni tutte `success`, colonna V7 completa `due_*`, tre colonne V8, colonna `blocks_json` V9, `recurrence_json` V10, nessuna Flyway fallita e conteggi core.
- `REQUIRE_TIME_BLOCK_SCHEMA=1 REQUIRE_FULL_SCHEMA=1 bash infra/t4-check-api.sh` — `GET /actuator/health` con `status=UP`, poi `GET /api/v1/capabilities` **con bearer**. Sono obbligatorie `taskDueSchema=1`, `timeBlockSchema=1`, `timeBlocksSchema=1`, `recurrenceSchema=1`, `noteRestoreSchema=1`, supporto dei kind none/date/datetime/legacy e `requiresExplicitDueForModernTasks=true`.
- Solo dopo entrambi i PASS produce `RELEASE_SERVER_GATE=PASS`. Fallimenti stampano cause **senza restituire body HTTP, token o altri dati utente**.

La vecchia chiamata `t4-inspect-db.sh` senza versione e `t4-check-api.sh` senza strict flag **restano compatibili** con le ispezioni storiche. Un `health=UP` senza contratto autenticato **non** autorizza il client moderno. L'access token non deve essere inserito negli argomenti shell, nei file sotto Git o nei report.

## Collaudo finale Windows/Android — successivo al PASS server

Su Windows, dal checkout aggiornato di `main` (senza scartare modifiche locali):

```powershell
cd E:\dev\simple-notes
git status --short
git pull --ff-only origin main
.\tools\t4-build-devices.ps1 -ValidateOnly
.\tools\t4-build-devices.ps1 -Target both -RequireClean
```

Lo script genera **solo** ZIP Windows, APK debug e manifest SHA256; **non installa** nulla. Per le build occorrono i due Google OAuth Client ID nel file privato `.t4-device-build.json`. `-RequireClean` evita build non riproducibili; se il checkout contiene modifiche legittime, verificare e conservarle, non eseguire `reset --hard`.

Collaudo su profili e dati di prova, senza `uninstall`, `pm clear`, reset SQLite o nuovo DB:

- Stesso account su PC/Android; avatar → **Verifica sincronizzazione** su entrambi; controllare capability, cursor, pending e assenza 426.
- Creare un task su PC, sincronizzarlo su Android; ripetere Android→PC con note e liste; offline→online, conflitto 409 e cursor avanzato, senza perdita di outbox.
- Scadenze date-only e orari IANA, blocchi multipli, RRULE task; promemoria, tray e Sticky Windows, layout mobile/light/dark e riavvio.
- File ICS e feed HTTPS dal dispositivo, aggiornamento esplicito e cache offline, nomi inline e owner switch. L'ICS non è sincronizzato fra dispositivi.
- Firma Android: solo `adb install -r` **se** la firma coincide. Non disinstallare per aggirare `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- Windows ZIP ≠ MSIX: prima di cambiare packaging assicurare continuità di percorsi SQLite, outbox, secure storage e preferenze (ICS, Pomodoro, Habit); non installare MSIX sul profilo reale senza questa verifica.

## Risultato previsto e limiti

| Livello | Evidenza richiesta | Stato prima del collaudo reale |
|---|---|---|
| Backend repo | V10 e capability nel codice, test Testcontainers CI | Presente nel codice |
| VPS reale | Script read-only `RELEASE_SERVER_GATE=PASS` | **NON VERIFICATO** |
| Backup/offsite | Evidenza recente conforme alla policy del rilascio | **NON ATTESTATO per questo incremento** |
| Windows/Android | stessa versione e firma, OAuth, sync e dati preservati | **NON VERIFICATO** |
| Release pubblica | firma affidabile, monitoraggio, rollback pianificato | **NON AUTORIZZATA** |

**Esiti CI degli script:** eseguibili con database PostgreSQL 17 **sintetico** e mock capability senza credenziali; non rappresentano la condizione attuale della VPS. Non registrare un PASS reale finché i comandi sopra non saranno eseguiti e osservati dall'operatore.

Riferimenti: [Stato](CURRENT-STATUS.md) · [Runbook precedente](P1-RELEASE-BATCH.md) · [Operazioni](OPERATIONS.md) · [T4](T4-DEVICE-SYNC.md) · [Backend](../infra/README.md).

## Evidenze reali aggiornate 03/11/2026

L'utente ha eseguito l'ispezione **read-only** del DB Simple Notes: PostgreSQL 17 e Flyway V10 PASS con nessuna migrazione fallita e colonne V7–V10 coerenti. Le precedenti note con VPS V8 sono **storiche e superate**. Il client Windows ha riportato login Google e owner coerenti, API compatibile secondo diagnostica, pending 0. Il gate strict `release-readiness.sh` si è fermato per JWT non fornito e **non** è PASS; health e capability complete richiedono ulteriore verifica. L'utente ha rinviato i test Windows↔Android al batch finale senza autorizzare un reset o un nuovo deploy. [Registro](DEVICE-ACCEPTANCE-DEFERRED.md).

**Nota 03/11/2026:** la versione client ora è `0.30.0+32` (P2.4A PR #27); gli export CSV non aggiungono endpoint o migrazioni. Il gate PostgreSQL V10 reale è già PASS; il check API full-schema con JWT resta **non concluso**, come l'accettazione Windows↔Android rinviata. [Registro](DEVICE-ACCEPTANCE-DEFERRED.md).

**Versione attuale 03/11/2026:** Flutter `0.31.0+33` con backup cifrato .snb P2.4B1, PR #28. Non modifica backend, schema Flyway o requisiti del gate; VPS V10 già ispezionata, API strict con JWT non verificata. Nessun restore client né test Windows↔Android eseguiti. [Backup](P2-FULL-BACKUP.md).
