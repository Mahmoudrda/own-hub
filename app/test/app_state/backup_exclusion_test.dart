import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/backup_exclusion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ownhub.app/files');
  final calls = <MethodCall>[];

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    calls.clear();
  });

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  test('on iOS the folder is handed to the Runner to exclude', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer((_) async => true);
    await excludeFromBackup('/data/payments-pending');
    expect(calls.single.method, 'excludeFromBackup');
    expect(calls.single.arguments, '/data/payments-pending');
  });

  test('a phone that refuses changes nothing and throws nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer((_) async => throw PlatformException(code: 'no'));
    await excludeFromBackup('/data/payments-pending');
    expect(calls, hasLength(1));
  });

  test('Android makes no call: its backup is already off', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((_) async => true);
    await excludeFromBackup('/data/payments-pending');
    expect(calls, isEmpty);
  });
}
