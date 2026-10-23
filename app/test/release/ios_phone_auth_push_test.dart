// L2-8: Firebase phone auth on iOS verifies the app with a silent push and
// falls back to a reCAPTCHA web view. The push needs the aps-environment
// entitlement and the remote-notification background mode; the fallback needs
// the REVERSED_CLIENT_ID URL scheme. The APNs key itself is uploaded to
// Firebase by the owner.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _plistValue(String plist, String key) {
  final match = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
      .firstMatch(plist);
  return match?.group(1) ?? '';
}

void main() {
  final info = File('ios/Runner/Info.plist').readAsStringSync();
  final entitlements = File('ios/Runner/Runner.entitlements')
      .readAsStringSync();

  test('the app can receive a silent push', () {
    expect(_plistValue(entitlements, 'aps-environment'), isNotEmpty);
    expect(
      RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>[\s\S]*?'
        r'<string>remote-notification</string>[\s\S]*?</array>',
      ).hasMatch(info),
      isTrue,
    );
  });

  test('the reCAPTCHA fallback still has its URL scheme', () {
    final google = File('ios/Runner/GoogleService-Info.plist')
        .readAsStringSync();
    final reversed = _plistValue(google, 'REVERSED_CLIENT_ID');
    expect(reversed, isNotEmpty);
    expect(info, contains('<string>$reversed</string>'));
  });
}
