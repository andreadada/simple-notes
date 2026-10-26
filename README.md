# Simple Notes

> **Incremento in verifica (26/10/2026, branch `feature/p1-7-windows-msix-reminders`):** Flutter `0.12.0+14` aggiunge notifiche Windows solo con identità MSIX (EXE/ZIP escluso), opt-in locale e annullamento tramite ledger; configurazione pacchetto MSIX e job CI di packaging. **Non mergiato, non distribuito, CI e test Windows reali ancora da verificare**. Lo stato su `main` resta P1.7 Android `0.11.0+13`; Coolify non modificato. Vedere [specifica Windows](docs/P1-WINDOWS-MSIX.md).

App offline-first per **Windows 11 e Android** dedicata ad attività, note e pianificazione. Flutter/Forui con Drift SQLite locale, Google OAuth e sincronizzazione con Spring Boot/PostgreSQL su Coolify.

<!-- CURRENT-STATUS-REF -->
> **Stato di riferimento (25/10/2026):** P1.1–P1.6 e **P1.7 Android** integrate su `main`; Flutter `0.11.0+13`, Drift V8, Flyway V10. P1.7 Android offre promemoria locali **opt-in e inexact** nel codice, CI verde, non ancora provati su un telefono reale; **Windows non notifica** senza MSIX/package identity. Ultima VPS verificata: Flyway V8; V9/V10 e collaudo Windows↔Android del batch non attestati. Lo stato verificabile e i gate sono in **[docs/CURRENT-STATUS.md](docs/CURRENT-STATUS.md)**.

## Funzionalità presenti nel codice

- Login Google, note e task, liste/priorità/tag/sottotask, modifica direttamente sul testo visualizzato, cestino note e sincronizzazione offline-first con coda persistente.
- Calendario giorno/settimana/mese, scadenze civili e date-time con fuso IANA e DST.
- Blocchi orari multipli e drag/resize, riepilogo del tempo, slot liberi, ricerca e filtri.
- Ricorrenze giornaliere/settimanali/mensili (P1.6). P1.7 aggiunge scheduling locale Android opt-in (delivery da verificare sul telefono); nessun reminder nativo sul client Windows ZIP.

**Implementato su GitHub ≠ distribuito.** Prima di installare client aggiornati verificare su Coolify Flyway V10 e le capability autenticate. Nessun reset, cancellazione di volumi o migrazione manuale per una normale verifica. Il deploy resta un'operazione distinta e controllata dall'utente.

## Percorso rapido

- [Stato canonico e prossimi gate](docs/CURRENT-STATUS.md)
- [Roadmap P0–P3](project.md), [regole per agenti](AGENTS.md), [design](design.md)
- [Handoff e cronologia](docs/HANDOFF.md)
- [Architettura](docs/architecture.md), [API](docs/api.md), [sync](docs/sync.md)
- [Client Windows/Android](apps/flutter/README.md), [backend/Coolify](infra/README.md)
- [P1.6: ricorrenze](docs/P1-RECURRENCE.md), [P1.7: Android e limiti Windows](docs/P1-REMINDERS-FOUNDATION.md)
- [Runbook di rilascio V10](docs/P1-RELEASE-BATCH.md) e [check E2E](docs/T4-DEVICE-SYNC.md)

## Regole UX e dati

La UI usa **Forui**, preferisce campi testuali editabili *inline* senza pulsanti "Rinomina", e un underline che segue soltanto i glifi; il campo conserva margine per cursore/selezione. Le modifiche passano sempre da SQLite/outbox, non solo dallo stato grafico. Preservare versioni, cursor e pending mutation; non trattare HTTP 426 come conflitto 409.

## Verifiche

Le GitHub Actions coprono Flutter, backend, Compose e link Markdown. I test automatici **non** certificano la versione realmente distribuita, OAuth sui dispositivi, né la sync E2E. Tutte le procedure di reset e le versioni P0/T2/T3/P1.1–P1.5 sono documentate nelle specifiche storiche, non costituiscono istruzioni di rollout aggiornate.
