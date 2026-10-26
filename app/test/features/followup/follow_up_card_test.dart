// The follow-up card on Home: each kind, the week review sheet, and the way
// out. Nothing changes her plan until she taps "Use this".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:own_hub/features/followup/presentation/follow_up_card.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_chip_row.dart';

// 16 October 2026 is a Friday.
final DateTime _friday = DateTime(2026, 10, 16, 9, 30);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const SessionRecap _recap = SessionRecap(
  dateKey: '2026-10-15',
  moves: 4,
  sets: 11,
  topMoveName: 'Goblet squat',
  topKg: 12.5,
);

FollowUp _after({bool safety = false, bool gentle = false}) => FollowUp(
  kind: FollowUpKind.afterSession,
  session: _recap,
  safetyFirst: safety,
  gentle: gentle,
);

const FollowUp _week = FollowUp(
  kind: FollowUpKind.weekReview,
  weekStartKey: '2026-10-10',
  sessions: 3,
  sets: 30,
  bests: 1,
  avgProtein: 82,
);

const FollowUp _back = FollowUp(
  kind: FollowUpKind.comeBack,
  session: _recap,
  daysAway: 9,
);

const FollowUp _food = FollowUp(
  kind: FollowUpKind.food,
  lowDays: 4,
  pick: (name: 'Ful medames', proteinG: 14),
);

FollowUpCard _card(
  FollowUp follow, {
  FollowUpState? state,
  IntakeRepository? repository,
  VoidCallback? onOpenTrain,
  VoidCallback? onOpenEat,
}) => FollowUpCard(
  followUp: follow,
  now: _friday,
  intakeRepository: repository ?? InMemoryIntakeRepository(),
  state: state,
  onOpenTrain: onOpenTrain,
  onOpenEat: onOpenEat,
);

void main() {
  setUp(() {
    FollowUpState.instance.reset();
    FollowUpCard.lastThanks = null;
  });
  tearDown(() {
    FollowUpState.instance.reset();
    FollowUpCard.lastThanks = null;
  });

  group('after a session', () {
    testWidgets('shows her numbers and asks how she feels', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_after())));
      expect(
        find.byKey(const ValueKey('follow-up-afterSession')),
        findsOneWidget,
      );
      expect(find.text('Moves: 4 · Sets: 11'), findsOneWidget);
      expect(find.text('Up to 12.5 kg on Goblet squat'), findsOneWidget);
      expect(find.text('How do you feel today?'), findsOneWidget);
      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('A bit sore'), findsOneWidget);
      expect(find.text('Very sore'), findsOneWidget);
    });

    testWidgets('her answer is stored and the card thanks her', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_after())));
      await tester.tap(find.text('A bit sore'));
      await tester.pump();
      expect(FollowUpState.instance.feels['2026-10-15'], Feel.aBitSore);
      expect(find.text('Thanks for telling us.'), findsOneWidget);
      expect(find.text('How do you feel today?'), findsNothing);
      expect(find.textContaining('same weights'), findsNothing);
    });

    testWidgets('very sore twice in a row says the weights stay', (
      tester,
    ) async {
      _phone(tester);
      FollowUpState.instance.answerFeel('2026-10-12', Feel.verySore);
      await tester.pumpWidget(_host(_card(_after())));
      await tester.tap(find.text('Very sore'));
      await tester.pump();
      expect(
        find.text(
          'Next time, the same weights. Build up again when you feel fresh.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a session with no sets or no weight draws no empty line', (
      tester,
    ) async {
      _phone(tester);
      const bare = SessionRecap(dateKey: '2026-10-15', moves: 0, sets: 0);
      await tester.pumpWidget(
        _host(
          _card(const FollowUp(kind: FollowUpKind.afterSession, session: bare)),
        ),
      );
      expect(find.textContaining('Moves:'), findsNothing);
      expect(find.textContaining('Up to'), findsNothing);
      expect(find.text('How do you feel today?'), findsOneWidget);
    });

    testWidgets('the safety line and the gentle line show when they apply', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_after(safety: true, gentle: true))));
      expect(
        find.text(
          'Only moves screened for you, and stop if anything feels off.',
        ),
        findsOneWidget,
      );
      expect(find.text('Today can be a gentle day.'), findsOneWidget);

      await tester.pumpWidget(_host(_card(_after())));
      expect(find.textContaining('screened for you'), findsNothing);
      expect(find.textContaining('gentle day'), findsNothing);
    });
  });

  group('the other kinds', () {
    testWidgets('week review shows only what she did, never a missed count', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_week)));
      expect(
        find.byKey(const ValueKey('follow-up-weekReview')),
        findsOneWidget,
      );
      expect(find.text('Your week'), findsOneWidget);
      expect(
        find.textContaining('Sessions: 3 · Sets: 30 · New bests: 1'),
        findsOneWidget,
      );
      expect(find.textContaining('Average protein: 82 g'), findsOneWidget);
      expect(find.text('3 quick questions'), findsOneWidget);
    });

    testWidgets('a quiet week draws no zeros', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _card(
            const FollowUp(
              kind: FollowUpKind.weekReview,
              weekStartKey: '2026-10-10',
            ),
          ),
        ),
      );
      expect(find.textContaining('0'), findsNothing);
      expect(find.text('A few questions about your week.'), findsOneWidget);
    });

    testWidgets('come back says how long, and opens Train', (tester) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(_host(_card(_back, onOpenTrain: () => opened++)));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('Your last session was 9 days ago. A short one today?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Go to Train'));
      expect(opened, 1);
    });

    testWidgets('protein idea names a food she has, and opens logging', (
      tester,
    ) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(_host(_card(_food, onOpenEat: () => opened++)));
      expect(find.text('Protein ideas'), findsOneWidget);
      expect(
        find.text(
          'Under your target on 4 of your last 5 logged days. Ful medames is '
          'one you already have, 14 g of protein.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Log a meal'));
      expect(opened, 1);
    });
  });

  group('the way out', () {
    testWidgets('swiping it away hides the kind until tomorrow', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_back)));
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Not now'), findsNothing);
      expect(find.text("Don't show this kind again"), findsNothing);
      await tester.fling(
        find.byKey(const ValueKey('follow-up-not-now-comeBack')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        FollowUpState.instance.notBefore[FollowUpKind.comeBack],
        '2026-10-17',
      );
      expect(FollowUpState.instance.muted, isEmpty);
    });
  });

  group('the week review sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('3 quick questions'));
      await tester.pumpAndSettle();
    }

    Future<void> answer(
      WidgetTester tester,
      String felt,
      String fit,
      String focus,
    ) async {
      await tester.tap(find.text(felt));
      await tester.tap(find.text(fit));
      await tester.tap(find.text(focus));
      await tester.pump();
    }

    testWidgets('Save waits for all three answers', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_week)));
      await openSheet(tester);
      expect(find.text('How did this week feel?'), findsOneWidget);
      expect(find.text('Did the plan fit your time?'), findsOneWidget);
      expect(find.text("Next week's focus"), findsOneWidget);

      await tester.tap(find.text('Good week'));
      await tester.tap(find.text('Too much'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('week-review-save')));
      await tester.pump();
      expect(FollowUpState.instance.weekReviews, isEmpty);
    });

    testWidgets('saving stores the answer and changes nothing else', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryIntakeRepository(
        const Intake(days: 4, goal: TrainingGoal.stronger),
      );
      await tester.pumpWidget(_host(_card(_week, repository: repo)));
      await openSheet(tester);
      await answer(tester, 'Hard week', 'Too much', 'Feel good');
      await tester.tap(find.byKey(const ValueKey('week-review-save')));
      await tester.pumpAndSettle();

      expect(
        FollowUpState.instance.weekReviews['2026-10-10'],
        const WeekReviewAnswer(
          felt: WeekFelt.hard,
          fit: PlanFit.tooMuch,
          focus: WeekFocus.feelGood,
        ),
      );
      expect(repo.writes, isEmpty, reason: 'nothing changes without a tap');
      expect(
        find.text('Here is what we suggest. Nothing changes unless you tap.'),
        findsOneWidget,
      );
      expect(find.text('Days a week: 3'), findsOneWidget);
      expect(find.text('Focus: Feel good and move'), findsOneWidget);
    });

    testWidgets('Use this writes just that row', (tester) async {
      _phone(tester);
      final repo = InMemoryIntakeRepository(const Intake(days: 4));
      await tester.pumpWidget(_host(_card(_week, repository: repo)));
      await openSheet(tester);
      await answer(tester, 'Okay week', 'Too much', 'Strength');
      await tester.tap(find.byKey(const ValueKey('week-review-save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('week-review-use-days')));
      await tester.pumpAndSettle();
      expect(repo.read().days, 3);
      expect(repo.writes, [
        {'days'},
      ]);
      expect(
        find.byKey(const ValueKey('week-review-done-days')),
        findsOneWidget,
      );
    });

    testWidgets('a plan that already fits says so and offers only Done', (
      tester,
    ) async {
      _phone(tester);
      final repo = InMemoryIntakeRepository(const Intake());
      await tester.pumpWidget(_host(_card(_week, repository: repo)));
      await openSheet(tester);
      await answer(tester, 'Good week', 'About right', 'Strength');
      await tester.tap(find.byKey(const ValueKey('week-review-save')));
      await tester.pumpAndSettle();

      expect(find.text('Use this'), findsNothing);
      expect(
        find.text('Your plan stays as it is. See you next week.'),
        findsOneWidget,
      );
      expect(find.text('Keep my plan'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('week-review-sheet')), findsNothing);
      expect(repo.writes, isEmpty);
    });

    testWidgets('Steady loss is one of the focuses', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_week)));
      await openSheet(tester);
      expect(find.text('Steady loss'), findsOneWidget);
    });

    testWidgets('Steady loss is hidden when safety comes first', (
      tester,
    ) async {
      _phone(tester);
      const safe = FollowUp(
        kind: FollowUpKind.weekReview,
        weekStartKey: '2026-10-10',
        sessions: 3,
        safetyFirst: true,
      );
      await tester.pumpWidget(_host(_card(safe)));
      await openSheet(tester);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Feel good'), findsOneWidget);
      expect(find.text('Steady loss'), findsNothing);
    });

    testWidgets('the Arabic chips agree with the week and never say pain', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_card(_week), locale: const Locale('ar')));
      await tester.tap(find.byType(AppButton).first);
      await tester.pumpAndSettle();
      for (final text in const [
        'أسبوع حلو',
        'أسبوع عادي',
        'أسبوع صعب',
        'إحساس أحسن',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('أحسّ بتحسن'), findsNothing);

      await tester.pumpWidget(
        _host(_card(_after()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('نشيطة'), findsOneWidget);
      expect(find.text('عضلاتي شادّة شوية'), findsOneWidget);
      expect(find.text('عضلاتي شادّة أوي'), findsOneWidget);
      expect(find.textContaining('واجعاني'), findsNothing);
    });

    testWidgets('a Latin food name is fenced inside Arabic text', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_card(_food, onOpenEat: () {}), locale: const Locale('ar')),
      );
      expect(find.textContaining('\u2068Ful medames\u2069'), findsOneWidget);
    });

    testWidgets('her chosen weekdays follow a change in days', (tester) async {
      _phone(tester);
      final repo = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      await tester.pumpWidget(_host(_card(_week, repository: repo)));
      await openSheet(tester);
      await answer(tester, 'Good week', 'Too little', 'Strength');
      await tester.tap(find.byKey(const ValueKey('week-review-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-review-use-days')));
      await tester.pumpAndSettle();
      expect(repo.read().days, 4);
      expect(repo.read().weekdays.length, 4);
      expect(repo.read().weekdays.containsAll({6, 1, 3}), isTrue);
    });
  });

  group('large text', () {
    final kinds = <String, FollowUp>{
      'afterSession': _after(safety: true, gentle: true),
      'weekReview': _week,
      'comeBack': _back,
      'food': _food,
    };
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final entry in kinds.entries) {
        testWidgets('${entry.key} fits at 2.0 in ${locale.languageCode}', (
          tester,
        ) async {
          _phone(tester);
          await tester.pumpWidget(
            _host(
              _card(entry.value, onOpenTrain: () {}, onOpenEat: () {}),
              locale: locale,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('the sheet fits at 2.0 in ${locale.languageCode}', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(_card(_week), locale: locale, textScale: 2.0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AppButton).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('week-review-sheet')), findsOneWidget);
        final inSheet = tester.element(
          find.byKey(const ValueKey('week-review-sheet')),
        );
        expect(MediaQuery.textScalerOf(inSheet).scale(10), 20);
        final chips = find.byType(AppChip);
        for (final i in const [0, 3, 6]) {
          await tester.ensureVisible(chips.at(i));
          await tester.tap(chips.at(i));
          await tester.pump();
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('week-review-save')),
        );
        await tester.tap(find.byKey(const ValueKey('week-review-save')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('week-review-keep')), findsOneWidget);
      });
    }
  });
}
