/// Web and other platforms never load a native tray/window library.
/// This is an inert facade for Flutter Web compilation.
abstract final class WindowsTray {
  static bool get supported => false;
  static bool get available => false;
  static Future<bool> initialize() async => false;
  static Future<bool> hide() async => false;
  static Future<void> show() async {}
  static Future<void> exitApp() async {}
}
