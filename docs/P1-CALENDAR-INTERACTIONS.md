# P1.3 — Interazioni dirette nel calendario (trascina e ridimensiona)

<!-- CURRENT-STATUS-REF -->
> **Riferimento 26/10/2026:** `main` integra P1.13 Weekly Habit (PR #14, Flutter `0.18.0+20`, CI verde). P1.14 Sticky Windows è nel branch `feature/p1-14-sticky-windows` (Flutter candidata `0.19.0+21`), CI/merge e prova PC da verificare. Nessun deploy/reset; repo Flyway V10 e VPS attestata V8. Questa guida conserva informazioni dell'incremento originario: consultare lo [stato operativo](CURRENT-STATUS.md), le [operazioni](OPERATIONS.md) e la [P1.14](P1-STICKY-WINDOWS.md) per le decisioni correnti.


> **Aggiornamento dopo merge:** P1.2 e P1.3 sono ora su `main` in Flutter `0.7.0+9`; **non significa deploy Coolify**. Procedura di rilascio e gate: [P1-RELEASE-0.7.0.md](P1-RELEASE-0.7.0.md). Le etichette “in sviluppo” sotto sono cronologia del branch.


**25 ottobre 2026 · Branch `feature/p1-3-calendar-interactions` · Flutter `0.7.0+9`**

> Stato: codice di sviluppo su branch dedicato, creato dal P1.2 con CI verde. Non è su `main`, non è installato sui dispositivi, non è stato deployato su Coolify e non ha modificato il database reale. Non usare questa pagina per dedurre che P1.2 sia già distribuito.

## Funzionalità introdotte

1. **Timeline a 24 ore civili (23/25 ore effettive nei giorni di cambio ora)**, visibile nelle viste Giorno e Settimana. Un'ora = 54 dp in Giorno, 38 dp nelle colonne Settimana, con righello orario e blocchi collocati secondo istanti UTC e fuso *locale del dispositivo*.
2. **Sposta un blocco** trascinando verticalmente il corpo del blocco; il preview aggiorna la posizione senza scrivere. Solo al rilascio si crea **un solo** upsert task, arrotondato a passi di 15 minuti. La durata resta invariata.
3. **Ridimensiona un blocco** trascinando la maniglia inferiore; varia soltanto la fine, minimo 15 minuti, massimo 24 ore; in caso di errore la modifica non viene salvata.
4. **Sposta tra giorni** trascinando la maniglia a puntini sull'intestazione di un altro giorno nella Settimana oppure su una data del Mese. Il giorno di destinazione eredita l'ora di inizio nel fuso IANA originale e la durata assoluta, senza alterare la scadenza del task.
5. Su Android/iOS il trascinamento tra giorni richiede **pressione prolungata** sulla maniglia per non confliggere con lo scroll; su Windows il grip è trascinabile subito. Per modifiche rapide è presente anche uno spostamento di 15 minuti via pulsanti nelle card del calendario, con tooltip accessibili.
6. **Sovrapposizioni**: assegnazione di corsie separate ai blocchi concorrenti, senza eliminare o modificare automaticamente altri blocchi. Non viene applicato uno spostamento forzato.
7. Le attività create e modificate nel calendario restano nello stesso percorso SQLite→outbox→Spring Boot di P1.2; non esiste una seconda entità, né una mutazione su ogni frame di drag.

## Sicurezza sui fusi e DST

- Il movimento verticale usa intervalli di tempo UTC reali per mantenere un istante univoco, compresa l'ora ripetuta durante il ritorno all'ora solare.
- Il drop su un altro giorno risolve giorno + ora civile nel **fuso IANA salvato sul blocco**, preservando quando possibile l'offset originale. Se l'ora non esiste (DST gap) o è ambigua e non disambiguabile, l'operazione viene rifiutata con messaggio; l'utente può aprire l'editor P1.2 per scegliere esplicitamente il nuovo orario.
- Un blocco che attraversa la mezzanotte è visibile su entrambi i giorni; la durata si calcola come `end - start` UTC.
- Il righello è derivato dagli istanti compresi tra mezzanotte locale e mezzanotte locale del giorno successivo, non da 24h fisse: gestisce il cambio DST e segnala l'ora duplicata con la sigla del fuso.
- Il limite di 15 minuti è **UX**, non un nuovo vincolo backend. Il modello P1.2 continua a supportare durata minima maggiore di 0 e massima 24h.

## File e verifiche

- `apps/flutter/lib/ui/time_block_interactions.dart`: gesti snap 15', spostamento, resize, trasferimento tra giorni, righello DST e corsie di sovrapposizione.
- `apps/flutter/lib/ui/time_block_timeline.dart`: widget riutilizzabile, preview e commit su gesture-end, handle touch/desktop, drop targets.
- `apps/flutter/lib/ui/calendar_board.dart`: integrazione nelle tre viste, callback su `LocalStore.setTaskTimeBlock`, errori visibili e comandi accessibili.
- `apps/flutter/test/time_block_interactions_test.dart`: snap/move/resize, blocchi sovrapposti, errori DST, durata, persistenza SQLite e drag widget. Verificare CI del commit finale.

**Nessuna nuova migrazione.** Resta necessario distribuire **backend P1.2 Flyway V8 + `timeBlockSchema:1` prima di installare client P1.3**. La versione Flutter è `0.7.0+9` con schema Drift **6**. La sincronizzazione protegge l'outbox quando il backend non è aggiornato.

## Checklist per il collaudo reale

- [ ] CI Flutter: analyze, widget/unit, Windows release e Android JDK17/21 verdi sull'ultimo commit.
- [ ] Prima backend P1.2 pubblicato e `timeBlockSchema:1` verificato con JWT; non su database attuale a questa fase.
- [ ] Da Windows: trascina di +30', trascina end di -15', controlla sul telefono entrambe le modifiche e scadenza indipendente.
- [ ] Da Android: sposta +15' con touch, long-press per drop su altro giorno; verifica su Windows.
- [ ] Verifica fine del mese, 29 febbraio, ora legale gap e fold (23/25 ore), sovrapposizioni e blocchi tra due giorni.
- [ ] Connessione offline: drag & resize producono un solo outbox record ciascuno; sync successiva e gestione 409 senza perdere dati.
- [ ] Screen-reader/tastiera, narrow 360dp, tablet, Windows ridimensionato e scrolling su settimana.

## Limiti dichiarati / P1.4

- **Un solo blocco per task**, come in P1.2. **Multi-intervallo** richiede una modifica del modello e del protocollo, non è incluso in P1.3.
- Questa versione non implementa auto-scroll durante il drag verso date fuori schermo, suggerimento di slot, layout completo degli eventi su tutta la settimana, undo transazionale, shortcut tastiera per resize, ricorrenze e Google/Outlook.
- Il drag tra giorni preserva l'ora di partenza nel fuso dell'evento, mentre il drag verticale agisce sulla durata UTC: sull'ora del DST possono esserci salti visivi coerenti con il tempo reale.

**Gate di rilascio storico (merge già avvenuto):** merge del PR P1.3 solo dopo CI e approvazione, poi rollout backend P1.2 e installazione coordinata app. Nessun reset dei dati di test richiesto.

### Promozione del codice ≠ distribuzione

L'integrazione GitHub di P1.2 e P1.3 è distinta dal rollout su Coolify e dall'installazione Windows/Android. Il gate di uscita richiede Flyway V8 e `timeBlockSchema:1` confermati sul server prima di utilizzare il nuovo client; dopo il collaudo reale aggiornare checklist e stato in `project.md`.
