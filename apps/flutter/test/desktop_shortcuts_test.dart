import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/desktop_shortcuts.dart';

void main() {
  DesktopCommand? command(LogicalKeyboardKey key, {
    bool desktop = true,
    bool ctrl = true,
    bool shift = false,
    bool alt = false,
    bool meta = false,
  }) => DesktopShortcutPolicy.resolve(
    key: key, desktop: desktop, ctrl: ctrl,
    shift: shift, alt: alt, meta: meta,
  );

  test('Control+digits select the expected main sections', () {
    expect(command(LogicalKeyboardKey.digit1), DesktopCommand.inbox);
    expect(command(LogicalKeyboardKey.digit2), DesktopCommand.today);
    expect(command(LogicalKeyboardKey.digit3), DesktopCommand.upcoming);
    expect(command(LogicalKeyboardKey.digit4), DesktopCommand.allTasks);
    expect(command(LogicalKeyboardKey.digit5), DesktopCommand.notes);
    expect(command(LogicalKeyboardKey.numpad5), DesktopCommand.notes);
    expect(command(LogicalKeyboardKey.digit6), isNull);
  });

  test('Quick actions require both Ctrl and Shift', () {
    expect(command(LogicalKeyboardKey.keyT, shift: true),
        DesktopCommand.newTask);
    expect(command(LogicalKeyboardKey.keyN, shift: true),
        DesktopCommand.newNote);
    expect(command(LogicalKeyboardKey.keyT), isNull);
    expect(command(LogicalKeyboardKey.keyN), isNull);
    expect(command(LogicalKeyboardKey.slash), DesktopCommand.help);
  });

  test('Shortcuts do not run on Android or consume ordinary editing keys', () {
    expect(command(LogicalKeyboardKey.digit1, desktop: false), isNull);
    expect(command(LogicalKeyboardKey.digit1, ctrl: false), isNull);
    expect(command(LogicalKeyboardKey.digit1, alt: true), isNull);
    expect(command(LogicalKeyboardKey.digit1, meta: true), isNull);
    expect(command(LogicalKeyboardKey.keyA), isNull);
    expect(command(LogicalKeyboardKey.keyC), isNull);
    expect(command(LogicalKeyboardKey.keyV), isNull);
    expect(command(LogicalKeyboardKey.keyZ), isNull);
    expect(command(LogicalKeyboardKey.delete), isNull);
    expect(command(LogicalKeyboardKey.escape), isNull);
    expect(command(LogicalKeyboardKey.digit1, shift: true), isNull);
  });
}
