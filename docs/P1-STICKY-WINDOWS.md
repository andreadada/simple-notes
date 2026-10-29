# P1.14 — Sticky Notes in finestre Windows

> **Stato operativo 29/10/2026:** P1.16 Responsive su `main` (PR #17, Flutter `0.21.0+23`, CI verde); P1.17 Windows Tray `0.22.0+24` **in branch** e CI/merge/device da verificare. Repo Flyway V10, VPS Coolify attestata V8, nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [P1.17](P1-WINDOWS-TRAY.md).

**Stato 26/10/2026:** **integrata in `main` con PR #15**, Flutter `0.19.0+21`, [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40377359849) e [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40377360259). Il collaudo Windows reale resta da fare. P1.13 Weekly Habits ([PR #14](https://github.com/andreadada/simple-notes/pull/14)) integrata su `main`, Flutter `0.18.0+20`, [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/40371894259) e [Markdown](https://github.com/andreadada/simple-notes/actions/runs/40371894390) verdi. Nessun deploy/reset.

## Integrazione

- Nella sezione **Note**, ogni nota ha un comando `Apri finestra Sticky Note` **solo su Windows**. Si apre una seconda finestra Flutter nativa, indipendente dalla principale (non una modale).
- La finestra mostra titolo e corpo con i componenti inline già utilizzati nell'app. Le modifiche vengono inoltrate al processo **principale** tramite `desktop_multi_window ^0.3.1`, che chiama `LocalStore.renameNote / setNoteBody`. Solo il processo principale possiede la connessione Drift/SQLite, outbox e sincronizzazione; **il processo finestra secondaria non esegue `AppDatabase()`, OAuth o AutoSync**.
- Il bridge riconosce ogni richiesta per `noteId`, rifiuta campi non validi e modifiche su note cancellate o spostate nel cestino. Per titolo e corpo richiede il valore atteso: se la nota è stata modificata sulla schermata principale o dalla sincronizzazione, non sovrascrive automaticamente e invita a **Ricaricare**. Ciò non sostituisce il controllo versioni backend.
- Se una finestra per la stessa nota è già aperta dal medesimo processo principale, viene mostrata quella; non viene avviato un terzo editor concorrente. Alla chiusura della finestra principale, le richieste del pop-out falliscono in modo esplicito.
- Registrazione plugin degli engine secondari tramite callback nativa in `apps/flutter/windows/runner/flutter_window.cpp` (file Windows runner tracciato): il Windows scaffold restante continua a venire generato da Flutter quando mancante. Nessuna migrazione Flyway/Drift e nessun nuovo dato `SharedPreferences`.
- Su Android **non compare** il comando pop-out; l'editor note esistente rimane invariato. L'entrypoint usa un import condizionale verso uno **stub web**, evitando che un build Flutter Web importi il plugin Windows o `dart:io`.

## Limiti della prima versione

- La finestra è una finestra Windows normale, non `always-on-top`, senza posizione/dimensione persistente, colori personalizzati o apertura automatica al riavvio. Questi comportamenti rimangono futuri.
- Non è un processo autonomo che sincronizza note a desktop spento: richiede **finestra principale aperta** e che la sua sessione sia compatibile col server.
- Test Dart unitari coprono parser di argomenti e guardia anti-sovrascrittura; la build CI Windows verifica che il plugin e callback nativa compilino, ma **non** dimostra che aprire/scrivere/chiudere una finestra funziona su un Windows reale.
- Il risultato del salvataggio viaggia sul canale dell'engine; in caso di errore il componente inline non conferma il salvataggio. Ricarica disponibile per riallinearsi ai dati nel processo principale.

## Gate release

1. [ ] `flutter analyze`, `flutter test`, Windows EXE/MSIX, Android JDK17/JDK21 e controllo link Markdown tutti verdi sullo SHA finale.
2. [ ] Windows reale: aprire 2 note in finestre differenti; provare edit titolo/corpo da pop-out e comparsa nel principale, apertura doppia stessa nota, finestra principale chiusa, conflitto da modifica parallela, sync post-save.
3. [ ] Windows ZIP e MSIX: registrazione plugin su engine secondario, copia completa dell'EXE/DLL, account Google e path SQLite invariato, uscita/riapertura senza perdita di dati.
4. [ ] Android non deve mostrare il comando né avviare il plugin Windows; compilazione JDK17/21.
5. [ ] Prima di **installare nuovi client cumulativi**, il proprietario deve verificare la VPS Flyway V10/capability; ultimo stato attestato V8. Mai resettare database, SQLite/outbox, secure storage, preferenze o volumi.

[Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [P1.13](P1-WEEKLY-HABITS.md) · [Roadmap](../project.md).

## P1.16 — Resize della vista note

Le card Note di Windows nella [P1.16 Responsive](P1-RESPONSIVE.md) usano larghezza utile e Wrap 1/2/3 colonne; il pop-out Sticky P1.14, già integrato, rimane un'azione separata e continua a passare dal LocalStore principale, senza un nuovo DB o sync. Prova reale finestre e firme MSIX ancora aperta.

## P1.17 — Tray solo main engine

Il bootstrap Sticky termina prima di inizializzare la tray, quindi ogni finestra separata non crea icone secondarie. Su Windows reale verificare comportamento di Esci con Sticky già aperte, sync note e nessun database duplicato. [P1.17](P1-WINDOWS-TRAY.md).
