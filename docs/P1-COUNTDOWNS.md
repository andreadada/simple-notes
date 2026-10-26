# P1.12 — Countdown per eventi e scadenze

> **STATO OPERATIVO — 26/10/2026:** P1.12 Countdown `0.17.0+19` ([PR #13](https://github.com/andreadada/simple-notes/pull/13)) integrata su `main` e CI verde. P1.13 Weekly Habit `0.18.0+20` **solo nel branch** `feature/p1-13-weekly-habit-goals`, CI/merge/device ancora da verificare. Pomodoro/Habits/Countdown sono **locali per device/owner**, non sincronizzati. Repository Flyway V10, ultima VPS Coolify attestata V8; nessun deploy/reset. [Stato](CURRENT-STATUS.md) · [Operazioni](OPERATIONS.md) · [P1.13](P1-WEEKLY-HABITS.md).

**Stato 26/10/2026:** **integrata su `main` con PR #13**, Flutter `0.17.0+19`, [CI Flutter verde](https://github.com/andreadada/simple-notes/actions/runs/40368229874), [Markdown verde](https://github.com/andreadada/simple-notes/actions/runs/40368230012). P1.11 Habit Tracker è stata integrata su `main` via [PR #12](https://github.com/andreadada/simple-notes/pull/12) dopo [CI Flutter](https://github.com/andreadada/simple-notes/actions/runs/40364300062) e [Markdown](https://github.com/andreadada/simple-notes/actions/runs/40364300000) verdi. P1.12 ha completato CI e merge; **test device reali ancora da eseguire**. Nessun deploy, database reset o aggiornamento server.

## Comportamento

- Voce **Countdown** nell'area Focus di Windows e Android. Eventi liberi, scollegati da task e note; una scheda indica il tempo mancante o trascorso.
- Nuovo countdown in due passaggi: scegliere la data, opzionalmente **l'ora e il fuso IANA** dal `showTaskDueEditor` Forui già condiviso, poi inserire il **titolo direttamente inline**. Non viene creato nulla prima di aver confermato entrambi.
- Distinzione rigorosa tra **data civile senza orario** e **istante UTC con IANA**. Data civile: `Oggi`, `N giorni`, `Da N giorni`; nessuna mezzanotte inventata. Data con ora: differenza rispetto all'istante salvato, con minuti arrotondati in alto, `Scaduto` oltre la scadenza. Ora legale e ambiguità gestite dal medesimo editor TaskDue.
- Modifica inline del titolo, cambio data/ora col pulsante dedicato, ordinamento per giorno e poi ora, archivio **reversibile** senza cancellare eventi o storico.
- Memoria locale JSON schema 1 in SharedPreferences, chiave isolata dall'hash SHA256 dell'account Google. Il profilo non autenticato è distinto. Errore di lettura/JSON incompatibile **blocca le scritture**, non cancella né inizializza sopra ai dati esistenti. Limite 250 eventi per profilo, titolo 1–120 caratteri.
- Aggiornamento della vista ogni 30 secondi finché aperta e quando l'app torna in primo piano. I minuti non sono sostituti di una notifica schedulata: **nessun allarme se l'app è chiusa**.

## Compatibilità e scope

- **Device-only.** Non sono sincronizzati tra Windows e Android. Non esiste endpoint, nuova tabella, Flyway/Drift migration o modifica dell'outbox/task. Le date negli eventi locali possono utilizzare la stessa semantica di TaskDue ma **non entrano mai nella sync delle scadenze task**.
- La versione Flutter candidata è `0.17.0+19`, development MSIX `0.17.0.0`. Windows ZIP è diverso da MSIX: un upgrade MSIX non testato può cambiare posizione dei file SharedPreferences/secure storage.
- Nessun collegamento diretto a un task, nessun push o notifica countdown, nessuna ricorrenza automatica o condivisione; tutte funzionalità future, non annunciate come implementate.
- L'orologio del dispositivo influisce sulle differenze temporali. L'editor rifiuta fusi inesistenti, gap e richiede scelta per fold DST.

## Gate prima del merge e del rilascio

1. [x] CI `flutter analyze`, `flutter test`, APK Android JDK17/JDK21, Windows EXE/MSIX e Markdown verdi sulla PR #13; [ ] collaudo su dispositivi reali.
2. [ ] Test di logica: oggi/ieri/domani, data civile attraverso DST, tempi UTC, arrotondamento minuti, ordine, archivio e import JSON incompatibile senza perdita.
3. [ ] UI desktop/mobile reali: creazione da editor Forui, annullamento senza evento fantasma, modifica inline titolo, cambia scadenza, archivio/ripristino, stato dopo riavvio.
4. [ ] Cambia account Google, controlla assenza di dati dell'altro profilo; verifica aggiornamento al ritorno nell'app dopo scadenza.
5. [ ] Coolify **non richiede nuove migrazioni per P1.12**, ma per il rilascio cumulativo confermare Flyway V10/capability reali prima dell'installazione dei nuovi client; la VPS risulta attestata fino a V8.

[Stato corrente](CURRENT-STATUS.md) · [Guida operativa](OPERATIONS.md) · [P1.11 Habit Tracker](P1-HABITS.md) · [Roadmap](../project.md).
