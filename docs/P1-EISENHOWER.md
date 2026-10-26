# P1.8 — Matrice Eisenhower (vista derivata)

**Stato 26/10/2026:** branch `feature/p1-8-eisenhower-matrix`, Flutter `0.13.0+15`; implementazione e test di dominio aggiunti, CI e verifica hardware ancora da confermare. PR #7 (MSIX Windows) è stata integrata in `main` dopo CI verde [40245561264](https://github.com/andreadada/simple-notes/actions/runs/40245561264). Nessun deploy o reset.

## Comportamento

- Nuova voce **Matrice Eisenhower** nella sidebar Windows e nel drawer Android, con quattro quadranti Forui responsive: Fai subito (urgente/importante), Pianifica (non urgente/importante), Delega (urgente/meno importante), Valuta / elimina (non urgente/meno importante).
- Mappatura **documentata e deterministica**, basata esclusivamente sui campi task **già sincronizzati**: importante = `priority >= 2` (P2/P3); meno importante = `0/1`. Urgente = scadenza con istante nei prossimi 48 h (o già passata); `TaskDue.date` civile = oggi, domani o in arretrato (senza inventare un orario); scadenza assente = non urgente. I `timeBlocks` sono prenotazioni di lavoro, **non** scadenze.
- Operazioni disponibili su ciascun task: titolo editabile inline, priorità con menu Forui, scadenza con editor Forui, completamento con checkbox, apertura dettagli. Tutte utilizzano **LocalStore → SQLite → outbox → sync**; non esiste stato locale parallelo alla task list.
- Completati esclusi. Ricorrenze completate seguono la logica esistente (stesso UUID, scadenza avanzata).
- Distribuzione in 2 colonne quando la vista ha >=780 px, altrimenti una colonna scorrevole; conteggi per quadrante e empty state.
- **Nessuna** nuova tabella, colonna, migrazione Flyway/Drift, API, capability, permesso o rebootstrap. Compatibilità con i client esistenti invariata.

## Limiti dichiarati

- V1 **auto-classifica**, non introduce bandiere indipendenti `urgent`/`important` né assegnazione drag/drop diretta: cambiando priorità e/o scadenza il task cambia quadrante. `Delega` è un suggerimento di gestione, **non** l'assegnazione a un altro utente.
- La classificazione avviene durante il rebuild della vista. Una matrice lasciata aperta attraverso il cambio del giorno richiede refresh/rientro per aggiornare le scadenze civili. Nessuna attività schedulata in background.
- Il calcolo dei 48h si basa su `DateTime.now()` del dispositivo; orologio alterato può incidere sull'urgenza visualizzata. Non attribuire precisione al calendario civil-day basata sul fuso UTC.
- Test unitari puri validano tutte le combinazioni, deadline UTC e date civili, completati e immutabilità della proiezione; la CI completa Windows/Android e il test su display stretto restano gate distinti.

## Gate

1. [ ] CI Flutter `analyze`, `test`, APK JDK17/21, Windows EXE/MSIX e docs link **verdi sullo SHA finale**.
2. [ ] Mobile: verificare a larghezza stretta che testo, comandi e Forui popup non taglino contenuto; desktop: due colonne e pannello dettagli; tastiera/lettore schermo.
3. [ ] Due device: cambiare priorità, scadenza, titolo e completamento, sincronizzare, verificare quadranti ricostruiti su Windows e Android; simulare offline e retry, nessuna duplicazione outbox.
4. [ ] Verificare migrato Coolify Flyway V10 e capability prima di installare Flutter P1.8; **non deployare automaticamente**.
5. [ ] Solo dopo verifica, valutare feature successive: drag/drop quadranti con modello `important`/`urgent` esplicito o gestione di progetti Kanban.

[Stato canonico](CURRENT-STATUS.md) · [Roadmap](../project.md) · [Runbook](P1-RELEASE-BATCH.md).
