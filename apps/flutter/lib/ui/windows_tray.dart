import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

/// The tray is owned only by the **main** Windows Flutter engine.
/// The detached Sticky engines return from main() before this is initialized.
abstract final class WindowsTray {
  static bool get supported => !kIsWeb && Platform.isWindows;
  static bool _active = false;
  static tray.TrayIcon? _icon;
  static _TrayWindowListener? _listener;

  static bool get available => supported && _active;

  /// Small blue checkmark icon, embedded as PNG to avoid Windows executable
  /// resource / external asset path differences between ZIP and MSIX.
  static const _iconBase64 =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAnklEQVR42u2XwQ2AIAxFwU10A91EB3UUR3AVPXkh4O8vYBPTXgiXvgeUEuI4r1cwjCEYhwu4gAv8W+A8djuBB44kYo9WXIJOy9Z/Bxj4Z0VYgjcXyK3+Dd5UQFLxagGUnD13SgBdpxo4FEiTozkLhwK5ROg4GLi4EUkLjIWLi1CTuPljhCS0klQfKEFqdohuRA8sHbUR/WPiAi5gLXADj3Y6axqUy2YAAAAASUVORK5CYII=';

  static Future<bool> initialize() async {
    if (!supported) return false;
    if (_active) return true;
    tray.TrayIcon? newIcon;
    try {
      await windowManager.ensureInitialized();
      newIcon = tray.TrayIcon.create();
      if (newIcon == null) return false;
      final image = tray.Image.fromBase64(_iconBase64);
      if (image == null) throw StateError('Icona tray non disponibile');
      newIcon.icon = image;
      newIcon.setTooltip('Simple Notes');

      final menu = tray.Menu.create();
      final open = tray.MenuItem.createWithLabelAndType(
          'Apri Simple Notes', tray.MenuItemType.normal);
      final quit = tray.MenuItem.createWithLabelAndType(
          'Esci da Simple Notes', tray.MenuItemType.normal);
      if (menu == null || open == null || quit == null) {
        throw StateError('Menu tray non disponibile');
      }
      open.addListener((event) {
        if (event is tray.MenuItemClickedEvent) unawaited(show());
      });
      quit.addListener((event) {
        if (event is tray.MenuItemClickedEvent) unawaited(exitApp());
      });
      menu.addItem(open);
      menu.addSeparator();
      menu.addItem(quit);
      newIcon.setContextMenu(menu);
      newIcon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      newIcon.addListener((event) {
        if (event is tray.TrayIconClickedEvent ||
            event is tray.TrayIconDoubleClickedEvent) {
          unawaited(show());
        }
      });
      if (!newIcon.setVisible(true)) {
        throw StateError('Tray icon non visibile');
      }
      final listener = _TrayWindowListener();
      windowManager.addListener(listener);
      await windowManager.setPreventClose(true);
      _listener = listener;
      _icon = newIcon;
      _active = true;
      return true;
    } catch (_) {
      // A failed plugin must never leave a user unable to close the app.
      if (_listener != null) windowManager.removeListener(_listener!);
      _listener = null;
      _active = false;
      _icon = null;
      newIcon?.dispose();
      try {
        await windowManager.setPreventClose(false);
      } catch (_) {}
      return false;
    }
  }

  static Future<bool> hide() async {
    if (!available) return false;
    try {
      await windowManager.hide();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> show() async {
    if (!available) return;
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> exitApp() async {
    if (!supported) return;
    if (_listener != null) windowManager.removeListener(_listener!);
    _listener = null;
    _active = false;
    final icon = _icon;
    _icon = null;
    await windowManager.setPreventClose(false);
    icon?.dispose();
    // The close button hides only while tray mode is enabled. This is a
    // genuine close request and does not delete local files or outbox.
    await windowManager.close();
  }
}

class _TrayWindowListener extends WindowListener {
  @override
  void onWindowClose() {
    if (WindowsTray.available) unawaited(WindowsTray.hide());
  }
}
