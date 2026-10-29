# Simple Notes

> **Stato operativo 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non ancora attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](docs/CURRENT-STATUS.md) · [Tray](docs/P1-WINDOWS-TRAY.md).

App offline-first per **Windows 11 e Android** dedicata ad attività, note e pianificazione. Flutter/Forui con Drift SQLite locale, Google OAuth e sincronizzazione con Spring Boot/PostgreSQL su Coolify.

<!-- CURRENT-STATUS-REF -->

## Funzionalità presenti nel codice

- Login Google, note e task, liste/priorità/tag/sottotask, modifica direttamente sul testo visualizzato, cestino note e sincronizzazione offline-first con coda persistente.
- Calendario giorno/settimana/mese, scadenze civili e date-time con fuso IANA e DST.
- Blocchi orari multipli e drag/resize, riepilogo del tempo, slot liberi, ricerca e filtri.
- Ricorrenze giornaliere/settimanali/mensili (P1.6). P1.7 aggiunge promemoria opt-in Android e Windows **solo MSIX** (non su EXE/ZIP); funzionamento reale ancora da collaudare.

- Matrice Eisenhower P1.8: quattro quadranti da priorità/scadenza, adattiva e con modifica diretta dei task.
- Kanban P1.9 per liste con drag/drop, aggiunta rapida e spostamento accessibile: **integrato su main**.
- Pomodoro P1.10 (**main**): timer 25/5/15 e statistiche locali, **non sincronizzate tra dispositivi**.
- Habit Tracker P1.11 (**main**, PR #12): abitudini quotidiane, streak, check-in, storico/archivio locali, senza cloud sync.
- Countdown P1.12 (**main**, PR #13): eventi a data civile o ora IANA, titolo inline e archivio; locale, non sincronizzato.
- P1.13 (**main**, PR #14): obiettivi Habit 1–7 giorni alla settimana e streak settimanali, storico locale preservato.
- P1.14 (**main**, PR #15): apri note sincronizzate in finestre Windows indipendenti, editing inline attraverso il processo principale.
**Implementato su GitHub ≠ distribuito.** Prima di installare client aggiornati verificare su Coolify Flyway V10 e le capability autenticate. Nessun reset, cancellazione di volumi o migrazione manuale per una normale verifica. Il deploy resta un'operazione distinta e controllata dall'utente.

## Percorso rapido

- [Stato canonico e prossimi gate](docs/CURRENT-STATUS.md), [guida operativa](docs/OPERATIONS.md), [Kanban P1.9](docs/P1-KANBAN.md), [Pomodoro P1.10](docs/P1-POMODORO.md), [Habit Tracker P1.11](docs/P1-HABITS.md), [Countdown P1.12](docs/P1-COUNTDOWNS.md), [P1.13 Weekly Habit](docs/P1-WEEKLY-HABITS.md)
- [Roadmap P0–P3](project.md), [regole per agenti](AGENTS.md), [design](design.md)
- [Handoff e cronologia](docs/HANDOFF.md)
- [Architettura](docs/architecture.md), [API](docs/api.md), [sync](docs/sync.md)
- [Client Windows/Android](apps/flutter/README.md), [backend/Coolify](infra/README.md)
- [P1.6: ricorrenze](docs/P1-RECURRENCE.md), [P1.8: Matrice Eisenhower](docs/P1-EISENHOWER.md), [P1.7: Android](docs/P1-REMINDERS-FOUNDATION.md), [Windows MSIX](docs/P1-WINDOWS-MSIX.md)
- [Runbook di rilascio V10](docs/P1-RELEASE-BATCH.md) e [check E2E](docs/T4-DEVICE-SYNC.md)

## Regole UX e dati

La UI usa **Forui**, preferisce campi testuali editabili *inline* senza pulsanti "Rinomina", e un underline che segue soltanto i glifi; il campo conserva margine per cursore/selezione. Le modifiche passano sempre da SQLite/outbox, non solo dallo stato grafico. Preservare versioni, cursor e pending mutation; non trattare HTTP 426 come conflitto 409.

## Verifiche

Le GitHub Actions coprono Flutter, backend, Compose e link Markdown. I test automatici **non** certificano la versione realmente distribuita, OAuth sui dispositivi, né la sync E2E. Tutte le procedure di reset e le versioni P0/T2/T3/P1.1–P1.5 sono documentate nelle specifiche storiche, non costituiscono istruzioni di rollout aggiornate.

La fase Sticky Windows P1.14 è documentata in [P1-STICKY-WINDOWS.md](docs/P1-STICKY-WINDOWS.md); non è ancora attestata su hardware.

## P1.15 — Scorciatoie (main, PR #16)

Windows: `Ctrl+1..5` navigazione, `Ctrl+Shift+T` nuova attività, `Ctrl+Shift+N` nuova nota, `Ctrl+/` guida Forui. Android invariato; nessuna migrazione. [Specifica](docs/P1-DESKTOP-SHORTCUTS.md).

## P1.16 — Responsive (main, PR #17)

Le note si dispongono in **1, 2 o 3 colonne** secondo lo spazio del contenuto Windows/Android, senza tagliare il corpo né cambiare lo storico o la sincronizzazione. Flutter candidata `0.21.0+23`; CI/merge/device da verificare. [Specifiche](docs/P1-RESPONSIVE.md).

## P1.17 — Tray Windows (branch)

X→nascondi nell'area di notifica, click/menu→riapri, **Esci** dal menu per chiudere. Solo Windows, nessuna nuova API o sincronizzazione. Candidata Flutter `0.22.0+24`. [Specifica](docs/P1-WINDOWS-TRAY.md).
