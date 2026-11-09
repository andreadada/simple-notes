import 'package:flutter/services.dart';

/// Launcher widget intent: navigation only. No task contents, account data,
/// authentication or restore decisions may cross this channel.
class AndroidWidgetNavigation {
  const AndroidWidgetNavigation();

  static const MethodChannel channel =
      MethodChannel('it.andreadada.simplenotes/widget');

  static bool accepted(String? value) =>
      const {'today', 'inbox', 'new'}.contains(value);

  Future<void> listen(Future<void> Function(String) navigate) async {
    channel.setMethodCallHandler((call) async {
      final action = call.arguments;
      if (call.method == 'widgetAction' &&
          action is String && accepted(action)) {
        await navigate(action);
      }
    });
    try {
      final pending = await channel.invokeMethod<String>('takePendingAction');
      if (accepted(pending)) await navigate(pending!);
    } on MissingPluginException {
      // On desktop, during tests or if native code is not registered.
    }
  }

  void dispose() {
    channel.setMethodCallHandler(null);
  }
}
