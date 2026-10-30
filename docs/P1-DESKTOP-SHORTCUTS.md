# P1.15 — Scorciatoie tastiera Windows

> **Stato operativo 30/10/2026:** P2.1 import/export JSON portabile integrata su `main` ([PR #20](https://github.com/andreadada/simple-notes/pull/20), Flutter `0.24.0+26`, CI Flutter/Markdown verde: 152 test e build Windows/Android). Collaudi fisici e rilascio cumulativo non attestati. Backend repo Flyway V10, ultima VPS verificata V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Archivio](P2-PORTABLE-ARCHIVE.md).

**Stato 26/10/2026:** **integrata in `main` con PR #16**, Flutter `0.20.0+22`, [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40384676154) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40384676062). P1.14 Sticky Notes [PR #15](https://github.com/andreadada/simple-notes/pull/15) è integrata su `main` (Flutter `0.19.0+21`, [Flutter CI verde](https://github.com/andreadada/simple-notes/actions/runs/40377359849) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40377360259)). CI/merge P1.15 confermati; installazione e prove fisiche ancora da verificare.

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
