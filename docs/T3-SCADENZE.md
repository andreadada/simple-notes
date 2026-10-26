# T3 — Scadenze Forui, fusi IANA e calendario civile

<!-- CURRENT-STATUS-REF -->
> **SNAPSHOT STORICO — 26/10/2026:** `main` include P1.12 Countdown (`0.17.0+19`, PR #13, CI verde). P1.13 settimanale (`0.18.0+20`) è **solo nel branch**, CI/merge/device non attestati; `weeklyTarget` 1–7 non cancella check-in. Le funzioni Pomodoro/Habits/Countdown sono locali e non sincronizzate. Schema repo Flyway V10, Coolify attestato V8; nessun deploy/reset. La procedura sotto è storica. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [P1.13](P1-WEEKLY-HABITS.md).


> Stato al 24/10: codice T3 implementato; **Flyway V7 verificata sul DB reale e dump/restore isolato PASS**. API autenticata e prove fisiche Windows↔Android ancora non confermate. Verificare gli esiti più recenti in [GitHub Actions](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml).

## Cosa è stato sviluppato

- `apps/flutter/lib/data/task_due_clock.dart`: motore IANA basato su `timezone ^0.11.2` (tzdata inclusa). Rileva il fuso OS con `flutter_timezone ^5.1.0` quando possibile, **senza scegliere UTC silenziosamente in caso di errore**; in tale situazione l’utente indica il fuso IANA.
- `apps/flutter/lib/ui/task_due_editor.dart`: un solo dialog Forui usato per aggiunta rapida, dettaglio task e editor avanzato. Selettore esplicito **Solo giorno / Data e ora**, `FCalendar` esistente, HH:mm, fuso IANA modificabile, scelte rapide di fusi e scelta dell’occorrenza quando l’ora si ripete. `Annulla` non salva, `Rimuovi` salva `TaskDue.none`.
- `apps/flutter/lib/data/task_due_view.dart`: unica presentazione `taskDueLabel` (date-only senza orario; timed con ora e timezone; legacy chiaramente indicata) e funzioni `taskInToday` / `taskInNextSevenDays`. I filtri lavorano per **giorni civili** e non per ore da 24h, così il passaggio a ora legale non sposta la fine della finestra.
- `apps/flutter/lib/main.dart`: creazione rapida ora passa `TaskDue` tipizzato, il dettaglio usa `setTaskDueSemantics`, l’editor avanzato lo salva insieme alle altre proprietà **senza trasformarlo in legacy** in una rinomina. Le precedenti manipolazioni di `dueAt` sono rimosse dai tre flussi.
- `apps/flutter/lib/data/local_store.dart`: `addTask(..., due: ...)` e `editTask(..., due: ..., changeDue: true)` scrivono con l’attuale SQLite/outbox; `setTaskDueSemantics` disponibile per modifica mirata.
- Test: `task_due_clock_test.dart` (DST gap, due occorrenze fold, mezzanotte esplicita, fusi sconosciuti, filtri, etichette), più test widget su creazione date-only/timed e salvataggio avanzato che preserva `due`.

## Semantiche da non alterare

| Caso | Aspettativa |
| --- | --- |
| `date`, 26/10/2026 | Giorno civile senza UTC; stesso `due.date` su tutti i device |
| `datetime`, 26/10/2026 00:00, Europe/Rome | Orario esplicito, **mai** `date`; istante derivato dalla timezone |
| Europe/Rome, 29/03/2026 02:30 | **Ora inesistente**: errore, nessuna conversione implicita |
| Europe/Rome, 25/10/2026 02:30 | **Ora ripetuta**: selezionare UTC+02:00 oppure UTC+01:00 |
| `legacy` | Conservarla fino a conversione esplicita; nessuna deduzione da mezzanotte |
| Oggi | Task scaduti + task del giorno corrente, per calendario locale di visualizzazione |
| Prossimi 7 giorni | Scaduti + oggi e i 6 giorni civili successivi; niente durata fissa 168h |
| Server senza `taskDueSchema:1` | I nuovi `date/datetime` restano in outbox; non forzare o cancellare sync |
| HTTP 426 | Upgrade richiesto, non 409, niente rebase distruttivo |

## Validazione

- Test unitari e widget Flutter inclusi nella CI; controllare risultato dopo ciascun commit.
- Inventario V1–V7, dump e restore reale verificati il 24/10; controllare `/actuator/health` e `/api/v1/capabilities` autenticato senza redeploy non necessario.
- Verificare fisicamente Windows e Android con **stesso account**, date-only tra diversi fusi, fold/gap, avvio offline, riavvio, 409 e upload dopo upgrade backend.
- La sincronizzazione non è stata deployata ora; `flutter run -d chrome` continua a non essere un runtime supportato.
- `timezone` client e Java ZoneRules server possono avere versioni tzdata differenti: il server resta autorevole e un errore di validazione non deve riscrivere una scadenza senza consenso.

## Escluso da T3

Ricorrenze, notifiche pianificate Android/Windows, calendari avanzati, import/export e rilascio web. Prossimo gate operativo: **T4.2 API + test real-device**, non ripetere backup/restore o V7. Non cancellare mai SQLite, outbox o volumi per risolvere difetti di upgrade.

