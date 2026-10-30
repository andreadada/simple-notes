import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local appearance setting. Independent of Google identity and sync.
abstract final class ThemeModePreference {
  static const key = 'simple_notes.theme_mode.v1';

  static ThemeMode decode(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark, // preserve the pre-P1.18 default
  };

  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };

  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(key));
  }

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, encode(mode))) {
      throw StateError('Impossibile salvare il tema sul dispositivo.');
    }
  }
}

/// Scoped to a window so a detached Sticky window never mutates main state.
class NotesAppearance extends InheritedWidget {
  const NotesAppearance({
    super.key,
    required this.mode,
    required this.onChange,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChange;

  static NotesAppearance of(BuildContext context) {
    final value = context.dependOnInheritedWidgetOfExactType<NotesAppearance>();
    assert(value != null, 'NotesAppearance missing above app home');
    return value!;
  }

  @override
  bool updateShouldNotify(NotesAppearance oldWidget) => mode != oldWidget.mode;
}
