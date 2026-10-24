# Simple Notes — Design & Product Specification

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
- **Stile input inline obbligatorio — regola esatta:** niente background/grigio né rettangolo. Sottolineatura sottile neutra anche a riposo, blu accent al focus, **larga quanto i glifi effettivamente mostrati**, oppure quanto il testo placeholder se il campo è vuoto; non deve MAI allungarsi fino al margine del contenitore, né avere larghezze minime artificiali (es. 84/120 px) o padding orizzontale superfluo. È tollerabile soltanto ~1 px per il cursore di inserimento. Anche in righe con `Expanded`, il campo deve mantenere larghezza intrinseca: il resto della riga rimane spazio vuoto, NON una linea.
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
