// The doors into changing a plan: Train's "Your plan" row opens the programme
// page, whose "…" holds every way to change the plan, and Home keeps its two
// links.

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

  Future<void> pickFromMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('overflow-row-$label')));
    await tester.pumpAndSettle();
  }

  testWidgets('R02 offers all the ways to change the plan in one menu', (
    tester,
  ) async {
    _phone(tester);
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        ProgramView(
          onCustomizePlan: () => taps.add('customize'),
          onStartPlanFromScratch: () => taps.add('scratch'),
          onEditSplit: () => taps.add('split'),
          onBuildOwn: () => taps.add('workout'),
          onChangeProgram: () => taps.add('change'),
          onOpenRecentSessions: () => taps.add('recent'),
          days: const [ProgramDay(title: 'Upper')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // None of them is on the page itself.
    expect(find.text('Customize this plan'), findsNothing);
    for (final label in [
      'Customize this plan',
      'Start from scratch',
      'Edit one of the three splits',
      'Build my own workout',
      'Change program',
      'Recent sessions',
    ]) {
      await pickFromMenu(tester, label);
    }
    expect(taps, [
      'customize',
      'scratch',
      'split',
      'workout',
      'change',
      'recent',
    ]);
  });

  testWidgets('with a plan of her own R02 opens it, and offers no blank one', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ProgramView(
          hasMyPlan: true,
          onCustomizePlan: () {},
          onStartPlanFromScratch: () {},
          onEditSplit: () {},
          days: const [ProgramDay(title: 'Upper')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Edit my plan'), findsOneWidget);
    expect(find.text('Customize this plan'), findsNothing);
    // The editor has its own Start from scratch, which asks first.
    expect(find.text('Start from scratch'), findsNothing);
    expect(find.text('Edit one of the three splits'), findsNothing);
  });

  testWidgets('R01 has one row for the plan and one for her workouts', (
    tester,
  ) async {
    _phone(tester);
    var opened = 0;
    await tester.pumpWidget(
      _host(
        TrainView(
          onSeeProgram: () => opened++,
          onBuildOwn: () {},
          programTitle: 'Glutes and strength',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-build-plan-card')), findsNothing);
    expect(find.text('Glutes and strength'), findsOneWidget);
    final plan = find.byKey(const ValueKey('r01-your-plan'));
    final mine = find.byKey(const ValueKey('r01-open-my-workouts'));
    // On the first screen, without scrolling.
    expect(tester.getBottomLeft(mine).dy, lessThan(844));
    await tester.tap(plan);
    expect(opened, 1);
  });

  testWidgets('My workouts opens her list when there is one', (tester) async {
    _phone(tester);
    var built = 0;
    await tester.pumpWidget(
      _host(
        TrainView(
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
    expect(find.byKey(const ValueKey('r01-mine-w1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('r01-open-my-workouts')));
    await tester.pumpAndSettle();
    expect(built, 0);
    expect(find.byKey(const ValueKey('r01-mine-w1')), findsOneWidget);
    // Building another is in the list, not on the page.
    await tester.tap(find.byKey(const ValueKey('r01-build-own')));
    expect(built, 1);
  });

  testWidgets('My workouts builds the first one when there are none', (
    tester,
  ) async {
    _phone(tester);
    var built = 0;
    await tester.pumpWidget(_host(TrainView(onBuildOwn: () => built++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-open-my-workouts')));
    expect(built, 1);
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

  testWidgets(
    'the programme menu reads right to left in Arabic, rows 48 high',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ProgramView(
            onCustomizePlan: () {},
            onStartPlanFromScratch: () {},
            onEditSplit: () {},
            onBuildOwn: () {},
            days: const [ProgramDay(title: 'Upper')],
          ),
          locale: 'ar',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('overflow-list'));
      expect(Directionality.of(tester.element(list)), TextDirection.rtl);
      expect(find.text('Customize this plan'), findsNothing);
      final rows = find.descendant(
        of: list,
        matching: find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'overflow-row-"),
        ),
      );
      expect(rows, findsNWidgets(4));
      for (final e in rows.evaluate()) {
        expect(
          tester.getSize(find.byElementPredicate((x) => x == e)).height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );

  testWidgets('Home keeps a 48 high target at text scale 2.0', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: PlanLinksRow(onEdit: () {}, onChangePlan: () {}),
        ),
        locale: 'ar',
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    for (final key in ['home-edit-workout', 'home-change-plan']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    expect(tester.takeException(), isNull);
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
    testWidgets('R01 fits at text scale 2.0 in $locale', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          TrainView(onSeeProgram: () {}, onBuildOwn: () {}),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r01-your-plan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
