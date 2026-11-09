import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/android_widget_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = AndroidWidgetNavigation.channel;
  const bridge = AndroidWidgetNavigation();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    bridge.dispose();
  });

  test('widget navigation only accepts three non-sensitive actions', () {
    expect(AndroidWidgetNavigation.accepted('today'), isTrue);
    expect(AndroidWidgetNavigation.accepted('inbox'), isTrue);
    expect(AndroidWidgetNavigation.accepted('new'), isTrue);
    expect(AndroidWidgetNavigation.accepted('restore'), isFalse);
    expect(AndroidWidgetNavigation.accepted('logout'), isFalse);
    expect(AndroidWidgetNavigation.accepted(null), isFalse);
  });

  test('a queued widget action navigates and invalid commands are ignored',
      () async {
    var pending = 'today';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'takePendingAction');
        final result = pending;
        pending = '';
        return result;
      });
    final received = <String>[];
    await bridge.listen((value) async { received.add(value); });
    expect(received, ['today']);
    pending = 'restore';
    await bridge.listen((value) async { received.add(value); });
    expect(received, ['today']);
  });

  test('desktop or missing native handler remains harmless', () async {
    final received = <String>[];
    await bridge.listen((value) async { received.add(value); });
    expect(received, isEmpty);
  });
}
