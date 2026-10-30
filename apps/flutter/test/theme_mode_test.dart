import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/theme_mode_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme preference preserves dark as legacy default', () {
    expect(ThemeModePreference.decode(null), ThemeMode.dark);
    expect(ThemeModePreference.decode('unexpected'), ThemeMode.dark);
    for (final mode in ThemeMode.values) {
      expect(ThemeModePreference.decode(ThemeModePreference.encode(mode)), mode);
    }
  });

  test('theme preference survives new SharedPreferences reads', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ThemeModePreference.load(), ThemeMode.dark);
    await ThemeModePreference.save(ThemeMode.light);
    expect(await ThemeModePreference.load(), ThemeMode.light);
    await ThemeModePreference.save(ThemeMode.system);
    expect(await ThemeModePreference.load(), ThemeMode.system);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Material and Forui use matching $brightness palette',
        (tester) async {
      final palette = brightness == Brightness.dark
          ? NotesPalette.dark : NotesPalette.light;
      late NotesColors resolved;
      late Brightness resolvedBrightness;
      await tester.pumpWidget(MaterialApp(
        theme: NotesTheme.material(Brightness.light),
        darkTheme: NotesTheme.material(Brightness.dark),
        themeMode: brightness == Brightness.light
            ? ThemeMode.light : ThemeMode.dark,
        home: Builder(builder: (context) {
          resolved = NotesPalette.of(context);
          resolvedBrightness = Theme.of(context).brightness;
          return FTheme(
            data: NotesTheme.forPlatform(TargetPlatform.windows,
                brightness: resolvedBrightness),
            child: const Scaffold(body: Text('Tema')),
          );
        }),
      ));
      expect(resolvedBrightness, brightness);
      expect(resolved.background, palette.background);
      expect(resolved.secondaryText, palette.secondaryText);
      expect(Theme.of(tester.element(find.text('Tema')))
          .scaffoldBackgroundColor, palette.background);
      expect(FTheme.of(tester.element(find.text('Tema')))
          .colors.background, palette.background);
    });
  }

  testWidgets('appearance scope exposes selected mode', (tester) async {
    ThemeMode? changed;
    await tester.pumpWidget(MaterialApp(
      home: NotesAppearance(
        mode: ThemeMode.system,
        onChange: (mode) => changed = mode,
        child: Builder(builder: (context) => TextButton(
          onPressed: () => NotesAppearance.of(context)
              .onChange(ThemeMode.light),
          child: Text(NotesAppearance.of(context).mode.name),
        )),
      ),
    ));
    expect(find.text('system'), findsOneWidget);
    await tester.tap(find.text('system'));
    expect(changed, ThemeMode.light);
  });
}
