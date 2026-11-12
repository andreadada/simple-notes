# Indice documentazione — Simple Notes

**Aggiornato: 12 novembre 2026.** Punto di accesso ai documenti Markdown del progetto. Copertura: 68 documenti in `docs/` (escluso questo indice), oltre ai Markdown dei package e della radice.

Lo **stato canonico** è [CURRENT-STATUS.md](CURRENT-STATUS.md): verificare sempre separatamente **codice integrato**, **CI**, **migrazione/deploy VPS** e **test fisici**. Le righe storiche dei vecchi runbook non costituiscono autorizzazione a un deploy. La VPS è ora attestata a **Flyway V17 al 12 novembre 2026**, mentre la PR #77 propone **Flyway V18, non deployata** e la UI EDITOR è integrata (PR #75). La PR #62 (integrata in `main`) introduce riconciliazione delle definizioni delle automazioni *solo foreground*, non un job backend.

## Accessi principali

- [Introduzione repository](../README.md) · [Roadmap](../project.md) · [Istruzioni per agenti](../AGENTS.md) · [Design](../design.md)
- [Flutter](../apps/flutter/README.md) · [Infrastruttura](../infra/README.md)
- [Matrice di consegna P2](P2-DELIVERY-MATRIX.md) · [Collaudi hardware differiti](DEVICE-ACCEPTANCE-DEFERRED.md)
- [Specifica sync regole P2](P2-AUTO-ACTION-CATALOG.md) · [Specifica catalogo cloud V12](P2-CLOUD-ACTION-CATALOG.md)

## Stato, roadmap, architettura e UX

- [CURRENT-STATUS](./CURRENT-STATUS.md)
- [HANDOFF](./HANDOFF.md)
- [OPERATIONS](./OPERATIONS.md)
- [api](./api.md)
- [architecture](./architecture.md)
- [due-dates-timezones](./due-dates-timezones.md)
- [sync](./sync.md)
- [task-organization](./task-organization.md)
- [ui-design-audit](./ui-design-audit.md)
- [ui-forui](./ui-forui.md)

## P0 e verifica dispositivi

- [P0-DEVICE-CHECKS](./P0-DEVICE-CHECKS.md)
- [P0-STATUS](./P0-STATUS.md)
- [T3-SCADENZE](./T3-SCADENZE.md)
- [T4-DEVICE-SYNC](./T4-DEVICE-SYNC.md)
- [T4-RELEASE-RUNBOOK](./T4-RELEASE-RUNBOOK.md)

## P1 e interfaccia

- [P1-APPEARANCE](./P1-APPEARANCE.md)
- [P1-CALENDAR-INTERACTIONS](./P1-CALENDAR-INTERACTIONS.md)
- [P1-CALENDAR](./P1-CALENDAR.md)
- [P1-COUNTDOWNS](./P1-COUNTDOWNS.md)
- [P1-DESKTOP-SHORTCUTS](./P1-DESKTOP-SHORTCUTS.md)
- [P1-EISENHOWER](./P1-EISENHOWER.md)
- [P1-HABITS](./P1-HABITS.md)
- [P1-KANBAN](./P1-KANBAN.md)
- [P1-MULTI-BLOCKS](./P1-MULTI-BLOCKS.md)
- [P1-POMODORO](./P1-POMODORO.md)
- [P1-QUICK-PLANNING](./P1-QUICK-PLANNING.md)
- [P1-RECURRENCE](./P1-RECURRENCE.md)
- [P1-RELEASE-0.7.0](./P1-RELEASE-0.7.0.md)
- [P1-RELEASE-BATCH](./P1-RELEASE-BATCH.md)
- [P1-REMINDERS-FOUNDATION](./P1-REMINDERS-FOUNDATION.md)
- [P1-RESPONSIVE](./P1-RESPONSIVE.md)
- [P1-STICKY-WINDOWS](./P1-STICKY-WINDOWS.md)
- [P1-TIME-BLOCKING](./P1-TIME-BLOCKING.md)
- [P1-WEEKLY-HABITS](./P1-WEEKLY-HABITS.md)
- [P1-WINDOWS-MSIX](./P1-WINDOWS-MSIX.md)
- [P1-WINDOWS-TRAY](./P1-WINDOWS-TRAY.md)

## P2 — funzionalità, backup e integrazioni

- [P2-AUTO-ACTION-CATALOG](./P2-AUTO-ACTION-CATALOG.md)
- [P2-CLOUD-ACTION-CATALOG](./P2-CLOUD-ACTION-CATALOG.md)
- [P2-CLOUD-TEMPLATES](./P2-CLOUD-TEMPLATES.md)
- [P2-NOTE-ATTACHMENTS](./P2-NOTE-ATTACHMENTS.md)
- [P2-LIST-SHARING](./P2-LIST-SHARING.md)
- [P2-LIST-EDITOR](./P2-LIST-EDITOR.md)
- [P2-AUTO-TEMPLATE-CATALOG](./P2-AUTO-TEMPLATE-CATALOG.md)
- [P2-CSV-EXPORT](./P2-CSV-EXPORT.md)
- [P2-DELIVERY-MATRIX](./P2-DELIVERY-MATRIX.md)
- [P2-FULL-BACKUP](./P2-FULL-BACKUP.md)
- [P2-ICS-FEEDS](./P2-ICS-FEEDS.md)
- [P2-ICS-RECURRENCE](./P2-ICS-RECURRENCE.md)
- [P2-ICS-SOURCE-MANAGEMENT](./P2-ICS-SOURCE-MANAGEMENT.md)
- [P2-ICS-SOURCES](./P2-ICS-SOURCES.md)
- [P2-ICS](./P2-ICS.md)
- [P2-LOCAL-INTEGRATIONS](./P2-LOCAL-INTEGRATIONS.md)
- [P2-PORTABLE-ARCHIVE](./P2-PORTABLE-ARCHIVE.md)
- [P2-REMINDER-AUTOMATIONS](./P2-REMINDER-AUTOMATIONS.md)
- [P2-RESTORE-DURABILITY](./P2-RESTORE-DURABILITY.md)
- [P2-SYNC-INTENT-CONFLICTS](./P2-SYNC-INTENT-CONFLICTS.md)
- [P2-TASK-ACTIONS](./P2-TASK-ACTIONS.md)
- [P2-TEMPLATE-TRANSFER](./P2-TEMPLATE-TRANSFER.md)

## Rilascio, recupero e troubleshooting

- [DEVICE-ACCEPTANCE-DEFERRED](./DEVICE-ACCEPTANCE-DEFERRED.md)
- [RELEASE-V10-READINESS](./RELEASE-V10-READINESS.md)
- [RELEASE-V11-READINESS](./RELEASE-V11-READINESS.md)
- [RELEASE-V15-READINESS](./RELEASE-V15-READINESS.md)
- [RELEASE-V16-READINESS](./RELEASE-V16-READINESS.md)
- [RELEASE-V17-READINESS](./RELEASE-V17-READINESS.md)
- [RELEASE-V18-READINESS](./RELEASE-V18-READINESS.md)
- [RESET-TEST-DATA](./RESET-TEST-DATA.md)
- [android-troubleshooting](./android-troubleshooting.md)

## Regole di manutenzione

Aggiornare prima [CURRENT-STATUS](CURRENT-STATUS.md), [P2-DELIVERY-MATRIX](P2-DELIVERY-MATRIX.md) e [HANDOFF](HANDOFF.md) a ogni merge. Le specifiche di feature mantengono la cronologia e rimandano allo stato canonico. I link relativi vengono controllati dalla workflow Markdown; un link valido non è prova di funzionalità distribuita.
