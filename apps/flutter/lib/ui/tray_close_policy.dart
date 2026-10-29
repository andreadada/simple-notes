/// An unsupported platform or a failed native tray must preserve the
/// operating system's normal window-close behavior.
enum TrayCloseAction { closeNormally, hideToTray }

abstract final class TrayClosePolicy {
  static TrayCloseAction resolve({
    required bool isWindows,
    required bool trayReady,
  }) => isWindows && trayReady
      ? TrayCloseAction.hideToTray
      : TrayCloseAction.closeNormally;
}
