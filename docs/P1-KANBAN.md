# P1.9 — Kanban per liste con drag & drop

> **Snapshot storico — 26/10/2026:** P1.14 Sticky Windows su `main`, [PR #15](https://github.com/andreadada/simple-notes/pull/15), Flutter `0.19.0+21`, CI verde. P1.15 Shortcuts Windows in branch `feature/p1-15-desktop-shortcuts`, candidata `0.20.0+22`, CI/merge/device da verificare. Repo Flyway V10, ultima VPS reale attestata V8; nessun deploy/reset. La guida sotto conserva attestazioni storiche, non la procedura attuale. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Scorciatoie](P1-DESKTOP-SHORTCUTS.md).

**Stato (26/10/2026):** **integrata su main con PR #10**, Flutter `0.14.0+16`; [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40328803094) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40328803015). Deploy e test dispositivi reali **non attestati**. Backend Flyway V10 e Drift V8 invariati.

## Implementazione

- Nuova voce **Kanban** nella sidebar Windows e nel drawer Android.
- Ogni colonna corrisponde a **Inbox** o a una lista esistente, con nome inline editabile; liste vuote rimangono visibili. Le attività completate non compaiono nelle colonne attive, ma restano in **Completati** nella navigazione.
- **Drag & drop cross-column**: `Draggable<String>` desktop, `LongPressDraggable<String>` mobile, `DragTarget<String>` per ogni colonna. Su mobile la vista scorre orizzontalmente. La card trascinata conserva il proprio task ID; il drop usa `LocalStore.setTaskList` con validazione.
- **Alternativa accessibile** senza gesture: menu Forui **Sposta in** su ogni card. Titolo modificabile inline, checkbox completamento, apertura dettagli, badge priorità e scadenza. Input `InlineQuickAdd` in fondo a ciascuna colonna inserisce il task in quella lista.
- Non viene creato un secondo stato del board: l'operazione passa da `LocalStore → SQLite → outbox → sync`; il server gestisce la stessa `listId` già sincronizzata. Nessun nuovo endpoint, schema, permesso o migrazione.
- Se il server restituisce per breve tempo una task riferita a una lista mancante, il board la mostra in Inbox **senza riscrivere il dato**. Le operazioni noop o verso liste inesistenti vengono rifiutate.
- Test di dominio: mapping lista/Inbox, liste vuote, priorità, task completati, lista orfana, drop non valido, immutabilità. Test widget: riordino tra colonne via LocalStore, outbox persistente e dimensioni mobile.

## Limiti espliciti della P1.9

- Questo è un **Kanban per liste/progetti**, non uno stato workflow `Da fare/In corso/Fatto` autonomo: se serve quel modello, occorrerà progettare schema + migrazioni + sync. Il drop non cambia priorità o scadenza e non crea colonne invisibili.
- Il completamento ricorrente segue la semantica già presente: avanza la scadenza mantenendo lo stesso UUID, non trasforma automaticamente la card in una copia completata.
- Le colonne sono ordinate dalla sequenza delle liste sincronizzate, le card sono ordinate per priorità e creazione. **Non** persiste un ranking interno arbitrario delle card: trascinarla entro la stessa lista non modifica l'ordine.
- I test GitHub Actions non certificano il drag reale su touchscreen, desktop o il round-trip su VPS Coolify.

## Gate

1. [x] CI Flutter analyze/test, Windows EXE+MSIX, APK JDK17/21 e Markdown verdi sulla PR #10; [ ] verifica post-merge main.
2. [ ] Test interazione su Windows/Android: drag drop, pressione prolungata mobile, menu Sposta in, nuova attività, rinomina inline, completamento ricorrente.
3. [ ] Sync su due dispositivi, stessa account identity, pending=0, offline/online e cancellazione delle liste.
4. [ ] Verificare Flyway V10/capability su Coolify **prima** di aggiornare i client.
5. [ ] Installazione Windows ZIP vs MSIX solo dopo verifica non distruttiva SQLite/OAuth.

[Stato canonico](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Roadmap](../project.md).

## Stato successivo (26 ottobre 2026)

P1.10 Pomodoro è integrata su main e P1.11 Habit Tracker è in sviluppo in branch. Il Kanban P1.9 rimane invariato, usa le liste sincronizzate; lo storico locale di Habit Tracker e Pomodoro non modifica lo schema di sync. [Stato](CURRENT-STATUS.md) · [Habit Tracker](P1-HABITS.md).
