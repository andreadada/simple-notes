# P1.13 — Obiettivi settimanali Habit Tracker

> **Stato operativo 31/10/2026:** P2.2 ICS read-only integrata su `main` ([PR #21](https://github.com/andreadada/simple-notes/pull/21), Flutter `0.25.0+27`, CI Flutter/Markdown verde: 162 test, Windows EXE/MSIX, Android JDK17/21). Test fisici e deploy cumulativo non attestati. Backend repo Flyway V10, VPS ultima attestazione V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [ICS](P2-ICS.md).

**Stato 26/10/2026:** **integrata su `main` con PR #14**, Flutter `0.18.0+20`, [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/40371894259) e [Markdown](https://github.com/andreadada/simple-notes/actions/runs/40371894390) verdi; hardware/installazione non attestati. P1.12 Countdown [PR #13](https://github.com/andreadada/simple-notes/pull/13) è integrata su `main` (`0.17.0+19`) con [Flutter CI verde](https://github.com/andreadada/simple-notes/actions/runs/40368229874) e [docs verdi](https://github.com/andreadada/simple-notes/actions/runs/40368230012).

## Cosa aggiunge

- Ogni abitudine mantiene un obiettivo configurabile **1–7 giorni alla settimana**, scelto tramite menu Forui nella card. La modifica non cambia check-in, nome, archivio o il comportamento del task manager.
- Progressivo `check-in questa settimana / obiettivo`, barra di avanzamento con massimo 100%, indicatore **streak di settimane** e mantenimento dello streak giornaliero esistente.
- Settimana civile **lunedì–domenica**, calcolata con `DateTime(year, month, day ± 7)`, senza somme di ore UTC attraverso DST. Il conteggio include soltanto giorni check-in non futuri, dal giorno di creazione in poi.
- Una settimana raggiunge l'obiettivo quando ha almeno N check-in; se la settimana corrente non è ancora completata, lo streak può continuare da quella precedente completata. Nessuna penalità immediata il lunedì. Una settimana mancante già trascorsa interrompe lo streak.
- L'obiettivo `weeklyTarget` è aggiunto al JSON **schema 1** delle abitudini **in modo retrocompatibile**: record pre-P1.13 senza il campo usano default **7** (equivalente alla frequenza quotidiana precedente). I valori fuori da 1–7 o di tipo errato vengono rifiutati senza sovrascrivere l'archivio.
- `rename`, `archive`, `restore`, check-in/undo e nuovo obiettivo **mantengono lo stesso ID e tutte le date**. Lo stato passa dal consueto percorso SharedPreferences con chiave SHA-256 dell'account Google. Nessuna migrazione distruttiva.

## Limiti dichiarati

- Come P1.11, obiettivi/streak/abitudini sono **locali al dispositivo** e separati per account. Non diventano sincronizzati cambiando la frequenza.
- Non esiste calendario flessibile tipo «solo lunedì, mercoledì e venerdì»; N rappresenta il numero di giorni nella settimana.
- La prima settimana iniziata a metà non fa giorni retroattivi: se non restano sufficienti date per raggiungere N, lo streak inizia dalla settimana successiva. Questo non azzera lo storico.
- Il riepilogo «completate oggi» resta basato sui check-in giornalieri, indipendentemente dalla soglia settimanale.
- Eventi con orario, Pomodoro e Countdown restano indipendenti. Nessuna nuova migration Flyway/Drift, endpoint API, voce outbox o permesso.
- Stato reale Coolify: ultima attestazione Flyway V8, mentre il repo contiene V10. Un upgrade cumulativo deve verificare V10/capability sul server prima di installare nuovi client, anche se P1.13 è locale.

## Gate di accettazione

1. [ ] CI su SHA finale: `flutter analyze`, `flutter test`, Windows EXE+MSIX, APK Android JDK17/21 e link Markdown verdi.
2. [ ] Test unitari: default 7 per vecchio JSON, cambi obiettivo senza perdita date, lunedì/DST, streak di settimane, obiettivi non validi, archivio/restore.
3. [ ] Test widget Windows/Android: selezione menu Forui, avanzamento, check-in/undo, rientro in app, cambio owner Google, archivio senza perdita.
4. [ ] Device E2E batch: preservazione SharedPreferences/SQLite/secure storage in particolare ZIP→MSIX; nessun reset o cancellazione dati.
5. [ ] Verifica separata server Flyway V10 e capability prima del rollout cumulativo Coolify; nessun deploy automatico.

[Stato corrente](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [Habit Tracker P1.11](P1-HABITS.md) · [Roadmap](../project.md).
