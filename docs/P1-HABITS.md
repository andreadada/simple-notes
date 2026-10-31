# P1.11 — Habit Tracker locale

> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI Flutter/Markdown verde: 162 test, Windows EXE/MSIX, Android JDK17/21). Test fisici e deploy cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [ICS](P2-ICS.md).

> **Snapshot 29/10/2026:** P1.17 Windows Tray integrata in `main` ([PR #18](https://github.com/andreadada/simple-notes/pull/18), Flutter `0.22.0+24`, CI Flutter/Markdown verde); prove fisiche Windows/Android e rilascio cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. Le sezioni originali sottostanti restano storiche; vedere lo stato canonico. [Stato](CURRENT-STATUS.md) · [Tray](P1-WINDOWS-TRAY.md).

**Stato 26/10/2026:** **integrata su main con PR #12**, Flutter `0.16.0+18`, [Flutter CI verde](https://github.com/andreadada/simple-notes/actions/runs/40364300062) e [Markdown CI verde](https://github.com/andreadada/simple-notes/actions/runs/40364300000). P1.10 Pomodoro è integrata in `main` (PR #11), dopo [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/40347771381) e Markdown verdi. **P1.11 è integrata nel repo, ma non verificata installata sui dispositivi reali.** Backend GitHub Flyway V10/Drift V8 invariati; ultima versione Coolify confermata V8.

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

1. [x] CI Flutter analyze/test, Windows EXE+MSIX, APK JDK17+21 e Markdown verdi su PR #12; [ ] device reali ancora da verificare.
2. [ ] Widget test su Android stretto e Windows: crea, spunta e annulla, correggi data, rinomina, archivia/ripristina, isolamento profilo Google e gestione JSON corrotto.
3. [ ] Riapertura app, cambio giorno, DST, clock alterato e prova account/login/logout reali senza perdite.
4. [ ] Nessun deploy Coolify né cambio schema per Habit Tracker; Flyway V10 sul server reale resta gate generale per il resto dell'app.
5. [ ] Un unico collaudo cumulativo Windows↔Android dopo aver confermato server, firme e packaging, **senza reset dei dati**; le abitudini restano volutamente separate su ciascun device.

[Stato canonico](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Roadmap](../project.md) · [Design](../design.md).

## P1.13 (estensione candidata)

Nella [P1.13](P1-WEEKLY-HABITS.md) ogni abitudine riceve un obiettivo facoltativo 1–7 check-in/settimana, da UI Forui, senza modificare lo storico check-in. Il modello P1.11 senza campo `weeklyTarget` usa default 7 in lettura per compatibilità; avanzamento e streak di settimane sono locali al dispositivo. L'estensione è ancora sul branch e richiede CI/merge/hardware.
