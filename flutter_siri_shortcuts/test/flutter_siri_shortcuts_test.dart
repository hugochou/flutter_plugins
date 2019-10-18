import 'package:flutter/services.dart';
import 'package:flutter_siri_shortcuts/flutter_siri_shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_siri_shortcuts');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await FlutterSiriShortcuts.setShotcut, '42');
  });
}
