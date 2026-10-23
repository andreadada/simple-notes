# Simple Notes — UI e design system Forui

**Decisione:** Forui è il **design system primario** del client Flutter Windows/Android, a partire dal 23 ottobre 2026. Nuovi componenti e schermate devono preferire Forui; Flutter Material è consentito come **bridge di migrazione** per funzioni già funzionanti o ancora non portate. Non è ancora una riscrittura completa.

## Versione e compatibilità

- Dipendenza in [pubspec.yaml](../apps/flutter/pubspec.yaml): `forui: ^0.27.6`.
- **Flutter SDK >= 3.47.0** (la versione 0.26+ di Forui ha questo requisito). La CI Flutter usa il canale stable; verificare le versioni con `flutter --version` e usare `flutter upgrade` solo se necessario.
- Sito: [forui.dev](https://forui.dev/) · [Getting Started](https://forui.dev/docs/getting-started) · [pub.dev](https://pub.dev/packages/forui) · [GitHub](https://github.com/duobaseio/forui).
- Forui è compatibile con Android e Windows (oltre alle altre piattaforme Flutter), ma **le build e i test reali su entrambe le piattaforme restano obbligatori**.

## Implementazione attuale

| Elemento | Implementazione |
| --- | --- |
| Tema generale | `FTheme` nel `MaterialApp.builder`, così l'intero Navigator e i dialoghi ereditano il tema Forui |
| Token grafici | `lib/ui/notes_theme.dart`: `NotesPalette` e `NotesTheme.forPlatform()` |
| Breakpoint/ergonomia | `FTheme.neutral.dark.desktop` per PC, `.touch` per Android; scelta dal `TargetPlatform` |
| Brand | Accent blu `#547AFF`, superfici dark, sidebar separata, contrasto e bordi |
| Navigazione | `FSidebar` + `FSidebarGroup` + `FSidebarItem`, condivise da desktop e drawer mobile |
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
