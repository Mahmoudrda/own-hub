// The walk page: say what logging does, run a clock, then report minutes and an
// estimate beside the one button that logs it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/walk_session_state.dart';
import 'package:own_hub/features/train/presentation/walk_session_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  final walk = WalkSessionState.instance;
  var clock = DateTime(2026, 10, 28, 9);
  final logged = <int>[];
  var closed = 0;

  DateTime now() => clock;
  void walkFor(int minutes) => clock = clock.add(Duration(minutes: minutes));

  Widget view({double? kg = 65, Locale locale = const Locale('en')}) => _host(
    WalkSessionView(
      state: walk,
      now: now,
      bodyWeightKg: kg,
      onLog: (seconds) async => logged.add(seconds),
      onClose: () => closed++,
    ),
    locale: locale,
  );

  setUp(() {
    walk.reset();
    clock = DateTime(2026, 10, 28, 9);
    logged.clear();
    closed = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });
  tearDown(walk.reset);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    // At the largest text the footer scrolls with the page.
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('says what logging does before she starts', (tester) async {
    await tester.pumpWidget(view());
    final l10n = AppL10n.of(tester.element(find.byType(WalkSessionView)));
    expect(find.text(l10n.walkAsLongAsYouLikeLog), findsOneWidget);
    expect(find.text(l10n.theCaloriesAreAnEstimateTheyNever), findsOneWidget);
    expect(find.byKey(const ValueKey('walk-start')), findsOneWidget);
    expect(walk.isWalking, isFalse);
  });

  testWidgets('a walk of any length: clock, pause, finish, log', (
    tester,
  ) async {
    await tester.pumpWidget(view());
    final l10n = AppL10n.of(tester.element(find.byType(WalkSessionView)));
    await tapKey(tester, 'walk-start');
    expect(walk.isWalking, isTrue);
    expect(find.text('0:00'), findsOneWidget);

    walkFor(30);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30:00'), findsOneWidget);

    // A pause holds the clock; Resume carries on.
    await tapKey(tester, 'walk-pause');
    expect(find.text(l10n.resume), findsOneWidget);
    walkFor(10);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30:00'), findsOneWidget);
    await tapKey(tester, 'walk-pause');
    walkFor(35);
    await tester.pump(const Duration(seconds: 1));
    // Over an hour reads h:mm:ss.
    expect(find.text('1:05:00'), findsOneWidget);

    await tapKey(tester, 'walk-finish');
    // 65 minutes at 65 kg, 3.0 MET: 211 kcal. The minutes, the estimate and
    // the sentence that says logging counts it.
    expect(find.text('211'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(find.text(l10n.caloriesBurnedEstimate), findsOneWidget);
    expect(find.text(l10n.loggingCountsItInYourWeekAnd), findsOneWidget);
    expect(find.byKey(const ValueKey('walk-typical-weight')), findsNothing);
    expect(logged, isEmpty, reason: 'nothing is logged by finishing');

    await tapKey(tester, 'walk-log');
    await tester.pump();
    expect(logged, [65 * 60]);
    expect(find.text(l10n.walkLogged), findsOneWidget);
    expect(walk.touched, isFalse);
    await tapKey(tester, 'walk-done');
    expect(closed, 1);
  });

  testWidgets('logging twice in a row logs once', (tester) async {
    await tester.pumpWidget(view());
    await tapKey(tester, 'walk-start');
    walkFor(20);
    await tapKey(tester, 'walk-finish');
    final log = find.byKey(const ValueKey('walk-log'));
    await tester.tap(log);
    await tester.tap(log, warnIfMissed: false);
    await tester.pump();
    expect(logged.length, 1);
  });

  testWidgets('"Don\'t log it" drops the walk and records nothing', (
    tester,
  ) async {
    await tester.pumpWidget(view());
    await tapKey(tester, 'walk-start');
    walkFor(20);
    await tapKey(tester, 'walk-finish');
    await tapKey(tester, 'walk-drop');
    expect(logged, isEmpty);
    expect(walk.touched, isFalse);
    expect(closed, 1);
  });

  testWidgets('under a minute there is nothing to log', (tester) async {
    await tester.pumpWidget(view());
    final l10n = AppL10n.of(tester.element(find.byType(WalkSessionView)));
    await tapKey(tester, 'walk-start');
    clock = clock.add(const Duration(seconds: 40));
    await tapKey(tester, 'walk-finish');
    expect(find.text(l10n.thatWasUnderAMinuteSoThere), findsOneWidget);
    expect(find.byKey(const ValueKey('walk-log')), findsNothing);
    await tapKey(tester, 'walk-discard');
    expect(logged, isEmpty);
    expect(walk.touched, isFalse);
  });

  testWidgets('a walk left running overnight is logged at three hours', (
    tester,
  ) async {
    await tester.pumpWidget(view());
    await tapKey(tester, 'walk-start');
    walkFor(12 * 60);
    await tapKey(tester, 'walk-finish');
    await tapKey(tester, 'walk-log');
    await tester.pump();
    expect(logged, [3 * 3600]);
  });

  testWidgets('says so when the weight is a typical one', (tester) async {
    await tester.pumpWidget(view(kg: null));
    final l10n = AppL10n.of(tester.element(find.byType(WalkSessionView)));
    await tapKey(tester, 'walk-start');
    walkFor(30);
    await tapKey(tester, 'walk-finish');
    expect(find.text(l10n.workedOutWithATypicalWeightAdd), findsOneWidget);
    // 30 minutes at the typical 65 kg.
    expect(find.text('98'), findsOneWidget);
  });

  testWidgets('a walk finished and not logged is there when she comes back', (
    tester,
  ) async {
    walk.start(clock);
    walk.finish(clock.add(const Duration(minutes: 45)));
    await tester.pumpWidget(view());
    expect(find.byKey(const ValueKey('walk-log')), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final size in const [Size(390, 844), Size(375, 667)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          '${locale.languageCode} ${size.width.toInt()}x${size.height.toInt()}'
          ' text x$scale: every state fits, one filled button',
          (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearAllTestValues);

            void fits(String state) {
              expect(tester.takeException(), isNull, reason: state);
              expect(
                countControlsAboveFold(tester, includeChrome: false),
                lessThanOrEqualTo(5),
                reason: state,
              );
              expect(filledPrimaryActions(tester), 1, reason: state);
            }

            await tester.pumpWidget(view(locale: locale));
            final l10n = AppL10n.of(
              tester.element(find.byType(WalkSessionView)),
            );
            fits('ready');
            expect(find.text(l10n.startWalking), findsOneWidget);
            await tapKey(tester, 'walk-start');
            walkFor(31);
            await tester.pump(const Duration(seconds: 1));
            fits('walking');
            await tapKey(tester, 'walk-finish');
            fits('finished');
            expect(find.text(l10n.logThisWalk), findsOneWidget);
            await tapKey(tester, 'walk-log');
            await tester.pump();
            fits('logged');
          },
        );
      }
    }
  }

  test('never reaches into what she eats', () {
    for (final path in const [
      'lib/features/train/presentation/walk_session_view.dart',
      'lib/app_state/walk_session_state.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final banned in const [
        'features/eat',
        'domain/nutrition',
        'target_safety',
        'daily_targets',
      ]) {
        expect(
          source,
          isNot(contains(banned)),
          reason: '$path imports $banned',
        );
      }
    }
  });

  test('its words never speak of eating back, a net or a deficit', () {
    final en = lookupAppL10n(const Locale('en'));
    final words = [
      en.walkAsLongAsYouLikeLog,
      en.theCaloriesAreAnEstimateTheyNever,
      en.caloriesBurnedEstimate,
      en.loggingCountsItInYourWeekAnd,
      en.logItToCountTheCaloriesYou,
      en.workedOutWithATypicalWeightAdd,
    ].join(' ').toLowerCase();
    for (final banned in const [
      'deficit',
      'net ',
      'eat back',
      'eat more',
      'allowance',
      'remaining',
      'budget',
      'earned',
    ]) {
      expect(words, isNot(contains(banned)), reason: banned);
    }
  });
}
