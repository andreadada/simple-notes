# P1.15 — Scorciatoie tastiera Windows

**Stato 26/10/2026:** implementazione sul branch `feature/p1-15-desktop-shortcuts`, Flutter candidata `0.20.0+22`. P1.14 Sticky Notes [PR #15](https://github.com/andreadada/simple-notes/pull/15) è integrata su `main` (Flutter `0.19.0+21`, [Flutter CI verde](https://github.com/andreadada/simple-notes/actions/runs/40377359849) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40377360259)). CI/merge P1.15, installazione e prove fisiche ancora da verificare.

## Funzionalità

| Scorciatoia | Azione |
|---|---|
| `Ctrl+1` | Inbox |
| `Ctrl+2` | Oggi |
| `Ctrl+3` | Prossimi 7 giorni |
| `Ctrl+4` | Tutto |
| `Ctrl+5` | Note |
| `Ctrl+Shift+T` | Apre Inbox e mette il cursore in **Nuova attività**; non crea task vuoti |
| `Ctrl+Shift+N` | Apre Note e crea una nota tramite il **LocalStore/SQLite/outbox esistente** |
| `Ctrl+/` | Mostra il dialogo Forui con elenco scorciatoie |
| Icona tastiera nell'header | Mostra lo stesso elenco su Windows |

Le scorciatoie sono **interne alla finestra attiva dell'app Windows**, non globali di sistema, non intercettano input con Alt/Meta e non modificano il comportamento di Android. `Ctrl+C/V/A/Z`, i tasti normali e lo shift non associato restano disponibili all'editor. Il codice non aggiunge una libreria nativa, un processo in background, nuove credenziali, un endpoint, una migrazione Flyway/Drift o preferenze utente.

La navigazione da tastiera usa lo stesso stato `Section` della sidebar, cancella una selezione di task/lista precedente senza cancellare record. La creazione nota è instradata sul medesimo `LocalStore.addNote()` utilizzato dal bottone UI: la normale persistenza/outbox resta intatta e gli errori sono visibili. La creazione task mostra solo l'input già presente; dati non vengono salvati finché non si conferma una nuova attività.

## Gate tecnici

1. [ ] CI sul commit finale: `flutter analyze`, `flutter test`, build Windows EXE/MSIX, Android APK JDK17+21 e verifica link Markdown.
2. [ ] Test policy: Ctrl+digit, numpad, Ctrl+Shift+T/N, Ctrl+/, blocco Android, Alt/Meta e combinazioni editoriali.
3. [ ] Test widget: navigazione, creazione nota in SQLite, focus task, help Forui; Android non deve reagire a Ctrl+digit.
4. [ ] Test su Windows fisico: layout piccolo/grande, tastiera italiana con `/`, editing inline sotto focus, Ctrl+C/V/Z, lista aperta, sticky pop-out, ritorno di focus dopo un dialogo.
5. [ ] Test cumulativo client solo dopo controllo sulla VPS Flyway V10 reale (ultima attestazione V8). Nessun deploy/reset, SQLite/outbox, secure storage o preferenze alterati per questo incremento.

[Stato canonico](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [Roadmap](../project.md) · [Design](../design.md).
