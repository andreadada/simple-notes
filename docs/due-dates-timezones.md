# P0 — Scadenze, date-only e fusi orari

<!-- CURRENT-STATUS-REF -->
> **Snapshot storico, NON runbook attuale — 26/10/2026:** `main` = P1.10 Pomodoro `0.15.0+17` (PR #11, CI verde); P1.11 Habit Tracker `0.16.0+18` **solo branch**, CI/merge non confermati. Entrambe le funzioni hanno storico locale, **non sincronizzato**. Repo Flyway V10 / Coolify attestato V8, nessun deploy o test hardware nuovo. [Stato](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Specifiche P1.11](P1-HABITS.md).


> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

## T4 — Gate di rilascio sicuro (24/10/2026)

**Strumenti e CI implementati; inventario reale del DB, backup SHA256 e restore isolato PASS il 24/10/2026.** Flyway V7 è presente nel database. **Copia offsite non eseguita per scelta dell'utente; contratto API e prove T4.2 Windows↔Android ancora da verificare.** `infra/backup-postgres.sh` verifica container e schema prima del dump PostgreSQL custom + SHA256; `infra/verify-restore.sh` ripristina in container PostgreSQL 17 **senza rete**, interroga le tabelle e genera un receipt legato al digest del dump. `infra/t4-preflight.sh` rifiuta dump/receipt incoerenti, copia offsite non attestata, commit non approvato o tree sporco; **non avvia deploy**. `infra/t4-check-api.sh` verifica soltanto salute HTTPS e capability autenticata `taskDueSchema:1`.

La CI Compose usa dump **sintetici** e verifica i rifiuti su backup alterati; la CI backend prova una migrazione V6→V7 PostgreSQL Testcontainers con task/note/liste/sync log esistenti. **Gate reali al 24/10:** PostgreSQL V7, backup SHA256 e restore isolato già verificati. Offsite non effettuata per scelta dell'utente e distinta dal collaudo T4.2. Il prossimo controllo è su API autenticata e Windows/Android E2E; per una release formale restano anche hardening/offsite e preflight. Non avviare un redeploy solo perché V7 è citata. Non distribuire né ripristinare sulla produzione durante una prova. [Runbook T4](T4-RELEASE-RUNBOOK.md) · [GitHub Actions](https://github.com/andreadada/simple-notes/actions).


## T3 — Scadenze Forui, IANA e DST (24/10/2026)

**Implementato nel codice su main, non distribuito.** Un unico editor `ui/task_due_editor.dart` gestisce scadenze solo-giorno e data/ora, calendario Forui, HH:mm, fuso IANA e scelta esplicita delle due occorrenze in un cambio d'ora. Gli orari inesistenti sono rifiutati, la mezzanotte scelta rimane `datetime`, e le scadenze `legacy` non sono reinterpretate in automatico. Il fuso OS viene rilevato se disponibile, altrimenti richiesto esplicitamente.

`data/task_due_clock.dart` usa `timezone ^0.11.2` e `flutter_timezone ^5.1.0`; `data/task_due_view.dart` presenta label e filtri Oggi/7 giorni secondo **giorni civili**, evitando il calcolo sbagliato di 168 ore attorno all'ora legale. Aggiunta rapida, dettagli ed editor avanzato salvano `TaskDue` con SQLite/outbox; una rinomina non muta `date/datetime` in `legacy`. Test per gap/fold, visualizzazione, filtri e modifica avanzata. **V7 già verificata sul database reale**, backup SHA256 e restore isolato PASS. Mancano capability API `taskDueSchema:1` e prove Windows/Android; non ripetere deploy senza un'incompatibilità accertata. Ricorrenze, notifiche e browser web restano fuori da T3.

Dettagli e checklist: [specifica T3](T3-SCADENZE.md). CI: [Flutter Actions](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml).


> **Cronologia del 23/10, poi superata per il database:** T1 backend era inizialmente solo su GitHub. Il primo input orario HH:mm è già su main e ha superato le CI Flutter [40011701417](https://github.com/andreadada/simple-notes/actions/runs/40011701417) e [40011789270](https://github.com/andreadada/simple-notes/actions/runs/40011789270). Questo documento definisce l'intero incremento: **T1 backend e T2 client Flutter sono presenti nel codice** (commit [`1bafec0`](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26)). La CI backend [40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) è **riuscita** (Gradle test e bootJar) e il database reale è stato successivamente verificato con Flyway **V7 applicata**. T4.2 e gate di release ancora aperti; T2 e T3 presenti nel codice, ma non rilasciati sul backend e dispositivi reali.

## T2 — Flutter e SQLite v5 (implementato nel repository, non distribuito)

- **Modello canonico**: `apps/flutter/lib/data/task_due.dart` distingue `none/date/datetime/legacy`. Una data senza orario è una stringa civile ISO, mai una mezzanotte UTC inventata; la modalità `legacy` conserva lo storico senza inferenze.
- **Persistenza**: `AppDatabase` usa Drift **schemaVersion 5** con 5 colonne aggiuntive (kind, date, time, timezone, offset) e backfill `due_at != NULL → legacy`, altrimenti `none`. Le tabelle sync/outbox, il cursore e i remoteVersion non vengono cancellati.
- **Sincronizzazione**: i task moderni inviano l'oggetto `due` al backend; prima di inviare `date/datetime` il client controlla `GET /api/v1/capabilities` autenticato e richiede `taskDueSchema=1`. Se assente conserva la mutazione offline; **HTTP 426** non è trattato come un normale 409, quindi non viene ribasato e l'outbox resta intatta. I payload legacy già accodati sono mantenuti.
- **Test creati**: `task_due_test.dart`, `task_due_sync_test.dart`, `task_due_migration_test.dart`; includono due database simulati, fold DST, mezzanotte esplicita, server obsoleto, 426, e upgrade di SQLite v4 popolato con versioni e operazioni in coda. Verificare l'esito CI effettivo prima di considerarli convalidati.
- **Stato aggiornato:** T2 (Drift v5, `TaskDue`, capability/426) e T3 (editor Forui date-only/ora e IANA/DST) sono implementati nel codice, non ancora collaudati sui due dispositivi. Flyway V7 e restore reale PASS, ma contratto API da verificare. Flutter Web, ricorrenze e notifiche non ancora supportati.

## Implementazione disponibile nel repository — backend T1

- Nuovo `TaskDue.java` con quattro modalità, controllo del fuso IANA e selezione dell'offset DST per il fold.
- Migrazione **Flyway V7** additiva con `due_kind`, `due_date`, `due_time`, `due_timezone`, `due_offset_seconds`; backfill `legacy` o `none` senza dedurre che mezzanotte indichi solo-data.
- `SyncService` riconosce il campo `due`, lo salva nel DB e nel change log. Le vecchie scritture `dueAt` continuano a funzionare su task `none/legacy`.
- Una modifica priva di `due` a un task `date/datetime` produce **426** con `code: CLIENT_UPGRADE_REQUIRED`; stessa protezione sul vecchio `PUT /tasks/{id}`. Preservare l'outbox lato client: la gestione HTTP 426 è presente nel client Flutter T2, con outbox conservata.
- `GET /api/v1/capabilities` (richiede autenticazione) dichiara `taskDueSchema: 1`. Il client Flutter T2 verifica questa capability **prima** di creare task con formato moderno.
- Test Java: validazione date-only/00:00/DST gap/fold, sync+privacy/idempotenza/upgrade e prova di migrazione PostgreSQL popolato V6→V7. **CI backend 40019181083 riuscita**; V7 già presente nel DB reale, API/hardware ancora da testare.

## Problema effettivo nel codice

- `LocalTask.dueAt` (`apps/flutter/lib/data/models.dart`) rappresenta sia una scadenza solo-giorno che una scadenza con ora. `00:00` immessa esplicitamente è indistinguibile da un orario non specificato.
- `showNotesDatePicker()` restituisce mezzanotte locale; `cloud_sync.dart` converte `dueAt` in UTC; il server usa `Instant`; `app_database.dart` lo rilegge con `toLocal()`. Un task «entro il 26 ottobre» rischia di apparire in un altro giorno cambiando fuso.
- Le sezioni Oggi / Prossimi 7 giorni confrontano timestamp. Il dettaglio task ancora non mostra l'ora, e non esiste timezone IANA persistente.
- Stato precedente a T2/T3: Flutter **Drift v4** e UI HH:mm senza semantica date-only; backend **Flyway V7 ora nel repository**, e il database reale ha già V7. Il DB non attesta da solo la versione API.

## Decisione architetturale

La scadenza deve essere un value object `TaskDue` con quattro modalità, non un singolo `DateTime`:

| Modalità | Dato canonico | Significato |
|---|---|---|
| `none` | nessuno | Nessuna scadenza |
| `date` | `YYYY-MM-DD` | Giorno civile puro, identico su PC e telefono ovunque si trovino |
| `datetime` | data + ora locale + timezone IANA + offset selezionato + istante UTC | Evento puntuale, stesso istante su tutti i device |
| `legacy` | `dueAt` originale conservato | Dato storico la cui semantica «solo giorno» / «con ora» non è ricostruibile |

**Mai dedurre automaticamente** che una vecchia scadenza alle 00:00 sia un `date`: potrebbe essere una mezzanotte scelta esplicitamente. La modalità `legacy` deve restare riconoscibile; l'utente la convertirà in `date/datetime` quando modifica la scadenza.

### Contratto sync proposto (esempi NON attivi)

~~~json
{"due":{"kind":"date","date":"2026-10-26"}}
{"due":{"kind":"datetime","date":"2026-10-25","time":"02:30","timeZone":"Europe/Rome","instant":"2026-10-25T00:30:00Z","offsetSeconds":7200}}
{"due":{"kind":"legacy","instant":"2026-10-24T22:00:00Z"}}
{"due":{"kind":"none"}}
~~~

Il campo `due` diventerà fonte di verità nei payload task di `/sync/apply`, `/sync/changes` e `/sync/latest`. Mantenere versioning, `operationId` idempotente, owner isolation, outbox e tombstone. `dueAt` rimarrà solo per compatibilità e sarà derivato per `datetime/legacy`; il `date` non va convertito in mezzanotte UTC. Non inventare una data quando manca.

Il backend deve verificare che `instant` concordi con data/ora/`timeZone`/`offsetSeconds`; in caso contrario rifiutare con errore esplicito. Per le date-only non programmare automaticamente reminder a mezzanotte.

**Protezione vecchi client:** la sync attuale invia l'intero task. Un vecchio client privo del nuovo campo `due` potrebbe cancellare silenziosamente il dato quando modifica soltanto il titolo. Prima del rilascio implementare un capability/version handshake (es. `GET /api/v1/capabilities`) e una risposta strutturata tipo `CLIENT_UPGRADE_REQUIRED` per update senza `due` di entità già migrate. Non confondere questo caso con un 409 di revisione; outbox sempre preservata. Un client nuovo non deve abilitare i nuovi salvataggi se comunica con un server che ignora `due`. Verificare separatamente le vecchie rotte REST, oggi non collegate al change log, impedendo che sovrascrivano i campi moderni.

## Migrazioni incrementali — da sviluppare

**Backend: `V7__task_due_semantics.sql` — presente nel codice e verificata sul DB reale, API ancora da collaudare**
- Conservare `task.due_at TIMESTAMPTZ`, aggiungere `due_kind`, `due_date DATE`, `due_time TIME` (precisione minuti), `due_timezone VARCHAR(128)`, `due_offset_seconds INTEGER`; vincoli `CHECK` per combinazioni ammesse.
- Backfill: `due_at IS NULL -> none` e `due_at IS NOT NULL -> legacy`, senza reinterpretare date già archiviate.
- Spring Boot: introdurre `TaskDue` e validazione `LocalDate`/`LocalTime`/`ZoneId`/`ZoneRules`; serializzare i campi canonici nel change log, preservando compatibilità. Test con PostgreSQL/Testcontainers e dati provenienti da V6.

**Flutter: Drift `schemaVersion 5` — IMPLEMENTATO NEL CODICE, verifica CI e hardware separate**
- Aggiungere a `task_entries` `due_kind`, `due_date` (ISO text), `due_time` (`HH:mm` text), `due_timezone`, `due_offset_seconds`; conservare `due_at` durante la migrazione.
- `onUpgrade(from < 5)`: backfill `legacy/none` senza azzerare task, `remoteVersion`, tombstone, `pendingMutations`, cursor o account. Le operazioni già in coda, anche se in formato precedente, devono essere inviate senza inferenze e senza riordinamento.
- `LocalTask`, `LocalStore`, `AppDatabase.snapshot/upsertTask/applyRemote`, `CloudSync` e confronto conflitti si devono basare sul value object; non mantenere due fonti di verità.

**Rollout aggiornato:** PostgreSQL V7, SHA256 e restore isolato PASS; offsite non eseguita per scelta. Verificare API e build client Drift v5; redeploy solo per necessità accertata. Non aggiornare un client a V7 prima del supporto server. Vietato eliminare SQLite, outbox o volumi per risolvere problemi.

## Fusi orari e ora legale

- Data senza ora: mantenere la stringa civile invariata; non usare `DateTime(anno,mese,giorno)` come istante fittizio. Oggi/Prossimi 7 giorni valutano le date-only come giorni civili, mostrando anche i task scaduti secondo la regola attuale.
- Data con ora: salvare timezone IANA (es. `Europe/Rome`), ora a minuti e istante UTC calcolato usando le regole di quel fuso; cambiare fuso dispositivo non cambia l'istante. UI mostra chiaramente il fuso del task; eventuale orario nel fuso del device solo come aiuto.
- **Ora inesistente:** Europe/Rome 29/03/2026 02:30 non esiste: segnalare errore e chiedere una nuova ora, senza arrotondare.
- **Ora ripetuta:** Europe/Rome 25/10/2026 02:30 ha due occorrenze: richiedere prima (+02:00, 00:30Z) o seconda (+01:00, 01:30Z) e conservare offset/istante selezionato.
- `00:00` esplicita deve mantenere `datetime`; campo ora vuoto significa `date`, senza inferenza dal timestamp.
- Java `ZoneRules.getValidOffsets()` per distinguere 0/1/2 offset, validazione server autorevole. Su Flutter valutare [timezone](https://pub.dev/packages/timezone) per le regole IANA e [flutter_timezone](https://pub.dev/packages/flutter_timezone) per identificare il fuso OS Windows/Android. La libreria `timezone` non rileva da sola il fuso OS; verificare versione e compatibilità con Flutter/Dart reali prima di aggiungere dipendenze.
- Valutare e testare divergenze fra database IANA client/server; non applicare conversioni silenziose in caso di mismatch.

## UI Forui e regole prodotto

- Nell'editor task: controllo semplice «Solo giorno / Data e ora», `FCalendar` esistente, orario in formato 24h, fuso del task visibile e modificabile, selezione dell'occorrenza solo nel cambio d'ora ambiguo. No nuovi modali Material e rispettare inline-edit-first per attributi già mostrati.
- Distinguere visivamente «26 ott» da «26 ott · 00:00». Il dettaglio task deve riportare giorno/orario/fuso, non solo il giorno.
- Se una scadenza è `legacy`, mantenerla senza cambio semantico fino a modifica esplicita; non nasconderne eventuale ambiguità. Nessuna notifica schedulata da `legacy` senza riconferma.
- Il filtro Oggi e 7 giorni va verificato per `date`, `datetime`, scaduti e cambi del fuso impostato sul device.

## Piano eseguibile, in piccoli commit

1. **T0 – Gate operativo:** backup/restore reali e V1–V7 verificati; E2E liste/tag/sottotask/offline e 409 restano. [Checklist](P0-DEVICE-CHECKS.md).
2. **T1 – Backend-first:** codice e test aggiunti su `main` con commit `1bafec0`; [Backend CI 40019181083](https://github.com/andreadada/simple-notes/actions/runs/40019181083) **success** (test e bootJar). **Mai considerare il deploy automatico**. T2 Flutter è ora presente nel codice; rimangono verifiche e rilascio.
3. **T2 – Flutter core:** `TaskDue` + Drift v5; migrazione/snapshot/outbox/push-pull/risoluzione conflitti; test doppio SQLite, versioni e dati legacy.
4. **T3 – UI:** codice aggiunto: editor Forui, date-only, timed, timezone/fold e filtri oggi/7 giorni; verifiche manuali e API autenticata ancora da completare.
5. **T4 – Compatibilità e release:** verificare backend aggiornato, capability, upgrade senza reset, test Windows↔Android reali in entrambi i versi, offline/restart/conflict/DST. Aggiornare checklist soltanto dopo prova.
6. **T5 – Lavoro successivo:** ricorrenze e solo poi notifiche Android/Windows, snooze, deduplica per occorrenza/device, reboot, restrizioni sistema. **Non incluso** nel presente incremento.

### Matrice minima di accettazione

| Prova | Atteso |
|---|---|
| Date-only 26/10 su Roma e Los Angeles | 26/10 su entrambi e nel payload cloud |
| Timed 25/10/2026 02:30 +02:00 | UTC 00:30Z |
| Timed 25/10/2026 02:30 +01:00 | UTC 01:30Z |
| Timed 29/03/2026 02:30 Roma | Errore DST, niente auto-adjust |
| Timed esplicita a 00:00 | Resta timed, non diventa date-only |
| SQLite v4 con scadenze esistenti | Migra `legacy` senza perdita UUID/version/outbox |
| Payload vecchio `dueAt`, vecchi client | Compatibility e upgrade failure non distruttivi |
| Un task modificato su 2 dispositivi | Dati `due` in conflitto, 409 e coda preservata |
| Offline + rientro rete + riavvio/cambio fuso | Nessun giorno spostato, istante corretto |
| Server privo di capability nuova | Client nuovo non accoda scritture incompatibili |
| Cancella scadenza e cambio account | `none` pulito, nessun dato cross-account |

## Definition of Done

- [ ] Contratto nuovo stabile e retrocompatibilità *dimostrata*, non solo dichiarata.
- [x] Migrazioni V7 PostgreSQL e v5 Drift implementate con test automatici. [ ] Verificare SQLite/outbox su device senza perdita.
- [ ] DST gap/fold, fusi IANA e mezzanotte esplicita validati.
- [ ] UI Forui e filtri coerenti; date-only non varia fra dispositivi.
- [ ] CI backend/Flutter, build Windows+Android ed E2E fisico riusciti.
- [ ] Verificare capability API autenticata e annotare build/server; non avviare automaticamente il redeploy.
- [ ] P0 aggiornata e edit timespan registrato; ricorrenze/notifiche non spacciate per completate.

**File target:** `apps/flutter/lib/data/{models.dart,app_database.dart,local_store.dart}`, `apps/flutter/lib/sync/cloud_sync.dart`, `apps/flutter/lib/ui/notes_dialogs.dart`, `apps/flutter/lib/main.dart`, test Flutter; `services/api/.../task/TaskEntity.java`, `services/api/.../sync/SyncService.java`, nuovi value object e migrazione V7, test Java; documenti API/sync. Nessun file di codice è cambiato con questo documento.

## P1.11 — Date civili nelle abitudini

I check-in di Habit Tracker sono stringhe `YYYY-MM-DD` nel calendario locale. Il giorno successivo è calcolato tramite `DateTime(year, month, day + 1)`, non sommando 24 ore UTC: DST gap/fold non devono modificare il giorno assegnato. Non condividono la semantica di `TaskDue.datetime` e non sono sincronizzati. [Specifica](P1-HABITS.md).
