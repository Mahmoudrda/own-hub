// A03: turning the health backup off when the server refuses the call for a
// reason other than the network. "Removed when you are back online" is only
// true offline: a copy of the app App Check refuses is told to update, and a
// sign-in the server no longer accepts is told to sign in again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/account/presentation/privacy_view.dart';
import 'package:own_hub/features/signup/domain/review_request.dart';
import 'package:own_hub/l10n/app_l10n.dart';

class _RefusingStore implements HealthConsentStore {
  _RefusingStore(this.fail);
  final Object fail;

  @override
  Future<void> record({required bool granted}) async => throw fail;

  @override
  Future<HealthConsentState?> current(String uid) async => null;
}

Future<AppL10n> _turnOff(WidgetTester tester, Object failure) async {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final pref = HealthBackupPreference.instance..resetForTest();
  await pref.set(true);
  addTearDown(pref.resetForTest);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: PrivacyView(
        service: PrivacySettingsService(InMemoryPrivacyRepository()),
        healthBackup: HealthBackupController(store: _RefusingStore(failure)),
        onSignInAgain: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('health-backup-toggle')),
  );
  await tester.tap(find.byKey(const ValueKey('health-backup-toggle')));
  await tester.pumpAndSettle();
  // Turning it off deletes the account copy, so it is asked first.
  await tester.tap(find.byKey(const ValueKey('a03-backup-off')));
  await tester.pumpAndSettle();
  expect(pref.enabled, isFalse, reason: 'off on this phone whatever happens');
  return AppL10n.of(tester.element(find.byType(PrivacyView)));
}

void main() {
  testWidgets('App Check refused: update the app, not "back online"', (
    tester,
  ) async {
    final l10n = await _turnOff(
      tester,
      const VerificationCallFailure(
        'failed-precondition',
        ServerReason.appCheckMissing,
      ),
    );
    expect(find.text(l10n.healthBackupIsOffOnThisPhone_1x622), findsOneWidget);
    expect(find.text(l10n.healthBackupIsOffOnThisPhone), findsNothing);
  });

  testWidgets('sign-in rejected: sign in again, not "back online"', (
    tester,
  ) async {
    final l10n = await _turnOff(
      tester,
      const VerificationCallFailure('unauthenticated'),
    );
    expect(find.text(l10n.healthBackupIsOffOnThisPhone_1x3p3), findsOneWidget);
    expect(find.text(l10n.healthBackupIsOffOnThisPhone), findsNothing);
    expect(find.text(l10n.signInAgain), findsOneWidget);
  });

  testWidgets('offline keeps the "back online" wording', (tester) async {
    final l10n = await _turnOff(tester, StateError('offline'));
    expect(find.text(l10n.healthBackupIsOffOnThisPhone), findsOneWidget);
  });
}
