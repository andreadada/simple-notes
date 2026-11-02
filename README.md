# Simple Notes

> **Stato operativo 02/11/2026:** P2.3C feed ICS HTTPS integrata su `main` ([PR #24](https://github.com/andreadada/simple-notes/pull/24), Flutter `0.28.0+30`; [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/41460378203) verde: **182 test**, Windows EXE/MSIX, Android JDK17/21; [Markdown](https://github.com/andreadada/simple-notes/actions/runs/41460378261) verde). Nessun deploy, installazione, reset o collaudo hardware. Backend repo V10, VPS ultima attestazione V8. [Stato](docs/CURRENT-STATUS.md) · [Feed ICS](docs/P2-ICS-FEEDS.md).

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

## P1.17 — Tray Windows (main, PR #18)

X→nascondi nell'area di notifica, click/menu→riapri, **Esci** dal menu per chiudere. Solo Windows, nessuna nuova API o sincronizzazione. Candidata Flutter `0.22.0+24`. [Specifica](docs/P1-WINDOWS-TRAY.md).

## P1.18 — Tema chiaro/scuro/sistema (main, PR #19)

Integrata in `main` ([PR #19](https://github.com/andreadada/simple-notes/pull/19)), Flutter `0.23.0+25`: preferenza `SharedPreferences` per dispositivo (default legacy Scuro); palette coerenti Material/Forui e modifica dal menu account, senza nuove API, migrazioni o outbox. CI completa sullo SHA finale **verde**; test fisici Windows/Android, installazione e deploy non attestati; nessun reset. [Specifica](docs/P1-APPEARANCE.md) · [Stato](docs/CURRENT-STATUS.md).

## P2.1 — Archivio portabile JSON (integrata, PR #20)

Menu account → **Esporta dati JSON** oppure **Importa dati JSON**. Esporta liste, attività (comprese scadenze/ricorrenze/blocchi/sottotask) e note attive. Importa copie con nuovi ID senza sovrascrivere alcun elemento, tramite SQLite e outbox standard. Non è un backup completo: esclude cestino, cronologia sync, impostazioni, dati Focus locali, credenziali e sessioni. Flutter `0.24.0+26` integrata in `main` dopo CI completa verde (152 test, Windows/Android, Markdown); nessun deploy. [Specifica](docs/P2-PORTABLE-ARCHIVE.md).

## P2.2 — Calendario ICS esterno (main, PR #21)

Nella schermata Calendario si possono importare fino a 5 file ICS in sola lettura per account/dispositivo; compaiono in giorno, settimana e mese senza essere convertiti in task. Nessuna nuova API o migrazione; ricorrenze ICS e timezone non IANA sono rifiutati con un errore esplicito. Integrata su `main` con [PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI completa verde (162 test, Windows e Android), collaudo fisico ancora aperto. [Specifica](docs/P2-ICS.md).

## P2.3A — Modello sorgenti ICS (main, PR #22)

Integrato su `main` con [PR #22](https://github.com/andreadada/simple-notes/pull/22) è il modello di identità stabile delle sorgenti ICS: archivio locale schema 2 con lettura schema 1, tipologia file/URL (URL ancora inattivo), rimozione per ID e protezione nei cambi account durante import. Flutter `0.26.0+28`, CI verde (166 test, Windows EXE/MSIX, Android JDK17/21, Markdown); nessun deploy o sync cloud. Prima di utilizzare client meno recenti, considerare che P2.2 non può leggere lo schema 2 scritto dopo una nuova modifica. [Specifica](docs/P2-ICS-SOURCES.md).

## P2.3B — Ricorrenze ICS (main, PR #23)

Flutter `0.27.0+29`: le serie RRULE importate da file possono mostrare ripetizioni ed eccezioni RDATE/EXDATE/RECURRENCE-ID, generate solo per il giorno visualizzato. Archivio locale schema 3 con lettura versioni 1/2, senza cloud o feed URL; nessun deploy. [Specifica](docs/P2-ICS-RECURRENCE.md).

## P2.3C — Feed ICS da URL (main, PR #24)

Aggiunta di un URL HTTPS nella vista calendario, download solo su conferma, proiezione read-only offline con refresh manuale e cache conservata su errore. I link privati con query-token non vengono mostrati nell'interfaccia. Nessun server o OAuth aggiuntivo. [Specifica](docs/P2-ICS-FEEDS.md).

## P2.3D — Gestione calendari esterni (candidata)

La vista Calendario ha un pannello **Sorgenti** richiudibile: mostra file e feed HTTPS, conta eventi/serie, indica l'ultimo refresh riuscito, permette aggiornamento manuale e rimozione con conferma. Il titolo di ciascuna sorgente è modificabile subito, inline; non cambia il filename né il link usato per l'import. I feed con token non mostrano il loro URL. Nessun nuovo backend o OAuth. [Specifica](docs/P2-ICS-SOURCE-MANAGEMENT.md).

