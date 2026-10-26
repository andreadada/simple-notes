<!-- CURRENT-STATUS-REF -->
> **Stato operativo 26/10/2026:** P1.13 Weekly Habits su `main` (PR #14, Flutter `0.18.0+20`, CI verde); P1.14 Sticky Windows **in branch** `feature/p1-14-sticky-windows` (Flutter candidata `0.19.0+21`, CI/merge/device non attestati). Repo Flyway V10, ultimo Coolify confermato V8, nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Sticky Windows](P1-STICKY-WINDOWS.md).

<!-- Vincolo UI aggiornato 24/10/2026: tutti i titoli di liste, task e subtasks usano la stessa logica inline-first. La sottolineatura non deve eccedere la larghezza del valore (o dell'hint) +~1px, nessun grigio di riempimento; placeholder semitrasparente (~72%). Utilizzare InlineTextMetrics.fieldWidth in notes_theme.dart, non minWidth artificiale o Expanded TextField full-width. Regole: ../design.md, ui-forui.md e ui-design-audit.md. -->
# Organizzazione attività (P0) — liste, priorità, tag e sottotask

> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](T4-DEVICE-SYNC.md).

**Implementato nel codice del branch `main` il 23 ottobre 2026.** Test automatici backend + Flutter riusciti; **non è ancora stato testato con Coolify aggiornato e due dispositivi reali**.

## Comportamento

- **Liste personalizzate**: creazione e cancellazione dalla sidebar Forui (Windows e Android); il **titolo della lista si rinomina direttamente nell'header**, cliccando sul testo, senza pulsante Rinomina né dialog aggiuntivo. Le liste vuote rimangono disponibili anche dopo un riavvio perché sono entità vere; non sono ricavate dai task.
- **Inbox**: attività senza lista, anche se hanno una scadenza. **Tutto** mostra le attività aperte di tutte le liste. Selezionando una lista, si filtrano le attività di quella lista.
- **Eliminazione lista**: conferma esplicita, poi tutte le attività della lista (anche completate) vengono spostate senza essere cancellate; soltanto dopo viene registrata la cancellazione della lista. La sync backend rifiuta la rimozione di una lista non vuota con 409, così evita riferimenti orfani.
- **Priorità**: normale = 0, P1 = 1, P2 = 2, P3 = 3. Nei risultati P3 viene prima; c'è un filtro per livello.
- **Tag**: massimo 16 per attività, 40 caratteri ciascuno, valori distinti; editor Forui, ricerca per tag.
- **Sottotask**: massimo 50 per attività; UUID persistenti, testo e stato completato; modificabili nell'editor e spuntabili nel pannello dettagli. Le modifiche si sincronizzano come parte della revisione del task.
- Ricerca su titolo, descrizione, tag e titolo dei sottotask. Rimangono esclusi filtri complessi basati su più regole.

## Persistenza e migrazioni

| Componente | Cambiamento |
| --- | --- |
| Flutter model | `LocalTask.listId`, `priority`, `tags`, `subtasks`; `LocalTaskList` e `LocalSubtask` |
| SQLite/Drift | schema **v4**, tabella `task_list_entries`, colonne `list_id`, `priority`, `tags_json`, `subtasks_json` in `task_entries` |
| PostgreSQL/Flyway | **V6__task_organization.sql**: versione delle liste, priorità e JSON dei tag/sottotask su `task`; indice per lista e utente |
| Backend | `TaskListEntity` e `TaskListRepository`; `SyncService` valida listId con owner corrente e i metadati |
| Sincronizzazione | `entityType: list` supporta upsert/delete/versioni/tombstone; le modifiche del task restano `entityType: task` |
| Client | `LocalStore` e `AppDatabase` usano outbox sequenziale; `CloudSync` riutilizza upload/delta/pull e UI conflitti |

### Ordine delle mutazioni e compatibilità

SQLite Drift registra i timestamp con risoluzione al secondo. L'outbox assegna timestamp strettamente crescenti alle **nuove operazioni** per rispettare le dipendenze: lista prima del task che la utilizza; task spostati in Inbox prima del delete-list. Modifiche preesistenti in coda sono preservate.

La migrazione schema v4 è incrementale e usa default: priorità 0, tag e sottotask `[]`, lista null. Il payload backend accetta l'assenza di questi campi per compatibilità con app vecchie. **Un client vecchio non conserva necessariamente la nuova organizzazione quando sovrascrive una vecchia copia dello stesso task:** aggiornare tutti i dispositivi.

**Ordine obbligatorio per provare su dati reali:**
1. Backup e restore reale già riusciti 24/10, V6 presente nel DB. Offsite non effettuata per scelta; collaudo T4.2 deve partire dalla verifica API, non dal redeploy.
2. Redeploy API da `main`, attendere Flyway **V5+V6**, controllare `/actuator/health`, errori e test login già funzionante.
3. Aggiornare Flutter Windows e Android (con generazione Drift), senza cancellare SQLite né disinstallare.
4. Testare lista vuota, task dentro la lista, priorità/tag/sottotask, modifica su secondo device, riavvio, eliminazione della lista senza perdita del task.
5. Testare il comportamento offline e in caso di conflitto. Non segnare E2E concluso prima dei test reali.

## Test effettuati nel repository

- [Backend CI](https://github.com/andreadada/simple-notes/actions/runs/39990997833): `organizedTasksAndListsSyncWithOwnerIsolation` verifica privacy, contenuto, 409 lista non vuota, spostamento e tombstone.
- [Flutter CI (analisi e test)](https://github.com/andreadada/simple-notes/actions/runs/39991667611): `task_organization_test.dart` verifica due SQLite separati e round-trip PC ↔ Android simulati, cambio sottotask, rinomina e delete sicuro; `widget_test.dart` verifica la creazione lista dalla UI Forui.

## Limitazioni non nascoste

- Le modifiche concorrenti ai diversi sottotask dello **stesso task** possono generare conflitto dell'intero task; non esiste merge campo-per-campo.
- Filtri salvati, ordinamenti personalizzati, tag come entità globali, ricorrenze e notifiche rimangono da sviluppare.
- Rebootstrap completo e recupero edit-vs-delete remoto restano attività aperte nel P0.
- CI green non prova né deploy Coolify né funzionamento fisico o backup del database reale.

## UX obbligatoria — titoli inline

I valori testuali semplici già mostrati devono essere **normalmente editabili nello stesso punto**: il titolo di lista nell'header è già `InlineEditableTitle`. Clicca il testo, scrivi, salva con Invio o perdita di focus, annulla con Esc; senza pulsante `Rinomina`. Titolo corto = campo compatto, non un input largo quanto la pagina. La modifica richiama `LocalStore.renameList()` e viene registrata nella stessa outbox della precedente rinomina. Applicare progressivamente a titoli di task/note quando non comporta regressioni; mantenere dialog per le modifiche multi-campo. Regola generale: [design.md](../design.md) e [ui-forui.md](ui-forui.md).

## P1.8 — Riutilizzo dei campi di organizzazione

La matrice Eisenhower deriva **importanza** dalle priorità task già esistenti (`P2`/`P3`) e **urgenza** da `due` (date-only civile o istante entro 48h). Non aggiunge campi né migrazioni; scegliere un quadrante non assegna attività a una persona. [Specifiche aggiornate](P1-EISENHOWER.md).

## Ambito Habit Tracker (P1.11)

Le abitudini quotidiane non sono tag, sottotask o task ricorrenti: il loro storico viene salvato su SharedPreferences per dispositivo/owner, con check-in civili e streak, **non** via LocalStore o sincronizzazione task. Le liste Kanban e le ricorrenze rimangono invariate. [Specifiche](P1-HABITS.md).

## P1.12 — Eventi Countdown non sono task

Countdown permette date civili e con ora senza creare un task, blocco orario, ricorrenza o promemoria. I record sono locali in SharedPreferences e non modificano Kanban/Eisenhower né priorità, listId, tag e scadenze task. [Specifica](P1-COUNTDOWNS.md).

## P1.13 — Obiettivi frequenza Habit

Habit Tracker resta una funzionalità distinta da task ricorrenti, tag, liste e time blocks. L'obiettivo di 1–7 check-in ogni settimana modifica solo `LocalHabit.weeklyTarget` locale; non è una nuova scadenza, ricorrenza backend o assegnazione Kanban. [P1.13](P1-WEEKLY-HABITS.md).
