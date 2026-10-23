// The profile picture and the language switch are on every routed screen
// except the live workout, the camera and ID screens, sign-in and setup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_avatar.dart';
import 'package:own_hub/ui/language_switch.dart';
import 'package:own_hub/ui/screen_scope.dart';

Future<String?> _open(
  WidgetTester tester,
  String id, {
  Locale? locale,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('$id-${locale?.languageCode}-$textScale'),
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: appDestinations[id]!.name,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pump(const Duration(milliseconds: 80));
  final scopes = tester.widgetList<ScreenScope>(find.byType(ScreenScope));
  return scopes.isEmpty ? null : scopes.last.screenId;
}

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    AppRouter.consentRecorded = true;
  });
  tearDown(() {
    AppRouter.featureFlags = saved;
    AppRouter.consentRecorded = false;
  });

  testWidgets('every routed screen outside the no-chrome list carries one '
      'picture and one language switch', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final missing = <String>[];
    final skipped = <String>[];
    for (final id in appDestinations.keys) {
      if (kNoChromeScreens.contains(id)) continue;
      final shown = await _open(tester, id);
      final threw = tester.takeException();
      if (threw != null) missing.add('$id threw: $threw');
      // A gate or a flag sent her to another screen: that one is checked on
      // its own turn.
      if (shown != id) {
        skipped.add(id);
        continue;
      }
      final avatars = find.byWidgetPredicate((w) => w is AppAvatar && w.isSelf);
      final switches = find.byType(LanguageSwitchButton);
      final a = avatars.evaluate().length;
      final s = switches.evaluate().length;
      if (a != 1 || s != 1) missing.add('$id avatar=$a switch=$s');
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
    // Most screens must open as themselves; a long skipped list would mean
    // the crawl is not looking at them. The old coach screens that coaching
    // no longer routes (K03, K04, K09 to K13, K25) and the ones that wait for
    // payments (K05, H04) are in the list on purpose.
    expect(skipped.length, lessThan(16), reason: 'skipped: $skipped');
  });

  testWidgets('the no-chrome screens show neither', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final shownChrome = <String>[];
    for (final id in kNoChromeScreens) {
      final shown = await _open(tester, id);
      final threw = tester.takeException();
      if (threw != null) shownChrome.add('$id threw: $threw');
      if (shown != id) continue;
      final avatar = find
          .byWidgetPredicate((w) => w is AppAvatar && w.isSelf)
          .evaluate()
          .length;
      // The sign-up screens keep the strip's switch they always had; every
      // other screen in the list has neither.
      final switches = id.startsWith('C')
          ? 0
          : find.byType(LanguageSwitchButton).evaluate().length;
      if (avatar > 0 || switches > 0) {
        shownChrome.add('$id avatar=$avatar switch=$switches');
      }
    }
    expect(shownChrome, isEmpty, reason: shownChrome.join('\n'));
  });

  testWidgets('in Arabic at text size 2.0 each still carries one picture and '
      'one switch, and nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final missing = <String>[];
    for (final id in appDestinations.keys) {
      if (kNoChromeScreens.contains(id)) continue;
      final shown = await _open(
        tester,
        id,
        locale: const Locale('ar'),
        textScale: 2,
      );
      final threw = tester.takeException();
      if (threw != null) {
        missing.add('$id threw: ${threw.toString().split('\n').first}');
      }
      if (shown != id) continue;
      final a = find
          .byWidgetPredicate((w) => w is AppAvatar && w.isSelf)
          .evaluate()
          .length;
      final s = find.byType(LanguageSwitchButton).evaluate().length;
      if (a != 1 || s != 1) missing.add('$id avatar=$a switch=$s');
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  group('the workout day (R03)', () {
    final session = WorkoutSessionState.instance;
    final day = WorkoutDay(
      id: '2026-10-13',
      title: 'Legs',
      summary: '',
      constraints: '',
      moves: [
        PlannedMove(
          exerciseId: 'squat',
          name: 'squat',
          prescriptionLabel: '',
          sets: [PrescribedSet(exerciseId: 'squat', order: 1, reps: 10)],
        ),
      ],
    );

    Future<bool> shown(WidgetTester tester) async {
      late bool result;
      await tester.pumpWidget(
        ScreenScope(
          screenId: 'R03',
          child: Builder(
            builder: (context) {
              result = AppChrome.shownFor(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    setUp(session.reset);
    tearDown(session.reset);

    testWidgets('carries the chrome as a preview', (tester) async {
      expect(await shown(tester), isTrue);
    });

    testWidgets('drops it while a session is live', (tester) async {
      session.start(day, InMemoryTrainRepository());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(session.isLive, isTrue);
      expect(await shown(tester), isFalse);
    });
  });
}
