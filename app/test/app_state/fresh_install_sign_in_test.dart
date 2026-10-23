// iOS keeps a Firebase sign-in in the Keychain after the app is deleted, so a
// reinstall must not open on the last account.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/firebase_boot.dart';

void main() {
  test('a truly fresh install forgets a sign-in left from an earlier one', () {
    expect(
      FirebaseBoot.shouldForgetEarlierSignIn(
        installSeen: false,
        preferencesEmpty: true,
      ),
      isTrue,
    );
  });

  test('an update from an older build keeps her signed in', () {
    expect(
      FirebaseBoot.shouldForgetEarlierSignIn(
        installSeen: false,
        preferencesEmpty: false,
      ),
      isFalse,
    );
  });

  test('every later launch of the same install keeps her signed in', () {
    expect(
      FirebaseBoot.shouldForgetEarlierSignIn(
        installSeen: true,
        preferencesEmpty: false,
      ),
      isFalse,
    );
  });
}
