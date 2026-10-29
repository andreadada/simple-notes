import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/tray_close_policy.dart';

void main() {
  test('Windows only hides after tray is registered successfully', () {
    expect(TrayClosePolicy.resolve(isWindows: true, trayReady: true),
        TrayCloseAction.hideToTray);
    expect(TrayClosePolicy.resolve(isWindows: true, trayReady: false),
        TrayCloseAction.closeNormally);
  });

  test('Android, web, Linux and detached engines do not intercept close', () {
    for (final ready in [true, false]) {
      expect(TrayClosePolicy.resolve(isWindows: false, trayReady: ready),
          TrayCloseAction.closeNormally);
    }
  });
}
