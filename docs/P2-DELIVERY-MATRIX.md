# P2 — Matrice di consegna e criteri di chiusura

Aggiornato 9 novembre 2026. **CI verde non equivale a deploy Coolify o collaudo su dispositivi reali.**

**Quinto incremento P2 integrato:** [PR #60](https://github.com/andreadada/simple-notes/pull/60) merged (`e051162`), [Flutter CI #42714514197](https://github.com/andreadada/simple-notes/actions/runs/42714514197) **success** (392 test, analisi, Android JDK17/21, Windows EXE/MSIX e recovery), [Markdown #42714514223](https://github.com/andreadada/simple-notes/actions/runs/42714514223) **success**. Azioni task locali crea/completa con filtro titolo e priorità/tag/lista, un solo upsert/outbox. Non è uno scheduler server. [Contratto](P2-TASK-ACTIONS.md).

**Quarto incremento P2 integrato:** [PR #59](https://github.com/andreadada/simple-notes/pull/59) merged (`aa17094`), [Flutter CI #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) success (377 test e build Android/Windows), [Markdown #42701809467](https://github.com/andreadada/simple-notes/actions/runs/42701809467) success. Regole locali per notifiche native, non automazioni generaliste o delivery OS garantita. [Specifica](P2-REMINDER-AUTOMATIONS.md).

**Terzo incremento P2 integrato:** [PR #58](https://github.com/andreadada/simple-notes/pull/58), merge `e926a5a`, trasferimento manuale JSON dei modelli locali. [Flutter CI #42688444850](https://github.com/andreadada/simple-notes/actions/runs/42688444850) PASS (369 test e build Windows/Android), [Markdown #42688444618](https://github.com/andreadada/simple-notes/actions/runs/42688444618) PASS. Il file è non cifrato e non realizza la sync dei modelli o il restore live.

**Secondo batch locale integrato:** [PR #57](https://github.com/andreadada/simple-notes/pull/57), merge `90e5e26a`; [Flutter CI #42634429343](https://github.com/andreadada/simple-notes/actions/runs/42634429343) PASS (365 test, Android JDK17/21 e Windows), [Markdown #42634428206](https://github.com/andreadada/simple-notes/actions/runs/42634428206) PASS.

**Batch locale integrato:** [PR #56](https://github.com/andreadada/simple-notes/pull/56) merged (`56d40317`); [Flutter CI](https://github.com/andreadada/simple-notes/actions/runs/42625648804) PASS (350 test, Android JDK17/21, Windows), [Markdown CI](https://github.com/andreadada/simple-notes/actions/runs/42625649033) PASS. **La P2 complessiva resta aperta** sulle integrazioni elencate sotto.

La roadmap P2 include funzioni implementate, estensioni non ancora realizzate e gate operativi rinviati. Questo documento impedisce che una simulazione di backup o una compilazione vengano dichiarate ripristino o rilascio reali.

## Codice già disponibile, o sviluppato nel batch di chiusura

| Area | Implementazione | Limiti |
|---|---|---|
| P2.1 JSON portabile | Import additivo, esportazione, controllo schema | Verifica picker/share fisici rinviata |
| P2.2–2.3 ICS | File/HTTPS, ricorrenze, fonti, cache read-only | Nessun OAuth o scrittura provider |
| P2.4A CSV | Esportazione locale | Prove reali del picker pendenti |
| P2.4B1 backup cifrato | AES-GCM, verifica password/owner, confronto read-only | Nessun ripristino scrivente |
| P2.4B2 recovery | Journal, checkpoint e rollback in sandbox, preflight cloud CAS | Non è un restore sul profilo installato |
| Timeline/Gantt | Vista pianificazione a 14 giorni con blocchi e milestone civili | Nessun drag-and-drop cross-device |
| Filtri avanzati | Tag, ricerca, priorità, scadenze e ordinamento | Locali/offline, nessun nuovo endpoint |
| Statistiche | Totali, completate, arretrate, priorità, prossimi 7 giorni, tempo e liste | Fotografia dello stato, non cronologia |
| Modelli attività | Cinque preset + CRUD di modelli utente, owner-scoped locali, nuovi task tramite outbox e backup .snb compatibile | Definizioni personalizzate non sincronizzate fra dispositivi |
| Trasferimento modelli JSON | Import/export manuale definizioni con copia additiva e conferma, nessun task/outbox creato | Non cifrato, non sostituisce la sync; prove fisiche rinviate |
| Azioni task locali (PR #60 integrata) | Evento manuale crea/completa, filtro titolo, priorità/tag/lista, editor Forui, backup opzionale; 392 test e build native verdi | No scheduler server, cataloghi non sincronizzati, E2E fisici differiti |
| Regole promemoria locali (PR #59 integrata) | Tipi due/block, anticipo e priorità, editor Forui, dedup ledger e backup opzionale | Solo OS notifiche e quando l'app aggiorna il piano; non sono automazioni server generali |

Le statistiche sono calcolate sui dati locali senza telemetria. I modelli producono normali attività e operation ID distinti nella coda di sincronizzazione. Le date civili non sono riclassificate in un'ora UTC inventata.

## Gate P2 ancora aperti — non dichiararli finiti

| Area | Che cosa manca realmente |
|---|---|
| Restore live .snb | Coordinamento SQLite/preferenze installate, lock nativo, recupero dopo power loss, consenso, quarantena e riconciliazione outbox |
| Google Calendar/Outlook | OAuth separato, permessi minimi revocabili, API e token per account, test autenticati |
| Liste condivise | ACL multiowner, ruoli, assegnazioni, audit server, migrazioni, protezioni accesso e UI |
| Allegati S3 | Bucket e policy, endpoint signed URL, quote, verifiche file e flussi offline |
| Widget Android | Widget nativo Oggi/Inbox/Nuova attività compilato (Java 17/21); launcher/cold-start/logout su dispositivo fisico non verificati |
| Automazioni configurabili | **Parziale:** notifiche locali PR #59 e azioni task locali PR #60 integrate; restano scheduler server, dedup multi-device, regole sincronizzate e delivery affidabile |
| Release | VPS V11, OAuth Android, upgrade Windows, firma, backup/offsite, E2E Windows↔Android e controlli reali |

## Criteri per dichiarare P2 completata

- Implementato = codice e test automatici verdi; rilasciato = deploy verificato e controlli sul dispositivo dove necessari.
- Nessuna funzionalità di restore può riscrivere un database reale o rigiocare operazioni importate senza prova del recupero e consenso esplicito.
- La preflight del cloud non fornisce un lease e un confronto non è un'autorizzazione alla scrittura.
- Chiudere i requisiti con un criterio verificabile e test diretto; evitare nuove micro-fasi che aggiungono solo documentazione.

**La P2 non va marcata completata finché le righe aperte restano tali.** Il trasferimento JSON non equivale alla sincronizzazione cloud dei modelli. La CI del batch locale viene registrata in CURRENT-STATUS dopo l'esecuzione.

## Batch P2: calendario, modelli e accesso rapido Android (09/11/2026, integrato PR #57)

- Esportazione manuale ICS per task non completati: date-only senza falso timestamp, istanti UTC esatti, time block, UID stabili, escaping e folding UTF-8, limite 8 MiB.
- Modelli utente in SharedPreferences per owner: CRUD e definizioni backup compatibili con vecchi archivi .snb v1; applicazione del modello come task SQLite/outbox. Definizioni locali al dispositivo, non condivise in cloud.
- Widget Android launcher: apri Oggi, Inbox, nuova attività via MainActivity/MethodChannel, senza memorizzare/esporre contenuti. Non è un widget che mostra task, né prova hardware completata.
- Resta **non implementato nel batch #57**: collegamento OAuth automatico Google/Outlook, collaborazione ACL, allegati S3, automazioni configurabili e restore live. La successiva PR #59 copre soltanto regole di notifica locali. Il collaudo fisico del widget Android resta **non eseguito**. [Contratto](P2-LOCAL-INTEGRATIONS.md).
