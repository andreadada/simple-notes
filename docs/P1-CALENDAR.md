# P1.1 — Calendario giorno, settimana, mese

<!-- CURRENT-STATUS-REF -->
> **Codice corrente:** P1.6 ricorrenze integrata su `main`, Flutter `0.10.0+12`, Flyway V10/Drift V8. P1.7 promemoria su branch senza delivery nativa. Ultimo server controllato V8; V9/V10 e dispositivi reali da verificare. Questa specifica contiene anche note storiche: consultare [CURRENT-STATUS.md](CURRENT-STATUS.md) per la versione effettiva e i gate.


## Stato (25 ottobre 2026)

**Implementato su GitHub main nel client Flutter `0.5.0+7`; risultati di CI e prove su hardware vanno verificati separatamente.** Non è stata installata questa versione sui dispositivi né eseguito un deploy da questa attività. Nessuna nuova tabella, migrazione Flyway o versione dell'API è richiesta da P1.1.

## Funzioni disponibili nel codice

- Nuova voce **Calendario** nella navigazione Forui, responsive Windows e Android.
- Modalità **Giorno**: agenda del giorno, attività senza ora separate da quelle con orario.
- Modalità **Settimana**: lunedì–domenica; scorrimento orizzontale su finestre strette, selezione di una colonna per aprire il giorno.
- Modalità **Mese**: griglia di sei settimane lunedì–domenica, conteggi e titoli sintetici dove c'è spazio; selezione del giorno e agenda dettagliata in fondo.
- Navigazione precedente/successivo e pulsante **Oggi**. Il mese conserva quando possibile il numero del giorno selezionato (31 gennaio → 28/29 febbraio).
- Titolo attività modificabile **inline**, stato completato tramite checkbox, modifica scadenza col medesimo editor Forui già usato altrove.
- Aggiunta rapida nel giorno selezionato tramite `InlineQuickAdd`: salva `TaskDue.dateOnly(YYYY-MM-DD)` e sincronizza tramite SQLite/outbox già esistente.
- Include attività completate per conservare lo storico, visualizza il numero di attività aperte **senza scadenza** (escluse dalla griglia) e non le colloca arbitrariamente nel calendario.
- Le scadenze **solo giorno** rimangono giorni civili (non mezzanotte UTC). `datetime` e `legacy` sono posizionate nel giorno/ora locale del dispositivo che le visualizza; l'etichetta estesa delle `datetime` mantiene ora e fuso IANA scelti alla creazione. Nessun tempo viene inventato.

## Architettura

- `apps/flutter/lib/ui/calendar_logic.dart`: proiezione deterministica del giorno civile, movimento giorno/settimana/mese, griglia 42 giorni, matching task e ordinamento. Test indipendenti dalla UI in `apps/flutter/test/calendar_logic_test.dart`.
- `apps/flutter/lib/ui/calendar_board.dart`: interfaccia Forui/Material, senza nuovo stato persistente. Legge `localStoreProvider` così che le modifiche remote appaiano al `reload()`.
- `apps/flutter/lib/main.dart`: nuova sezione `Section.calendar`, nascosti filtri/search/quick-add della lista normale per evitare due editor contemporanei.
- Test widget: `apps/flutter/test/calendar_board_test.dart`.
- L'editor delle scadenze resta unico (`task_due_editor.dart`). Salvare da calendario passa sempre tramite `LocalStore` → Drift/outbox.

## Collaudo ancora richiesto

1. Aprire **Calendario** su Windows e Android dopo aver compilato/installato `0.5.0+7`; confrontare un giorno senza attività, uno con data-only, uno con orario e un task completato.
2. Cambiare giorno/settimana/mese e verificare navigazione a fine mese/anno, mese con 28/29 giorni e transizione DST.
3. Creare da calendario un task nel giorno selezionato su Windows; controllare la scadenza e l'arrivo su Android dopo la sync (e viceversa).
4. Rinomina inline, toggle completato e modifica data/ora su un dispositivo; verificare l'altro, dopo che il backend è compatibile con `taskDueSchema:1`.
5. Verificare layout a 360–420 dp Android e a diverse larghezze Windows, scroll settimanale e nessun clipping della griglia.
6. Separatamente, per il **Cestino note** introdotto in `0.4.2+6`, prima di provare il ripristino cloud aggiornare e verificare il backend `noteRestoreSchema:1`. P1.1 non effettua questo deploy.

## Limiti dichiarati

**P1.2 — Time blocking ancora da implementare.** La scadenza non è un blocco temporale: manca un intervallo inizio/fine o una durata. Non riutilizzare `dueAt` come orario di inizio e non alterare il modello `TaskDue` per simulare un blocco. La prossima modifica dovrà introdurre un modello start/end coerente con fusi orari, DST, conflitti e versionamento (nuovo contratto API/migrazioni con piano di rollout).

Ancora fuori ambito: drag/drop e ridimensionamento delle fasce orarie, ricorrenze, notifiche, connessione ai calendari Google/Outlook, sincronizzazione in background e selezione di slot senza scadenza.

## Check di release

- Flutter Analyze/Unit/Widget CI: verificare esito della revisione che contiene questo documento.
- Build APK (JDK17/JDK21) e Windows release: verificare i singoli job CI.
- E2E Windows–Android: **non completato**.
- Coolify deploy: **non eseguito**; P1.1 è client-only.
- Nessun reset dati e nessuna migrazione richiesti per aggiornare il client.

## P1.2 in sviluppo su branch separato (25/10/2026)

La versione successiva estende la proiezione aggiungendo i blocchi temporali distinti dalle scadenze. Serve API `timeBlockSchema:1` e Flyway V8 prima di aggiornare client: [P1-TIME-BLOCKING.md](P1-TIME-BLOCKING.md). Fino al merge e al rollout, le funzioni P1.2 **non sono presenti nella release attuale**.
