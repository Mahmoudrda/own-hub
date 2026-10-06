// R1-P7: the community's rules come before the community.
//
// With the community on, a woman who has not agreed to "How we treat each
// other" is shown the rules where the feed would be, and the feed once she
// agrees. Her agreement is kept on this phone (and survives a restart through
// the snapshot) and sent to the server's `record_pledge` when she is signed
// in. With the community off nothing asks for it: "Start day 1" is the
// primary on C13 and the pledge is not offered.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/pledge.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/presentation/feed_view.dart';
import 'package:own_hub/features/signup/presentation/pledge_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

class _Recording implements PledgeStore {
  final List<String> locales = <String>[];

  @override
  Future<void> record({required String locale}) async => locales.add(locale);
}

Future<void> _open(WidgetTester tester, String id) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(id),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: appRoutes[id]!.name,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    PledgeState.instance.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    PledgeState.instance.reset();
    AppRouter.pledgeStore = null;
  });

  testWidgets('the first feed waits for the rules, then opens', (
    tester,
  ) async {
    await _open(tester, 'M01');
    expect(find.byType(PledgeView), findsOneWidget);
    expect(find.byType(FeedView), findsNothing);

    await tester.tap(find.text('I agree, let me in'));
    await tester.pumpAndSettle();

    expect(PledgeState.instance.agreed, isTrue);
    expect(PledgeState.instance.agreedVersion, kPledgeVersion);
    expect(find.byType(FeedView), findsOneWidget);
    expect(find.byType(PledgeView), findsNothing);
  });

  testWidgets('agreed once, the feed opens straight away', (tester) async {
    PledgeState.instance.agree();
    await _open(tester, 'M01');
    expect(find.byType(FeedView), findsOneWidget);
    expect(find.byType(PledgeView), findsNothing);
  });

  test('her agreement survives a restart', () {
    PledgeState.instance.agree(at: DateTime.utc(2026, 10, 6, 9));
    final saved = jsonEncode(AppSnapshot.capture());
    PledgeState.instance.reset();
    AppSnapshot.restore(saved);
    expect(PledgeState.instance.agreed, isTrue);
    expect(PledgeState.instance.agreedAt, DateTime.utc(2026, 10, 6, 9));
  });

  test('a new version of the rules is asked again', () {
    PledgeState.instance.agreedVersion = kPledgeVersion - 1;
    expect(PledgeState.instance.agreed, isFalse);
  });

  test('the server record is the contract body', () {
    expect(pledgePayload(locale: 'ar', appVersion: '1.0.0+1'), {
      'version': kPledgeVersion,
      'locale': 'ar',
      'appVersion': '1.0.0+1',
    });
    expect(kRecordPledgeCallable, 'record_pledge');
  });

  testWidgets('signed out, nothing is sent', (tester) async {
    final recording = _Recording();
    AppRouter.pledgeStore = recording;
    await _open(tester, 'M01');
    await tester.tap(find.text('I agree, let me in'));
    await tester.pumpAndSettle();
    expect(recording.locales, isEmpty);
  });
}
