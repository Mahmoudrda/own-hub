// The plan editor: her days with Edit, Replace and Remove, Add day, Start from
// scratch and Back to the original split.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/my_plan_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/plan_editor_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

AuthoredProgramme _template() => AuthoredProgramme(
  programId: 'split_fixture',
  titleEn: 'Split',
  titleAr: 'خطة',
  status: ProgrammeStatus.published,
  sessions: [
    for (final id in ['a', 'b', 'c'])
      AuthoredSession(
        sessionId: id,
        titleEn: 'Day $id',
        titleAr: 'يوم $id',
        minutes: 45,
        lifeStages: const {LifeStage.none},
        moves: [
          for (final m in ['m1', 'm2', 'm3'])
            AuthoredMove(
              exerciseId: '$id$m',
              nameEn: '$id$m',
              nameAr: '$id$m',
              sets: 3,
              reps: 10,
            ),
        ],
      ),
  ],
);

PlannedMove _planned(String id) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

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

void _tall(WidgetTester tester, {Size size = const Size(800, 3000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _editor({
  List<int>? edited,
  VoidCallback? onBack,
  bool withOriginal = true,
}) => PlanEditorView(
  onEditDay: (i) => edited?.add(i),
  onPickMoves: () async => [_planned('picked_move')],
  original: withOriginal ? _template : null,
  stage: LifeStage.none,
  onBack: onBack,
);

void main() {
  final state = MyPlanState.instance;

  setUp(() {
    state.reset();
    state.save(MyPlan.fork(_template(), stage: LifeStage.none));
  });
  tearDown(state.reset);

  testWidgets('every day is listed with Edit, Replace and Remove', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('plan-day-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('plan-edit-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('plan-replace-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('plan-remove-$i')), findsOneWidget);
    }
    expect(find.text('1. Day a'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-add-day')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-scratch')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-original')), findsOneWidget);
  });

  testWidgets('Edit opens that day', (tester) async {
    _tall(tester);
    final edited = <int>[];
    await tester.pumpWidget(_host(_editor(edited: edited)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-edit-2')));
    expect(edited, [2]);
    // Opening a day changes nothing in the plan.
    expect(state.plan!.days.length, 3);
  });

  testWidgets('Remove takes a day out and Undo puts it back', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-remove-0')));
    await tester.pumpAndSettle();
    expect(state.plan!.days.length, 2);
    expect(find.text('1. Day b'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.plan!.days.length, 3);
    expect(find.text('1. Day a'), findsOneWidget);
  });

  testWidgets('Add a day: a copy of one of her days', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-add-day')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-add-blank')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-add-copy-1')));
    await tester.pumpAndSettle();
    expect(state.plan!.days.length, 4);
    expect(state.plan!.days.last.session.titleEn, 'Day b');
    expect(find.byKey(const ValueKey('plan-day-3')), findsOneWidget);
  });

  testWidgets('Add a day: a blank one, built move by move', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-add-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-add-blank')));
    await tester.pumpAndSettle();
    expect(find.text('Add a day to my plan'), findsOneWidget);
    expect(find.byKey(const ValueKey('build-start')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('build-name')), 'Arms');
    await tester.tap(find.byKey(const ValueKey('build-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-save')));
    await tester.pumpAndSettle();

    expect(state.plan!.days.length, 4);
    expect(state.plan!.days.last.session.titleEn, 'Arms');
    expect(
      state.plan!.days.last.session.moves.single.exerciseId,
      'picked_move',
    );
    expect(find.byKey(const ValueKey('plan-day-3')), findsOneWidget);
  });

  testWidgets('Replace: put a day back as the split wrote it', (tester) async {
    _tall(tester);
    state.save(state.plan!.withMoves(0, [_planned('only_one')]));
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-replace-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-restore-0')));
    await tester.pumpAndSettle();
    expect(state.plan!.days[0].session.moves.length, 3);
    expect(state.plan!.days[0].session.moves.first.exerciseId, 'am1');
  });

  testWidgets('Replace: take the moves of another day of the split', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-replace-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-use-0-2')));
    await tester.pumpAndSettle();
    expect(state.plan!.days[0].session.titleEn, 'Day c');
    expect(state.plan!.days[0].session.moves.first.exerciseId, 'cm1');
    expect(state.plan!.days.length, 3);
  });

  testWidgets('there is no Replace for a plan started blank', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor(withOriginal: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-replace-0')), findsNothing);
    expect(find.byKey(const ValueKey('plan-edit-0')), findsOneWidget);
  });

  testWidgets('Start from scratch asks, and Cancel keeps her days', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-scratch')));
    await tester.pumpAndSettle();
    expect(find.text('Start from a blank plan?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(state.plan!.days.length, 3);

    await tester.tap(find.byKey(const ValueKey('plan-scratch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-scratch-yes')));
    await tester.pumpAndSettle();
    expect(state.hasPlan, isTrue);
    expect(state.plan!.isBlank, isTrue);
    expect(find.text('No days yet. Add your first day.'), findsOneWidget);
    // The way back to the split she began with is still there.
    expect(find.byKey(const ValueKey('plan-original')), findsOneWidget);
    expect(state.plan!.sourceProgrammeId, 'split_fixture');
  });

  testWidgets('Back to the original split drops the plan after a confirm', (
    tester,
  ) async {
    _tall(tester);
    var backed = 0;
    await tester.pumpWidget(_host(_editor(onBack: () => backed++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-original')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(state.hasPlan, isTrue);
    expect(backed, 0);

    await tester.tap(find.byKey(const ValueKey('plan-original')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-original-yes')));
    await tester.pumpAndSettle();
    expect(state.hasPlan, isFalse);
    expect(backed, 1);
  });

  testWidgets('a plan she started blank can still be left for the split', (
    tester,
  ) async {
    _tall(tester);
    state.save(const MyPlan.blank());
    await tester.pumpWidget(_host(_editor(withOriginal: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-original')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-scratch')), findsOneWidget);
  });

  testWidgets('looking at a split in the editor keeps nothing', (tester) async {
    _tall(tester);
    state.reset();
    state.preview(_template(), LifeStage.none);
    final edited = <int>[];
    await tester.pumpWidget(_host(_editor(edited: edited)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-day-1')), findsOneWidget);
    // Opening a day, and leaving, change nothing.
    await tester.tap(find.byKey(const ValueKey('plan-edit-1')));
    expect(edited, [1]);
    expect(state.hasPlan, isFalse);
    expect(find.byKey(const ValueKey('plan-original')), findsNothing);

    // The first change made here is what keeps it.
    await tester.tap(find.byKey(const ValueKey('plan-remove-0')));
    await tester.pumpAndSettle();
    expect(state.hasPlan, isTrue);
    expect(state.plan!.days.length, 2);
    expect(find.byKey(const ValueKey('plan-original')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('days move earlier and later', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-up-0')), findsNothing);
    expect(find.byKey(const ValueKey('plan-down-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-down-0')));
    await tester.pumpAndSettle();
    expect(state.plan!.days.map((d) => d.sourceId), ['b', 'a', 'c']);
    await tester.tap(find.byKey(const ValueKey('plan-up-2')));
    await tester.pumpAndSettle();
    expect(state.plan!.days.map((d) => d.sourceId), ['b', 'c', 'a']);
  });

  testWidgets('Undo after Remove day brings back only that day', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(_editor()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-remove-0')));
    await tester.pumpAndSettle();
    // Something else changes before she taps Undo.
    state.save(state.plan!.withDayMoved(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(state.plan!.days.length, 3);
    expect(state.plan!.days.map((d) => d.sourceId), contains('a'));
    expect(state.plan!.days.first.sourceId, 'a');
  });

  testWidgets('in Arabic the days read right to left with Edit first', (
    tester,
  ) async {
    _tall(tester, size: const Size(390, 1200));
    await tester.pumpWidget(_host(_editor(), locale: 'ar'));
    await tester.pumpAndSettle();
    final day = find.byKey(const ValueKey('plan-day-0'));
    expect(Directionality.of(tester.element(day)), TextDirection.rtl);
    expect(find.text('1. يوم a'), findsOneWidget);
    expect(find.text('1. Day a'), findsNothing);
    // Edit leads, so it sits to the right of Replace; Remove follows, on the
    // next line when the three do not fit one.
    final edit = tester.getCenter(find.byKey(const ValueKey('plan-edit-0')));
    final replace = tester.getCenter(
      find.byKey(const ValueKey('plan-replace-0')),
    );
    final remove = tester.getCenter(
      find.byKey(const ValueKey('plan-remove-0')),
    );
    expect(edit.dx, greaterThan(replace.dx));
    expect(remove.dy, greaterThanOrEqualTo(replace.dy));
    if (remove.dy == replace.dy) expect(replace.dx, greaterThan(remove.dx));
    // Nothing runs off either edge.
    for (final key in ['plan-edit-0', 'plan-replace-0', 'plan-remove-0']) {
      final box = tester.getRect(find.byKey(ValueKey(key)));
      expect(box.left, greaterThanOrEqualTo(0), reason: key);
      expect(box.right, lessThanOrEqualTo(390), reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('at text scale 2.0 in $locale every target is 48 high and '
        'the sheets fit', (tester) async {
      _tall(tester, size: const Size(390, 844));
      final edited = <int>[];
      await tester.pumpWidget(
        _host(_editor(edited: edited), locale: locale, scale: 2),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'plan-edit-0',
        'plan-replace-0',
        'plan-remove-0',
        'plan-add-day',
        'plan-scratch',
        'plan-original',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(48),
          reason: key,
        );
      }
      await tester.ensureVisible(find.byKey(const ValueKey('plan-edit-0')));
      await tester.tap(find.byKey(const ValueKey('plan-edit-0')));
      expect(edited, [0]);

      await tester.ensureVisible(find.byKey(const ValueKey('plan-replace-0')));
      await tester.tap(find.byKey(const ValueKey('plan-replace-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-use-0-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('plan-scratch')));
      await tester.tap(find.byKey(const ValueKey('plan-scratch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-scratch-yes')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('plan-scratch-yes'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('plan-confirm-cancel')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in ['en', 'ar']) {
    testWidgets('fits a phone at text scale 2.0 in $locale', (tester) async {
      _tall(tester, size: const Size(390, 844));
      await tester.pumpWidget(_host(_editor(), locale: locale, scale: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-edit-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
