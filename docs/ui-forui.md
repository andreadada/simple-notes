# Simple Notes — UI e design system Forui

## T3 — Scadenze e fusi orari (24/10/2026)

Il client Flutter ha ora un editor scadenze Forui riutilizzato in creazione rapida, pannello dettagli e editor avanzato (`ui/task_due_editor.dart`). Supporta `date` senza ora, `datetime` con HH:mm + timezone IANA, scelta del fold DST e rifiuto del gap; non converte automaticamente `legacy`. Il rilevamento OS fallibile non produce una UTC inventata: l'utente sceglie un fuso valido. `task_due_view.dart` centralizza l'etichetta (mostra il fuso) e i filtri Oggi/7 giorni in giorni civili; gli aggiornamenti rimangono offline-first.

**Solo codice:** backend Flyway V7 e deploy Coolify non eseguiti; servono backup/restore reale e test hardware Windows↔Android. Esecuzione web, ricorrenze e notifiche non sono supportate in T3. Leggere [T3-SCADENZE.md](T3-SCADENZE.md) e verificare le [CI Flutter](https://github.com/andreadada/simple-notes/actions/workflows/flutter-ci.yml) per l'esito esatto.


## Vincolo correttivo: testo completo + sottolineatura aderente (24/10/2026)

**Due larghezze diverse, entrambe necessarie:**

- **Testo/placeholder integralmente visibile**: il `TextField` deve essere largo **almeno quanto il contenuto misurato, più spazio per cursore/selezione** (~18 dp, limitato dalla larghezza realmente disponibile). Il testo non deve essere troncato (es. «test telefono» → «test telefonc») né andare a capo inutilmente («Aggiungi una descrizione...» in un pannello sufficientemente largo). Un campo realmente stretto può andare a capo o scorrere, senza perdita di caratteri.
- **Linea breve**: la sottolineatura rimane sotto i glifi visibili (valore oppure placeholder) e NON include lo spazio riservato al cursore. Il bordo nativo resta invisibile; disegnare la linea con `InlineGlyphUnderline`, misurandola con `InlineTextMetrics.fieldWidth`. Usare `InlineTextMetrics.inputWidth` per la larghezza effettiva del campo, **non** riutilizzare `fieldWidth` anche per il `TextField`.
- **Aspetto**: nessun fondo grigio, linea neutra sottile e blu al focus, placeholder più trasparente (`NotesPalette.placeholder`). La larghezza dell'input cresce al digitare e si ferma ai limiti del contenitore disponibile.
- **Ovunque**: applicare questi componenti condivisi a titoli task/liste/note, descrizioni, tag, sottotask, input di aggiunta rapida e varianti desktop/Android. Nei test controllare *entrambe* le dimensioni: il viewport interno deve essere più largo della linea, e il segmento della linea deve seguire la misura del testo. Includere stringhe lunghe e placeholder, anche nelle sidebar strette.

Riferimento tecnico: `apps/flutter/lib/ui/notes_theme.dart` (`InlineTextMetrics.fieldWidth`, `InlineTextMetrics.inputWidth`, `InlineGlyphUnderline`). **Non ridurre la larghezza del TextField alla sola linea: provoca clipping.** Questa regola prevale sulle note storiche che chiedevano di togliere ogni spazio aggiuntivo dal campo: è la *linea* a dover essere precisa, non il viewport di editing.

**Decisione:** Forui è il **design system primario** del client Flutter Windows/Android, a partire dal 23 ottobre 2026. Nuovi componenti e schermate devono preferire Forui; Flutter Material è consentito come **bridge di migrazione** per funzioni già funzionanti o ancora non portate. Non è ancora una riscrittura completa.

## Versione e compatibilità

- Dipendenza in [pubspec.yaml](../apps/flutter/pubspec.yaml): `forui: ^0.27.6`.
- **Flutter SDK >= 3.47.0** (la versione 0.26+ di Forui ha questo requisito). La CI Flutter usa il canale stable; verificare le versioni con `flutter --version` e usare `flutter upgrade` solo se necessario.
- Sito: [forui.dev](https://forui.dev/) · [Getting Started](https://forui.dev/docs/getting-started) · [pub.dev](https://pub.dev/packages/forui) · [GitHub](https://github.com/duobaseio/forui).
- Forui è compatibile con Android e Windows (oltre alle altre piattaforme Flutter), ma **le build e i test reali su entrambe le piattaforme restano obbligatori**.

## Regola vincolante: modifica inline degli attributi

**Inline-edit first:** per titoli, nomi, descrizioni brevi e altri attributi testuali già visibili, rendere il **testo direttamente modificabile in loco** invece di aggiungere pulsanti `Rinomina`/`Modifica` che aprono modali dedicati. L'utente deve poter cliccare sul testo, digitare e continuare senza attraversare un secondo flusso.

- **Nessuno sfondo grigio negli input inline:** testo direttamente sulla superficie, con sottolineatura neutra sotto i caratteri (blu al focus). **Larghezza uguale al testo effettivo**, misurato nel font/dimensione/scaling correnti; con valore vuoto usare **solo la larghezza del placeholder**, non tutta la cella; al massimo ~1 px aggiuntivo per il cursore. È VIETATO introdurre min-width artificiali 84/120px o padding arbitrario **nella linea**; il `TextField` deve invece riservare un margine tecnico per cursore e testo, senza alterare la lunghezza disegnata. Sotto il titolo `A`, ad esempio, la linea deve essere corta quanto `A`, anche se il widget è dentro `Expanded`.
- **Placeholder semitrasparente:** usare sempre `NotesPalette.placeholder` (~72% di opacità) per i campi inline, mantenendo lo stile tipografico originale. Testo salvato a opacità normale. Niente hint pienamente grigi come testo principale.
- Implementazione condivisa: `InlineTextMetrics.fieldWidth(context, text, style, maxWidth)` in `notes_theme.dart` misura i glifi con `TextPainter` e `MediaQuery.textScalerOf`. Usare `SizedBox(width: misura)` attorno al `TextField`; nelle `Row` allineare l'azione a destra con `Spacer`, NON `Expanded(child: TextField(...))` che estende il bordo. `InlineEditableTitle`, `InlineEditableBody`, `InlineQuickAdd` e l'input `task-input` condividono questa regola. In un parent **tight** (`Expanded`/`SizedBox` con vincoli fissati), il `SizedBox` interno potrebbe comunque espandersi: prima avvolgerlo in `Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1)` per sciogliere il vincolo sul campo. Poiché anche l'`InputDecorator` di Flutter può imporre una larghezza minima, per la garanzia grafica usare `InlineGlyphUnderline(glyphWidth: larghezzaMisurata, focusNode: ..., child: TextField(...))`: disegna una riga separata sotto il testo, non il bordo fisico del campo. `NotesTheme.invisibleInlineBorder` rende trasparente il bordo nativo (pur mantenendo il tipo `UnderlineInputBorder`). **Testare la dimensione del segmento `inline-glyph-underline`**, non quella del `TextField` o wrapper. Quest'ultimo può essere volutamente più grande.
- I widget Material di transizione usano `NotesTheme.inlineBorder` e `inlineFocusedBorder` con `InputDecoration(filled:false, fillColor:Colors.transparent)`; il tema Material generale è anch'esso privo di riempimento. FTextField Forui nei dialog complessi/ricerca conserva lo stile Forui dedicato.
- Su campi testuali brevi: **Invio / perdita focus → salva**; **Esc → annulla**; se vuoto o invalido ripristinare l'ultimo valore valido. Mantenere selezione, keyboard focus, semantics, supporto touch, feedback errore.
- Il salvataggio deve andare in SQLite/outbox e poi nella sync; non manipolare soltanto lo stato visuale. Non perdere bozze durante refresh remoto mentre l'utente scrive.
- Usare `FDialog`/form Forui per dati complessi o multi-campo, date, conferme esplicite e operazioni potenzialmente distruttive. Non fare inline di qualsiasi campo indiscriminatamente: il principio vale **la maggior parte delle volte** dove il risultato rimane comprensibile.
- Componente di riferimento: `apps/flutter/lib/ui/inline_editable_title.dart` (`InlineEditableTitle`); è usato sul titolo della lista in header Windows e nella app bar Android. **Non reintrodurre il pulsante Rinomina lista** o una modale per la sola rinomina.

## Applicazione della regola su tutte le schermate esistenti

Il refactoring dell'interfaccia condivisa (24/10/2026) estende il vincolo inline-first oltre i titoli delle liste: titoli task e sottotask, descrizioni, tag, titoli/corpi delle note. `InlineEditableBody` gestisce testo multilinea, `InlineQuickAdd` l'aggiunta di sottotask; metodi `LocalStore` aggiornano SQLite/outbox senza stato grafico fittizio. Le proprietà non testuali (priorità/lista) usano `FPopoverMenu`, il calendario rimane Forui, il menu account è `FPopoverMenu` e i dettagli mobile usano `showFSheet`. Tutti i delete hanno conferma Forui. L'editor avanzato task è riservato a modifica coordinata multi-campo.

**Non dichiarare che web browser è disponibile:** la stessa UI è riutilizzabile sul web, ma backend storage/OAuth del client non sono stati portati; leggere [ui-design-audit.md](ui-design-audit.md). Il resto del Material bridge deve essere rimosso gradualmente, senza regressioni.

## Implementazione attuale

| Elemento | Implementazione |
| --- | --- |
| Tema generale | `FTheme` nel `MaterialApp.builder`, così l'intero Navigator e i dialoghi ereditano il tema Forui |
| Token grafici | `lib/ui/notes_theme.dart`: `NotesPalette` e `NotesTheme.forPlatform()` |
| Breakpoint/ergonomia | `FTheme.neutral.dark.desktop` per PC, `.touch` per Android; scelta dal `TargetPlatform` |
| Brand | Accent blu `#547AFF`, superfici dark, sidebar separata, contrasto e bordi |
| Navigazione | `FSidebar` + `FSidebarGroup` + `FSidebarItem`, condivise da desktop e drawer mobile |
| Titoli modificabili | `InlineEditableTitle` per titoli di lista: campo tipografico editabile direttamente in pagina, senza comando Rinomina |
| Interfaccia note | `FCard` per righe e `FButton` per nuova nota |
| Ricerca task | `FTextField` con callback di ricerca |
| Dettagli task | `FButton` variante outline per modifiche |
| Modali Forui | `NotesDialog` (basato su `FDialog`) per modifica attività e note; `showNotesDatePicker` con `FCalendar.grid` per tutte le scadenze |
| Compatibilità | `MaterialApp`, `Scaffold`, `TextField` di inserimento rapido, `ListTile`, `Checkbox`, `PopupMenuButton` e il bottom sheet dettagli restano temporaneamente Material |

## Regole per tutte le future modifiche

1. **Forui-first:** cercare prima `FButton`, `FTextField`, `FCard`, `FSidebar`, `FDialog`, `FPopoverMenu`, `FCheckbox` e relativi widget. Evitare di introdurre Material per nuove schermate senza motivazione.
2. **Design token centralizzati:** non duplicare colori, radius e spacing nei widget; aggiornare `notes_theme.dart` o token specifici se serve. Niente copia dell'interfaccia o degli asset TickTick.
3. **Responsive:** mantenere navigazione su sidebar Windows e drawer Android, gesture e area di tocco adeguate su mobile; non forzare layout desktop sul telefono.
4. **Conservare comportamento:** non alterare provider Riverpod, SQLite Drift, sincronizzazione automatica, account Google o modello dati soltanto per il restyle.
5. **Migrazione graduale:** sostituire widget Material per area funzionale; dopo ogni cambiamento eseguire `flutter analyze`, `flutter test`, build Windows e Android.
6. **Stati essenziali:** offline, sync in corso, errore/conflitto, vuoto, caricamento e focus accessibile devono rimanere comprensibili.
7. **Testabilità:** mantenere le chiavi dei widget già usate dai test (es. `task-input`, `task-search`, `account-menu-mobile`). Se un componente Forui cambia gerarchia interna, aggiornare i test per ricercare l'input correttamente.
8. **Nessun cambio backend necessario:** Forui riguarda soltanto `apps/flutter`, non Coolify, PostgreSQL o OAuth.

## Esempio

```dart
import 'package:forui/forui.dart';

// Dentro il sottoalbero FTheme, ad esempio in una pagina di note:
FButton(
  onPress: () { /* add local note -> outbox */ },
  prefix: const Icon(Icons.add),
  child: const Text('Nuova nota'),
);
```

> L'esempio richiede anche l'import Flutter dell'icona Material (`package:flutter/material.dart`) se si usa `Icons.add`.

## Piani successivi

- Esaminare conversione editor e ricerca avanzata a `FTextField` senza perdere comportamento dei controller.
- Convertire checkbox/list item, bottom sheet dettagli e menu account ai widget Forui dedicati; **dialoghi di modifica e calendario sono già Forui**.
- Valutare `FResizable` per tre colonne desktop e navigazione mobile FBottomNavigationBar.
- Fare test visivi su Windows (finestra ridotta, DPI 125–200%) e Android (keyboard, scrolling, dimensioni touch).
- Solo dopo prova reale, valutare tema chiaro, personalizzazione da Forui Create e preferenza utente.

## Note di verifica

Questa pagina documenta il *codice introdotto*; non dichiara che il passaggio di tutti i componenti sia terminato. Le verifiche effettive restano in `project.md` ed eventuali run GitHub Actions.

## Modali e scadenze — 23 ottobre 2026

- `apps/flutter/lib/ui/notes_dialogs.dart` contiene `NotesDialog`, layout condiviso su `FDialog` per tutti gli editor, e `showNotesDatePicker()` con `FCalendar.grid`.
- `Modifica attività` e `Modifica nota` sono `showFDialog` con input `FTextField` e azioni `FButton`. Non reintrodurre `AlertDialog` in questi flussi.
- Tutte le selezioni scadenza nell'attuale UI (creazione task e modifica task) passano dal calendario Forui: il vecchio `showDatePicker` Material è stato rimosso.
- Date-only: `FCalendar` restituisce giorni UTC; il picker restituisce intenzionalmente `DateTime(year, month, day)` **locale**, come nella semantica precedente del campo scadenza. Annulla non modifica il valore; il comando Rimuovi scadenza resta distinto.
- Controllare keyboard/focus, finestre Windows ridimensionate, dimensioni mobile, e test `apps/flutter/test/widget_test.dart`. Logica SQLite/outbox/sync invariata.

### Correzioni riscontrate nei test

- `FCalendar.grid` usa un header personalizzato compatto con pulsanti **Forui** per navigare tra mesi/anni; quello predefinito sforava di 26 px in una finestra stretta.
- `NotesEditorControllerScope` mantiene i `TextEditingController` attivi fino allo smontaggio completo della route; chiamare `.whenComplete(controller.dispose)` subito dopo `showFDialog` li liberava prima della fine dell'animazione e causava eccezioni in Flutter.
- Analisi e test widget del commit `cc0a6328` riusciti nella [CI Flutter 39977182371](https://github.com/andreadada/simple-notes/actions/runs/39977182371). Verificare separatamente anche le build native Windows/Android, ancora in esecuzione all'ultima osservazione.
