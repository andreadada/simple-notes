import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'notes_theme.dart';

/// Reusable content layout for Forui's opinionated modal surface.
/// Both Windows and Android use the same spacing and action placement.
class NotesDialog extends StatelessWidget {
  const NotesDialog({
    super.key,
    required this.style,
    required this.animation,
    required this.title,
    required this.body,
    required this.actions,
    this.maxWidth = 460,
  });

  final FDialogStyleDelta style;
  final Animation<double> animation;
  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => FDialog(
    style: style,
    animation: animation,
    semanticsLabel: 'Simple Notes',
    constraints: BoxConstraints(minWidth: 280, maxWidth: maxWidth),
    builder: (context, resolved) {
      final touch = context.platformVariant.touch;
      return Padding(
        padding: EdgeInsets.all(touch ? 20 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: resolved.titleTextStyle,
              child: title,
            ),
            SizedBox(height: touch ? 20 : 22),
            Flexible(child: SingleChildScrollView(child: body)),
            SizedBox(height: touch ? 22 : 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions) ...[
                  if (action != actions.first) const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Date-only picker with a real Forui calendar instead of Material's
/// large two-pane calendar modal. Cancel returns null; accepted dates are
/// local civil dates, preserving the previous due-date semantics.
Future<DateTime?> showNotesDatePicker(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final current = initialDate ?? DateTime.now();
  DateTime selected = DateTime.utc(current.year, current.month, current.day);
  return showFDialog<DateTime>(
    context: context,
    builder: (dialogContext, style, animation) => StatefulBuilder(
      builder: (dialogContext, update) => NotesDialog(
        key: const Key('forui-date-dialog'),
        style: style,
        animation: animation,
        maxWidth: 420,
        title: const Text('Scegli una data'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleziona il giorno della scadenza',
              style: TextStyle(
                fontSize: 13,
                color: NotesPalette.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            FCalendar.grid(
              key: const Key('forui-date-calendar'),
              control: FGridCalendarControl(
                start: DateTime.utc(2020),
                end: DateTime.utc(2100, 12, 31),
                initial: selected,
              ),
              selectionControl: FDateSelectionControl.managedSingle(
                initial: selected,
                toggleable: false,
                onChange: (date) {
                  if (date != null) update(() => selected = date);
                },
              ),
            ),
          ],
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FButton(
            key: const Key('confirm-due-date'),
            mainAxisSize: MainAxisSize.min,
            onPress: () => Navigator.pop(
              dialogContext,
              DateTime(selected.year, selected.month, selected.day),
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    ),
  );
}
