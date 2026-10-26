# Simple Notes — Design & Product Specification

> **Stato 26/10/2026:** P1.9 **Kanban integrato in `main`** con [PR #10](https://github.com/andreadada/simple-notes/pull/10) (Flutter `0.14.0+16`, [CI PR verde](https://github.com/andreadada/simple-notes/actions/runs/40328803094)). P1.10 **Pomodoro locale in sviluppo sul branch** `feature/p1-10-pomodoro-focus` (`0.15.0+17`), CI/merge e device da verificare. Backend repository Flyway V10/Drift V8; ultimo Coolify reale attestato **V8**, nessun deploy/reset. [Stato canonico](docs/CURRENT-STATUS.md).

<!-- CURRENT-STATUS-REF -->

> **P1.9 (main, PR #10):** Kanban con colonne derivanti dalle liste sincronizzate, drag/drop desktop, long-press mobile, menu accessibile, titoli e inserimenti inline Forui. Nessuna nuova semantica di stato delle task. [Specifiche](docs/P1-KANBAN.md) · [Operazioni](docs/OPERATIONS.md).


## Cronologia — rilascio 0.7.0+9 (superato da P1.8)

**Codice integrato su `main`**: PR #1 P1.2 (time blocking + Flyway V8 + Drift V6) e PR #2 P1.3 (drag/resize e timeline) unite con successo. La CI dei branch è verde; le build automatiche successive al merge sono da controllare separatamente. **Coolify e PostgreSQL reali NON sono stati aggiornati/verificati da questa chat; non dichiarare Flyway V8 già applicata, né l'app installata su Windows/Android.** Per il rollout serve verificare backend `timeBlockSchema:1` e Flyway V8 prima di aggiornare i client. Non eseguire reset degli archivi: l'utente ha già concluso il reset dei soli dati di test. **Runbook attuale:** [P1-RELEASE-0.7.0.md](docs/P1-RELEASE-0.7.0.md).

> I passaggi più in basso che parlano di PR «bozza» o di `main` `0.5.0+7` sono cronologia precedente al merge. Prevale lo stato appena indicato.


## Cronologia — P1.3 (ora integrata)

**Su branch `feature/p1-3-calendar-interactions` (non su `main`): Flutter `0.7.0+9`, timeline interattiva giorno/settimana, move/resize a step 15 minuti, drag su intestazioni giornaliere e celle del mese, supporto DST e corsie sovrapposizioni; test dedicati.** Non richiede nuove tabelle oltre Flyway V8 di P1.2 e Drift V6. *CI e test hardware da verificare; nessun deploy/merge di P1.2 e P1.3 né modifica ai dati reali*. P1.2 `feature/p1-2-time-blocking` ha CI backend e Flutter completamente verde ma resta draft, non distribuito. P1.3 è documentato in [P1-CALENDAR-INTERACTIONS.md](docs/P1-CALENDAR-INTERACTIONS.md). Multi-blocco per task resta fuori ambito, per successiva revisione di modello.


## Cronologia — P1.2 in sviluppo (ora integrata)

**Branch `feature/p1-2-time-blocking`, Flutter `0.6.0+8`.** Introdotto intervallo `timeBlock` indipendente dalla scadenza, con editor Forui, blocchi nel calendario e percorso di sincronizzazione versionato. **Backend V8/Drift V6 sono solo codice: nessun deploy Coolify, migrazione reale, nuova pulizia dati o installazione sui dispositivi effettuata.** `timeBlockSchema:1` è un gate obbligatorio prima di inviare nuovi task. I test CI automatici e l'accettazione PC↔Android sono ancora da verificare. Non confondere codice implementato con feature già rilasciata. Specifica e piano: [P1-TIME-BLOCKING.md](docs/P1-TIME-BLOCKING.md). La versione su `main` resta `0.5.0+7` fino a merge autorizzato/dopo verifiche.

**Design constraint:** le scadenze sono *deadline*, i blocchi sono periodi con inizio/fine e fuso IANA. Non rendere una deadline un blocco a mezzanotte. Per un attributo semplice continuare con editing inline; usare un dialog Forui soltanto per l'intervallo composto (data, ora, fuso, fold DST).


> **Aggiornamento prodotto 25/10/2026:** nuova sezione calendario P1.1 client-only con giorno/settimana/mese e quick-add inline; regola **inline-edit first** invariata. Giorni senza orario NON diventano midnight UTC, gli orari usano il giorno di visualizzazione locale senza perdere l'etichetta IANA. P1.2 time blocking non implementato. Reset di test PostgreSQL + Windows + Android confermato dall'utente; le note storiche sotto datate 24/10 sono precedenti al reset. Specifica: [P1-CALENDAR](docs/P1-CALENDAR.md).

> **Stato reale 24/10/2026:** PostgreSQL `simplenotes` 17.11, Flyway V1–V7 riuscite, backup `simple-notes-20261024T132857Z-271921.dump` con SHA256 valido e restore isolato PASS. Copia offsite non effettuata per scelta dell'utente. Restano da verificare l'API autenticata (`taskDueSchema:1`) e il collaudo T4.2 Windows↔Android con Flutter `0.4.0+4`. Non ripetere backup, migrazioni o deploy automaticamente. [T4.2](docs/T4-DEVICE-SYNC.md).

## T3 — Scadenze Forui, IANA e DST (24/10/2026)

**Implementato nel codice su main, non distribuito.** Un unico editor `ui/task_due_editor.dart` gestisce scadenze solo-giorno e data/ora, calendario Forui, HH:mm, fuso IANA e scelta esplicita delle due occorrenze in un cambio d'ora. Gli orari inesistenti sono rifiutati, la mezzanotte scelta rimane `datetime`, e le scadenze `legacy` non sono reinterpretate in automatico. Il fuso OS viene rilevato se disponibile, altrimenti richiesto esplicitamente.

`data/task_due_clock.dart` usa `timezone ^0.11.2` e `flutter_timezone ^5.1.0`; `data/task_due_view.dart` presenta label e filtri Oggi/7 giorni secondo **giorni civili**, evitando il calcolo sbagliato di 168 ore attorno all'ora legale. Aggiunta rapida, dettagli ed editor avanzato salvano `TaskDue` con SQLite/outbox; una rinomina non muta `date/datetime` in `legacy`. Test per gap/fold, visualizzazione, filtri e modifica avanzata. **V7 già verificata sul database reale**, backup SHA256 e restore isolato PASS. Mancano capability API `taskDueSchema:1` e prove Windows/Android; non ripetere deploy senza un'incompatibilità accertata. Ricorrenze, notifiche e browser web restano fuori da T3.

Dettagli e checklist: [specifica T3](docs/T3-SCADENZE.md). CI: [Flutter Actions](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml).


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

> Specifica funzionale/tecnica sintetica. **Non significa che tutto sia implementato.** Stato reale in [project.md](project.md).

## 1. Obiettivo e principi
- Un'unica app Windows 11 + Android per task, note, calendario, abitudini e produttività; backend Coolify.
- **Offline-first:** le modifiche devono essere disponibili subito e sopravvivere al riavvio, anche senza rete.
- **Fast UI:** un tap per completare; nuovi task tramite input rapido; navigazione e ricerca via tastiera.
- **Privacy:** dati sotto il controllo dell'utente; OAuth Google per identificazione, non per memorizzare le note.
- UI originale. I riferimenti TickTick sono funzionali: non riprodurre codice, marchi, icone o screenshot.
- Italiano come lingua iniziale; stringhe localizzabili, supporto inglese successivo.

## 2. Information architecture
**Sidebar desktop:** Oggi, Prossimi 7 giorni, Inbox, Tutto, Completati, Cestino; cartelle/liste; Tag; Filtri. Moduli: Calendario, Eisenhower, Pomodoro, Abitudini, Countdown e Note.
**Mobile:** drawer + navigazione inferiore per Attività, Calendario, Note, Altro. FAB per inserimento rapido.
**Pannelli desktop:** navigazione 240 px (collassabile), lista fluida, dettaglio 320–420 px (ridimensionabile); niente scroll orizzontale nei form.
**Dettaglio attività:** titolo, priorità, date+timezone, ricorrenza, reminder, descrizione, subtasks, checklist, allegati, tags, lista, storico.
**Sticky note:** finestra Windows separata, always-on-top opzionale, chiusura non elimina i dati.

## 3. Visual design

**Decisione (23 ottobre 2026):** Forui è la base UI ufficiale del client Flutter. Il tema, i colori e le modalità desktop/touch sono centralizzati in `apps/flutter/lib/ui/notes_theme.dart` e la documentazione attuativa è in [docs/ui-forui.md](docs/ui-forui.md). I componenti Material già in uso vengono sostituiti gradualmente, senza rifare il sistema di sincronizzazione o i dati.
| Token | Dark (base) | Light (target) |
|---|---|---|
| Surface | #181818 | #FFFFFF |
| Sidebar | #202020 | #F6F7F9 |
| Raised surface | #252525 | #FFFFFF |
| Accent | #547AFF | #476BE8 |
| Text primary | #F5F5F5 | #17191E |
| Text secondary | #A0A0A0 | #667085 |
| Error / destructive | #EF5350 | #D92D20 |
| Success | #2BD39B | #159D72 |
| Border | #343434 | #E5E7EB |

- Scale spacing: 4/8/12/16/24/32 px; radius input 10–12, panels 12–16.
- Font di sistema, tipografia con gerarchie nette; testo minimo consigliato 12–13 sp.
- Animazioni 120–220 ms con rispetto di reduced motion.
- Focus visibile, testo leggibile, semantica e touch targets almeno 44–48 dp.
- Stati sempre previsti: vuoto, caricamento, offline, conflitto, errore, successo.

### Vincolo UX: inline editing first (obbligatorio)

**Un attributo già mostrato deve, nella maggior parte dei casi, essere modificabile direttamente nello stesso punto in cui viene letto.** Preferire il contenuto stesso come campo editabile (aspetto tipografico normale quando inattivo) a bottoni ridondanti `Rinomina`, `Modifica titolo` o modal separati.

- Esempi prioritari: **titolo della lista nell'header**, titolo task, titolo nota, descrizione breve e altre proprietà testuali semplici. Un click/tap sul valore attiva cursore e selezione senza cambiare pagina.
- Il componente inline deve avere **stile coerente con il testo originale**, larghezza legata al contenuto, focus visibile ma leggero, semantica accessibile e comportamento adeguato a mouse, tastiera e touch.
- **Stile input inline obbligatorio — regola esatta:** niente background/grigio né rettangolo. Sottolineatura sottile neutra anche a riposo, blu accent al focus, **larga quanto i glifi effettivamente mostrati**, oppure quanto il testo placeholder se il campo è vuoto; non deve MAI allungarsi fino al margine del contenitore, né avere larghezze minime artificiali (es. 84/120 px) o padding orizzontale superfluo. La **linea** aggiunge al massimo ~1 px alla larghezza dei glifi; il **campo editabile** invece necessita di spazio ulteriore per mostrare testo e caret. Anche in righe con `Expanded`, il campo deve mantenere larghezza intrinseca: il resto della riga rimane spazio vuoto, NON una linea.
- **Placeholder più trasparente del testo reale:** il colore `NotesPalette.placeholder` è una versione semi-trasparente di `secondaryText` (~72% di opacità); mantiene dimensione/font del contenuto e resta distinguibile in tema scuro. Non riutilizzare il colore pieno dei dati salvati. Misurare il testo con `InlineTextMetrics.fieldWidth` includendo lo scaling accessibile e i caratteri effettivi. Non simulare la sottolineatura con un bordo full-width sotto un `Expanded`.
- **Ambito:** titoli task/note/liste/sottotask, tag, descrizioni, corpo nota, aggiunta rapida attività e sottotask nelle schermate Flutter Windows/Android (UI condivisa per il futuro web). Per paragrafi multilinea larghi o che vanno a capo, il campo può usare lo spazio necessario al wrapping, ma non un minimo arbitrario. Ricerca Forui e form multi-campo sono controlli distinti, non input inline.
- Per campi brevi, **Invio o perdita del focus salva**; **Esc annulla** e ripristina il testo precedente. Non salvare stringhe vuote, rispettare limiti e mostrare errori non distruttivi.
- Ogni modifica deve passare per gli stessi metodi di persistenza offline-first e outbox/sync, **mai essere solo un cambiamento grafico**. Non creare stati in cui il testo appare aggiornato ma non è stato salvato.
- Usare form/dialog Forui quando servono **più campi correlati, conferme, validazioni complesse o azioni distruttive**, non per una semplice rinomina. Preferire un controllo mirato (es. calendario, selettore) quando il dato non è testo libero.
- Considerare questo criterio nelle review di **ogni nuova schermata** e durante il refactoring delle schermate esistenti; le eccezioni vanno motivate per accessibilità o complessità.

Implementazione riusabile: `InlineEditableTitle`, `InlineEditableBody`, `InlineQuickAdd` e helper centralizzato `InlineTextMetrics.fieldWidth` in `apps/flutter/lib/ui/notes_theme.dart`. I valori sono modificabili direttamente e la sottolineatura è contenuta nella larghezza del testo; per l'input veloce dei task vedere `apps/flutter/lib/main.dart`. **Vincolo layout:** se il widget si trova dentro `Expanded` / `SizedBox(width:...)` con constraint stretto, usare un `Align(alignment: centerStart, widthFactor: 1)` *tra* il parent e il `SizedBox` del `TextField`. Una sola misura tramite `TextPainter` non basta se il parent impone una larghezza fissa. **Inoltre `InputDecorator` può imporre una larghezza intrinseca anche quando il campo è correttamente misurato**: in quel caso non usare il bordo nativo per disegnare la linea. Usare `InlineGlyphUnderline` (Stack + linea `PositionedDirectional` larga esattamente quanto il testo, con `FocusNode` per cambiare colore), mentre il `TextField` usa `NotesTheme.invisibleInlineBorder`. Così la linea NON supera i glifi anche se l'area di input effettiva è più larga.

### Applicazione UX effettiva nelle schermate esistenti (24 ottobre 2026)

La UI Flutter ora offre modifica inline di titoli **lista, attività, note e sottotask**, descrizione attività e corpo nota; priorità e lista si selezionano via `FPopoverMenu`, la data via calendario Forui e le conferme distruttive via `FDialog`. Profilo/sync usa menu Forui e il pannello dettagli mobile usa `showFSheet`. La scrittura è offline-first tramite `LocalStore`, SQLite e outbox. L'editor avanzato multi-campo è un'eccezione intenzionale; i componenti Material strutturali/quick-add restano bridge durante la migrazione.

**Web:** la UI è condivisa e responsive ma il runtime browser NON è ancora operativo (database Drift nativo e OAuth Windows/Android). Il gap e la checklist sono documentati in [docs/ui-design-audit.md](docs/ui-design-audit.md).

## 4. Funzionalità
**P0 — MVP:** login Google, account/sessioni, task, liste, note, tags, sottotask, scadenze, ricorrenze, reminder, ricerca, SQLite locale, push/pull incrementale, conflitti, Android/Windows.
**P1 — Produttività:** calendario giorno/settimana/mese, Eisenhower, Kanban, Pomodoro, stopwatch, habit, streak, countdown, sticky notes, shortcuts, tray.
**P2 — Estensioni:** timeline, ICS, Google/Outlook Calendar (consenso separato), liste condivise, ruoli, allegati S3, widget, analisi, export/import, temi.
**P3 — Smart:** parsing lingua italiana, voce, suggerimenti/riassunti AI *opt-in*.

## 5. Modello dati
User(id, googleSub, email), Device(id, userId, lastSeen), Session(id, deviceId, expires), List(id, ownerId, title, order), Task(id, ownerId, listId, title, description, dueAt, timezone, priority, completedAt, version, deletedAt), TaskOccurrence(ruleId, occurrenceDate, state), Note(id, ownerId, title, body, version, deletedAt), Tag(id,...), Reminder(id, taskId, fireAt), Habit(id, schedule, streak), FocusSession(...).
- ID UUID client-generated; tempi UTC sul server e *timezone* IANA dove ricorrente.
- `updated_at` server-side e `version` gestita in transazione; non fare affidamento solo sul timestamp del device.
- Tombstone e change log per sync; nessuna hard-delete immediata di contenuti sincronizzati.

## 6. Sincronizzazione (design target)
1. Write locale in SQLite + inserimento operazione in **outbox transazionale**.
2. Quando online/autenticato, invio batch con `operationId`, entityId, expectedVersion, payload; retry idempotente.
3. Server valida ownership, atomizza write+change log, incrementa revisione e restituisce ack.
4. Pull delta tramite cursor per utente; applica update nel DB locale senza cancellare outbox ancora pendenti.
5. Se `expectedVersion` non coincide, restituisce 409 e blocca l'upload senza perdere la coda. Target: ottenere stato server, conservarne due versioni e offrire una UI di scelta.
6. Attualmente auto-sync foreground (login, modifiche, resume, reconnessione, pull ogni 60s), con riprova esponenziale. Target futuro: invalidazione WebSocket/back-end, eventuale background sync, nessun polling aggressivo.
7. Logout cancella credenziali, interrompe sync e isola dataset dell'account. Il cambio account non mescola dati.

**Non fare:** last-write-wins silenzioso, shared_preferences per dataset finale, delete senza tombstone, sync basata sui soli orologi client.

## 7. Login e sicurezza
- Android: Google Identity, verifica ID token lato API.
- Windows: system browser + authorization code + PKCE (loopback per installed apps), non webview embedded.
- Backend: valida JWKS, issuer, audience, expiry; identifica con `sub` e non email. App JWT breve + refresh token ruotato/revocabile (implementato sul server); gestione completa dispositivo/recovery ancora da verificare.
- Segreti in Coolify e storage OS sicuro; TLS obbligatorio, rate-limit auth, auditing errori non sensibili, backup cifrati e test restore.
- Nessuna chiave privata, token, keystore o credenziale reale committata.

### Prossimo incremento P0: data-only e fusi orari (solo piano)

Il futuro modello distingue `none`/`date` (giorno civile, nessuna ora) / `datetime` (data/ora, timezone IANA, istante UTC, offset DST) / `legacy` (dato `dueAt` precedente, non inferire automaticamente dal valore 00:00). Non equivale a funzionalità implementata: sono pianificati Flyway V7, Drift v5, protezione per vecchi client e test multi-device. Leggere [docs/due-dates-timezones.md](docs/due-dates-timezones.md) prima di sviluppare ricorrenze o reminder.

## Cronologia — T2/Drift V5 (schema superato da V8)

Flutter adotta `TaskDue` (`none/date/datetime/legacy`) e Drift **schema v5**. Una data senza ora resta una data civile; scadenze storiche conservate come `legacy`; `due_at` e outbox rimangono per compatibilità. `CloudSync` controlla il server `GET /api/v1/capabilities` prima di caricare scadenze `date/datetime` e richiede `taskDueSchema=1`; il server obsoleto non riceve aggiornamenti moderni. HTTP **426 CLIENT_UPGRADE_REQUIRED** blocca la sync senza cancellare mutazioni o attivare la risoluzione 409. I payload `dueAt` storici restano leggibili.

Test automatici T2/T3 per data-only, DST, doppio SQLite, outbox, Drift v4→v5 ed editor Forui. [Flutter CI 40100324302](https://github.com/andreadada/simple-notes/actions/runs/40100324302) PASS sul commit `5a0e6b6`. Il DB reale ha V7 e restore isolato verificato; capability API e hardware T4.2 ancora da provare. Flutter Web non supportato.

## 8. Promemoria e calendari
- Android: notifiche locali prenotate + FCM per invalidazione/sync; gestione POST_NOTIFICATIONS, reboot e restrizioni exact alarms.
- Windows: notification center, processo in tray opzionale; impossibile notificare a PC spento.
- Reminder idempotenti per occurrence e device; snooze persistito, timezone e DST.
- Calendario esterno: prima read-only ICS; API Google/Outlook solo in P2 con permessi minimi.

## 9. Deliverable per fase e criteri
P0 supera solo se: login end-to-end su due sistemi, offline+retry, conflitti, reminder, build, restore DB, due dispositivi con stesso account, test integrazione.
P1/P2/P3 possono essere sbloccati a moduli indipendenti dopo P0 robusto.
Qualsiasi feature con sola UI o solo endpoint **non** è completata.

## 10. Decisioni & rischi aperti
- Decisione: monolite modulare Spring Boot e Flutter unico; nessun Redis/Kafka senza misurazione.
- Rischio: OAuth desktop/Android richiede OAuth client ID configurati dall'utente in Google Cloud Console.
- Rischio: sincronizzazione e conflitti; P0 priorità prima dei moduli visuali.
- Rischio: packaging/notifiche Windows; verificare MSIX/installer firmato in test reali.
- Drift/SQLite con import legacy presente e testato in CI; serve prova in upgrade reale e test conflitti multi-device.
- Rischio: scheduling Android e risparmio batteria; test su hardware, non solo emulatori.
- Deploy produzione NON previsto finché sicurezza e backup non risultano verificati.

## 11. Riferimenti interni
- Roadmap e log: [project.md](project.md)
- Architettura: [docs/architecture.md](docs/architecture.md)
- Contratto API: [docs/api.md](docs/api.md)

### Implementazione organizzazione P0 (23 ottobre 2026)
Le liste personalizzate persistenti, priorità, tag e sottotask sono ora nel codice client/server con migrazioni e UI Forui. La roadmap di P0 e i limiti dei test sono in [task-organization.md](docs/task-organization.md). Le funzioni di calendario, ricorrenze, notifiche e filtri complessi restano progettuali, non operative.

## P1.10 — Pomodoro (in sviluppo, device-only)

Schermata responsive Forui con cronometro e barra di avanzamento, controlli Avvia/Pausa/Ricomincia e Salta pausa, statistiche locali a 7 giorni. Timer del singolo account/dispositivo e storico non sincronizzato; non chiedere permessi notifiche e non modificare database task. Nessun dialogo di rinomina: il design rule inline resta invariato. [Specifica](docs/P1-POMODORO.md).
