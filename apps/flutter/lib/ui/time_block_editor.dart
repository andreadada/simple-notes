import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/task_due_clock.dart';
import 'calendar_logic.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Explicit time-block editor. A blank result is not a deletion:
/// TimeBlock.none requires the dedicated "Rimuovi blocco" action.
class TimeBlockDecision {
  final TimeBlock? block;
  const TimeBlockDecision(this.block);
}

Future<TimeBlockDecision?> showTimeBlockEditor(
  BuildContext context, {
  TimeBlock? initial,
  DateTime? selectedDay,
}) async {
  TaskDueClock.knowsZone('Etc/UTC'); // Initializes the bundled TZ database.
  final detected = TaskDueClock.deviceZone();
  final location = initial == null ? null : tz.getLocation(initial.timeZone);
  final initialStart = location == null ? null :
      tz.TZDateTime.from(initial!.start, location);
  final initialEnd = location == null ? null :
      tz.TZDateTime.from(initial!.end, location);
  DateTime day = initialStart == null
      ? calendarCivil(selectedDay ?? DateTime.now())
      : calendarCivil(initialStart);
  final zone = TextEditingController(text: initial?.timeZone ?? '');
  final from = TextEditingController(text: initialStart == null
      ? '09:00' : '${initialStart.hour.toString().padLeft(2, '0')}:'
          '${initialStart.minute.toString().padLeft(2, '0')}');
  final until = TextEditingController(text: initialEnd == null
      ? '10:00' : '${initialEnd.hour.toString().padLeft(2, '0')}:'
          '${initialEnd.minute.toString().padLeft(2, '0')}');
  int? startOffset;
  int? endOffset;
  List<DueOccurrence> startChoices = [];
  List<DueOccurrence> endChoices = [];
  bool discoveryStarted = false;
  String? warning;

  return showFDialog<TimeBlockDecision>(
    context: context,
    builder: (dialog, style, animation) =>
      NotesEditorControllerScope(
        controllers: [zone, from, until],
        child: StatefulBuilder(builder: (context, update) {
          if (!discoveryStarted) {
            discoveryStarted = true;
            detected.then((name) {
              if (context.mounted && name != null && zone.text.isEmpty) {
                update(() => zone.text = name);
              }
            });
          }
          void clearChoices() => update(() {
            startChoices = [];
            endChoices = [];
            startOffset = null;
            endOffset = null;
            warning = null;
          });
          void save() {
            try {
              final zoneName = zone.text.trim();
              if (!TaskDueClock.knowsZone(zoneName)) {
                throw const FormatException('Seleziona un fuso IANA valido.');
              }
              final date = calendarDateKey(day);
              final starts = TaskDueClock.possibilities(
                  date, from.text.trim(), zoneName);
              final ends = TaskDueClock.possibilities(
                  date, until.text.trim(), zoneName);
              if (starts.isEmpty || ends.isEmpty) {
                throw const FormatException(
                  'Orario inesistente per il cambio dell’ora legale.');
              }
              update(() {
                startChoices = starts.length > 1 ? starts : [];
                endChoices = ends.length > 1 ? ends : [];
              });
              if ((starts.length > 1 && startOffset == null) ||
                  (ends.length > 1 && endOffset == null)) {
                throw const FormatException(
                  'Orario ripetuto: seleziona l’occorrenza UTC di inizio e fine.');
              }
              final start = starts.where((x) =>
                  startOffset == null || x.offsetSeconds == startOffset).first;
              final end = ends.where((x) =>
                  endOffset == null || x.offsetSeconds == endOffset).first;
              final block = TimeBlock(start: start.instant,
                  end: end.instant, timeZone: zoneName);
              Navigator.pop(dialog, TimeBlockDecision(block));
            } on FormatException catch (error) {
              update(() => warning = error.message);
            } catch (_) {
              update(() => warning =
                  'Controlla orari e fuso: la fine deve essere dopo l’inizio '
                  '(durata massima 24 ore).');
            }
          }

          Widget optionPicker(String label, List<DueOccurrence> choices,
              int? selected, void Function(int) choose) => Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label: orario ripetuto, scegli l’occorrenza',
                style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final choice in choices)
                  FButton(
                    variant: selected == choice.offsetSeconds
                        ? FButtonVariant.primary : FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => choose(choice.offsetSeconds),
                    child: Text('UTC${choice.offsetLabel}'),
                  ),
              ]),
            ],
          );

          return NotesDialog(
            key: const Key('time-block-editor'),
            style: style, animation: animation,
            title: const Text('Pianifica blocco di tempo'),
            body: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('La scadenza del task resta indipendente.',
                style: const TextStyle(fontSize: 12,
                    color: NotesPalette.secondaryText)),
              const SizedBox(height: 12),
              FButton(
                key: const Key('time-block-date'),
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: () async {
                  final picked = await showNotesDatePicker(context,
                      initialDate: day);
                  if (picked != null && context.mounted) {
                    update(() => day = calendarCivil(picked));
                    clearChoices();
                  }
                },
                child: Text('${day.day}/${day.month}/${day.year}'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FTextField(
                  key: const Key('time-block-start'),
                  label: const Text('Inizio (HH:mm)'),
                  control: FTextFieldControl.managed(
                    controller: from, onChange: (_) => clearChoices()),
                )),
                const SizedBox(width: 8),
                Expanded(child: FTextField(
                  key: const Key('time-block-end'),
                  label: const Text('Fine (HH:mm)'),
                  control: FTextFieldControl.managed(
                    controller: until, onChange: (_) => clearChoices()),
                )),
              ]),
              const SizedBox(height: 10),
              FTextField(
                key: const Key('time-block-zone'),
                label: const Text('Fuso IANA'),
                hint: 'Europe/Rome',
                control: FTextFieldControl.managed(
                    controller: zone, onChange: (_) => clearChoices()),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: FButtonVariant.ghost,
                mainAxisSize: MainAxisSize.min,
                onPress: () {
                  zone.text = 'Europe/Rome';
                  clearChoices();
                },
                child: const Text('Europe/Rome'),
              ),
              if (startChoices.isNotEmpty) ...[
                const SizedBox(height: 10),
                optionPicker('Inizio', startChoices, startOffset,
                    (value) => update(() { startOffset = value; warning = null; })),
              ],
              if (endChoices.isNotEmpty) ...[
                const SizedBox(height: 10),
                optionPicker('Fine', endChoices, endOffset,
                    (value) => update(() { endOffset = value; warning = null; })),
              ],
              if (warning != null) ...[
                const SizedBox(height: 8),
                Text(warning!, style: const TextStyle(color: Color(0xFFFF9090),
                    fontSize: 12)),
              ],
            ]),
            actions: [
              FButton(variant: FButtonVariant.ghost,
                onPress: () => Navigator.pop(dialog),
                child: const Text('Annulla')),
              if (initial != null)
                FButton(variant: FButtonVariant.ghost,
                  key: const Key('time-block-clear'),
                  onPress: () =>
                      Navigator.pop(dialog, const TimeBlockDecision(null)),
                  child: const Text('Rimuovi blocco')),
              FButton(key: const Key('time-block-save'),
                onPress: save, child: const Text('Salva')),
            ],
          );
        }),
      ),
  );
}
