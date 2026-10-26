# Simple Notes API v1

<!-- CURRENT-STATUS-REF -->
> **STATO OPERATIVO — 26/10/2026:** `main` include P1.12 Countdown (`0.17.0+19`, PR #13, CI verde). P1.13 settimanale (`0.18.0+20`) è **solo nel branch**, CI/merge/device non attestati; `weeklyTarget` 1–7 non cancella check-in. Le funzioni Pomodoro/Habits/Countdown sono locali e non sincronizzate. Schema repo Flyway V10, Coolify attestato V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [P1.13](P1-WEEKLY-HABITS.md).


## Auth
- `POST /auth/google`: `{"idToken":"..."}` → `{accessToken,refreshToken,expiresInSeconds,userId,displayName,photoUrl?}`.
- `POST /auth/desktop/exchange`: `{"code":"...","codeVerifier":"...","redirectUri":"http://127.0.0.1:PORT/oauth/callback"}`.
- `POST /auth/refresh`: `{"refreshToken":"..."}` → sessione aggiornata (refresh token ruotato).
- `POST /auth/logout`: `{"refreshToken":"..."}` → 204, revoca.
- Google ID token convalidato server-side; claim opzionale `picture` (HTTPS Googleusercontent) salvato su utente, restituito come `photoUrl` in login/refresh; secret Desktop solo in variabili backend. Auth rate limiting da completare.

## Tasks
- `GET /tasks` — task dell'utente.
- `POST /tasks` — `{title,description,dueAt}`.
- `PUT /tasks/{id}` — `{version,title,description,dueAt,completed}` (409 se obsoleto).
- `PATCH /tasks/{id}/completion` — `{completed}` (legacy senza controllo versione).
- `DELETE /tasks/{id}` — soft delete.

## Notes
- `GET /notes` — note dell'utente.
- `POST /notes` — `{title,body}`.
- `PUT /notes/{id}` — `{version,title,body}`.
- `DELETE /notes/{id}?version=N` — soft delete.

## T2 — aggiornamento Flutter e compatibilità (24/10/2026)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## Synchronization
- `POST /sync/apply` — write idempotente con `operationId`, `entityId`, `entityType`, `action`, `expectedVersion`, `payload`.
- `GET /sync/changes?cursor=N&limit=100` — delta per utente; cursor monotono.
- `GET /sync/latest?entityType=note|task|list&entityId=UUID` — ultimo stato dell'elemento, compresi tombstone, limitato all'utente del JWT; 404 su elementi altrui/mancanti. Usato nel confronto conflitti.
- `entityType=list`: upsert/delete di lista personalizzata; payload `{title,createdAt}`.
- `entityType=task` ora include `listId`, `priority`, `tags`, `subtasks` (vedi [task-organization.md](task-organization.md)); `listId` è validato rispetto all'utente JWT.
- Contratto ed esempi: [sync.md](sync.md).

**Contratto presente nel codice, V7 applicata al DB reale; disponibilità della nuova API ancora da testare:** `POST /sync/apply` supporta un oggetto `due` (`none/date/datetime/legacy`) per i task, con timezone IANA, offset DST e verifica dell'istante. Il server continua ad accettare `dueAt` per i task legacy. Il backend restituisce `due` canonico negli eventi `/sync/changes` e `/sync/latest`, mantenendo `dueAt` per compatibilità. Per non sovrascrivere le nuove scadenze, i client privi di `due` ricevono HTTP **426** + `code: CLIENT_UPGRADE_REQUIRED` quando modificano task `date/datetime`. `GET /api/v1/capabilities` autenticato restituisce `taskDueSchema: 1`. **Flutter T2 ora implementa il contratto nel codice, con capability e gestione 426**, e la migrazione V7 sul DB reale è già stata verificata, mentre capability e comportamento HTTP restano da provare. Dettagli: [due-dates-timezones.md](due-dates-timezones.md).

**Nota:** i vecchi endpoint REST non alimentano ancora il change log: per dati multi-device usare esclusivamente `/sync/apply`. Mancano rate limiting, prove di conflitto su device reali e verifica del nuovo deploy Coolify; UI Forui e test simulati aggiunti.

## Contratto P1.2 — timeBlock (versione storica, integrata su main)

**Per il payload corrente di task multi-slot e ricorrenze, vedere [P1-MULTI-BLOCKS.md](P1-MULTI-BLOCKS.md) e [P1-RECURRENCE.md](P1-RECURRENCE.md).** Il seguente schema è la forma singolo-blocco di P1.2 mantenuta per compatibilità. Su `POST /api/v1/sync/apply` per `entityType:task`, payload opzionale `timeBlock`: `{"kind":"none"}` oppure `{"kind":"range","start":"2026-10-26T08:00:00Z","end":"2026-10-26T09:30:00Z","timeZone":"Europe/Rome"}`. Il blocco è indipendente dal campo `due`. Durata 1 minuto–24h, fuso IANA valido. `GET /api/v1/capabilities` annuncia `timeBlockSchema:1` soltanto con backend V8 aggiornato. Un vecchio client senza `timeBlock` su task già pianificato riceve HTTP 426. Nuovi client non inviano upsert senza capability, preservano outbox. Dettagli: [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). Non attestare deploy.

## Aggiornamento contratto corrente (26 ottobre 2026)

Il backend presente in `main` contiene Flyway V10 e le capability `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` (consultare [P1-RELEASE-BATCH.md](P1-RELEASE-BATCH.md)). La Matrice Eisenhower P1.8 non aggiunge endpoint/campi. Le notifiche P1.7 sono locali per dispositivo e non creano un endpoint di scheduling. La versione Flyway/capability effettivamente deployata su Coolify **deve ancora essere verificata**.

## P1.10 — Timer Pomodoro (branch, device-only)

Timer 25/5/15 e statistiche locali, identità Google isolata nelle chiavi SharedPreferences, ID sessione per impedire doppi conteggi. Nessun endpoint, outbox, SQLite/Flyway schema o sync dedicata. La CI del branch e i test device restano separati dalla compilazione di P1.9. [Specifiche](P1-POMODORO.md).

## P1.10/P1.11 — Contratto attuale (26/10/2026)

Il Pomodoro P1.10 (main) e Habit Tracker P1.11 (branch) non aggiungono API, DTO, capability o migrazioni backend. I dati restano in SharedPreferences per dispositivo e account; **non esiste endpoint di sync abitudini**, né storico Pomodoro sincronizzato. [Stato](CURRENT-STATUS.md).

## P1.12 — Nessun contratto API aggiuntivo

Countdown è device-only in SharedPreferences per account. Non esiste endpoint per eventi Countdown, push, condivisione o sincronizzazione; riutilizza il parser locale TaskDue solo lato Flutter. Backend ancora Flyway V10 nel repository, deploy reale non attestato oltre V8. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Nessuna nuova API

`weeklyTarget` è un campo **opzionale locale** del JSON Habit schema 1, default 7 per record P1.11. Nessun DTO, endpoint, Flyway, PostgreSQL, sync capability o outbox. Non dichiarare che gli obiettivi settimanali siano sincronizzati. [P1.13](P1-WEEKLY-HABITS.md).
