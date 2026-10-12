// R2: after account deletion, the whole-app gate is shut again.
//
// The wipe signed her out and left `_verifiedClaim` (and the phone's memory
// of her verification) standing, and the sheet then popped to the first
// route, which was Home. So for the rest of the session the product stayed
// open on a phone that no longer had an account. With an account required,
// deletion now ends on C01 with nothing underneath, and no product route
// resolves to itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/verification_memory.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/presentation/your_data_sheet.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/ui/app_button.dart';

/// Every feature on and an account required: the launch build.
FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

const _product = ['T01', 'R01', 'E01', 'P01', 'Y03'];

void _verified() {
  AppRouter.lastVerification = VerificationResult(
    method: VerificationMethod.automatic,
    decidedAt: DateTime.utc(2026, 10, 2),
    imagesDeletedAt: DateTime.utc(2026, 10, 2),
  );
  AppRouter.serverVerification = const ServerVerification(
    ServerVerificationState.approved,
  );
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppRouter.featureFlags = _gated;
    AppRouter.consentRecorded = true;
  });

  tearDown(() async {
    AppRouter.featureFlags = saved;
    AppRouter.consentRecorded = false;
    await AppRouter.forgetVerification();
  });

  test('the wipe zeroes every source of verification', () async {
    _verified();
    await VerificationMemory.rememberVerified('u1');
    AppRouter.markReviewAsked();
    expect(AppRouter.isVerified, isTrue);

    await deleteEverythingOnThisPhone();

    expect(AppRouter.isVerified, isFalse);
    expect(AppRouter.serverVerification, isNull);
    expect(AppRouter.reviewAsked, isFalse);
    expect(await VerificationMemory.verifiedUid(), isNull);
    for (final id in _product) {
      expect(
        AppRouter.verificationGate(id),
        appRoutes['C01']!.name,
        reason: '$id must be closed after deletion',
      );
    }
  });

  testWidgets('deleting from A02 ends on C01 with nothing underneath', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    _verified();
    // Setup already done, so Home is the first route and nothing is stacked.
    AppRouter.intakeRepository.markSetupDone();
    addTearDown(AppRouter.intakeRepository.reset);

    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(appDestinations['A02']!.name);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Your data').first);
    await tester.tap(find.text('Your data').first);
    await tester.pumpAndSettle();
    expect(find.byType(YourDataSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Delete everything'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeView), findsOneWidget);
    expect(find.byType(TodayView), findsNothing);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isFalse, reason: 'no product underneath');

    // And a deep link into the product meets the front door.
    navigator.pushNamed(appDestinations['R01']!.name);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeView), findsWidgets);
  });
}
