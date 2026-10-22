// The doors into changing a plan are big, plain and one tap from the page they
// sit on: the card at the top of Train, the button on the programme page and
// the two links under Home's training card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/custom_workout.dart';
import 'package:own_hub/features/train/presentation/plan_entry_cards.dart';
import 'package:own_hub/features/train/presentation/program_view.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child, {String locale = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(Locale(locale)),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.train: true,
      Feature.workoutLibrary: true,
      Feature.program: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('the card offers all the ways in, and each is one tap', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: SingleChildScrollView(
            child: BuildOwnPlanCard(
              hasMyPlan: false,
              onCustomizePlan: () => taps.add('customize'),
              onStartFromScratch: () => taps.add('scratch'),
              onEditSplit: () => taps.add('split'),
              onBuildWorkout: () => taps.add('workout'),
              onMyWorkouts: () => taps.add('mine'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Build my own plan'), findsOneWidget);
    for (final key in [
      'r01-customize-plan',
      'r01-plan-scratch',
      'r01-edit-split',
      'r01-build-own',
      'r01-open-my-workouts',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(taps, ['customize', 'scratch', 'split', 'workout', 'mine']);
    expect(find.text('Customize this plan'), findsOneWidget);
  });

  testWidgets('with a plan of her own the card opens it', (tester) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: BuildOwnPlanCard(
            hasMyPlan: true,
            onCustomizePlan: () {},
            onStartFromScratch: () {},
            onEditSplit: () {},
          ),
        ),
      ),
    );
    expect(find.text('Edit my plan'), findsOneWidget);
    expect(find.text('Customize this plan'), findsNothing);
    expect(find.byKey(const ValueKey('r01-edit-split')), findsNothing);
    // The editor has its own Start from scratch, which asks first.
    expect(find.byKey(const ValueKey('r01-plan-scratch')), findsNothing);
  });

  testWidgets('R01 draws the card first, above the week', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        TrainView(
          onCustomizePlan: () {},
          onStartPlanFromScratch: () {},
          onEditSplit: () {},
          onBuildOwn: () {},
          programWeek: 'Week 2 of 6',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.getTopLeft(
      find.byKey(const ValueKey('r01-build-plan-card')),
    );
    final week = tester.getTopLeft(find.text('Week 2 of 6'));
    expect(card.dy, lessThan(week.dy));
    // It is on the first screen, without scrolling.
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('r01-customize-plan'))).dy,
      lessThan(844),
    );
    // One build-your-own door, not two.
    expect(find.byKey(const ValueKey('r01-build-own')), findsOneWidget);
  });

  testWidgets('R01 taps: customize, scratch and split are the first tap', (
    tester,
  ) async {
    _phone(tester);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        TrainView(
          onCustomizePlan: () => taps.add('customize'),
          onStartPlanFromScratch: () => taps.add('scratch'),
          onEditSplit: () => taps.add('split'),
          onBuildOwn: () => taps.add('workout'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-customize-plan')));
    await tester.tap(find.byKey(const ValueKey('r01-plan-scratch')));
    await tester.tap(find.byKey(const ValueKey('r01-edit-split')));
    await tester.tap(find.byKey(const ValueKey('r01-build-own')));
    expect(taps, ['customize', 'scratch', 'split', 'workout']);
  });

  testWidgets('My workouts scrolls to the list when there is one', (
    tester,
  ) async {
    _phone(tester);
    var built = 0;
    await tester.pumpWidget(
      _host(
        TrainView(
          onCustomizePlan: () {},
          onBuildOwn: () => built++,
          myWorkouts: const [
            CustomWorkout(
              id: 'w1',
              name: 'Arms',
              moves: [CustomMove(exerciseId: 'curl', reps: 10)],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-open-my-workouts')));
    await tester.pumpAndSettle();
    expect(built, 0);
    expect(find.byKey(const ValueKey('r01-mine-w1')), findsOneWidget);
  });

  testWidgets('My workouts builds the first one when there are none', (
    tester,
  ) async {
    _phone(tester);
    var built = 0;
    await tester.pumpWidget(
      _host(TrainView(onCustomizePlan: () {}, onBuildOwn: () => built++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-open-my-workouts')));
    expect(built, 1);
  });

  testWidgets('with no new callbacks R01 still shows the old build button', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(TrainView(onBuildOwn: () {})));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-build-plan-card')), findsNothing);
    expect(find.byKey(const ValueKey('r01-build-own')), findsOneWidget);
  });

  testWidgets('R02 has Customize this plan, or Edit my plan', (tester) async {
    _phone(tester);
    var taps = 0;
    await tester.pumpWidget(
      _host(
        ProgramView(
          onCustomizePlan: () => taps++,
          days: const [ProgramDay(title: 'Upper')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r02-customize-plan')));
    expect(taps, 1);
    expect(find.text('Customize this plan'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        ProgramView(
          onCustomizePlan: () => taps++,
          hasMyPlan: true,
          days: const [ProgramDay(title: 'Upper')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit my plan'), findsOneWidget);
  });

  testWidgets('Home links: Edit and Change plan', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: PlanLinksRow(
            onEdit: () => taps.add('edit'),
            onChangePlan: () => taps.add('change'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('home-edit-workout')));
    await tester.tap(find.byKey(const ValueKey('home-change-plan')));
    expect(taps, ['edit', 'change']);

    await tester.pumpWidget(_host(const Scaffold(body: PlanLinksRow())));
    expect(find.byKey(const ValueKey('home-plan-links')), findsNothing);
  });

  testWidgets('the card reads right to left in Arabic, every button 48 high', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: SingleChildScrollView(
            child: BuildOwnPlanCard(
              hasMyPlan: false,
              onCustomizePlan: () {},
              onStartFromScratch: () {},
              onEditSplit: () {},
              onBuildWorkout: () {},
              onMyWorkouts: () {},
            ),
          ),
        ),
        locale: 'ar',
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('r01-build-plan-card'));
    expect(Directionality.of(tester.element(card)), TextDirection.rtl);
    expect(find.text('Build my own plan'), findsNothing);
    // The icon leads, so in Arabic it sits to the right of the label.
    final button = find.byKey(const ValueKey('r01-customize-plan'));
    expect(
      tester
          .getCenter(find.descendant(of: button, matching: find.byType(Icon)))
          .dx,
      greaterThan(
        tester
            .getCenter(find.descendant(of: button, matching: find.byType(Text)))
            .dx,
      ),
    );
    for (final key in [
      'r01-customize-plan',
      'r01-plan-scratch',
      'r01-edit-split',
      'r01-build-own',
      'r01-open-my-workouts',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
  });

  testWidgets('every door keeps a 48 high target at text scale 2.0', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                BuildOwnPlanCard(
                  hasMyPlan: false,
                  onCustomizePlan: () {},
                  onStartFromScratch: () {},
                  onEditSplit: () {},
                  onBuildWorkout: () {},
                  onMyWorkouts: () {},
                ),
                PlanLinksRow(onEdit: () {}, onChangePlan: () {}),
              ],
            ),
          ),
        ),
        locale: 'ar',
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    for (final key in [
      'r01-customize-plan',
      'r01-plan-scratch',
      'r01-edit-split',
      'r01-build-own',
      'r01-open-my-workouts',
      'home-edit-workout',
      'home-change-plan',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Customize is never a filled button beside the screen\'s own', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: BuildOwnPlanCard(hasMyPlan: false, onCustomizePlan: () {}),
        ),
      ),
    );
    final button = tester.widget<AppButton>(
      find.byKey(const ValueKey('r01-customize-plan')),
    );
    expect(button.variant, isNot(AppButtonVariant.filled));
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('Replace your plan with this split? answers both ways in '
        '$locale', (tester) async {
      _phone(tester);
      final answers = <bool>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('ask'),
                onPressed: () async =>
                    answers.add(await askReplacePlan(context)),
                child: const Text('ask'),
              ),
            ),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('plan-replace-yes'));
      expect(sheet, findsOneWidget);
      expect(
        Directionality.of(tester.element(sheet)),
        locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.getSize(sheet).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byKey(const ValueKey('plan-replace-keep'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('plan-replace-keep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-replace-yes')));
      await tester.pumpAndSettle();
      expect(answers, [false, true]);
    });
  }

  for (final locale in ['en', 'ar']) {
    testWidgets('R01 card fits at text scale 2.0 in $locale', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          TrainView(
            onCustomizePlan: () {},
            onStartPlanFromScratch: () {},
            onEditSplit: () {},
            onBuildOwn: () {},
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r01-customize-plan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
