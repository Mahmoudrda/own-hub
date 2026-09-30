// T07 — Your first week.
//
// HANDOFF rule 17 and `P0-FR-02`: no timer, no expiry, no failure state. The
// arc's steps simply wait. `DECISIONS.md` D1 also makes the step count
// load-bearing — all five ship, including the two that belong to Community —
// because an arc that quietly became three steps would leave T08 unreachable
// while looking finished.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/first_week_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_ring_stat.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        // copyWith, not a bare MediaQueryData: a fresh one zeroes the window
        // size, so any widget that measures itself against the screen lays out
        // to nothing here while working perfectly in production.
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

FirstWeekView _view({
  TodayRepository? repository,
  ValueChanged<String>? onOpenStep,
  // Stated by the caller, because the widget no longer states them for it. The
  // defaults were 90 and 2 — the prototype's — and the router passed neither,
  // so T07 and T08 told every woman she had 90 points. See the case below.
  int points = 90,
  int level = 2,
}) {
  return FirstWeekView(
    points: points,
    level: level,
    // The prototype's day, asked for by name. `InMemoryTodayRepository()` now
    // starts on day one — an empty arc with today's date — because that is what
    // a fresh install must get; these cases are about an arc part way through,
    // so they state the day they mean.
    repository:
        repository ??
        InMemoryTodayRepository(day: InMemoryTodayRepository.defaultDay()),
    onClose: () {},
    onStartSession: () {},
    onOpenStep: onOpenStep ?? (_) {},
    onBackToToday: () {},
    onSeeProgress: () {},
  );
}

void main() {
  // T07 draws the two Community steps, so it needs Community on. Its other
  // three lead into Train and Eat, and a step whose destination is dark is
  // not drawn, so those are named too. The first release ships without
  // Community and the arc is three steps there — the case below, and
  // `release_readiness_test.dart`.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.today: true,
      Feature.train: true,
      Feature.eat: true,
      Feature.community: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('five concrete first actions', () {
    testWidgets('all five are listed, in order', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Your first week'), findsOneWidget);
      for (final step in [
        'Log one set',
        'Log one meal',
        'Finish one session',
        'Join one group',
        'Add a follow-up picture',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the two Community steps are kept, not dropped', (
      tester,
    ) async {
      // D1 withdrew the MVP cut. Community is not built yet, so these route
      // onward and land on the router's "not built yet" page — visible rather
      // than silently missing.
      _phone(tester);
      final opened = <String>[];
      await tester.pumpWidget(_host(_view(onOpenStep: opened.add)));
      await tester.pumpAndSettle();

      for (final step in ['Join one group', 'Add a follow-up picture']) {
        await tester.ensureVisible(find.text(step));
        await tester.pumpAndSettle();
        await tester.tap(find.text(step));
        await tester.pumpAndSettle();
      }

      expect(opened, ['M04', 'M11']);
    });

    testWidgets('progress is two of five, from the arc', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      final ring = tester.widget<AppRingStat>(find.byType(AppRingStat));
      expect(ring.big, '2');
      expect(ring.small, 'of 5');
      expect(ring.fraction, 2 / 5);
      // Counted, not stated: `twoDoneThreeWaiting` was fixed copy sitting
      // above two live numbers, so it read "Two done, three waiting" to a
      // woman who had done none.
      expect(find.text('2 done, 3 waiting'), findsOneWidget);
      expect(find.text('done'), findsNWidgets(2));
    });

    testWidgets('and the arc is only as long as this build can offer', (
      tester,
    ) async {
      // The first release ships with Community dark. The two Community steps
      // are not drawn, and — the part that matters — they are not counted
      // either: an arc of three that still asked for five would leave her at
      // "2 of 5" forever with nothing left to tap.
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.train: true,
        Feature.eat: true,
      });
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.text('Join one group'), findsNothing);
      expect(find.text('Add a follow-up picture'), findsNothing);

      final ring = tester.widget<AppRingStat>(find.byType(AppRingStat));
      expect(ring.big, '2');
      expect(ring.small, 'of 3');
      expect(ring.fraction, 2 / 3);
      expect(find.text('2 done, 1 waiting'), findsOneWidget);
    });
  });

  group('rule 17 — nothing expires, and nothing can fail', () {
    test('there is no failed state to construct', () {
      // The absence is the enforcement: a step can only be done, current or
      // waiting, so a failure indicator is not expressible here.
      expect(ArcStepState.values, [
        ArcStepState.done,
        ArcStepState.now,
        ArcStepState.waiting,
      ]);
      expect(
        ArcStepState.values.map((s) => s.name),
        isNot(anyElement(anyOf('failed', 'expired', 'missed'))),
      );
    });

    testWidgets('and the screen says so out loud', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No timer on any of them. Miss a day and nothing here changes.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('is not a deadline'), findsOneWidget);
    });

    testWidgets('the reward is the points the app already gives', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      // "35 points so far" was a fixed string sitting two lines from
      // `widget.points`, the real figure. Label and value now, the same shape
      // T08 uses.
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('35 points so far'), findsNothing);
      expect(
        find.textContaining('Nothing extra for opening it.'),
        findsOneWidget,
      );
    });

    testWidgets('and an unwired screen states a new woman, not the mockup', (
      tester,
    ) async {
      // The defaults were the prototype's 90 and 2, and `app_router.dart` built
      // T07 and T08 and passed neither: every woman opening her first week was
      // told she had 90 points and was level 2 before she had logged anything.
      // The label three lines above had already been fixed for exactly this
      // reason and the number was left.
      //
      // The router wires both from `progressStore.rewards` now. This asserts
      // the other half: what a caller that forgets gets is a woman who has done
      // nothing, which is who is holding the phone when a wiring is missed.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          FirstWeekView(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(),
            ),
            onClose: () {},
            onStartSession: () {},
            onOpenStep: (_) {},
            onBackToToday: () {},
            onSeeProgress: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Points'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(
        find.text('90'),
        findsNothing,
        reason: 'the mockup had 90 points; a woman on a fresh install has none',
      );
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('أسبوعك الأول'), findsOneWidget);
    expect(find.text('سجّلي مجموعة واحدة'), findsOneWidget);
    expect(find.text('انضمّي إلى مجموعة واحدة'), findsOneWidget);
    expect(find.text('Log one set'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_view(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
