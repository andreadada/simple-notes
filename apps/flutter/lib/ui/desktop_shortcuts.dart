import 'package:flutter/services.dart';

/// P1.15: user-initiated, app-local keyboard shortcuts on Windows.
/// No global system hooks, no background hotkeys and no automatic data writes.
enum DesktopCommand {
  inbox,
  today,
  upcoming,
  allTasks,
  notes,
  newTask,
  newNote,
  help,
}

abstract final class DesktopShortcutPolicy {
  static DesktopCommand? resolve({
    required LogicalKeyboardKey key,
    required bool desktop,
    required bool ctrl,
    required bool shift,
    required bool alt,
    required bool meta,
  }) {
    if (!desktop || !ctrl || alt || meta) return null;
    if (shift) {
      if (key == LogicalKeyboardKey.keyT) return DesktopCommand.newTask;
      if (key == LogicalKeyboardKey.keyN) return DesktopCommand.newNote;
      if (key == LogicalKeyboardKey.slash ||
          key == LogicalKeyboardKey.question) {
        return DesktopCommand.help;
      }
      return null;
    }
    if (key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.numpad1) {
      return DesktopCommand.inbox;
    }
    if (key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.numpad2) {
      return DesktopCommand.today;
    }
    if (key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.numpad3) {
      return DesktopCommand.upcoming;
    }
    if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4) {
      return DesktopCommand.allTasks;
    }
    if (key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.numpad5) {
      return DesktopCommand.notes;
    }
    if (key == LogicalKeyboardKey.slash) return DesktopCommand.help;
    return null;
  }

  static DesktopCommand? forKey(KeyEvent event, HardwareKeyboard keyboard,
      {required bool desktop}) {
    if (event is! KeyDownEvent) return null;
    return resolve(
      key: event.logicalKey,
      desktop: desktop,
      ctrl: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
  }
}
