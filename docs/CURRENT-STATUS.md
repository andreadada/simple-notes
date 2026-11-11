# Stato corrente — Simple Notes

**Aggiornato 11 novembre 2026 (audit su commit 7ee9dce).** Questo documento prevale sulla cronologia. **Codice/CI, deploy Coolify, installazione e collaudo fisico sono stati distinti.**

**Audit Markdown del 10/11/2026:** ricontrollati tutti i **68 file `.md`** del repository (**62 in `docs/`**, indice incluso, e 6 distribuiti nei package/radice). Normalizzate intestazioni P0/P1 e runbook T3/T4, corrette diciture PR #62–#65 e migrazioni Flyway V14 nel codice, aggiunto [indice completo](README.md); controlli link relativi [Markdown CI #42854337893](https://github.com/andreadada/simple-notes/actions/runs/42854337893) **success** dopo il merge. Le modifiche documentali successive mantengono la stessa rete di link. La [CI Flutter della PR #62](https://github.com/andreadada/simple-notes/actions/runs/42854004235) è **success**; la CI Flutter della PR #63 su `main` [#42859684045](https://github.com/andreadada/simple-notes/actions/runs/42859684045) è **success**; PR #64 allegati S3 e PR #65 auto-sync modelli sono integrate su `main`.

**Hardening allegati in sviluppo (branch 11/11):** controllo condizionato dei magic bytes prima del COPY S3 e manutenzione dei soli metadata PENDING scaduti. La presenza del codice non equivale a CI verde o a deploy; verificare l'eventuale merge prima di considerarlo su `main`.

| Area | Stato verificato | Gate ancora aperti |
|---|---|---|
| `main` | **P0–P2.4B2W e batch P2 #56–#65 integrati**, Flutter `0.31.0+33`. [PR #65](https://github.com/andreadada/simple-notes/pull/65) merged `ed45d0e`: auto-sync conservativa modelli V13 foreground. [PR #64](https://github.com/andreadada/simple-notes/pull/64) merged `5ae2bd3`: allegati S3 opt-in, Flyway **V14 nel repository**. CI Flutter/Backend/Compose PR #64 **verdi**, CI Flutter sull'ultimo commit main [#42887921742](https://github.com/andreadada/simple-notes/actions/runs/42887921742) **success** (analyze/test, Windows, Android JDK17/21).. | **P2 ancora aperta:** scheduler server/promemoria multi-device, OAuth Calendar/Outlook, collaborazione ACL, restore live, lifecycle/cleanup S3, test device. **Nessun deploy**: VPS Flyway V10 attestata al 03/11, V11–V14 solo nel repository |
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
| Backend nel repository | Spring Boot/PostgreSQL 17, Flyway **V14**; client Drift/SQLite **V8** | VPS attestata solo a Flyway **V10 (03/11/2026)**; migrazioni V11–V14, API e capability nuove non verificate sulla VPS |
| Test reali | VPS V10 verificata il 03/11; Google Windows connesso e pending 0 nel report disponibile | Android E2E, API strict, V11 e restore live ancora aperti |

## Incremento P2 — sync automatica conservativa modelli (PR #65 integrata)

[PR #65](https://github.com/andreadada/simple-notes/pull/65) sincronizza automaticamente in primo piano i cataloghi modelli V13, con checkpoint owner-scoped, PUT CAS e tre-way conflict detection. Pausa mentre la schermata Modelli è aperta, riavvia dopo le modifiche e dopo la sync task; risoluzione manuale esplicita. **Merge `ed45d0e` verificato su `main`; CI Flutter sull'ultimo commit main [#42887921742](https://github.com/andreadada/simple-notes/actions/runs/42887921742) **success** (analyze/test, Windows, Android JDK17/21)..** [Specifica](P2-AUTO-TEMPLATE-CATALOG.md). Non è una nuova sync dei task o background Android.

## Incremento P2 — allegati cloud alle note (PR #64 integrata)

[PR #64](https://github.com/andreadada/simple-notes/pull/64) introduce storage S3 compatibile, migrazione Flyway **V14** additiva, API JWT per owner/nota e upload PUT firmato + verifica HEAD/COPY prima di pubblicare, UI Forui con picker e conferma cancellazione. **Merge `5ae2bd3` verificato**, backend CI e test Flutter verdi; build native e post-merge verdi. Lo storage è disabilitato finché Coolify non dispone di bucket privato; nessuna migrazione o upload live. [Contratto](P2-NOTE-ATTACHMENTS.md).

## Incremento P2 — catalogo cloud modelli (PR #63 integrata)

**Incremento P2 integrato nel codice (10/11/2026):** [PR #63](https://github.com/andreadada/simple-notes/pull/63) aggiunge la possibilità di **trasferire manualmente** modelli personali con API JWT `GET/PUT /api/v1/templates/catalog`, controllo CAS, Flyway V13 additiva e conferme Forui. Non è sincronizzazione automatica e non modifica task/outbox. **PR #63 merged `b9dd67a`**; CI dell'ultimo codice in esecuzione. Nessun deploy: VPS attestata Flyway V10 (03/11). [Contratto](P2-CLOUD-TEMPLATES.md).

## Incremento P2 — sincronizzazione automatica regole (PR #62 integrata, 10/11/2026)

- [PR #62](https://github.com/andreadada/simple-notes/pull/62): riconciliazione foreground a tre vie con checkpoint per owner e revisione remota CAS. Upload/download automatici soltanto se univoci; su divergenza offline mostra conflitto e mantiene entrambi i cataloghi. UI Forui sospende l'automatismo mentre è aperto l'editor; nessuna nuova migrazione, modifica task o deploy. **Merge `766860c` confermato; CI dell'ultimo head ancora da completare.** Aggiunti controlli per rollback cloud e revisione stale durante Scarica. [Specifica](P2-AUTO-ACTION-CATALOG.md).

## Incremento P2 — catalogo cloud regole task (PR #61 integrata, 10/11/2026)

- [PR #61](https://github.com/andreadada/simple-notes/pull/61) **merged** (`bf16cba`): catalogo owner-scoped con GET/PUT JWT, CAS, Flyway V12 additiva, scambio manuale Forui Pubblica/Scarica e protezione 404/409. [Flutter CI #42821851199](https://github.com/andreadada/simple-notes/actions/runs/42821851199) **success** (399 test Flutter, Windows/Android), [Backend CI #42821851073](https://github.com/andreadada/simple-notes/actions/runs/42821851073) **success** (PostgreSQL 17 e build backend), [Markdown CI #42821851207](https://github.com/andreadada/simple-notes/actions/runs/42821851207) **success**. Nessun server job, deploy, migrazione live o test hardware. VPS Flyway V10 attestata al 03/11; **V11/V12 solo nel repo**. [Contratto](P2-CLOUD-ACTION-CATALOG.md).

## Incremento P2 — automazioni task locali (PR #60 integrata, 09/11/2026)

- [PR #60](https://github.com/andreadada/simple-notes/pull/60) **merged** (`e051162`): regole crea/completa, filtro titolo, priorità/tag/lista, editor Forui, un solo upsert/outbox per evento e backup `.snb` opzionale. [Flutter CI #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) **success** (392 test, build Android e Windows), [Markdown #42714514223](https://github.com/andreadada/simple-notes/actions/runs/42714514223) **success**. Nessun job server, nuovo deploy, restore live o test fisico. [Contratto](P2-TASK-ACTIONS.md).

## Incremento P2 — automazioni promemoria locali (PR #59 integrata, 09/11/2026)

- Implementate nel branch regole owner-scoped per scadenze con ora e blocchi, anticipi configurabili, priorità minima, enable/disable, editor Forui, dedup ledger e compatibilità con il precedente default 15/15. Il backup `.snb` include un campo opzionale validato; nessun restore live o nuovo deploy.
- [PR #59](https://github.com/andreadada/simple-notes/pull/59) **merged** (`aa17094`) dopo [Flutter CI #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) **success** (377 test, Android JDK17/21, Windows EXE/MSIX/recovery) e [Markdown #42701809467](https://github.com/andreadada/simple-notes/actions/runs/42701809467) **success**. Automazioni su task/server e prova OS rimangono aperte. [Specifica](P2-REMINDER-AUTOMATIONS.md).

## Incremento P2 — trasferimento modelli JSON (integrato, PR #58, 09/11/2026)

- Preparato import/export manuale dei modelli personali device-local, validazione fail-closed, ID rigenerati e consenso Forui. Nessuna nuova API, Flyway, sincronizzazione delle definizioni, restore live, deploy o modifica dati installati.
- [PR #58](https://github.com/andreadada/simple-notes/pull/58) **merged** (`e926a5a`) dopo [Flutter CI #42688444850](https://github.com/andreadada/simple-notes/actions/runs/42688444850) **success**: 369 test, analisi e build Android/Windows, e [Markdown CI #42688444618](https://github.com/andreadada/simple-notes/actions/runs/42688444618) **success**. Non è stata attestata alcuna installazione o prova hardware. [Contratto](P2-TEMPLATE-TRANSFER.md).

## Snapshot corrente dopo la PR #57 (09/11/2026)

- `main` include **P2 batch #57** ([PR #57](https://github.com/andreadada/simple-notes/pull/57), merge `90e5e26a`): esportazione file calendario RFC5545 ICS, modelli personalizzati locali per account e inclusione opzionale retrocompatibile nei backup cifrati .snb, widget Android di accesso rapido a Oggi/Inbox/Nuovo task.
- [Flutter CI #42634429343](https://github.com/andreadada/simple-notes/actions/runs/42634429343) **success**: 365 test, analisi statica, Windows EXE/MSIX e test di recovery, Android JDK17/21. [Markdown #42634428206](https://github.com/andreadada/simple-notes/actions/runs/42634428206) **success**.
- Il widget Android non visualizza dati personali; l'esportazione ICS richiede azione esplicita, non è sync OAuth. I modelli personalizzati sono **locali al dispositivo**, non sincronizzati tra dispositivi.
- La **P2 complessiva rimane aperta** per OAuth provider, collaborazione ACL, allegati S3, automazioni configurabili e restore live; prove hardware widget, Android↔Windows e deploy/API V11 non eseguite. [Matrice](P2-DELIVERY-MATRIX.md), [specifica](P2-LOCAL-INTEGRATIONS.md).

## Snapshot corrente dopo la PR #56 (09/11/2026)

- `main` include **P2.4B2W + batch P2 locale** ([PR #56](https://github.com/andreadada/simple-notes/pull/56), merge `56d40317`): Timeline/Gantt 14 giorni, filtri avanzati, statistiche locali e cinque modelli con task e sottotask inviabili tramite outbox.
- [Flutter CI #42625648804](https://github.com/andreadada/simple-notes/actions/runs/42625648804) **success**: 350 test, `flutter analyze`, Windows recovery/EXE/MSIX e APK Android JDK17/21; [Markdown #42625649033](https://github.com/andreadada/simple-notes/actions/runs/42625649033) **success**. Test sidebar creazione lista verde dopo la correzione che sposta gli strumenti sotto le liste.
- Nessun deploy, migrazione o modifiche ai dati installati. La VPS resta attestata a **Flyway V10 (03/11/2026)**, V11 solo nel codice; il restore live e il replay dell'outbox importata sono disabilitati.
- **La P2 originale non è interamente completata**: [matrice di consegna](P2-DELIVERY-MATRIX.md) identifica provider OAuth Calendar/Outlook, liste multiutente/ACL, allegati S3, widget Android, automazioni configurabili, restore live e prove hardware/release ancora pendenti.

## Snapshot corrente dopo la PR #55 (08/11/2026)

- `main` include **P2.4B2W** ([PR #55](https://github.com/andreadada/simple-notes/pull/55), merge `e5ab7b76`) e i passi precedenti. [Flutter CI #42525928542](https://github.com/andreadada/simple-notes/actions/runs/42525928542) **success**: 338 test, analisi statica, claim tra due isolate Dart, barriera native `fsync` Linux, test recovery Windows, build EXE/MSIX e APK Android Java 17/21. [Markdown CI #42525928540](https://github.com/andreadada/simple-notes/actions/runs/42525928540) **success**.
- `IsolateNameServer` coordina soltanto codice cooperativo nello stesso Flutter engine; il lock file esistente copre i processi cooperanti. La barriera `opendir/dirfd/fsync` è **solo Linux test-sandbox**: non verifica durabilità su Android/Windows, perdita di alimentazione reale o transazione atomica SQLite+preferenze. [Contratto](P2-RESTORE-DURABILITY.md).
- Il restore live, il replay dell'outbox importata, lo sblocco AutoSync, il deploy V11 e gli E2E fisici **rimangono esclusi**. VPS attestata Flyway V10 al 03/11; V11 nel codice, non attestata in produzione. I paragrafi seguenti sono cronologia.

## Snapshot corrente dopo la PR #54 (08/11/2026)

- `main` integra **P2.4B2V** ([PR #54](https://github.com/andreadada/simple-notes/pull/54), merge `73dba8ad`) oltre alle fasi precedenti.
- [Flutter CI #42522660761](https://github.com/andreadada/simple-notes/actions/runs/42522660761) **success**: 331 test Flutter, analisi statica, lock cross-process in test Linux/Windows, recovery sandbox Windows, EXE/MSIX Windows e APK Android Java 17/21. [Markdown CI #42522660755](https://github.com/andreadada/simple-notes/actions/runs/42522660755) **success**.
- Il lock ora rifiuta richieste concorrenti nel medesimo isolate e fra processi **cooperanti**, verifica lock/path non regolari e il journal dopo append. Il lock rimane advisory e non copre isolate separati nello stesso processo POSIX, writer esterni, TOCTOU/hardlink né directory fsync. Tutto il recovery rimane sandbox/test-only, senza restore live o replay outbox.
- Nessun deploy o modifica alla VPS. Il database di produzione è attestato fino a Flyway **V10 (03/11/2026)**, mentre V11 esiste nel codice; E2E Windows/Android fisici ancora rinviati. I riepiloghi storici sottostanti restano cronologia, non uno stato corrente.

## Snapshot corrente dopo la PR #53 (06/11/2026)

- `main` include **P2.4B2U** ([PR #53](https://github.com/andreadada/simple-notes/pull/53), merge `afa835d6`) oltre a tutte le fasi precedenti.
- [Flutter CI #42239264547](https://github.com/andreadada/simple-notes/actions/runs/42239264547) **success**: 322 test Flutter, analyze, APK Java 17/21, test recovery su sandbox Windows, Windows EXE/MSIX; [Markdown #42239264424](https://github.com/andreadada/simple-notes/actions/runs/42239264424) **success**. La guardia CI impedisce importazione dell'orchestratore solo-test dal client produttivo.
- Consenso monouso e rollback dopo crash sono verificati **soltanto su filesystem temporaneo**. Non sono implementati il restore sul profilo installato, il replay dell'outbox importata o il consenso live. Restano aperti fsync directory/lock cross-process/atomicità SQLite+preferenze.
- La VPS rimane attestata a Flyway **V10 (03/11/2026)**; V11 è presente nel codice ma non è attestato il deploy, né API strict, né test fisici Windows↔Android. Nessun dato di produzione modificato.

## Snapshot corrente dopo la PR #52 (06/11/2026)

- `main` ora include [PR #51](https://github.com/andreadada/simple-notes/pull/51) (guard di validità dello snapshot locale) e [PR #52](https://github.com/andreadada/simple-notes/pull/52) (ricevuta informativa delle scelte e del preflight); merge `16869c8f`.
- [Flutter CI #42233052499](https://github.com/andreadada/simple-notes/actions/runs/42233052499) **success**: analisi statica, widget test, APK Android Java 17/21, Windows EXE/MSIX e rehearsal recovery su sandbox. [Markdown CI #42233052437](https://github.com/andreadada/simple-notes/actions/runs/42233052437) **success**. Backend/Compose restano attestati dai run precedenti della PR #50; non confonderli con un deploy.
- I due sottostep sono **informativi e non scriventi**: nessun restore `.snb` live, nessun replay outbox importata, nessuna modifica alla VPS e nessuna autorizzazione implicita da `reviewComplete`. Il prossimo lavoro richiede consenso, lock/recovery durabile, atomicità cross-store e collaudi differiti.
- Il riepilogo storico della PR #50 sotto questa sezione resta valido per l'epoca, ma non rappresenta più la punta corrente di `main`.

## Snapshot verificato dopo la PR #50 (06/11/2026)

- `main` baseline `0d31133b`: [PR #50](https://github.com/andreadada/simple-notes/pull/50) (capability runtime V11) e [PR #49](https://github.com/andreadada/simple-notes/pull/49) (409 tipizzato `SYNC_OPERATION_ID_REUSE` e stop sicuro della sync Flutter) integrate; nessuna PR aperta alla verifica.
- CI sul merge #50: [Backend](https://github.com/andreadada/simple-notes/actions/runs/42227814409), [Compose](https://github.com/andreadada/simple-notes/actions/runs/42227814144) e [Markdown](https://github.com/andreadada/simple-notes/actions/runs/42227814257) `success`. Ultima [Flutter CI](https://github.com/andreadada/simple-notes/actions/runs/42103008443) `success` sul merge #49, non sul merge #50.
- **Prossimo gate di sviluppo:** implementare solo con garanzie verificabili il percorso di restore live, senza sbloccare replay automatici: embargo AutoSync, lock e recovery durabili, consenso per entità e test. Deploy Coolify V11 ed E2E fisici rimangono separati e rinviati dall'utente.
- Gli addendum seguenti con diciture storiche «branch/PR/in verifica» sono snapshot della loro redazione: i sottostep fino a P2.4B2R risultano oggi integrati in `main`, non necessariamente presenti nel runtime VPS.

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


## P2.4B2F — Confronto locale + verifica cloud opzionale (04/11/2026, sviluppo)

Aggiunti `backup_cloud_safety.dart` e test, e pulsante Forui «Consulta inventario cloud» nel dialog confronto .snb: GET autenticato esplicito su `/sync/inventory`, solo con access token già valido, nessun refresh/post di sincronizzazione. Segnala rischi e divergenze solo con conteggi e non concede restore o replay. API 404/offline significa **non verificato**, non assenza di conflitti. Deriva da PR CI #37 per evitare build duplicate; CI e merge di entrambe vanno verificati. Nessun deploy o accesso in scrittura.


## P2.4B2G — Planner dry-run dei conflitti (04/11/2026, PR in sviluppo)

Matrice deterministica di rischi (local/backup/cloud) e quattro strategie *solo ipotetiche*, collegata al dialog Forui dopo il GET dell'inventario. Aggrega assenze, versioni, tombstone, differenze di contenuti e code pendenti senza riportare dati privati; fingerprint SHA-256 lega la bozza a snapshot e inventario. Nessun nuovo endpoint, import, update, sync o autorizzazione live: piano sempre non eseguibile. Test unitari aggiunti, CI/merge non ancora verificati. Branch dipende dalla PR #38; nessun deploy.


## P2.4B2H — Revisione interattiva senza applicazione (04/11/2026, sviluppo)

Scheda temporanea `ReconciliationWorksheet`, scelte per singolo item con token opachi e controllo fingerprint, UI Forui «Esamina conflitti» con titoli visibili solo al proprietario autenticato. Il report aggregato non contiene PII e le scelte non vengono salvate. Errori/sorgenti assenti o oltre 500 entità restano fail-closed; nessun permesso di ripristino/sync. Test unitari aggiunti, PR e CI da verificare. Nessun deploy.

## P2.4B2I — Server-side CAS/preflight (05/11/2026, PR)

Implementati controllo batch read-only (`/sync/reconciliation/check`) su owner/cursor/revisioni e campo opzionale `expectedAccountCursor` per `/sync/apply`, verificato atomicamente sotto advisory lock. Client legacy invariati. Test Testcontainers: isolamento JWT, assenza payload nel check, richieste invalide, cursore obsoleto, retry idempotente e concorrenza. CI e merge da verificare. **Nessun deploy** e restore live sempre vietato.

## P2.4B2J — Check remoto read-only nel confronto (05/11/2026, PR Flutter)

Nuovo `reconciliation_preflight_client.dart` e test MockClient, con pulsante Forui opt-in «Ricontrolla revisioni». POST è **sola lettura lato server**, senza richieste di sincronizzazione. Risposta accuratamente validata e bozza invalidata quando il cursore o le revisioni cambiano, il server manca o la verifica fallisce. Inventario oltre 100 item non viene controllato parzialmente. Tutti i permessi restore/replay/AutoSync restano false. PR backend #41 già integrata su main ma non deployata; Flutter CI/merge da verificare.


## P2.4B2K — Guard fail-closed contro divergenze API legacy (05/11/2026, PR)

Aggiunto controllo tra righe materializzate e ultimo evento owner-scoped durante `/sync/reconciliation/check`. Se una creazione, modifica o tombstone legacy non è registrata nel ledger, risponde 409 senza esportare contenuti. Test PostgreSQL di creazione non tracciata, update e cancellazione di nota tracciata e isolamento account. CI/merge da verificare; nessun deploy, nessun restore operativo.


## P2.4B2L — Controllo owner-wide dei dati fuori ledger (05/11/2026, PR)

Nel preflight `/sync/reconciliation/check` aggiunto audit read-only dell'intero account per nota/task/lista vs latest sync_change: identifica record legacy non richiesti nel batch, versioni/tombstone non tracciati e record attivi mancanti. Mantiene validi tombstone sintetici senza riga. Test integrazione PostgreSQL e documentazione aggiornati; CI/merge da verificare, **nessun deploy o restore**.


## P2.4B2M — Backend: write-path legacy unificato (05/11/2026, PR)

`NoteService` e `TaskService` delegano POST/PUT/PATCH/DELETE a `SyncService.apply` con advisory lock dell'owner prima di letture che precedono mutazioni. I vecchi endpoint non lasciano più eventi sync mancanti; completion/task preserva dati moderni. Test di integrazione + concorrenza REST vs sync, 426 per due civile, 409/lock, vecchi test di corruzione spostati a bypass SQL espliciti. CI/merge da verificare; **nessun deploy Coolify**.


## P2.4B2N — Integrità owner-wide anche su GET inventory (05/11/2026, PR)

`SyncService.inventory` verifica ora l'intera coerenza materiale vs ledger prima di restituire `complete=true`. Anomalie storiche SQL/legacy non loggate generano HTTP 409 senza risposta parziale. Test Testcontainers per isolamento owner, versione errata, riga attiva mancante, delete sintetico e REST tracciato. CI/merge da verificare; nessun deploy.


## P2.4B2O — Fingerprint idempotenza (05/11/2026, PR)

Aggiunta migrazione Flyway V11 **additiva e nullable** e digest canonical SHA-256 dell'intento per i nuovi `sync_operation`. Retry con payload/action/versione differenti e stesso operation ID => 409; JSON semanticamente identico con chiavi riordinate e cursore mutato resta idempotente. Righe storiche NULL mantengono la compatibilità. Test PostgreSQL owner/race/byte payload e documentazione aggiornati; CI/merge da verificare. Nessuna migrazione o deploy effettuati su produzione.

## P2.4B2P — Gate read-only di rilascio Flyway V11 (05/11/2026, PR)

Inspector PostgreSQL esteso a V11 con controllo del fingerprint nullable VARCHAR(64), verifica della versione esatta e formati non nulli. Nuovo wrapper esplicito `infra/release-v11-readiness.sh`, senza modificare la verifica V10 storica; Compose CI prova su PostgreSQL **sintetico** V10→V11 e rifiuta colonna sbagliata. Nessuna verifica né deploy sulla VPS: lo stato reale confermato resta Flyway V10 (03/11). [Runbook](RELEASE-V11-READINESS.md).


## P2.4B2Q — Errore strutturato su operationId non riutilizzabile (05/11/2026, PR)

Il backend distingue un 409 da `SYNC_OPERATION_ID_REUSE` da un normale 409 di versione senza includere dati privati. Flutter ferma l'upload, conserva l'intera outbox e non offre la risoluzione keep-local/remote quando l'ID è legato a un intento già committato. Parser limitato e test API/Flutter aggiunti; CI/merge da verificare, nessun deploy. [Runbook](P2-SYNC-INTENT-CONFLICTS.md).

## P2.4B2R — Capability runtime richiesta dal gate V11 (05/11/2026, PR)

`/api/v1/capabilities` annuncia `syncOperationFingerprintSchema=1`; il wrapper V11 lo richiede esplicitamente e il validatore rifiuta tipi errati o capability mancante. Test Python offline per V10 backward compatibility/V11 strict e backend Testcontainers. Nessun cambiamento ai dati utenti, CI/merge da verificare, nessun deploy. [Runbook](RELEASE-V11-READINESS.md).

## P2.4B2S — Snapshot locale invariato durante la revisione (06/11/2026)

Il client controlla in sola lettura che i dati locali non siano cambiati mentre è aperto un confronto `.snb`: un digest canonico delle cinque tabelle e delle preferenze (inclusi cursor e outbox) viene ricalcolato prima/dopo le richieste cloud e prima di esaminare le scelte. Se lo stato è diverso, la bozza è invalidata e occorre ripetere il confronto. Nessuna scrittura, restore live, replay outbox o deploy attivato. La verifica **non** è un lock o un lease e non rende atomico SQLite + SharedPreferences; i test di integrazione nativi/real-device restano rinviati.

## P2.4B2T — Ricevuta informativa di revisione (06/11/2026, sviluppo)

Nuovo controllo a livello client che riassume le scelte simulate solo se il worksheet è ancora legato agli snapshot di dispositivo/backup/inventario cloud e il preflight copre tutte le revisioni ammesse (max 100). Un account diverso, dati o cursor mutati, check assente/stantio o scelte rimaste invalida il completamento. Il dialog mostra solo conteggi e stato; scelte e report sono **volatili** e non costituiscono permessi per scritture, restore o replay dell'outbox. Nessun deploy V11 o collaudo fisico incluso.

## P2.4B2U — Sandbox consent + recovery (06/11/2026, integrato PR #53)

Incremento integrato in `main` con PR #53: consenso monouso per l'esecuzione **solo in sandbox temporanea**, validazione AES-GCM same-owner e compensazione SQLite/preferenze dopo crash simulati. Nessuna modifica a startup, OAuth, cloud o profili installati; i getter di autorizzazione live/sync/replay restano sempre false. Le garanzie native cross-process/fsync e i test fisici sono ancora aperti. La tabella iniziale descrive lo stato integrato; questo non costituisce rilascio o deploy.

## P2.4B2V — Hardening lock/journal in sandbox (08/11/2026, integrato PR #54)

Branch `feat/p2-4b2v-sandbox-lock-journal-hardening`: aggiunto lease OS non bloccante e guardia intra-isolate per le simulazioni di recupero, verifiche fail-closed dei tipi di file e della directory journal, read-back post-append e test con processo Dart separato. Nessun intervento sul client in uso, sui dati locali installati, sul cloud o sulla VPS. Il lock resta advisory, senza garanzie contro TOCTOU/hardlink, e manca fsync directory. L'integrazione su `main` è documentata nello snapshot corrente; nessun ripristino reale è autorizzato.

## P2.4B2W — Durability / isolate sandbox (08/11/2026, integrata PR #55)

Incremento integrato in `main` con la PR #55: claim cooperativo su `IsolateNameServer` oltre al lock OS per provare l'esclusione tra isolate Flutter; barriera fsync del journal e dei rename dei file sandbox disponibile esclusivamente su Linux, e fallback esplicitamente non attestato altrove. Test su contesa, errori prima/dopo rename e OS sync. **Il profilo installato, il cloud e il deploy non sono modificati**. Restano aperti test reali power-loss, durabilità Windows/Android, atomicità SQLite/preferenze, non-cooperating writers e restore live. [Contratto](P2-RESTORE-DURABILITY.md).

## Batch funzionalità P2 (09/11/2026, integrato PR #56)

Integrato su `main` con PR #56: Timeline/Gantt a 14 giorni, filtri avanzati per task, analytics solo sui dati locali e cinque modelli con sottotask/UUID salvati in SQLite + outbox. Test dedicati e CI Flutter/Windows/Android superati. Backend Flyway V11 è **solo nel codice** e non attestato sulla VPS; restore live e le integrazioni OAuth Calendar/Outlook, collaborazione/S3/widget Android rimangono aperti. La matrice effettiva della P2 è in [P2-DELIVERY-MATRIX.md](P2-DELIVERY-MATRIX.md). La tabella principale sopra descrive lo stato integrato.

## Incremento P2 integrato — Calendario esportabile, modelli utente e widget Android (09/11/2026)

Integrazione PR #57 su `main`: esportazione manuale eventi in ICS, modello utente CRUD per account/dispositivo con chiave hashed e backup .snb retrocompatibile, widget launcher Android senza dati privati. Quattro nuove suite di test dedicate. CI Flutter/Windows/Android e Markdown superate; merge completato. Nessun deploy, modifica alla VPS, migrazione o restore live. [Dettagli](P2-LOCAL-INTEGRATIONS.md).
