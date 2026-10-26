# P1.11 — Habit Tracker locale

**Stato 26/10/2026:** sviluppo nel branch `feature/p1-11-habit-tracker`, Flutter `0.16.0+18`. P1.10 Pomodoro è integrata in `main` (PR #11), dopo [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/40347771381) e Markdown verdi. **P1.11 non è ancora distribuita, mergiata o verificata su hardware.** Backend GitHub Flyway V10/Drift V8 invariati; ultima versione Coolify confermata V8.

## Funzioni implementate

- Voce **Abitudini** nell'area FOCUS di Windows e Android; nessuna modifica a task, note o liste sincronizzate.
- Creazione rapida di abitudini quotidiane, nome editabile inline, checkbox check-in per oggi e per gli ultimi **7 giorni** visibili; nessuna data futura o antecedente alla creazione.
- Progressivo **completate oggi**, streak corrente (con tolleranza per oggi non ancora spuntato, partendo da ieri), conteggi degli ultimi **7 e 30 giorni**. I giorni sono **date civili locali** in formato ISO `YYYY-MM-DD`, non istanti UTC/midnight né ore fittizie; passaggio DST gestito per giorno civile.
- **Archivio senza cancellazione**: nascondi/ripristina abitudini preservando titolo, check-in e storico. Nessun tasto di cancellazione definitiva o reset.
- Storage JSON schema 1 in `SharedPreferences`, chiave locale SHA-256 dell'ID Google; profilo `signed-out-local` separato. Salvataggio serializzato, parsing difensivo; se il record è corrotto o incompatibile viene mostrato un errore **senza sovrascriverlo**.
- Fino a 200 abitudini per profilo, massimo 5000 date registrate per abitudine; date duplicate o impossibili rifiutate. Titoli 1–120 caratteri, nomi e ID univoci, nessun check-in anticipato. Il cronologico delle date rimane completo entro tali limiti.
- Forui card, checkbox, input inline e comandi accessibili; schermata scorrevole e layout per Android stretto.

## Limiti e compatibilità

- **V1 intenzionalmente device-only**: Windows e Android NON sincronizzano abitudini, check-in, streak o archivio. Usare lo stesso Google account serve soltanto a isolare i dati localmente; la sincronizzazione eventuale richiederà un modello server e migrazioni progettati separatamente.
- `SharedPreferences` non è parte della sincronizzazione task/notes e non usa outbox. Nessuna modifica a Spring Boot, Flyway, Drift, OAuth o notifiche.
- Modificare il fuso orario o la data del dispositivo può cambiare la giornata visualizzata. L'app aggiorna il calcolo al rientro, non garantisce rollover giornaliero su schermata lasciata permanentemente aperta.
- Prima del passaggio a Windows MSIX, verificare persistenza **sia** SQLite sia `SharedPreferences` e secure storage. Nessun tool effettua migrazioni automatiche dei dati tra ZIP e MSIX.
- Per future abitudini settimanali, obiettivi numerici e sincronizzazione tra device serve una progettazione esplicita; non presentarli come implementati.

## Test e gate prima del merge/release

1. [ ] CI Flutter analyze/test, Windows EXE+MSIX, APK JDK17+21, Markdown links verdi su SHA finale.
2. [ ] Widget test su Android stretto e Windows: crea, spunta e annulla, correggi data, rinomina, archivia/ripristina, isolamento profilo Google e gestione JSON corrotto.
3. [ ] Riapertura app, cambio giorno, DST, clock alterato e prova account/login/logout reali senza perdite.
4. [ ] Nessun deploy Coolify né cambio schema per Habit Tracker; Flyway V10 sul server reale resta gate generale per il resto dell'app.
5. [ ] Un unico collaudo cumulativo Windows↔Android dopo aver confermato server, firme e packaging, **senza reset dei dati**; le abitudini restano volutamente separate su ciascun device.

[Stato canonico](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Roadmap](../project.md) · [Design](../design.md).
