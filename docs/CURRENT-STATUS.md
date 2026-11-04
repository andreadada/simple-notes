# Stato corrente — Simple Notes

**Aggiornato 3 novembre 2026.** Questo documento prevale sulla cronologia. **Codice/CI, deploy Coolify, installazione e collaudo fisico sono stati distinti.**

| Area | Stato verificato | Gate ancora aperti |
|---|---|---|
| `main` | **P0–P2.4B1 e R1 integrate**, Flutter **`0.31.0+33`**, [PR #28](https://github.com/andreadada/simple-notes/pull/28) merged, commit [`95741a20`](https://github.com/andreadada/simple-notes/commit/95741a2013246296dd3e278ec09ae8e72f14a836) | **P2.4B2 restore non implementato**; API strict e prove reali differite |
| P1.18 integrata (storico) | [PR #19](https://github.com/andreadada/simple-notes/pull/19) merged, Flutter **`0.23.0+25`**, temi chiaro/scuro/sistema, preferenza locale e Sticky | CI verde; test visivi e su dispositivi fisici ancora aperti |
| CI P2.4B1 | [Flutter #41636993011](https://github.com/andreadada/simple-notes/actions/runs/41636993011) **success**: 204 test, Windows EXE/MSIX, Android JDK17/21; [Markdown #41636993004](https://github.com/andreadada/simple-notes/actions/runs/41636993004) **success** | Nessun restore live, prova picker/share o Windows↔Android su dispositivi reali |
| CI P2.4A | [Flutter #41562133925](https://github.com/andreadada/simple-notes/actions/runs/41562133925) **success**: 198 test, Windows EXE/MSIX, Android JDK17/21; [Markdown #41561797719](https://github.com/andreadada/simple-notes/actions/runs/41561797719) **success** | Collaudo CSV nativo e Windows↔Android rinviati |
| CI P2.3D | [Flutter CI #41471546808](https://github.com/andreadada/simple-notes/actions/runs/41471546808) **success** (191 test, Windows EXE/MSIX, Android JDK17/21); [Markdown #41471546568](https://github.com/andreadada/simple-notes/actions/runs/41471546568) **success** | Non certifica migrazione dati installati o prove fisiche |
| CI P2.3C | [Flutter CI #41460378203](https://github.com/andreadada/simple-notes/actions/runs/41460378203) **success** (182 test, Windows EXE/MSIX, Android JDK17/21); [Markdown #41460378261](https://github.com/andreadada/simple-notes/actions/runs/41460378261) **success** | Non sostituisce prove reali URL HTTPS e sync server-first |
| CI P2.3B | [Flutter CI #41350187352](https://github.com/andreadada/simple-notes/actions/runs/41350187352) **success** (174 test, Windows EXE/MSIX, Android JDK17/21); [Markdown #41350191590](https://github.com/andreadada/simple-notes/actions/runs/41350191590) **success** | Non certifica upgrade ICS schema 2→3 o test reali |
| CI P2.3A | [Flutter CI #41339906564](https://github.com/andreadada/simple-notes/actions/runs/41339906564): **success** (166 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41339910458](https://github.com/andreadada/simple-notes/actions/runs/41339910458): **success** | Non certifica l'upgrade ICS schema 1→2 sui dispositivi reali |
| CI P2.2 | [Flutter CI #41157322208](https://github.com/andreadada/simple-notes/actions/runs/41157322208): **success** (162 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41157326277](https://github.com/andreadada/simple-notes/actions/runs/41157326277): **success** | Non certifica picker ICS su dispositivi fisici o deploy |
| CI P2.1 | [Flutter CI #41114448268](https://github.com/andreadada/simple-notes/actions/runs/41114448268): **success** (152 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41114449602](https://github.com/andreadada/simple-notes/actions/runs/41114449602): **success** | Non dimostra test fisico, OAuth, upgrade ZIP→MSIX o rilascio |
| CI P1.18 | [Flutter CI #41067872668](https://github.com/andreadada/simple-notes/actions/runs/41067872668): **success** (148 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41067872675](https://github.com/andreadada/simple-notes/actions/runs/41067872675): **success** | Non dimostra test fisico, OAuth né upgrade ZIP→MSIX |
| CI P1.17 | [Flutter CI #40797207231](https://github.com/andreadada/simple-notes/actions/runs/40797207231): **success** per analyze/test, Windows release + MSIX di sviluppo, Android JDK17 e JDK21. [Markdown #40797207130](https://github.com/andreadada/simple-notes/actions/runs/40797207130): **success** | La CI non certifica interazioni fisiche, Google login o notifiche |
| Gate R1 (codice) | [PR #26](https://github.com/andreadada/simple-notes/pull/26) merged; [Compose CI #41523319857](https://github.com/andreadada/simple-notes/actions/runs/41523319857) success (V6 rifiutata, V10 incompleta rifiutata, V10 sintetica accettata), [Markdown #41523319860](https://github.com/andreadada/simple-notes/actions/runs/41523319860) success | **Non certifica Flyway V10 reale, health e API autenticata in VPS** |
| Backend nel repository | Spring Boot/PostgreSQL 17, Flyway **V10**; client Drift/SQLite **V8** | VPS reale Flyway **V10 verificata il 03/11/2026**; API strict e health non attestate |
| Test reali | VPS V10 verificata; Windows Google connesso e pending 0, sync recente | Android E2E, API strict e firma/persistenza ancora aperti e rimandati |

## Funzioni integrate nel codice

- **P0–P1.6:** Google OAuth, attività/note/liste offline-first, outbox e sync, Forui ed editing inline, calendario, time blocking, filtri, ricorrenze.
- **P1.7–P1.9:** reminder Android opt-in inexact; reminder Windows solo su MSIX con identità valida; matrice Eisenhower e Kanban per liste.
- **P1.10–P1.13:** Pomodoro, Habit Tracker e Countdown **locali per account/dispositivo**, non sincronizzati tra Windows e Android.
- **P1.14–P1.16:** Sticky Notes Windows con bridge al LocalStore principale, scorciatoie Windows e griglia note responsive 1–3 colonne.
- **P1.17:** icona nell'area di notifica Windows, X→nascondi, Apri/ripristina ed Esci esplicito; fallback quando plugin non disponibile. **Implementazione + CI verificate, comportamento reale da collaudare**.
- **P1.18 (integrata in main, PR #19):** modalità Scuro/Chiaro/Sistema e preferenza locale, nessuna modifica SQLite/outbox/server. [Specifica](P1-APPEARANCE.md).
- **P2.1 (integrata in main, PR #20):** export/import JSON versionato di liste, task e note attive con conferma Forui, nuovi UUID e outbox nella transazione. [Specifica](P2-PORTABLE-ARCHIVE.md).
- **P2.2 (integrata in main, PR #21):** file ICS esterni, locali per account, read-only in calendario giorno/settimana/mese, fino a 5 fonti; nessun task/outbox/cloud. [Specifica](P2-ICS.md).
- **P2.3A (integrata in main, PR #22):** ID stabili per sorgenti ICS, formato locale schema 2 con lettura legacy schema 1, `file/url` (URL ancora senza fetch) e rimozione per ID. [Specifica](P2-ICS-SOURCES.md).
- **P2.3B (integrata, PR #23):** ricorrenze RRULE/RDATE/EXDATE/RECURRENCE-ID locali con proiezione lazy e schema 3. [Specifica](P2-ICS-RECURRENCE.md).
- **P2.3C (main, PR #24):** HTTPS ICS manuale, DNS pinning e restrizioni SSRF/redirect, cache offline, refresh esplicito; nessun OAuth/backend. [Specifica](P2-ICS-FEEDS.md).
- **P2.3D (main, PR #25):** pannello ICS collassabile, nomi inline senza cambiare file/URL, conteggi, ultimo refresh riuscito e gestione per ID. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).
- **P2.4A e P2.4B1 integrate:** CSV locale (PR #27), backup cifrato `.snb` e verifica senza scritture (PR #28). **Ripristino completo P2.4B2, condivisione e smart non implementati**. [CSV](P2-CSV-EXPORT.md).

## Gate di rilascio ancora aperti

1. **Coolify server-first:** Flyway **V10** e `FAILED_MIGRATIONS=0` verificati il 03/11/2026; restano health `UP` e capability autenticate `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` prima di installare client aggiornati.
2. **Windows reale:** prova ZIP completo, apertura/chiusura/riapertura tray, voce Esci, assenza icone orfane e doppie tray nelle finestre Sticky. Per MSIX usare **solo un profilo di prova**, con firma/publisher/identity coerenti.
3. **Collaudo Windows ↔ Android:** login e sessione, sync offline/retry, 409/426, liste/task/note, calendario/ricorrenze, reminder, resize, temi chiaro/scuro/sistema, accessibilità e persistenza al riavvio.
4. **Preservazione dati:** nessun reset o uninstall. Verificare esplicitamente SQLite, outbox, secure storage e SharedPreferences nel passaggio ZIP→MSIX; la sola CI non dimostra compatibilità del percorso.
5. **Release pubblica:** signing affidabile, hardening/monitoraggio e decisione esplicita sulla policy backup/offsite (non eseguita). Il backup/restore isolato riuscito il 24/10 è una prova **storica**, non un backup fresco.

[Guida operativa](OPERATIONS.md) · [Specifica Tray](P1-WINDOWS-TRAY.md) · [Runbook server-first](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).

## P1.18 integrata (30/10/2026)

PR #19 merged con CI di codice e documentazione verde sullo SHA finale. Restano il collaudo reale di temi su Windows/Android, Sticky e preferenze dopo riavvio, più il release gate cumulativo backend-first. [Specifica](P1-APPEARANCE.md).

## P2.1 integrata (30/10/2026)

[Specifica import/export](P2-PORTABLE-ARCHIVE.md). [PR #20](https://github.com/andreadada/simple-notes/pull/20) merged: Flutter `0.24.0+26`, JSON portabile liste/task/note attive con validazione e importazione additiva. CI completa verde; test fisici e deploy aperti. Non modifica PostgreSQL/Flyway o schema Drift; non è un backup del profilo, dei dati Focus o della coda sync.


## P2.2 — Integrata in main il 31/10/2026

[PR #21](https://github.com/andreadada/simple-notes/pull/21) merged, Flutter `0.25.0+27`: import locale file `.ics` (fino a 5, eventi singoli, UTC/IANA o all-day), overlay read-only nel calendario giorno/settimana/mese, preferenze con hash owner. Nessuna modifica task/SQLite/outbox/cloud. CI e Markdown verdi; collaudo reale e distribuzione sempre distinti. [Specifica](P2-ICS.md).


## P2.3A — Identità sorgenti ICS (main, PR #22, 01/11/2026)

**Integrata su `main` con PR #22**, Flutter `0.26.0+28`: schema locale ICS 2 con `id` persistente, `kind=file/url`, migrazione in memoria da schema 1, reimport file e rimozione su ID, controllo owner durante picker/conferma. Il formato viene scritto soltanto dopo un'azione esplicita; i client P2.2 vecchi non leggono schema 2 ma devono conservarlo senza cancellazioni. URL è **solo metadato di modello**, nessuna sottoscrizione o ricorrenza nuova. CI Flutter **166 test** + Windows EXE/MSIX e Android JDK17/21 verde sul commit candidato `7b7d4db`; Markdown verde, nessun deploy e device E2E ancora da eseguire. [Specifica](P2-ICS-SOURCES.md).

## P2.3B — Ricorrenze ICS integrate (main, PR #23, 01/11/2026)

PR #23 merged su `main`, Flutter `0.27.0+29`, RRULE/RDATE/EXDATE/RECURRENCE-ID con proiezione lazy su giorno, schema locale 3 leggibile insieme ai vecchi 1/2, nessun fetch URL. **CI 174 test/Windows/Android/Markdown verde; nessun deploy Coolify o collaudo hardware.** [Specifica](P2-ICS-RECURRENCE.md).

## P2.3C — Feed HTTPS ICS (main, PR #24, 02/11/2026)

PR #24 integrata su `main`, Flutter `0.28.0+30`: fonte HTTPS con DNS pinning, protezioni SSRF, refresh manuale e cache locale preservata su fallimento. Nessun backend, Flyway, outbox o OAuth in più. CI Flutter 182 test, build Windows/Android e Markdown verdi; collaudo fisico ancora aperto. [Specifica](P2-ICS-FEEDS.md).

## P2.3D — Gestione fonti ICS (main, PR #25, 02/11/2026)

PR #25 integrata su `main`, Flutter `0.29.0+31`: sorgenti ICS nel pannello compatto, titolo inline (`displayLabel` schema 3 opzionale), refresh riuscito e errori senza query token, etichetta di proiezione aggiornata senza alterare ID/UID/filename/URL. CI 191 test e build Windows/Android/Markdown verdi; nessun deploy o test hardware. [Specifica](P2-ICS-SOURCE-MANAGEMENT.md).

## R1 — Gate server-first (main, PR #26, 02/11/2026)

PR #26 integrata su `main`: verifica V10 rigorosa e capability API complete con token temporaneo, senza scritture, migrazioni, backup, deploy o installazioni. CI Compose #41523319857 e Markdown #41523319860 **verdi** con PostgreSQL **sintetico** e test JSON; non è evidenza della VPS. **Nota storica R1:** alla creazione del gate la VPS era attestata V8; il 03/11/2026 l'utente ha verificato con `t4-inspect-db.sh` Flyway **V10**, colonne previste e 0 migration failed. Il gate API strict resta aperto. [Runbook operativo](RELEASE-V10-READINESS.md).


## Evidenze reali e test rinviati (03/11/2026)

L'utente ha eseguito `t4-inspect-db.sh` su VPS: PostgreSQL 17, `FLYWAY_LATEST=10`, `FAILED_MIGRATIONS=0`, colonne scadenze=5, blocchi=3, `blocks_json`=1, `recurrence_json`=1; app_user=1/task=3/note=1/sync_change=57/sync_operation=57. Diagnostica Windows: API compatibile secondo il client, Google connesso, owner coerente, pending=0, task visibili=0, note=1, cursor=91, ultima sync 2026-11-03 02:24:58. Il gate strict con JWT **non ha prodotto PASS**, nessun report Android. La differenza fra righe fisiche server e task visibili Windows va verificata in seguito, senza dedurre perdita di dati. **L'utente ha rinviato esplicitamente E2E hardware** al batch futuro; non dichiararlo completato. [Registro](DEVICE-ACCEPTANCE-DEFERRED.md).

## P2.4A — Esportazione CSV (main, PR #27)

PR #27 merged, Flutter `0.30.0+32`, CSV separati attività/note attive/liste, UTC/date civili, JSON per slot/tag/subtask, BOM UTF-8, CSV quoting e blocco formula injection. Nessuna API/migration o import CSV. CI 198 test/Windows/Android e Markdown verdi, prove fisiche rinviate. [Specifica](P2-CSV-EXPORT.md).

## P2.4B1 — Backup cifrato (main, PR #28, 03/11/2026)

PR #28 merged su `main`, Flutter `0.31.0+33`: archivio .snb cifrato AES-256-GCM/PBKDF2, snapshot logico SQLite V8 completo di tombstone/outbox/sync settings e preferenze locali owner-scoped. Menu account Forui Crea backup/Verifica backup, validazione password/integrità/owner/schema **senza scrivere nulla**. **Non esiste ancora un ripristino effettivo**: P2.4B2 richiederà cold-start, blocco sync, checkpoint e rollback. CI Flutter (204 test e build native) e Markdown verdi; le verifiche fisiche restano differite, VPS Flyway V10 già verificata. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2A — Avanzamento 04/11/2026 (branch, non ancora certificato main)

Predisposta una prova di restore **solo in memoria**, separata dall'app installata: preflight .snb password/account, cinque tabelle SQLite V8 scritte in una transazione, confronto integrale dei valori grezzi e verifica decodifica Drift; test di errore iniettato, rollback e retry. Non modifica database installato, SharedPreferences, credenziali o server, e NON abilita la sync. Fino a merge e CI finali lo stato ufficiale main resta P2.4B1. Il vero P2.4B2 richiede ancora checkpoint reale, cold-start e anti-replay. [Specifica](P2-FULL-BACKUP.md).


## P2.4B2B1 — Preflight checkpoint (04/11/2026, branch in sviluppo)

Oltre alla rehearsal SQLite isolata P2.4B2A (PR #29), preparata una fase di salvataggio verificato: file .snb cifrato nuovo e non sovrascrivibile, scrittura temporanea/flush/rename, verifica read-back SHA-256 e AES-GCM, account e payload, rehearsal in memoria e receipt senza permesso di sync. Test su directory temporanee e fault; nessuna scrittura sul dispositivo dell'utente. **Il restore live non esiste ancora**, e rimangono da provare fsync/cold-start, rollback SQLite + preferenze, controllo anti-replay e compatibilità package. Stato main fino a merge verificato: P2.4B1.


## P2.4B2B2 — Rehearsal rollback cross-store (04/11/2026, in PR)

Prova incrementale della compensazione delle cinque tabelle SQLite e delle preferenze **solo in sandbox**: due .snb verificati per password/account, transazione SQLite in memoria, preferenze simulate in `Map`, fault injection durante SQL/preferenze/post-commit, ripristino esatto del checkpoint con SHA-256 e verifica Drift. Nessun restore installato, nessuna scrittura a SharedPreferences reali, nessun replay outbox o collegamento ad AutoSync/Coolify. La sicurezza su crash e storage persistente **non è ancora attestata**. PR #29/#30 e questo sottostep restano separati dalle CI e dal merge di `main`, che rimane P2.4B1 finché non verificati.


## P2.4B2C1 — Cold-start fail-closed / anti-replay (04/11/2026, PR di sviluppo)

Realizzati guard e journal append-only per **simulare** interruzioni e recovery tra nuovi processi in directory temporanea; blocco su file incompleti, identità non valida o digest cambiati; ricostruzione del checkpoint verificata solo via sandbox B2B2; valutazione outbox e cursore importati sempre in quarantena senza autorizzazione AutoSync. Nessun collegamento allo startup in produzione né a profili installati. **Non equivale a recovery persistente verificato**: fsync directory, lock multiprocesso, rollback cross-store reale e riconciliazione online restano P2C2+. PR #31 è la dipendenza di questo incremento; merge e CI vanno verificati.


## P2.4B2C2 — Startup embargo + cloud preflight (04/11/2026, PR)

- `main.dart` verifica **prima di SQLite/OAuth** l'eventuale directory riservata di recovery, e in presenza di marker anche corrotti blocca l'app con schermata offline statica. Il probe è solo lettura; web usa uno stub. Non esistono writer live per il restore.
- Gate iniettato nel ProviderScope a protezione di AutoSync, sincronizzazione manuale e risoluzione conflitti; nessun permesso per replay importato.
- Nuovo client esplicito cloud read-only (GET paginati e validati, max 100 pagine/10k eventi) e review versioni/outbox/cursor sempre non autorizzante.
- Test unitari di bootstrap, gate e ricognizione cloud con server simulato; CI e merge ancora da verificare.
- **Non pronto il restore reale:** lock multi-processo, recovery persistente SQLite+preferenze, scelta conflitti e E2E fisici restano mancanti.

P2.4B2C2 include anche parser e test GET-only per `/sync/inventory` previsto dalla PR API #34, non ancora attivato/deployato; analisi dei conflitti solo informativa, senza replay.


## P2.4B2C3 — Endpoint backend read-only (04/11/2026, PR separata)

Aggiunto `GET /sync/inventory` lato Spring Boot: ultimo change per entità e cursor in snapshot coerente `REPEATABLE_READ`, filtraggio JWT, tombstone, limite 10k, nessun testo/credenziale. Test integrazione A/B e letture non mutanti. Branch backend indipendente da PR Flutter #33; controlli CI e merge da verificare. **Non deployato**, nessuna modifica al DB reale né migrazione.


## P2.4B2D — Compensazione persistente su directory di test (04/11/2026, integrata su main via PR #35)

Nuovo `full_backup_disk_recovery_rehearsal.dart`: recovery di SQLite e preferenze su **file temporanei isolati**, checkpoint .snb cifrato letto e autenticato, lock OS consultivo, journal append-only, rollback e verifica post-riavvio. Test di crash dopo SQL, dopo preferenze e durante recovery; fail-closed su password, account, archivio o registro errato. Nessun ripristino o AutoSync su profilo installato. Mancano fsync directory/compatibilità OS e protocollo di ripristino live. CI/merge da verificare.


## P2.4B2E — Confronto .snb con dispositivo (04/11/2026, PR in sviluppo)

Nuova azione Forui nel menu account per confrontare localmente backup cifrato e snapshot corrente con sola lettura, senza chiamate cloud. Il report espone solo conteggi di differenze, tombstone, outbox, preferenze, cursor e rischi; non espone note o token e non autorizza mai restore/sync. Test unitari di confronto owner-scoped e casi obsoleti/malformed. CI/merge da verificare. Il restore vero resta disabilitato e non è stato eseguito alcun deploy.

**Checkpoint release:** PR #35 integrata con analisi, widget test, recupero temporaneo Windows e build Android 17/21, Windows verdi. PR #36 aggiunge il confronto locale in sola lettura; ogni nuova modifica è soggetta alla propria CI.

## CI più rapida per PR (04/11/2026, branch indipendente)
Flutter, backend e Compose continuano a verificare i push su `main`, ma non avviano più una pipeline duplicata per ogni push di un branch già associato a una PR. Tutti e quattro i workflow (anche documentazione) cancellano automaticamente soltanto le esecuzioni obsolete della *stessa PR* quando arrivano commit nuovi. Nessuna riduzione di test, build, controlli di sicurezza o validazione. PR e CI/merge da verificare; nessun deploy.
