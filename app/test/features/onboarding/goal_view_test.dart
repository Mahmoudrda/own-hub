// O01 — What do you want most?
//
// The first setup question. What is worth testing beyond "the text is there" is
// the contract underneath it: the answer reaches the repository, it reaches it
// as ONE field (D3's merge, not a whole-object save), skipping writes nothing,
// and re-opening the screen shows what is stored rather than the default.
//
// The last of those is D3 in miniature. My Profile opens this same screen later;
// if it opened on "Get stronger" for a woman who chose something else, the
// "editable forever" half of the decision would be a lie the first time she used
// it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/goal_view.dart';
import 'package:own_hub/features/onboarding/presentation/intake_option.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

bool _isSelected(WidgetTester tester, String title) => tester
    .widget<IntakeOption>(
      find.ancestor(of: find.text(title), matching: find.byType(IntakeOption)),
    )
    .selected;

void main() {
  group('the question and its four answers', () {
    testWidgets('asks once, and every goal is on the screen', (tester) async {
      await tester.pumpWidget(
        _host(GoalView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('What do you want most?'), findsOneWidget);
      // The promise the whole flow rests on: her goal changes the training, not
      // the interface.
      expect(
        find.text('Pick one. It changes the program, not the app.'),
        findsOneWidget,
      );
      for (final goal in [
        'Get stronger',
        'Feel better in my body',
        'Lose weight steadily',
        'Get back into it',
      ]) {
        expect(find.text(goal), findsOneWidget, reason: goal);
      }
    });

    testWidgets('each answer carries its explanation', (tester) async {
      await tester.pumpWidget(
        _host(GoalView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Build up, lift a bit more each week'), findsOneWidget);
      // "Lose weight steadily" is a goal, never a number — §2 rule 11. The
      // subtitle is what keeps it that way in her head too.
      expect(
        find.text('Slowly, without cutting food you love'),
        findsOneWidget,
      );
    });

    testWidgets('shows which of the four steps this is', (tester) async {
      await tester.pumpWidget(
        _host(GoalView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 4'), findsOneWidget);
    });
  });

  group('choosing', () {
    testWidgets(
      '"Get stronger" is preselected, which is what makes Skip safe',
      (tester) async {
        await tester.pumpWidget(
          _host(GoalView(repository: InMemoryIntakeRepository())),
        );
        await tester.pumpAndSettle();

        expect(_isSelected(tester, 'Get stronger'), isTrue);
        expect(_isSelected(tester, 'Get back into it'), isFalse);
      },
    );

    testWidgets('tapping another goal moves the tick', (tester) async {
      await tester.pumpWidget(
        _host(GoalView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Feel better in my body'));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, 'Feel better in my body'), isTrue);
      expect(_isSelected(tester, 'Get stronger'), isFalse);
    });

    testWidgets('Continue writes the goal, and only the goal', (tester) async {
      // The per-step merge is the whole reason abandoning setup is safe. A
      // whole-object save would pass an "it saved" assertion and quietly
      // overwrite answers the other steps own.
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(GoalView(repository: repository, onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();

      // Scrolled to first. O01 opens the app on a fresh install now, so it
      // carries a line saying how many questions there are and that they can
      // be skipped — one line more than the 800x600 test window has room for
      // under the fourth answer. Every phone this ships on is far taller; the
      // screen is a `SingleChildScrollView` either way.
      await tester.ensureVisible(find.text('Get back into it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get back into it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().goal, TrainingGoal.backIntoIt);
      expect(repository.writes, [
        {'goal'},
      ]);
      expect(continued, 1);
    });

    testWidgets('Skip writes nothing and the default stands', (tester) async {
      final repository = InMemoryIntakeRepository();
      var skipped = 0;
      await tester.pumpWidget(
        _host(GoalView(repository: repository, onSkip: () => skipped++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, 1);
      expect(
        repository.writes,
        isEmpty,
        reason: 'a skipped question is unanswered, not answered with a guess',
      );
      expect(
        repository.read().goal,
        TrainingGoal.stronger,
        reason: 'the preselected default still yields a real programme',
      );
    });

    testWidgets('D3 — re-opening shows what is stored, not the default', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository(
        const Intake(goal: TrainingGoal.loseSteadily),
      );
      await tester.pumpWidget(_host(GoalView(repository: repository)));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, 'Lose weight steadily'), isTrue);
      expect(_isSelected(tester, 'Get stronger'), isFalse);
    });
  });

  group('leaving', () {
    testWidgets('she is never trapped in setup', (tester) async {
      var closed = 0;
      var backed = 0;
      await tester.pumpWidget(
        _host(
          GoalView(
            repository: InMemoryIntakeRepository(),
            onClose: () => closed++,
            onBack: () => backed++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(closed, 1);
      expect(backed, 1);
    });
  });

  group('Arabic', () {
    testWidgets('every string comes from the dictionary', (tester) async {
      await tester.pumpWidget(
        _host(
          GoalView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ما الذي تريدينه أكثر؟'), findsOneWidget);
      expect(find.text('أن أصبح أقوى'), findsOneWidget);
      expect(
        find.text('What do you want most?'),
        findsNothing,
        reason: 'English here means a string bypassed AppL10n',
      );
      expect(find.text('Get stronger'), findsNothing);
    });

    testWidgets('mirrors right to left', (tester) async {
      await tester.pumpWidget(
        _host(
          GoalView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(GoalView))),
        TextDirection.rtl,
      );
    });

    testWidgets('the step counter keeps Western numerals', (tester) async {
      // P0-A11Y-01. The counter is a translated string, so this is really a
      // check on the dictionary — and it is worth having, because "الخطوة ١ من ٤"
      // would read correctly and still be wrong for this product.
      await tester.pumpWidget(
        _host(
          GoalView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الخطوة 1 من 4'), findsOneWidget);
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    // Four options, each a wrapped title and subtitle, plus two buttons. Arabic
    // runs longer than English, so this is where a clipped answer would appear.
    await tester.pumpWidget(
      _host(
        GoalView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
