# Stato corrente — Simple Notes

**Aggiornato 30 ottobre 2026.** Questo documento prevale sulla cronologia. **Codice/CI, deploy Coolify, installazione e collaudo fisico sono stati distinti.**

| Area | Stato verificato | Gate ancora aperti |
|---|---|---|
| `main` | **P0–P1.17 integrate**. [PR #18 Windows Tray](https://github.com/andreadada/simple-notes/pull/18) merged, commit [`66927c7`](https://github.com/andreadada/simple-notes/commit/66927c73171964f7eb302273d7801df89225e1da), Flutter **`0.22.0+24`** | Test su Windows e Android reali |
| P1.18 in sviluppo | [Branch tema chiaro/scuro/sistema](https://github.com/andreadada/simple-notes/tree/feature/p1-18-theme-modes), candidato Flutter **`0.23.0+25`**: scelta locale per dispositivo, palette Material/Forui e Sticky | CI SHA finale, verifica visiva e test fisici ancora aperti; **non merged** |
| CI P1.17 | [Flutter CI #40797207231](https://github.com/andreadada/simple-notes/actions/runs/40797207231): **success** per analyze/test, Windows release + MSIX di sviluppo, Android JDK17 e JDK21. [Markdown #40797207130](https://github.com/andreadada/simple-notes/actions/runs/40797207130): **success** | La CI non certifica interazioni fisiche, Google login o notifiche |
| Backend nel repository | Spring Boot / PostgreSQL 17, Flyway **V10**; client Drift/SQLite **V8** | VPS Coolify ultima attestazione **V8**; V9–V10 reali, health e capability ancora da verificare |
| Distribuzione | Nessun deploy, installazione o reset PostgreSQL, SQLite, outbox, SharedPreferences eseguito per P1.17 | Upgrade server-first, conservazione dati e collaudo cumulativo |

## Funzioni integrate nel codice

- **P0–P1.6:** Google OAuth, attività/note/liste offline-first, outbox e sync, Forui ed editing inline, calendario, time blocking, filtri, ricorrenze.
- **P1.7–P1.9:** reminder Android opt-in inexact; reminder Windows solo su MSIX con identità valida; matrice Eisenhower e Kanban per liste.
- **P1.10–P1.13:** Pomodoro, Habit Tracker e Countdown **locali per account/dispositivo**, non sincronizzati tra Windows e Android.
- **P1.14–P1.16:** Sticky Notes Windows con bridge al LocalStore principale, scorciatoie Windows e griglia note responsive 1–3 colonne.
- **P1.17:** icona nell'area di notifica Windows, X→nascondi, Apri/ripristina ed Esci esplicito; fallback quando plugin non disponibile. **Implementazione + CI verificate, comportamento reale da collaudare**.
- **P1.18 (branch, non ancora integrata):** modalità Scuro/Chiaro/Sistema e preferenza locale, nessuna modifica SQLite/outbox/server. [Specifica](P1-APPEARANCE.md).
- **P2/P3:** temi, integrazioni calendario, import/export, condivisione, funzioni smart opzionali **non implementate**.

## Gate di rilascio ancora aperti

1. **Coolify server-first:** verificare in read-only schema Flyway **V10**, `FAILED_MIGRATIONS=0`, health `UP` e capability autenticate `taskDueSchema:1`, `timeBlockSchema:1`, `timeBlocksSchema:1`, `recurrenceSchema:1` prima di installare client aggiornati.
2. **Windows reale:** prova ZIP completo, apertura/chiusura/riapertura tray, voce Esci, assenza icone orfane e doppie tray nelle finestre Sticky. Per MSIX usare **solo un profilo di prova**, con firma/publisher/identity coerenti.
3. **Collaudo Windows ↔ Android:** login e sessione, sync offline/retry, 409/426, liste/task/note, calendario/ricorrenze, reminder, resize, accessibilità e persistenza al riavvio.
4. **Preservazione dati:** nessun reset o uninstall. Verificare esplicitamente SQLite, outbox, secure storage e SharedPreferences nel passaggio ZIP→MSIX; la sola CI non dimostra compatibilità del percorso.
5. **Release pubblica:** signing affidabile, hardening/monitoraggio e decisione esplicita sulla policy backup/offsite (non eseguita). Il backup/restore isolato riuscito il 24/10 è una prova **storica**, non un backup fresco.

[Guida operativa](OPERATIONS.md) · [Specifica Tray](P1-WINDOWS-TRAY.md) · [Runbook server-first](P1-RELEASE-BATCH.md) · [Roadmap](../project.md) · [Handoff](HANDOFF.md).

## Prossimo incremento P1.18 (30/10/2026)

Non segnare P1.18 completata fino a CI finale verde. Includere nel collaudo cumulativo il tema su Windows/Android, Sticky e rientro con preferenza persistita. [Specifiche](P1-APPEARANCE.md).
