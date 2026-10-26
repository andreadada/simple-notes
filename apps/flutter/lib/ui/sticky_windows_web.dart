import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web builds never import the desktop_multi_window Windows plugin or dart:io.
abstract final class StickyDesktop {
  static bool get supported => false;
  static Future<bool> launchSubwindowIfNeeded() async => false;
  static Future<void> open(WidgetRef ref, String noteId) async =>
      throw UnsupportedError('Sticky pop-out disponibile solo su Windows');
}
