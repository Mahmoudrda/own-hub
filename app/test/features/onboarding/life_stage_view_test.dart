// O04 — Anything we should train around?
//
// The only safety-critical question in setup. Her answer feeds what the
// programme avoids, and the copy is the boundary: "we avoid what hurts, we do
// not diagnose". These assertions exist because that line is the difference
// between adapting a workout and practising medicine through a phone — if it
// ever drifts, it should fail here rather than in a review.
//
// The second promise on the screen is privacy: "Only you and your coach ever see
// this." A life stage that leaked into a feed would be the worst privacy failure
// this product could have.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/intake_option.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
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
  group('what it asks, and how it asks it', () {
    testWidgets('four answers, asked plainly', (tester) async {
      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anything we should train around?'), findsOneWidget);
      for (final option in [
        'Nothing right now',
        'After a birth',
        'Pregnant',
        'A knee, back or shoulder',
      ]) {
        expect(find.text(option), findsOneWidget, reason: option);
      }
      expect(find.text('Step 4 of 4'), findsOneWidget);
    });

    testWidgets('it promises adaptation, and explicitly not diagnosis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('We avoid what hurts, we do not diagnose'),
        findsOneWidget,
        reason: 'this sentence is the boundary the screen is built on',
      );
    });

    testWidgets('it says who sees this, and names nobody who cannot', (
      tester,
    ) async {
      // The coach app ships dark, so "and your coach" would name a reader this
      // release does not have, on the one screen that asks about a pregnancy.
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      AppRouter.featureFlags = FeatureFlags.allOff;

      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Only you ever see this.'), findsOneWidget);
      expect(find.text('Only you and your coach ever see this.'), findsNothing);
    });

    testWidgets('with a coach side, the promise names her coach too', (
      tester,
    ) async {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.coachApp: true,
      });

      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Only you and your coach ever see this.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'pregnancy and postpartum say what changes, not what is wrong',
      (tester) async {
        await tester.pumpWidget(
          _host(LifeStageView(repository: InMemoryIntakeRepository())),
        );
        await tester.pumpAndSettle();

        // Re-pointed at the rule in this case's own name, which the old strings
        // broke in two different ways.
        //
        // "Pelvic floor first, cleared from week six" told a woman when she is
        // cleared. "Cleared" is a clinician's word, six weeks is a convention
        // rather than a fact, and it is wrong after a caesarean, with a
        // complication or with diastasis — so the row was making a clinical
        // claim on a screen whose own list says "We avoid what hurts, we do not
        // diagnose". "Safe movements" asserted safety in the app's voice about
        // a body it has never seen.
        //
        // Both rows now describe the training and leave the timing and the
        // verdict with her and her doctor, so the assertions are tightened
        // rather than relaxed: the training word must be there, and the two
        // words that were the defect must not be anywhere on the screen.
        expect(
          find.text('Pelvic floor first, once your doctor says you are ready'),
          findsOneWidget,
        );
        expect(
          find.text('Gentler movements, nothing on the belly'),
          findsOneWidget,
        );
        expect(
          find.textContaining('cleared', findRichText: true),
          findsNothing,
          reason: 'this screen does not clear anyone for exercise',
        );
        expect(
          find.textContaining('Safe movements', findRichText: true),
          findsNothing,
          reason: 'and it does not promise safety it cannot know',
        );
      },
    );
  });

  group('answering', () {
    testWidgets('"Nothing right now" is preselected', (tester) async {
      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      expect(_isSelected(tester, 'Nothing right now'), isTrue);
      expect(_isSelected(tester, 'Pregnant'), isFalse);
    });

    testWidgets('Continue writes the life stage, and only that', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          LifeStageView(repository: repository, onContinue: () => continued++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pregnant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().lifeStage, LifeStage.pregnant);
      expect(repository.writes, [
        {'lifeStage'},
      ]);
      expect(continued, 1);
    });

    testWidgets('Skip leaves it unanswered rather than guessing', (
      tester,
    ) async {
      final repository = InMemoryIntakeRepository();
      await tester.pumpWidget(_host(LifeStageView(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.writes, isEmpty);
      expect(repository.read().lifeStage, LifeStage.none);
    });

    testWidgets('D3 — this answer above all must stay changeable', (
      tester,
    ) async {
      // A woman who was pregnant at setup is not pregnant forever. The screen
      // opens on what is stored, so changing it is as easy as giving it was.
      final repository = InMemoryIntakeRepository(
        const Intake(lifeStage: LifeStage.pregnant),
      );
      await tester.pumpWidget(_host(LifeStageView(repository: repository)));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, 'Pregnant'), isTrue);

      await tester.tap(find.text('After a birth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().lifeStage, LifeStage.postpartum);
    });
  });

  group('Arabic', () {
    testWidgets('the safety copy translates too', (tester) async {
      await tester.pumpWidget(
        _host(
          LifeStageView(repository: InMemoryIntakeRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أشيء ينبغي أن نتجنّبه في التمرين؟'), findsOneWidget);
      expect(find.text('لا شيء الآن'), findsOneWidget);
      // The "we do not diagnose" promise must exist in the language she reads.
      expect(find.text('نتجنّب ما يؤلم، ولا نشخّص'), findsOneWidget);
      expect(find.text('الخطوة 4 من 4'), findsOneWidget);
      expect(find.text('Anything we should train around?'), findsNothing);
    });
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LifeStageView(repository: InMemoryIntakeRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
