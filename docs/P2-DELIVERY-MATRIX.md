# P2 — Matrice di consegna e criteri di chiusura

Aggiornato 9 novembre 2026. **CI verde non equivale a deploy Coolify o collaudo su dispositivi reali.**

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
| Modelli attività | Cinque preset con sottotask, normale salvataggio e outbox | Preset integrati, non editor modelli personalizzati |

Le statistiche sono calcolate sui dati locali senza telemetria. I modelli producono normali attività e operation ID distinti nella coda di sincronizzazione. Le date civili non sono riclassificate in un'ora UTC inventata.

## Gate P2 ancora aperti — non dichiararli finiti

| Area | Che cosa manca realmente |
|---|---|
| Restore live .snb | Coordinamento SQLite/preferenze installate, lock nativo, recupero dopo power loss, consenso, quarantena e riconciliazione outbox |
| Google Calendar/Outlook | OAuth separato, permessi minimi revocabili, API e token per account, test autenticati |
| Liste condivise | ACL multiowner, ruoli, assegnazioni, audit server, migrazioni, protezioni accesso e UI |
| Allegati S3 | Bucket e policy, endpoint signed URL, quote, verifiche file e flussi offline |
| Widget Android | Widget/launcher nativi, account/logout privacy, aggiornamento, test fisici |
| Automazioni configurabili | Regole persistenti, esecuzione affidabile, deduplica ed editor; le ricorrenze/reminder esistenti non bastano |
| Release | VPS V11, OAuth Android, upgrade Windows, firma, backup/offsite, E2E Windows↔Android e controlli reali |

## Criteri per dichiarare P2 completata

- Implementato = codice e test automatici verdi; rilasciato = deploy verificato e controlli sul dispositivo dove necessari.
- Nessuna funzionalità di restore può riscrivere un database reale o rigiocare operazioni importate senza prova del recupero e consenso esplicito.
- La preflight del cloud non fornisce un lease e un confronto non è un'autorizzazione alla scrittura.
- Chiudere i requisiti con un criterio verificabile e test diretto; evitare nuove micro-fasi che aggiungono solo documentazione.

**La P2 non va marcata completata finché le righe aperte restano tali.** La CI del batch locale viene registrata in CURRENT-STATUS dopo l'esecuzione.

## Batch P2: calendario, modelli e accesso rapido Android (09/11/2026, CI in verifica)

- Esportazione manuale ICS per task non completati: date-only senza falso timestamp, istanti UTC esatti, time block, UID stabili, escaping e folding UTF-8, limite 8 MiB.
- Modelli utente in SharedPreferences per owner: CRUD e definizioni backup compatibili con vecchi archivi .snb v1; applicazione del modello come task SQLite/outbox. Definizioni locali al dispositivo, non condivise in cloud.
- Widget Android launcher: apri Oggi, Inbox, nuova attività via MainActivity/MethodChannel, senza memorizzare/esporre contenuti. Non è un widget che mostra task, né prova hardware completata.
- Resta **non implementato**: collegamento OAuth automatico Google/Outlook, collaborazione ACL, allegati S3, automazioni configurabili, restore live e collaudo fisico Android. [Contratto](P2-LOCAL-INTEGRATIONS.md).
