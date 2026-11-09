# P2 — Regole locali configurabili per i promemoria

**9 novembre 2026 — [PR #59](https://github.com/andreadada/simple-notes/pull/59) integrata su `main` (`aa17094`).** [Flutter CI #42701809601](https://github.com/andreadada/simple-notes/actions/runs/42701809601) **success** (377 test, analyze, Android JDK17/21 e Windows EXE/MSIX/recovery); [Markdown #42701809467](https://github.com/andreadada/simple-notes/actions/runs/42701809467) **success**. Nessun deploy o test hardware. Prima tranche delle automazioni P2: **regole di notifica native locali**, non automazioni server generali. CI, merge, Windows/Android reali e deploy rimangono stati separati.

## Flusso e confini

La voce **Strumenti → Automazioni** consente di aggiungere, modificare, sospendere e cancellare fino a 20 regole. Ogni regola stabilisce un evento: scadenza con ora oppure inizio di un blocco orario; anticipo 0, 5, 15, 30, 60 o 1440 minuti; priorità minima P0–P3; e abilitazione individuale. Il controllo **Attiva/Disattiva** gestisce l'opt-in globale già previsto dal sistema P1.7, con richiesta esplicita dei permessi Android. Non sono schedulate notifiche per scadenze *date-only* e task completati.

- Solo Android o Windows **MSIX con package identity**. ZIP/EXE non offre notifiche; la schermata indica il limite. Android mantiene scheduling **inexact**, senza richiedere exact alarm.
- Le regole sono archiviate in SharedPreferences con chiave SHA-256 dell'owner, schema 1, max 20; lettura corrotta/ignota **fail-closed**, senza reset delle impostazioni. Nessuna nuova API, scope OAuth, Flyway, Drift o outbox.
- Se la preferenza non esiste, si ricostruiscono **le due regole precedenti** (scadenza e blocchi a 15 minuti) senza scrittura implicita. Un catalogo esplicitamente vuoto resta vuoto, non reintroduce i default.
- Il motore riusa `ReminderPlanner`, gli ID stabili delle occorrenze e `ReminderReconciler`; trigger equivalenti sono deduplicati per owner/task/tipo/istante/anticipo. Al cambio regola il diff annulla prima gli allarmi obsoleti. Max 100 nei prossimi 14 giorni; l'aggiornamento avviene all'avvio, al cambiamento task/sync e quando l'app ritorna in primo piano.
- I messaggi OS non includono nomi task né contenuti sensibili nella notifica. Non viene avviato alcun job persistente sul server e non viene promessa la consegna se Android/Windows limita notifiche o app background.
- Nel backup cifrato `.snb` è compreso il campo **opzionale** `automations`, validato prima della creazione. Il formato storico v1 senza questo campo rimane leggibile; il restore live resta rigorosamente disabilitato.

## Test e rischi residui

`reminder_automations_test.dart`: default retrocompatibili, limiti, isolamento account, confronto ledger e dedup, disabilitazione, schema futuro e contenuto malformato. `reminder_automations_widget_test.dart`: editor Forui e blocco archivio corrotto. `user_template_backup_test.dart`: snapshot cifrato per owner, schema opzionale e rifiuto di archivi di regole rotti.

**Non è la chiusura complessiva delle automazioni P2.** Restano esecuzione affidabile di azioni configurate su task, dedup durevole distribuita, sincronizzazione regole tra dispositivi, pianificazione quando l'app non viene riaperta, collaudo su hardware, migrazione V11 reale e gli altri gate P2. Il collaudo manuale resta nel [registro differito](DEVICE-ACCEPTANCE-DEFERRED.md) e lo stato canonico nella [matrice](P2-DELIVERY-MATRIX.md).

## Estensione P2 successiva — automazioni che modificano task

Le notifiche OS di questa specifica restano indipendenti dalle nuove azioni task locali su creazione/completamento, integrate nello stesso menu Strumenti → Automazioni. [Contratto separato della PR #60 integrata](P2-TASK-ACTIONS.md). Le azioni task non richiedono il permesso notifiche.
