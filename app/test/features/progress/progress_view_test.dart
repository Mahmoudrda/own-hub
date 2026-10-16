// P01 — Your progress.
//
// The assertions that matter here are the NEGATIVE ones. Nine Phase 1 cases
// finish on this screen, and the defect PHASE1-QA-VERDICT calls blocking is a
// screen stating the prototype's numbers as her personal facts. So the first
// group builds a woman who is nothing like the mockup's and asserts that every
// one of the mockup's figures is ABSENT — a test a hardcoded constant fails.
//
// The second group then builds the mockup's own woman and asserts the same
// figures ARE present, which is what distinguishes "computed" from "deleted".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/progress/domain/milestone.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';

import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/presentation/progress_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';
import 'package:own_hub/features/progress/presentation/progress_widgets.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';
import 'package:own_hub/ui/app_week_segments.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

WeekBar _bar(int i, {required bool counted, bool repaired = false}) => WeekBar(
  week: WeekKey.tryParse('2026-W${(30 + i).toString().padLeft(2, '0')}')!,
  sessionsLogged: counted ? 2 : 0,
  sessionsTarget: 2,
  counted: counted,
  repairedByRestWeek: repaired,
);

/// A woman who is nothing like the prototype's: nine counted weeks, a best run
/// of five, level 3, four bests, a two-session week with one logged.
ProgressSummary _hers({
  int countedWeeks = 9,
  int bestRun = 5,
  int points = 235,
  int bestsCount = 4,
  int restWeeksBanked = 0,
  int milestonesEarned = 2,
  int milestoneCount = 7,
  List<WeekBar>? recent8,
  TierLadder ladder = TierLadder.unauthored,
}) {
  return ProgressSummary.from(
    goal: WeeklyGoal(
      sessionsTarget: 2,
      countedWeeks: countedWeeks,
      restWeeksBanked: restWeeksBanked,
      currentRun: 3,
      bestRun: bestRun,
      recent8: recent8 ?? [_bar(0, counted: true), _bar(1, counted: false)],
    ),
    rewards: Rewards(
      points: points,
      bestsCount: bestsCount,
      milestones: {
        for (var i = 0; i < milestonesEarned; i++) 'm$i': DateTime(2026, 6, 3),
      },
    ),
    currentWeek: WeekDoc(
      week: WeekKey.tryParse('2026-W38')!,
      sessionsTarget: 2,
      creditedSessionIds: const ['a'],
    ),
    ladder: ladder,
    milestoneCount: milestoneCount,
  );
}

Widget _view(ProgressSummary summary) => ProgressView(
  summary: summary,
  onBack: () {},
  onOpenMilestones: () {},
  onOpenBests: () {},
  onOpenBody: () {},
  onOpenFirstWeek: () {},
  onOpenRestWeek: () {},
  onOpenTierSlip: () {},
  onSelectTab: (_) {},
);

/// Every string rendered anywhere in the tree.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  group('it states her figures, never the prototype\'s', () {
    testWidgets('the week line and the segments come from the same numbers', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers())));
      await tester.pumpAndSettle();

      expect(find.text('This week, 1 of 2'), findsOneWidget);
      expect(
        find.text('This week, 2 of 3'),
        findsNothing,
        reason: "the mockup's week",
      );

      // The bar is built from the same two integers as the sentence, so the
      // two cannot disagree — the defect PHASE1-FIXES.md §13 fixed on T01.
      final segments = tester.widget<AppWeekSegments>(
        find.byType(AppWeekSegments),
      );
      expect(segments.total, 2);
      expect(segments.filled, 1);
    });

    testWidgets('none of the mockup\'s numbers appears for a different woman', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers())));
      await tester.pumpAndSettle();

      for (final mockup in [
        '14 weeks counted · best run 9',
        'Level 7',
        'Regular',
        'Regular holds while four of your last eight weeks count. Six did.',
        'Next: Strong',
        '14 of 20',
        '8 of 10',
        '4 of 12',
        '8 so far',
        '1 saved',
      ]) {
        expect(
          find.text(mockup),
          findsNothing,
          reason:
              '"$mockup" is the prototype\'s figure. Rendering it to a woman '
              'with nine counted weeks and four bests is the defect '
              'PHASE1-QA-VERDICT calls blocking.',
        );
      }
    });

    testWidgets('the same screen DOES state them for the woman they describe', (
      tester,
    ) async {
      // The other half of the control. If the figures above were simply deleted
      // rather than computed, this test fails too.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            _hers(
              countedWeeks: 14,
              bestRun: 9,
              points: 490, // level 7
              bestsCount: 8,
              restWeeksBanked: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14 weeks counted · best run 9'), findsOneWidget);
      expect(find.text('Level 7'), findsOneWidget);
      expect(find.text('8 so far'), findsOneWidget);
      expect(find.text('1 saved'), findsOneWidget);
    });

    testWidgets('the level pill is hers, whatever her level is', (
      tester,
    ) async {
      // `levelN` replaces the fixed `level7`, which announced level 7 to a
      // woman on level 3. Her level is now stated rather than withheld.
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers(points: 235))));
      await tester.pumpAndSettle();

      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('Level 7'), findsNothing);

      // A woman with nothing at all is level 1, and is told so.
      await tester.pumpWidget(_host(_view(_hers(points: 0))));
      await tester.pumpAndSettle();
      expect(find.text('Level 1'), findsOneWidget);
    });

    testWidgets('the milestones tile counts her earned against the list', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(milestonesEarned: 2, milestoneCount: 8))),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 of 8'), findsOneWidget);
      expect(find.text('4 of 12'), findsNothing, reason: "the mockup's");
    });

    testWidgets('an empty catalogue means no figure, not "2 of 0"', (
      tester,
    ) async {
      // The state P01 is wired in today: app_router.dart passes
      // MilestoneCatalogue.unauthored.count, which is zero.
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(milestonesEarned: 2, milestoneCount: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 of 0'), findsNothing);
      expect(find.text('Milestones'), findsOneWidget);
    });

    testWidgets('the rest-week legend appears only with a pale bar', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers())));
      await tester.pumpAndSettle();
      expect(
        find.text('Last eight weeks · the pale one was a rest week'),
        findsNothing,
      );

      await tester.pumpWidget(
        _host(
          _view(
            _hers(
              recent8: [
                _bar(0, counted: true),
                _bar(1, counted: true, repaired: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Last eight weeks · the pale one was a rest week'),
        findsOneWidget,
      );
    });
  });

  group('D6 — P01 ships no authoritative tier number', () {
    testWidgets('with no ladder authored, every tier surface is absent', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(countedWeeks: 14, bestRun: 9, points: 490))),
      );
      await tester.pumpAndSettle();

      // Even for the mockup's own woman, the tier says nothing — because no
      // threshold has been written into DECISIONS.md.
      expect(find.text('Regular'), findsNothing);
      expect(find.text('Next: Strong'), findsNothing);
      expect(find.text('14 of 20'), findsNothing);
      expect(find.text('8 of 10'), findsNothing);
      expect(find.text('about 6 weeks away'), findsNothing);

      // And the amber next-tier card is not drawn at all.
      final cards = tester.widgetList<AppCard>(find.byType(AppCard));
      expect(cards.where((c) => c.variant == AppCardVariant.amber), isEmpty);
    });

    testWidgets('given a ladder, the tier renders from her real standing', (
      tester,
    ) async {
      // Proves the absence above is D6 and not a missing feature.
      const ladder = TierLadder(<TierRung>[
        TierRung(
          tier: Tier.showingUp,
          countedWeeks: 1,
          bestsCount: 0,
          recencyFloor: 0,
        ),
        TierRung(
          tier: Tier.regular,
          countedWeeks: 5,
          bestsCount: 2,
          recencyFloor: 1,
        ),
      ]);

      _phone(tester);
      await tester.pumpWidget(
        _host(
          _view(
            _hers(
              countedWeeks: 9,
              recent8: [
                _bar(0, counted: true),
                _bar(1, counted: true),
                _bar(2, counted: true),
                _bar(3, counted: true),
                _bar(4, counted: true),
                _bar(5, counted: true),
              ],
              ladder: ladder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Regular'), findsOneWidget);
      expect(
        find.text(
          'Regular holds while four of your last eight weeks count. Six did.',
        ),
        findsOneWidget,
        reason: 'she really does have six counted weeks in the window',
      );
    });
  });

  group('the tier names exist now; the ladder still does not', () {
    /// A ladder whose thresholds are nothing like the ones G6 infers, so a
    /// screen reciting an inferred table would fail here.
    const ladder = TierLadder(<TierRung>[
      TierRung(
        tier: Tier.showingUp,
        countedWeeks: 1,
        bestsCount: 0,
        recencyFloor: 0,
      ),
      TierRung(
        tier: Tier.strong,
        countedWeeks: 7,
        bestsCount: 3,
        recencyFloor: 0,
      ),
      TierRung(
        tier: Tier.unshakeable,
        countedWeeks: 30,
        bestsCount: 25,
        recencyFloor: 0,
      ),
    ]);

    testWidgets('a tier that had no name in the dictionary can be named', (
      tester,
    ) async {
      // "Strong" and "Unshakeable" were absent from both languages, so even an
      // authored ladder could not have named them. They exist now. This proves
      // the minting; it does not make the ladder authoritative.
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(countedWeeks: 9, bestsCount: 4, ladder: ladder))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Strong'), findsOneWidget);
      expect(find.text('Regular'), findsNothing);
    });

    testWidgets('the next-tier bars state her own ratio', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(countedWeeks: 9, bestsCount: 4, ladder: ladder))),
      );
      await tester.pumpAndSettle();

      // Next is Unshakeable at 30 counted weeks and 25 bests.
      expect(find.text('9 of 30'), findsOneWidget);
      expect(find.text('4 of 25'), findsOneWidget);
      expect(find.text('14 of 20'), findsNothing, reason: "the mockup's");
      expect(find.text('8 of 10'), findsNothing, reason: "the mockup's");
    });

    testWidgets('with the shipped ladder, no tier is named for anybody', (
      tester,
    ) async {
      // The app supplies TierLadder.unauthored, so every one of the five names
      // stays off the screen however steady she has been.
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers(countedWeeks: 40, bestsCount: 30))),
      );
      await tester.pumpAndSettle();

      for (final name in [
        'First steps',
        'Showing up',
        'Regular',
        'Strong',
        'Unshakeable',
      ]) {
        expect(
          find.text(name),
          findsNothing,
          reason:
              'D6: until the thresholds are written down, no tier number is '
              'authoritative — and a name is a claim about a number',
        );
      }
    });
  });

  group('P1-RULE-03 — weeks, not days', () {
    testWidgets('no streak, no day count and no deficit anywhere', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers())));
      await tester.pumpAndSettle();

      // Streak language must not reach the screen in any form.
      for (final banned in [
        'streak',
        'day in a row',
        'days in a row',
        'consecutive',
      ]) {
        expect(
          find.textContaining(banned, skipOffstage: false),
          findsNothing,
          reason: 'rule 3: the week is the only unit',
        );
      }

      // "Missed" is a different case, and the distinction IS the rule.
      // P0-WEEK-02 forbids "a count of what was missed" — a figure attached to
      // it. It does not forbid the word in the sentence that explains the
      // repair: P01's "A missed week, repaired without asking" is the row that
      // leads to T04, and it is the product telling her the sting was removed.
      // Banning the word outright would delete that sentence and teach the next
      // person that rule 3 is about vocabulary rather than about counters.
      final countOfMissed = RegExp(
        r'\d+\s*\w*\s*(missed|skipped)|(missed|skipped)\s*:?\s*\d+',
        caseSensitive: false,
      );
      for (final text in _texts(tester)) {
        expect(
          countOfMissed.hasMatch(text),
          isFalse,
          reason: 'rule 3: no count of what was missed — "$text"',
        );
      }

      // And the guard bites: this is what a violation would look like.
      expect(countOfMissed.hasMatch('2 missed weeks'), isTrue);
      expect(countOfMissed.hasMatch('Missed: 3'), isTrue);
      expect(
        countOfMissed.hasMatch('A missed week, repaired without asking'),
        isFalse,
      );
    });

    testWidgets('the chart draws one bar per closed week and none for none', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers(recent8: const <WeekBar>[]))));
      await tester.pumpAndSettle();

      // A new woman gets an absent chart, not eight grey stubs implying eight
      // weeks of failure.
      final chart = tester.widget<WeekBarsChart>(find.byType(WeekBarsChart));
      expect(chart.weeks, isEmpty);
    });

    testWidgets('nothing on the screen is an error surface', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view(_hers())));
      await tester.pumpAndSettle();

      for (final card in tester.widgetList<AppCard>(find.byType(AppCard))) {
        expect(card.variant, isNot(AppCardVariant.error));
      }
    });
  });

  group('P0-NAV-01 — P01 is the door to T04 and T05', () {
    testWidgets(
      'the onward rows are present and wired, and T05 stays hidden (D43)',
      (tester) async {
        _phone(tester);
        var restWeek = 0;
        var tierSlip = 0;
        var firstWeek = 0;

        await tester.pumpWidget(
          _host(
            ProgressView(
              summary: _hers(),
              onOpenRestWeek: () => restWeek++,
              onOpenTierSlip: () => tierSlip++,
              onOpenFirstWeek: () => firstWeek++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // "If a tier slips" opens T05, which is hidden for launch (D43): the
        // row is not drawn, so there is nothing that leads to it.
        expect(find.text('If a tier slips'), findsNothing);

        // The rest week sits one tap behind "How weeks count".
        expect(find.text('What a rest week covers'), findsNothing);
        await tester.ensureVisible(find.text('How weeks count'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('How weeks count'));
        await tester.pumpAndSettle();
        expect(find.text('If a tier slips'), findsNothing);
        await tester.tap(find.text('What a rest week covers'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Your first week'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Your first week'));
        await tester.pump();

        expect(restWeek, 1, reason: "T04's only inbound edge in the design");
        expect(tierSlip, 0, reason: 'T05 is hidden, so nothing opens it');
        expect(firstWeek, 1);
      },
    );

    testWidgets('the three tiles open P02, P03 and P04', (tester) async {
      _phone(tester);
      var milestones = 0;
      var bests = 0;
      var body = 0;

      await tester.pumpWidget(
        _host(
          ProgressView(
            summary: _hers(),
            onOpenMilestones: () => milestones++,
            onOpenBests: () => bests++,
            onOpenBody: () => body++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Milestones'));
      await tester.tap(find.text('Bests'));
      await tester.tap(find.text('Body'));
      await tester.pump();

      expect(milestones, 1);
      expect(bests, 1);
      expect(body, 1);
    });
  });

  group('P0-A11Y-01', () {
    testWidgets('it mirrors in Arabic with Western numerals', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(ProgressView))),
        TextDirection.rtl,
      );

      final eastern = RegExp('[٠-٩]');
      for (final text in _texts(tester)) {
        expect(
          eastern.hasMatch(text),
          isFalse,
          reason: 'P0-A11Y-01 requires Western numerals in Arabic: "$text"',
        );
      }

      // Her real figures still appear, in Western digits.
      expect(find.textContaining('1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(_hers()), locale: const Locale('ar'), textScale: 1.6),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('D37 and §15: the streak row and the next milestone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ProgressView(
          summary: _hers(),
          trainingStreak: const StreakStatus(enabled: true, days: 4, best: 9),
          nextMilestone: const MilestoneStanding(
            milestone: Milestone(
              id: 'ten_sessions',
              measure: MilestoneMeasure.sessions,
              target: 10,
            ),
            progress: 7,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p01TrainingStreak')), findsOneWidget);
    // The line names the streak, so it is the row's title; her best sits
    // under it rather than repeating "Training streak" twice.
    expect(find.text('Training streak: 4 days'), findsOneWidget);
    expect(find.text('Your best: 9 days'), findsOneWidget);
    expect(find.text('Training streak'), findsNothing);
    expect(find.byKey(const ValueKey('p01-next-milestone')), findsOneWidget);
    expect(find.text('7 of 10'), findsOneWidget);
  });

  testWidgets('no streak row when it is off, and never the kitten', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ProgressView(summary: _hers())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p01TrainingStreak')), findsNothing);
  });
}
