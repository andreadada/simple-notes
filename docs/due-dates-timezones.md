# P0 — Scadenze, date-only e fusi orari

> **Stato del 23 ottobre 2026 — T1 BACKEND IMPLEMENTATO SU GITHUB, NON DEPLOYATO.** Il primo input orario HH:mm è già su main e ha superato le CI Flutter [40011701417](https://github.com/andreadada/simple-notes/actions/runs/40011701417) e [40011789270](https://github.com/andreadada/simple-notes/actions/runs/40011789270). Questo documento definisce l'intero incremento: **solo T1 backend è stato introdotto nel codice** (commit [`1bafec0`](https://github.com/andreadada/simple-notes/commit/1bafec046dd0cbd3f18b8933873da7381fc28a26)). La CI backend deve essere verificata separatamente e il database Coolify **NON è stato migrato**. T0, T2, T3 e T4 ancora aperti.

## Implementazione disponibile nel repository — backend T1

- Nuovo `TaskDue.java` con quattro modalità, controllo del fuso IANA e selezione dell'offset DST per il fold.
- Migrazione **Flyway V7** additiva con `due_kind`, `due_date`, `due_time`, `due_timezone`, `due_offset_seconds`; backfill `legacy` o `none` senza dedurre che mezzanotte indichi solo-data.
- `SyncService` riconosce il campo `due`, lo salva nel DB e nel change log. Le vecchie scritture `dueAt` continuano a funzionare su task `none/legacy`.
- Una modifica priva di `due` a un task `date/datetime` produce **426** con `code: CLIENT_UPGRADE_REQUIRED`; stessa protezione sul vecchio `PUT /tasks/{id}`. Preservare l'outbox lato client: la gestione specifica 426 nei client è **ancora da sviluppare in T2**.
- `GET /api/v1/capabilities` (richiede autenticazione) dichiara `taskDueSchema: 1`. Un client T2/T3 dovrà verificare questa capability **prima** di creare task con formato moderno.
- Test Java: validazione date-only/00:00/DST gap/fold, sync+privacy/idempotenza/upgrade e prova di migrazione PostgreSQL popolato V6→V7. **Verificare la CI**; test hardware e deploy ancora mancanti.

## Problema effettivo nel codice

- `LocalTask.dueAt` (`apps/flutter/lib/data/models.dart`) rappresenta sia una scadenza solo-giorno che una scadenza con ora. `00:00` immessa esplicitamente è indistinguibile da un orario non specificato.
- `showNotesDatePicker()` restituisce mezzanotte locale; `cloud_sync.dart` converte `dueAt` in UTC; il server usa `Instant`; `app_database.dart` lo rilegge con `toLocal()`. Un task «entro il 26 ottobre» rischia di apparire in un altro giorno cambiando fuso.
- Le sezioni Oggi / Prossimi 7 giorni confrontano timestamp. Il dettaglio task ancora non mostra l'ora, e non esiste timezone IANA persistente.
- Stato attuale: Flutter **Drift v4** e UI HH:mm senza semantica date-only; backend **Flyway V7 ora nel repository**, ma Coolify potrebbe ancora usare una versione precedente. Non dedurre deploy dal codice.

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

**Backend: `V7__task_due_semantics.sql` — presente nel codice, verifica CI/deploy ancora distinta**
- Conservare `task.due_at TIMESTAMPTZ`, aggiungere `due_kind`, `due_date DATE`, `due_time TIME` (precisione minuti), `due_timezone VARCHAR(128)`, `due_offset_seconds INTEGER`; vincoli `CHECK` per combinazioni ammesse.
- Backfill: `due_at IS NULL -> none` e `due_at IS NOT NULL -> legacy`, senza reinterpretare date già archiviate.
- Spring Boot: introdurre `TaskDue` e validazione `LocalDate`/`LocalTime`/`ZoneId`/`ZoneRules`; serializzare i campi canonici nel change log, preservando compatibilità. Test con PostgreSQL/Testcontainers e dati provenienti da V6.

**Flutter: Drift `schemaVersion 5` — DA IMPLEMENTARE (T2)**
- Aggiungere a `task_entries` `due_kind`, `due_date` (ISO text), `due_time` (`HH:mm` text), `due_timezone`, `due_offset_seconds`; conservare `due_at` durante la migrazione.
- `onUpgrade(from < 5)`: backfill `legacy/none` senza azzerare task, `remoteVersion`, tombstone, `pendingMutations`, cursor o account. Le operazioni già in coda, anche se in formato precedente, devono essere inviate senza inferenze e senza riordinamento.
- `LocalTask`, `LocalStore`, `AppDatabase.snapshot/upsertTask/applyRemote`, `CloudSync` e confronto conflitti si devono basare sul value object; non mantenere due fonti di verità.

**Rollout:** prima backup PostgreSQL reale verificato con restore isolato e copia offsite, poi backend V5/V6 attuale se non già distribuito, successivamente V7 compatibile; infine entrambi i client aggiornati con Drift v5. Non aggiornare un client a V7 prima del supporto server. Vietato eliminare SQLite, outbox o volumi per risolvere problemi.

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

1. **T0 – Gate operativo:** completare [P0-DEVICE-CHECKS.md](P0-DEVICE-CHECKS.md): backup/recovery reale, Coolify V5+V6 e test E2E delle attuali liste, tag, sottotask, offline e 409.
2. **T1 – Backend-first:** codice e test aggiunti su `main` con commit `1bafec0`; CI da verificare; **mai considerare il deploy automatico**. Correggere eventuali problemi della CI prima di passare a T2.
3. **T2 – Flutter core:** `TaskDue` + Drift v5; migrazione/snapshot/outbox/push-pull/risoluzione conflitti; test doppio SQLite, versioni e dati legacy.
4. **T3 – UI:** editor e presentazione Forui, date-only, timed, timezone e fold; filtri oggi/7 giorni; test widget su desktop e mobile.
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
- [ ] Migrazioni V7/v5 additive e test su DB precedenti; nessuna perdita outbox.
- [ ] DST gap/fold, fusi IANA e mezzanotte esplicita validati.
- [ ] UI Forui e filtri coerenti; date-only non varia fra dispositivi.
- [ ] CI backend/Flutter, build Windows+Android ed E2E fisico riusciti.
- [ ] Deploy Coolify effettuato solo dopo backup reale+restore isolato; documentare commit/build/server.
- [ ] P0 aggiornata e edit timespan registrato; ricorrenze/notifiche non spacciate per completate.

**File target:** `apps/flutter/lib/data/{models.dart,app_database.dart,local_store.dart}`, `apps/flutter/lib/sync/cloud_sync.dart`, `apps/flutter/lib/ui/notes_dialogs.dart`, `apps/flutter/lib/main.dart`, test Flutter; `services/api/.../task/TaskEntity.java`, `services/api/.../sync/SyncService.java`, nuovi value object e migrazione V7, test Java; documenti API/sync. Nessun file di codice è cambiato con questo documento.
