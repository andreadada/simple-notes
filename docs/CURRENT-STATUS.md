# Stato corrente — Simple Notes

**Aggiornato 31 ottobre 2026.** Questo documento prevale sulla cronologia. **Codice/CI, deploy Coolify, installazione e collaudo fisico sono stati distinti.**

| Area | Stato verificato | Gate ancora aperti |
|---|---|---|
| `main` | **P0–P1.18 + P2.1 + P2.2 integrate**. [PR #21 ICS](https://github.com/andreadada/simple-notes/pull/21) merged, commit [`141004d`](https://github.com/andreadada/simple-notes/commit/141004d2ead988a9fdd58078e8b6e6b3d10c20c4), Flutter **`0.25.0+27`** | Test su Windows e Android reali |
| P1.18 integrata (storico) | [PR #19](https://github.com/andreadada/simple-notes/pull/19) merged, Flutter **`0.23.0+25`**, temi chiaro/scuro/sistema, preferenza locale e Sticky | CI verde; test visivi e su dispositivi fisici ancora aperti |
| CI P2.2 | [Flutter CI #41157322208](https://github.com/andreadada/simple-notes/actions/runs/41157322208): **success** (162 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41157326277](https://github.com/andreadada/simple-notes/actions/runs/41157326277): **success** | Non certifica picker ICS su dispositivi fisici o deploy |
| CI P2.1 | [Flutter CI #41114448268](https://github.com/andreadada/simple-notes/actions/runs/41114448268): **success** (152 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41114449602](https://github.com/andreadada/simple-notes/actions/runs/41114449602): **success** | Non dimostra test fisico, OAuth, upgrade ZIP→MSIX o rilascio |
| CI P1.18 | [Flutter CI #41067872668](https://github.com/andreadada/simple-notes/actions/runs/41067872668): **success** (148 test, Windows EXE/MSIX, Android JDK17/21). [Markdown #41067872675](https://github.com/andreadada/simple-notes/actions/runs/41067872675): **success** | Non dimostra test fisico, OAuth né upgrade ZIP→MSIX |
| CI P1.17 | [Flutter CI #40797207231](https://github.com/andreadada/simple-notes/actions/runs/40797207231): **success** per analyze/test, Windows release + MSIX di sviluppo, Android JDK17 e JDK21. [Markdown #40797207130](https://github.com/andreadada/simple-notes/actions/runs/40797207130): **success** | La CI non certifica interazioni fisiche, Google login o notifiche |
| Backend nel repository | Spring Boot / PostgreSQL 17, Flyway **V10**; client Drift/SQLite **V8** | VPS Coolify ultima attestazione **V8**; V9–V10 reali, health e capability ancora da verificare |
| Distribuzione | Nessun deploy, installazione o reset PostgreSQL, SQLite, outbox, SharedPreferences eseguito per P2.2 | Upgrade server-first, conservazione dati e collaudo cumulativo |

## Funzioni integrate nel codice

- **P0–P1.6:** Google OAuth, attività/note/liste offline-first, outbox e sync, Forui ed editing inline, calendario, time blocking, filtri, ricorrenze.
- **P1.7–P1.9:** reminder Android opt-in inexact; reminder Windows solo su MSIX con identità valida; matrice Eisenhower e Kanban per liste.
- **P1.10–P1.13:** Pomodoro, Habit Tracker e Countdown **locali per account/dispositivo**, non sincronizzati tra Windows e Android.
- **P1.14–P1.16:** Sticky Notes Windows con bridge al LocalStore principale, scorciatoie Windows e griglia note responsive 1–3 colonne.
- **P1.17:** icona nell'area di notifica Windows, X→nascondi, Apri/ripristina ed Esci esplicito; fallback quando plugin non disponibile. **Implementazione + CI verificate, comportamento reale da collaudare**.
- **P1.18 (integrata in main, PR #19):** modalità Scuro/Chiaro/Sistema e preferenza locale, nessuna modifica SQLite/outbox/server. [Specifica](P1-APPEARANCE.md).
- **P2.1 (integrata in main, PR #20):** export/import JSON versionato di liste, task e note attive con conferma Forui, nuovi UUID e outbox nella transazione. [Specifica](P2-PORTABLE-ARCHIVE.md).
- **P2.2 (integrata in main, PR #21):** file ICS esterni, locali per account, read-only in calendario giorno/settimana/mese, fino a 5 fonti; nessun task/outbox/cloud. [Specifica](P2-ICS.md).
- **P2 successiva/P3:** subscription ICS via URL, ricorrenze complete, export CSV, backup completo, condivisione e smart opzionali **non implementati**.

## Gate di rilascio ancora aperti

1. **Coolify server-first:** verificare in read-only schema Flyway **V10**, `FAILED_MIGRATIONS=0`, health `UP` e capability autenticate `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` prima di installare client aggiornati.
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

