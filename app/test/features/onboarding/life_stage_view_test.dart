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

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/presentation/intake_option.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_step_bar.dart';

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
      // The last question of the walk at home.
      expect(find.text('6 of 6'), findsOneWidget);
    });

    testWidgets('it promises adaptation, and explicitly not diagnosis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();

      // The boundary sentence, and the rule it now obeys.
      //
      // "We avoid what hurts, we do not diagnose" is the promise this screen is
      // built on, and round four found that nothing keeps the first half of it:
      // `selectStartingProgram` does not read `intake.lifeStage`, the catalogue
      // holds one programme, and all four answers lead to the same one. So the
      // sentence is now shown exactly when it is true, through
      // `lifeStageShapesTraining()`, and this case asserts the coupling rather
      // than either state — it goes on passing the day a life-stage filter
      // lands, and fails if the sentence and the selector ever come apart.
      final promise = find.text('We avoid what hurts, we do not diagnose');
      if (lifeStageShapesTraining()) {
        expect(
          promise,
          findsOneWidget,
          reason: 'this sentence is the boundary the screen is built on',
        );
      } else {
        expect(
          promise,
          findsNothing,
          reason:
              'nothing avoids what hurts in this build, so saying it is a '
              'promise with no mechanism behind it',
        );
        expect(
          find.text(
            'We save your answer with the rest of your setup. Nothing in your '
            'sessions changes from it yet.',
          ),
          findsOneWidget,
          reason: 'and the screen still has to answer the question it asked',
        );
      }
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
        // Both rows were rewritten to describe the training and leave the
        // timing and the verdict with her and her doctor. Round four then found
        // that they describe training this build does not do, so they are held
        // behind `lifeStageShapesTraining()` — measured from the selector, not
        // declared — and the assertion is the coupling rather than either
        // state. The two words that were the original defect must not be
        // anywhere on the screen in EITHER state, which is what makes this
        // tighter than it was rather than looser.
        final rows = <Finder>[
          find.text('Pelvic floor first, once your doctor says you are ready'),
          find.text('Gentler movements, nothing on the belly'),
        ];
        for (final row in rows) {
          expect(
            row,
            lifeStageShapesTraining() ? findsOneWidget : findsNothing,
            reason:
                'the rows and the selector have to agree: '
                'lifeStageShapesTraining() is ${lifeStageShapesTraining()}',
          );
        }
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
      // Skip is drawn only where it leads somewhere.
      var skipped = 0;
      await tester.pumpWidget(
        _host(LifeStageView(repository: repository, onSkip: () => skipped++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, 1);
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

      expect(find.text('فيه حاجة نراعيها في التمرين؟'), findsOneWidget);
      expect(find.text('مفيش حاجة دلوقتي'), findsOneWidget);
      // Whatever this screen says about her training, it says it in the
      // language she reads. Both states are asserted in Arabic, so a row gated
      // in English and left in Arabic fails here.
      if (lifeStageShapesTraining()) {
        expect(find.text('بنتجنّب اللي بيوجع، ومابنشخّصش'), findsOneWidget);
      } else {
        expect(find.text('بنتجنّب اللي بيوجع، ومابنشخّصش'), findsNothing);
        expect(
          find.text(
            'بنحفظ إجابتك مع باقي إعداداتك. ولسه مفيش حاجة في تمارينك هتتغيّر بسببها.',
          ),
          findsOneWidget,
        );
      }
      expect(find.text('6 من 6'), findsOneWidget);
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

  group('the short "Your week", before sign-up', () {
    // The last of its three screens. Asking about a pregnancy before her first
    // session is the safety reason the question is in the short walk at all.
    setUp(() => OnboardingState.instance.beforeSignup = true);
    tearDown(() => OnboardingState.instance.beforeSignup = false);

    testWidgets('the third of three, and it ends on her week', (tester) async {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      AppRouter.featureFlags = FeatureFlags.allOff;
      final repository = InMemoryIntakeRepository();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          LifeStageView(
            repository: repository,
            titleOverride: '1 of 3 · Your week',
            continueLabel: 'See my week',
            onBack: () {},
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 · Your week'), findsOneWidget);
      final bar = tester.widget<AppStepBar>(find.byType(AppStepBar));
      expect((bar.step, bar.total), (3, 3));
      // Before she has an account the answer stays on this phone, and the
      // line says so.
      expect(
        find.text('Only you see this. It stays on this phone.'),
        findsOneWidget,
      );
      // Everything is preselected, so there is nothing to skip, and before
      // she has an account there is no Home to close to.
      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      final pregnant = find.text('Pregnant');
      await tester.ensureVisible(pregnant);
      await tester.tap(pregnant);
      await tester.pumpAndSettle();
      final see = find.text('See my week');
      await tester.ensureVisible(see);
      await tester.tap(see);
      await tester.pumpAndSettle();

      expect(continued, 1);
      expect(repository.writes, [
        {'lifeStage'},
      ]);
      expect(repository.read().lifeStage, LifeStage.pregnant);
    });

    testWidgets('does not overflow in Arabic at the largest text size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LifeStageView(
            repository: InMemoryIntakeRepository(),
            titleOverride: '1 من 3 · أسبوعك',
            continueLabel: 'شوفي أسبوعك',
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
