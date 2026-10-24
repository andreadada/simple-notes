import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../data/task_due.dart';
import '../data/task_due_clock.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Shared Forui editor for quick add, details and the advanced task editor.
/// null = cancelled. TaskDue.none = user explicitly cleared the date.
Future<TaskDue?> showTaskDueEditor(BuildContext context, {
  TaskDue initial = TaskDue.none,
}) async {
  // Present the dialog immediately. Platform timezone discovery can be slow
  // or unavailable (notably in widget tests and desktop integration).
  final detectedZoneFuture = TaskDueClock.deviceZone();
  String? detectedZone;
  bool zoneDiscoveryStarted = false;

  final initialDay = initial.kind == 'datetime' && initial.date != null
      ? DateTime.parse(initial.date!)
      : (initial.displayLocal ?? DateTime.now());
  DateTime selected = DateTime(
      initialDay.year, initialDay.month, initialDay.day);
  String mode = initial.kind == 'datetime' ? 'datetime' : 'date';
  String? message;
  int? selectedOffset = initial.kind == 'datetime'
      ? initial.offsetSeconds : null;
  List<DueOccurrence> choices = [];
  String? foldSignature;
  final time = TextEditingController(
      text: initial.kind == 'datetime' ? initial.time! : '09:00');
  final zone = TextEditingController(
      text: initial.kind == 'datetime'
          ? initial.timeZone! : '');
  bool busy = false;

  String dateIso() =>
      '${selected.year.toString().padLeft(4, '0')}-'
      '${selected.month.toString().padLeft(2, '0')}-'
      '${selected.day.toString().padLeft(2, '0')}';
  String dateLabel() =>
      '${selected.day.toString().padLeft(2, '0')}/'
      '${selected.month.toString().padLeft(2, '0')}/${selected.year}';

  return showFDialog<TaskDue>(
      context: context,
      builder: (dialogContext, style, animation) =>
          NotesEditorControllerScope(
        controllers: [time, zone],
        child: StatefulBuilder(
          builder: (dialogContext, update) {
            if (!zoneDiscoveryStarted) {
              zoneDiscoveryStarted = true;
              detectedZoneFuture.then((value) {
                if (dialogContext.mounted) {
                  update(() {
                    detectedZone = value;
                    if (value != null && zone.text.trim().isEmpty) {
                      zone.text = value;
                    }
                  });
                }
              });
            }
            void resetOptions() => update(() {
              choices = [];
              selectedOffset = null;
              foldSignature = null;
              message = null;
            });
            Future<void> save() async {
              if (busy) return;
              update(() => busy = true);
              try {
                if (mode == 'date') {
                  Navigator.pop(dialogContext, TaskDue.dateOnly(dateIso()));
                  return;
                }
                if (zone.text.trim().isEmpty ||
                    !TaskDueClock.knowsZone(zone.text.trim())) {
                  throw const FormatException(
                      'Seleziona un fuso orario IANA valido.');
                }
                final options = TaskDueClock.possibilities(
                    dateIso(), time.text.trim(), zone.text.trim());
                if (options.isEmpty) {
                  throw const FormatException(
                      'Questo orario non esiste: cambio dell’ora legale.');
                }
                // Never reuse a fold choice after editing the date, clock
                // or zone: the same offset may represent a different instant.
                final signature =
                    '${dateIso()}|${time.text.trim()}|${zone.text.trim()}';
                if (options.length == 2 && (selectedOffset == null ||
                    foldSignature != signature ||
                    !options.any((o) => o.offsetSeconds == selectedOffset))) {
                  update(() {
                    choices = options;
                    foldSignature = signature;
                    selectedOffset = null;
                    message = 'Orario ripetuto: scegli la prima '
                        'o la seconda occorrenza.';
                  });
                  return;
                }
                final due = TaskDueClock.resolve(dateIso(), time.text.trim(),
                    zone.text.trim(), selectedOffsetSeconds:
                        options.length == 1 ? null : selectedOffset);
                if (dialogContext.mounted) Navigator.pop(dialogContext, due);
              } on FormatException catch (error) {
                update(() => message = error.message);
              } catch (_) {
                update(() => message =
                    'Fuso orario non riconosciuto. Usa un identificatore IANA.');
              } finally {
                if (dialogContext.mounted) update(() => busy = false);
              }
            }

            return NotesDialog(
              key: const Key('task-due-editor'),
              style: style,
              animation: animation,
              maxWidth: 480,
              title: const Text('Scadenza attività'),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (initial.kind == 'legacy') ...[
                    const Text(
                      'Scadenza storica: scegliere una modalità per '
                      'convertirla esplicitamente. Annulla non la modifica.',
                      style: TextStyle(fontSize: 12,
                        color: NotesPalette.secondaryText),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(child: FButton(
                      key: const Key('due-mode-date'),
                      variant: mode == 'date'
                          ? FButtonVariant.primary : FButtonVariant.outline,
                      onPress: () => update(() {
                        mode = 'date';
                        choices = [];
                        foldSignature = null;
                        message = null;
                      }),
                      child: const Text('Solo giorno'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: FButton(
                      key: const Key('due-mode-datetime'),
                      variant: mode == 'datetime'
                          ? FButtonVariant.primary : FButtonVariant.outline,
                      onPress: () => update(() {
                        mode = 'datetime';
                        choices = [];
                        selectedOffset = null;
                        foldSignature = null;
                        message = null;
                      }),
                      child: const Text('Data e ora'),
                    )),
                  ]),
                  const SizedBox(height: 16),
                  FButton(
                    key: const Key('due-pick-day'),
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    prefix: const Icon(Icons.calendar_today_outlined,
                        size: 17),
                    onPress: () async {
                      final picked = await showNotesDatePicker(dialogContext,
                          initialDate: selected);
                      if (picked != null && dialogContext.mounted) {
                        update(() => selected = DateTime(
                            picked.year, picked.month, picked.day));
                        resetOptions();
                      }
                    },
                    child: Text(dateLabel()),
                  ),
                  if (mode == 'datetime') ...[
                    const SizedBox(height: 16),
                    FTextField(
                      key: const Key('due-time-input'),
                      control: FTextFieldControl.managed(controller: time),
                      label: const Text('Ora esatta (24h, HH:mm)'),
                      hint: '09:00',
                    ),
                    const SizedBox(height: 12),
                    FTextField(
                      key: const Key('due-zone-input'),
                      control: FTextFieldControl.managed(controller: zone),
                      label: const Text('Fuso orario IANA'),
                      hint: 'Es. Europe/Rome',
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 5, runSpacing: 5, children: [
                      for (final suggestion in const [
                        'Europe/Rome', 'Etc/UTC',
                        'America/New_York', 'America/Los_Angeles',
                        'Asia/Tokyo',
                      ])
                        FButton(
                          key: Key('due-zone-${suggestion.replaceAll('/', '-')}'),
                          variant: FButtonVariant.ghost,
                          size: FButtonSizeVariant.xs,
                          onPress: () {
                            zone.text = suggestion;
                            resetOptions();
                          },
                          child: Text(suggestion,
                            style: const TextStyle(fontSize: 11)),
                        ),
                    ]),
                    if (detectedZone == null && initial.kind != 'datetime')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Fuso del dispositivo non rilevato: '
                            'scegline uno esplicitamente.',
                          style: TextStyle(fontSize: 12,
                            color: NotesPalette.secondaryText)),
                      ),
                    if (choices.length == 2) ...[
                      const SizedBox(height: 12),
                      const Text('Questo orario compare due volte:',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < choices.length; i++)
                          FButton(
                            key: Key('due-fold-${i+1}'),
                            variant: selectedOffset ==
                                choices[i].offsetSeconds
                                ? FButtonVariant.primary
                                : FButtonVariant.outline,
                            mainAxisSize: MainAxisSize.min,
                            onPress: () => update(() {
                              selectedOffset = choices[i].offsetSeconds;
                              message = null;
                            }),
                            child: Text('${i + 1}ª · UTC${choices[i].offsetLabel}'),
                          ),
                      ]),
                    ],
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(message!, key: const Key('due-validation-error'),
                      style: const TextStyle(fontSize: 12,
                        color: Color(0xFFFF9090))),
                  ],
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
                  key: const Key('due-clear'),
                  variant: FButtonVariant.ghost,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.pop(
                      dialogContext, TaskDue.none),
                  child: const Text('Rimuovi'),
                ),
                FButton(
                  key: const Key('due-save'),
                  mainAxisSize: MainAxisSize.min,
                  onPress: busy ? null : save,
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        ),
      ),
    );
}
