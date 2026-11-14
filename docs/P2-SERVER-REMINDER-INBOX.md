# P2 — Inbox promemoria cloud opt-in (Flyway V19)

**14 novembre 2026, PR #79.** Implementazione di uno scheduler server e di una inbox di promemoria condivisi tra dispositivi. Non è una soluzione push remota e non invia email, SMS o notifiche OS.

## Come funziona

Nella schermata **Automazioni promemoria**, una sezione Forui **Inbox promemoria sul server** permette di attivare esplicitamente per account la funzione, scegliere l'anticipo (0/5/15/30/60/1440 minuti), aggiornare gli eventi e confermare gli avvisi. Per impostazione predefinita è OFF.

Ogni minuto il backend individua solo task datetime non completati e non eliminati di proprietari che hanno attivato la funzione; inserisce una sola occorrenza per owner/task/dueAt/anticipo grazie alla chiave UNIQUE PostgreSQL e a ON CONFLICT DO NOTHING. Recupera al massimo 24 ore di ritardo e conserva le occorrenze fino a 30 giorni. I task date-only non hanno un orario fittizio.

La GET espone un massimo di 50 eventi non confermati, correnti e di proprietà dell'utente. La conferma memorizza acknowledged_at sul server, condivisa fra dispositivi. L'inbox è aggiornata manualmente e non genera eventi nella sync personale né interferisce con le notifiche locali già attive.

## API autenticata (JWT Simple Notes)

| Metodo | Percorso | Funzione |
|---|---|---|
| GET | /api/v1/reminders/server/preferences | Stato OFF iniziale, 15 min, versione 0 |
| PUT | /api/v1/reminders/server/preferences | enabled, leadMinutes, expectedVersion (CAS, 409 stale) |
| GET | /api/v1/reminders/server/occurrences | Max 50 eventi non confermati |
| POST | /api/v1/reminders/server/occurrences/{id}/ack | Conferma idempotente per owner |

Flyway V19 crea due tabelle additive: server_reminder_preference e server_reminder_occurrence; il ledger salva solo ID, istanti, anticipo e timestamp di conferma, non titoli o descrizioni. La risposta recupera il titolo dal task corrente dopo verifica ownership. Completamenti, cancellazioni o cambio scadenza nascondono vecchie occorrenze.

## Cosa NON è ancora finito

Non è disponibile una vera consegna push multi-device (FCM/APNs/Windows), registrazione token device o retry di push. Mancano pure uno scheduler server per regole locali dei blocchi, la paginazione UI oltre 50 e la riconciliazione background. Nessun collaudo Windows/Android è stato effettuato. La P2 resta aperta.

[Gate V19](RELEASE-V19-READINESS.md) · [Stato](CURRENT-STATUS.md) · [Checklist manuale](CHECKLIST-MANUALE-P2.md).