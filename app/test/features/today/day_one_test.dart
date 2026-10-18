// T06 — Today, on day one.
//
// The Home every other screen assumes she has already outgrown. The single most
// important thing to prove here is that it is a **state and not a route**
// (HANDOFF rule 16): the same widget, same route, choosing a different branch
// because nothing has been logged yet. If it were a separate destination,
// something could navigate to "Home, empty" over a Home that is not empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

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

// Distinct keys, so pumping one after the other builds a fresh State rather
// than reusing the first one's day.
TodayView _dayOne() => TodayView(
  key: const ValueKey('day-one'),
  repository: InMemoryTodayRepository(
    day: InMemoryTodayRepository.dayOne(date: _tuesday),
  ),
  now: _tuesday,
  onStartSession: () {},
  onOpenFirstWeek: () {},
  onTellUsWhatYouEat: () {},
  onOpenBeginnersGroup: () {},
  onSelectTab: (_) {},
);

TodayView _populated() => TodayView(
  key: const ValueKey('populated'),
  repository: InMemoryTodayRepository(
    day: InMemoryTodayRepository.defaultDay(date: _tuesday),
  ),
  now: _tuesday,
  onStartSession: () {},
  onRecall: () {},
  onOpenMeal: () {},
  onOpenWeek: () {},
  onOpenCycle: () {},
  onAsk: () {},
  onNotifications: () {},
  onSelectTab: (_) {},
);

void main() {
  // Day one offers the beginners group and counts the whole five-step arc.
  // Community owns two of those steps and Train and Eat own three, and a
  // step this build cannot offer is not counted. Stated, not inherited.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.today: true,
      Feature.firstWeek: true,
      Feature.quietWeek: true,
      Feature.tiers: true,
      Feature.lockScreenNudge: true,
      Feature.train: true,
      Feature.recordFromMemory: true,
      Feature.program: true,
      Feature.exerciseVideo: true,
      Feature.exerciseSwap: true,
      Feature.followAlong: true,
      Feature.workoutLibrary: true,
      Feature.trainingReminders: true,
      Feature.eat: true,
      Feature.recipes: true,
      Feature.weekPlan: true,
      Feature.groceryList: true,
      Feature.community: true,
      Feature.communityGroups: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('rule 16 — a state, not a route', () {
    test('day one is not a destination anything can navigate to', () {
      expect(firstRunStates, contains('T06'));
      expect(appDestinations.containsKey('T06'), isFalse);
      expect(screenIdForRoute(appRoutes['T06']!.name), isNull);
    });

    testWidgets('the same widget renders it, chosen by the data', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_dayOne()));
      await tester.pumpAndSettle();
      expect(find.text('Nothing added yet'), findsOneWidget);
      expect(find.text('Walk this morning · 32 min'), findsNothing);

      // Same TodayView, one log later.
      await tester.pumpWidget(_host(_populated()));
      await tester.pumpAndSettle();
      expect(find.text('Nothing added yet'), findsNothing);
      expect(find.text('Walk this morning · 32 min'), findsOneWidget);
    });
  });

  group('rule 17 — the empty state is the onboarding', () {
    testWidgets('it says what will appear, and offers the smallest start', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_dayOne()));
      await tester.pumpAndSettle();

      expect(find.text('Day 1'), findsOneWidget);

      // The cover says what the app is for. It used to name a programme —
      // "Beginner foundations" — and promise what was in today's session —
      // "Four moves on the floor. Nothing jumps." Both were fixed strings on
      // the one screen that renders before she has answered a single question
      // or been given a plan.
      expect(find.text('Your training, week by week'), findsOneWidget);
      expect(
        find.text(
          'This app counts weeks, not days, and only what you add yourself.',
        ),
        findsOneWidget,
      );
      expect(find.text('Beginner foundations'), findsNothing);
      expect(
        find.textContaining('Four moves on the floor'),
        findsNothing,
        reason: 'T06 is handed no plan, so it cannot say what is in one',
      );
      // Her three days are chosen in O04 and never reach this screen, so the
      // fixed "Monday, Tuesday, Thursday · 15 min" read the prototype's
      // schedule back to a woman who had just picked Saturday and Sunday.
      expect(find.text('Monday, Tuesday, Thursday · 15 min'), findsNothing);
      // One obvious thing to do.
      expect(find.text('Start day 1'), findsOneWidget);

      // What will appear here, and why it is empty.
      expect(find.text('Nothing added yet'), findsOneWidget);
      expect(find.textContaining('will sit here'), findsOneWidget);

      // The single smallest action that starts each empty surface. "Tell us
      // one thing you eat" went (§15): it was a second door to the meal step
      // the first-week row already asks for, one tab away.
      expect(find.text('Tell us one thing you eat'), findsNothing);
      // The optional rows fold behind one row when there are two or more.
      if (find.text('More you can do').evaluate().isNotEmpty) {
        await tester.tap(find.text('More you can do'));
        await tester.pumpAndSettle();
      }
      // The group has a name. Nothing in this app counts its members, so the
      // fixed "4,210 women in the beginners group" was a membership figure
      // frozen into the dictionary on her very first screen.
      expect(find.text('Beginners group'), findsOneWidget);
      expect(find.text('4,210 women in the beginners group'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the weekly rule is said once, before she can fail it', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_dayOne()));
      await tester.pumpAndSettle();

      // The rule, and never the number: she sets her own target in setup, and
      // this used to sit beside it saying three.
      expect(
        find.text(
          'Hit your goal and the week counts. If you miss a week, a rest week you\'ve earned covers it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Three sessions'), findsNothing);
    });

    testWidgets('the first-week arc is offered, and nothing expires', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_dayOne()));
      await tester.pumpAndSettle();

      expect(find.text('Your first week'), findsOneWidget);
      // The subtitle was "2 of 5 done · nothing expires" — a fixed string, on
      // the one screen that renders only while `arc.hasAnyLog` is false. It
      // told a woman with an empty arc that two of it were finished. It is
      // now counted off the arc; on day one that is none of five.
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.textContaining('2 of 5 done'), findsNothing);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_dayOne(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('يوم 1'), findsOneWidget);
    expect(find.text('تمرينك، أسبوع بأسبوع'), findsOneWidget);
    expect(find.text('لسه ماضفتيش حاجة'), findsOneWidget);
    expect(find.text('Your training, week by week'), findsNothing);
    expect(find.text('Nothing added yet'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_dayOne(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('day one has one Start and one way to log a meal', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_dayOne()));
    await tester.pumpAndSettle();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Start day 1'), findsOneWidget);
    expect(find.text('Log a meal'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-week-strip')), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'does not overflow at text scale 2.0 in ${locale.languageCode}',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(_dayOne(), locale: locale, textScale: 2.0),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
