# Rollout coordinato — Simple Notes backend V10 e client P2.3A

> **Stato operativo 02/11/2026:** P2.3D gestione fonti ICS integrata su `main` ([PR #25](https://github.com/andreadada/simple-notes/pull/25), Flutter `0.29.0+31`; [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/41471546808) success: **191 test**, Windows EXE/MSIX, Android JDK17/21; [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41471546568) success). Nessun deploy, reset, installazione o test hardware. Backend Flyway V10 in repo, VPS ultima attestazione V8. [Stato](CURRENT-STATUS.md) · [Gestione ICS](P2-ICS-SOURCE-MANAGEMENT.md).

**Stato:** runbook per backend Flyway V10 e client P2.3A `0.26.0+28` (**P0–P1.18, P2.1 e P2.2 integrate in `main`, PR #21, CI Flutter/Markdown verdi**). Non è attestato un deploy Coolify, un'installazione o un collaudo cumulativo; l'utente intende effettuare personalmente il deploy dopo gli incrementi. I comandi sono read-only salvo la procedura Redeploy espressamente distinta.

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

## 4 — Client Flutter cumulativo (P2.2 0.25.0+27; P2.3A 0.26 candidata) soltanto quando backend è compatibile

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

- P1.6 di per sé non genera notifiche a client chiuso. P1.7 introduce notifiche Android opt-in inexact e Windows **soltanto MSIX** (CI verde, prove real-device da completare); l'EXE/ZIP Windows non le attiva. Prima di sostituire ZIP con MSIX occorre verificare percorso SQLite, OAuth e identità senza perdita di dati. Vedere [P1-REMINDERS-FOUNDATION.md](P1-REMINDERS-FOUNDATION.md).
- Un downgrade del codice **non** annulla in sicurezza migrazioni Flyway già applicate. Non tentare di tornare a V8 cancellando manualmente le colonne.
- In caso di migration ERROR o HTTP426 fermarsi e diagnosticare, mantenendo i dati/operazioni in coda: evitare azioni distruttive.

## Gate P1.8–P1.17 prima del rollout

La [Matrice Eisenhower](P1-EISENHOWER.md) è una proiezione dei task senza migrazioni; CI/merge PR #8 già completati. Prima del rollout eseguire un solo collaudo batch della navigazione in quattro quadranti, edit inline, mapping P2/P3, scadenze civili e sync. Il packaging MSIX Windows richiede verifica di identità, firma e compatibilità SQLite/OAuth: non sostituire alla cieca un ZIP con MSIX. Nessun reset è autorizzato.

## Operazioni correnti e P1.9

Il percorso iniziale consolidato è nella [guida operativa](OPERATIONS.md). La [P1.9 Kanban](P1-KANBAN.md), ora integrata su main, usa soltanto `listId` e `completed`: **nessuna nuova migrazione oltre Flyway V10/Drift V8**. Dopo CI+merge, includere drag/drop Windows/Android e test offline→online nei gate E2E del batch. Non installare client da un branch senza CI verde, e non installare MSIX sul profilo Windows esistente prima di verificare percorso SQLite/OAuth e firma.

### P1.10 (main, device-only)

[Pomodoro](P1-POMODORO.md) salva timer e statistiche su SharedPreferences (per owner/dispositivo), non sul DB; nessun nuovo gate Flyway oltre V10. Verificare che installazioni e transizione ZIP→MSIX preservino **sia** SQLite sia SharedPreferences/secure storage. Non promettere sync delle statistiche. Prima dell'upgrade su dispositivi reali sono necessari CI del branch, merge e collaudo locale.

### P1.11 Habit Tracker (integrato su main, device-only)

[Habit Tracker P1.11](P1-HABITS.md) aggiunge check-in su date civili, streak, archivio e statistiche **solo locali** su SharedPreferences per owner. Nessun Flyway/Drift aggiuntivo. Includere test di preservazione SharedPreferences e separazione account nel collaudo di batch; NON dichiarare sync tra Windows e Android. 

### Countdown P1.12 (solo client)

[Countdown P1.12](P1-COUNTDOWNS.md) non aggiunge endpoint o Flyway: lo storico è locale SharedPreferences per owner/dispositivo. Il deploy Coolify deve essere verificato a Flyway V10 **solo per le funzioni cloud già presenti**, non per attivare il countdown. Test cumulativi: data civile/IANA, archivio, persistenza, ZIP→MSIX, differenza di stato tra dispositivi dichiarata. Nessun deploy automatico.

### P1.13 — Nuovi obiettivi senza migrazione

[P1.13 Weekly Habit](P1-WEEKLY-HABITS.md) mantiene JSON SharedPreferences schema 1, aggiungendo `weeklyTarget` opzionale/default7 e logica settimane civili. Non richiede una migration Flyway o Drift. Eseguire verifica backward compatibility sul device e continuità dati soprattutto ZIP→MSIX; CI e merge non implicano test reali né autorizzano deploy.

### P1.14 — Gate desktop multi-engine

[Sticky Windows](P1-STICKY-WINDOWS.md) non introduce migrazioni: il runner Windows registra plugin sul second engine e il child non apre database/OAuth. Prima di installare MSIX/ZIP reale: verifica DLL, apertura pop-out, modifiche via LocalStore/outbox principale, conflitti, chiusura main e assenza di data loss. Nessun deploy automatico.

### P1.15 — Gate keyboard Windows

[P1.15](P1-DESKTOP-SHORTCUTS.md) non richiede backend, DB schema o dipendenze native nuove. I shortcut sono interni alla finestra Windows, l'azione Nuova nota usa il normale LocalStore/outbox. Collaudare focus e combinazioni di editing, CI Windows/MSIX e regression Android. Restano necessari i gate server-first Flyway V10 per la release cumulativa e la conservazione dati ZIP→MSIX.

### P1.16 — Responsive (solo client)

[Specifiche P1.16](P1-RESPONSIVE.md): nuove soglie di disposizione card Note e test responsive, nessuna modifica a Flyway/Drift, server o outbox. Aggiungere verifica Windows resize e Android 320/390 px al collaudo cumulativo non distruttivo; il rollout richiede ancora Flyway V10/capability effettive sul server e verifica conservativa ZIP→MSIX.

### P1.17 — Tray Windows

[P1.17](P1-WINDOWS-TRAY.md) aggiunge plugin client, hide/restore e voce Esci; nessuna API/migration. Testare tray su ZIP/MSIX reali, sticky e Android invariato, con gate backend-first Flyway V10 ancora aperto e nessun reset.

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](P1-APPEARANCE.md) · [Stato](CURRENT-STATUS.md).

### P1.18 — Tema locale (client Flutter 0.23.0+25)

[Specifiche P1.18](P1-APPEARANCE.md): `ThemeMode` Scuro/Chiaro/Sistema con persistenza SharedPreferences device-only, Forui/Material e Sticky. PR #19 su `main`, CI completa verde; test fisici ancora aperti, nessun cambio DB/API. Per un client cumulativo restano obbligatori Flyway V10 reale, capability, backup secondo policy e collaudo senza reset.

## Gate aggiuntivo — P2.1 incluso nel client cumulativo

La P2.1 è integrata su `main` (PR #20, CI completa verde); non installare i client aggiornati prima di deploy server-first Flyway V10 e collaudo hardware. Un import nel client genera nuove modifiche sync e **non** sostituisce backup, restore isolato o preflight delle capability. [Specifica](P2-PORTABLE-ARCHIVE.md).


### P2.2 — Calendari ICS locali (Flutter 0.25.0+27)

[PR #21](https://github.com/andreadada/simple-notes/pull/21) integrata, CI finale verde: 162 test, Windows EXE/MSIX, Android JDK17/JDK21, Markdown. Il file `.ics` è letto solo come overlay locale per account; non crea task/outbox/endpoint. Nel collaudo cumulativo verificare picker ICS, sostituzione, rimozione e isolamento dopo cambio account, ma **non** considerarli conferma di un deploy server. Per il client completo restano i gate Flyway V10 e capability; nessun reset o intervento dati. [Specifica](P2-ICS.md).

### P2.3A — Compatibilità archivio ICS schema 2

Il client `0.26.0+28` integrato su `main` (PR #22, CI verde) legge `schema=1` e `schema=2`, ma scrive `schema=2` solo dopo una modifica confermata. I client P2.2 `0.25.0+27` rifiutano `schema=2` (senza cancellarlo): non fare downgrade cieco sui profili con sorgenti locali. Collaudare preservazione dati prima/dopo il reimport, separazione di fonti omonime e owner switch; nessuna migrazione Flyway/Drift richiesta dalla sola feature, mentre il rilascio cumulativo completo necessita sempre delle capability server V10. CI/merge E2E hardware documentati separatamente. [Specifiche](P2-ICS-SOURCES.md).

### P2.3B — Archivio locale schema 3

Nel collaudo cumulativo di Flutter candidata `0.27.0+29` controllare eventi RRULE e singole exception, senza task/outbox. Schema 1/2 leggibili, schema 3 scritto solo su conferma; downgrade verso client precedenti vietato senza conservazione dati. Nessuna nuova migration backend per P2.3B, ma resta gate server V10 del client cumulativo. [Specifica](P2-ICS-RECURRENCE.md).

### P2.3C — Feed ICS HTTPS

Nel collaudo cumulativo utilizzare URL ICS HTTPS di prova: consenso, preview, riavvio offline, refresh esplicito, errori HTTP/redirect/ICS senza perdita cache, cancellazione e separazione account. Niente upgrade DB per questa funzione, ma mantenere gate Flyway V10, capability autenticate, firma e verifica E2E delle altre funzionalità. [Specifica](P2-ICS-FEEDS.md).

### P2.3D — Identità e gestione ICS

Nel collaudo finale verificare: apertura del pannello Sorgenti, label editabile inline/annullamento, file reimport con stesso nome originale, feed refresh e ultimo success UTC/local, errori che preservano cache, rimozione per ID, owner switch e nessun token in UI. Nuovo metadato opzionale su schema 3 senza migration SQL; non fare downgrade su client incompatibili. Backend V10 e capability restano gate del client cumulativo. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## Aggiornamento gate R1 — Verifica rigorosa prima dei nuovi client

Il precedente `t4-check-api.sh` controllava solo due capability. La modalità `REQUIRE_FULL_SCHEMA=1`, insieme a `REQUIRE_TIME_BLOCK_SCHEMA=1`, verifica ora il contratto completo V10, mentre `REQUIRE_FLYWAY_VERSION=10` obbliga lo schema PostgreSQL giusto. Il wrapper `infra/release-readiness.sh` esegue entrambi in **sola lettura**. Le prove CI su PostgreSQL sintetico non dimostrano che la VPS reale sia aggiornata (ultima versione verificata V8). Non eseguire deploy/reset/downgrade finché non esiste un piano autorizzato e conservativo. [Runbook R1](RELEASE-V10-READINESS.md).

