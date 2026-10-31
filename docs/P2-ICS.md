# P2.2 — Calendari ICS locali in sola lettura

**Stato 31/10/2026:** sviluppo nel branch `feature/p2-2-ics-readonly`, Flutter candidato `0.25.0+27`. Non dichiarare CI, merge, deploy o test hardware finché non verificati. [Stato](CURRENT-STATUS.md).

## Scopo e interazione

- In Calendario → **Importa ICS** (file picker nativo Windows/Android), preview Forui con nome file e conteggio eventi, scelta Annulla/Importa eventi.
- Possono coesistere **massimo cinque** file ICS per account e dispositivo. Reimportare un nome già presente **sostituisce solo quel file**, dopo conferma. Il pulsante «× nome» chiede conferma prima di rimuovere un overlay, lasciando altre sorgenti e tutti i dati applicativi intatti.
- Eventi mostrati nelle viste **giorno, settimana e mese**: categoria «EVENTI ESTERNI · SOLA LETTURA», icona lucchetto e nome file. Non hanno edit, checkbox, drag&drop, notifiche o azioni di pianificazione. Date intere e orari sono trattati distintamente.
- Persistenza JSON `schema=1` in SharedPreferences con chiave hash SHA-256 di `userId` Google (o bucket signed-out). Non sono sincronizzati su altri dispositivi e non diventano entità task/note.

## Formato supportato in P2.2

- iCalendar UTF-8 valido con `BEGIN:VCALENDAR` e componenti `VEVENT`; UID e SUMMARY obbligatori e non vuoti; DTSTART e **DTEND obbligatori**. `DTEND` è **esclusivo**: eventi multi-giorno restano date civili, senza mezzanotte inventata.
- Date `YYYYMMDD`/VALUE=DATE, orari UTC `YYYYMMDDTHHMMSSZ`, oppure data-ora locale con `TZID=Europe/Rome` o altro **nome IANA noto**. Le occorrenze vengono proiettate nel giorno civile del dispositivo; la durata è calcolata in istanti reali.
- Line folding RFC5545, escape testuali comuni, esclusione VEVENT con STATUS:CANCELLED, UID unici per file. Valori `VTIMEZONE` personalizzati non sono interpretati; il parser può usare solo identificatori IANA.
- **Non supportati e rifiutati senza importazione parziale:** RRULE, RDATE, EXDATE, RECURRENCE-ID, DURATION, orari senza Z/TZID (floating), timezone custom non IANA, orari locali impossibili o ambigui per DST, intervalli malformati.
- Limiti: **1 MiB** e **500 eventi validi** per file; **5 file** per archivio. Non è abilitata subscription da URL né aggiornamento periodico. Il file non viene interpretato come codice o collegamento di rete.

## Sicurezza, privacy e compatibilità

L'ICS può contenere informazioni personali: selezionare solo file fidati. Il parser valida completamente il candidato **prima** della conferma, senza scrivere nulla in caso di errore/annullamento. L'import salva una copia locale del risultato; sostituzione e rimozione cambiano solo SharedPreferences con controllo esito. JSON locale corrotto blocca modifiche e non viene azzerato automaticamente.

Nessuna migrazione Drift o Flyway, nessun endpoint, outbox, Google Calendar OAuth o permesso cloud nuovo. Il server reale continua ad avere il gate **V10** per la distribuzione cumulativa dell'app, indipendentemente da questi overlay.

## Test e gate

1. UTC, IANA Europe/Rome inverno/estate, eventi giorno intero multi-giorno/end exclusive, UTC→giorno locale.
2. DST gap/fold, floating/custom TZID, ricorrenze e exception, UID duplicati, data impossibile, file grande/corrotto → errore fail-closed.
3. Ri-import stesso file, multi-source, rimozione, serializzazione versionata, chiavi per account diversi.
4. CI analyze/test Windows EXE/MSIX, Android debug JDK17/JDK21, Markdown sullo **SHA finale**; prova fisica picker e persistenza successiva al merge.
5. Nessun deploy/reset o test con dati reali durante questo incremento.

## Incrementi futuri

P2.3: subscription URL ICS con rete e refresh espliciti, ricorrenze/EXDATE, integrazioni Google/Outlook solo con permessi minimi e policy di accesso separate. Queste funzioni **non** appartengono alla P2.2.
