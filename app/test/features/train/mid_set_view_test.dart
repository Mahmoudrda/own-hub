// R07 — Mid-set.
//
// Implements P0-LOG-01, P0-LOG-03, P1-RULE-01 and P1-RULE-09. This is the screen
// the whole group exists for, so the tests are about the rules rather than the
// layout: one tap logs, nothing is pre-filled, nothing asks "are you sure", and
// the write does not leave the device until the undo window has closed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/end_workout_sheet.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/pause_menu.dart';

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

void main() {
  testWidgets('states the set, the numbers and why they moved', (tester) async {
    await tester.pumpWidget(_host(const MidSetView()));
    await tester.pumpAndSettle();

    // No "Move 2 of 5": the bar carried that fixed string over the first move
    // of a four-move session. A caller that has not said which move this is
    // gets no count at all.
    expect(find.text('Move 2 of 5'), findsNothing);
    expect(find.text('Goblet squat'), findsOneWidget);
    // Was "Set 2 of 3" from a fixed string, whatever the move prescribed; it
    // is now counted off `move.sets`, which is also what draws the rows below.
    expect(find.text('Set 2 of 3'), findsOneWidget);
    // And no "Last Tuesday": see the group below.
    expect(find.textContaining('Last Tuesday'), findsNothing);
    // The other sets and the move's other tools are not on the page.
    expect(find.text('This move'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('names the move she is on, when the caller knows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MidSetView(moveNumber: 1, moveCount: 4)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Move 1 of 4'), findsOneWidget);
  });

  testWidgets('and says nothing when the numbers are not a real position', (
    tester,
  ) async {
    // Opened with no live session, `moveIndex + 1` is 1 and `moveCount` is 0,
    // so the first version of this bar read "Move 1 of 0" on the simulator.
    await tester.pumpWidget(
      _host(const MidSetView(moveNumber: 1, moveCount: 0)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Move 1 of'), findsNothing);
  });

  group('the last time she is told about is one she actually had', () {
    // R07 drew "Last Tuesday: 10 kg × 10, every set finished. So we added
    // 2 kg." — three figures about a session that had to have happened. It was
    // guarded against the prescription `(12, 10)`, a sound guard defeated by
    // the fact that the one workout in the build prescribed exactly 12 kg × 10
    // to everybody. So the first set a woman was ever asked to do cited a
    // Tuesday she had not trained.

    testWidgets('a woman with no logged history is told nothing about one', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MidSetView()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Last Tuesday'), findsNothing);
      expect(find.textContaining('Last time'), findsNothing);
      // An empty note is not worth a line mid-set: nothing is said at all.
      expect(find.textContaining('No history'), findsNothing);
      expect(find.textContaining('So we added'), findsNothing);
    });

    testWidgets('and a woman who has one is told what she lifted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const MidSetView(lastLogged: SetOutcome(weightKg: 10, reps: 10))),
      );
      await tester.pumpAndSettle();

      // Her numbers, and the step from them to today's 12 kg.
      expect(
        find.text('Last time: 10 kg × 10. So we added 2 kg.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last Tuesday'), findsNothing);
    });

    testWidgets('with no step claimed when nothing was added', (tester) async {
      await tester.pumpWidget(
        _host(const MidSetView(lastLogged: SetOutcome(weightKg: 12, reps: 10))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last time: 12 kg × 10.'), findsOneWidget);
      expect(find.textContaining('added'), findsNothing);
    });

    testWidgets('her last result stays in view beside the load advice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MidSetView(
            progressionLine: 'Stay at 12 kg until every set is done.',
            lastLogged: SetOutcome(weightKg: 20, reps: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Stay at 12 kg until every set is done.'),
        findsOneWidget,
      );
      expect(find.text('Last time: 20 kg × 12.'), findsOneWidget);
    });

    testWidgets('and is not said twice when the advice already says it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MidSetView(
            progressionLine: 'Last time you did 20 kg × 12. Stay there.',
            lastLogged: SetOutcome(weightKg: 20, reps: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('r07-last-time')), findsNothing);
    });

    testWidgets('with no history there is no last-time line at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const MidSetView(progressionLine: 'Start light.')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('r07-last-time')), findsNothing);
      expect(find.textContaining('Last time'), findsNothing);
    });

    testWidgets('a bodyweight move is never announced as zero kilos', (
      tester,
    ) async {
      // The button forced the loaded sentence with `weightKg ?? 0`, so the
      // first move of the first session read "Done · 0 kg × 12" — a weight she
      // never lifted, on the button that logs it.
      const move = PlannedMove(
        exerciseId: 'glute_bridge',
        name: 'Glute bridge',
        prescriptionLabel: '3 × 12 · bodyweight',
        sets: [PrescribedSet(exerciseId: 'glute_bridge', order: 1, reps: 12)],
      );

      final handles = <LogHandle>[];
      await tester.pumpWidget(
        _host(MidSetView(move: move, setIndex: 0, onSetLogged: handles.add)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Done · 12 reps'), findsOneWidget);
      expect(find.textContaining('0 kg'), findsNothing);

      await tester.tap(find.text('Done · 12 reps'));
      await tester.pump();
      expect(handles.single.describe, 'Set 1 saved · 12 reps');
    });
  });

  testWidgets('the button names HER prescription, not the prototype set', (
    tester,
  ) async {
    // The label was `l10n.done12Kg10` — a fixed string. A woman prescribed
    // 20 kg × 8 was shown "Done · 12 kg × 10" and, tapping it, logged numbers
    // the screen had never shown her. Same defect class as R08 writing nothing
    // and C13 inventing a duration.
    //
    // Note that the DEFAULT move is 12 kg × 10, so every other test in this
    // file renders exactly the same text before and after the fix. They cannot
    // catch this; only a different prescription can.
    const move = PlannedMove(
      exerciseId: 'romanian_deadlift',
      name: 'Romanian deadlift',
      prescriptionLabel: '3 × 8',
      sets: [
        PrescribedSet(
          exerciseId: 'romanian_deadlift',
          order: 1,
          weightKg: 20,
          reps: 8,
        ),
        PrescribedSet(
          exerciseId: 'romanian_deadlift',
          order: 2,
          weightKg: 20,
          reps: 8,
        ),
      ],
    );

    final handles = <LogHandle>[];
    await tester.pumpWidget(
      _host(MidSetView(move: move, onSetLogged: handles.add)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Done · 20 kg × 8'), findsOneWidget);
    expect(find.text('Done · 12 kg × 10'), findsNothing);

    // And the snackbar must name the same numbers the button named — rule 9 is
    // only meaningful if the confirmation matches what she agreed to.
    await tester.tap(find.text('Done · 20 kg × 8'));
    await tester.pump();
    expect(handles.single.describe, 'Set 2 saved · 20 kg × 8');
  });

  testWidgets('a whole number never renders as 20.0', (tester) async {
    // weightKg is a double, so the parameterised label would print "20.0 kg"
    // without weightLabel(). Pinned here because it is the kind of thing that
    // reads as a typo to a user and as nothing at all to a test that only
    // checks the number is present.
    const move = PlannedMove(
      exerciseId: 'hip_thrust',
      name: 'Hip thrust',
      prescriptionLabel: '3 × 12',
      sets: [
        PrescribedSet(
          exerciseId: 'hip_thrust',
          order: 1,
          weightKg: 20,
          reps: 12,
        ),
        PrescribedSet(
          exerciseId: 'hip_thrust',
          order: 2,
          weightKg: 20,
          reps: 12,
        ),
      ],
    );

    await tester.pumpWidget(_host(const MidSetView(move: move)));
    await tester.pumpAndSettle();

    expect(find.textContaining('20.0'), findsNothing);
    expect(find.text('Done · 20 kg × 12'), findsOneWidget);
  });

  testWidgets('P1-RULE-01 — nothing on the screen can be pre-filled', (
    tester,
  ) async {
    // The prescription is shown. There is no field holding what she did, empty
    // or otherwise, so there is nothing for a helpful default to fill in.
    await tester.pumpWidget(_host(const MidSetView()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('P0-LOG-01 — one tap logs the set', (tester) async {
    final bus = LogCommandBus();
    final repository = InMemoryTrainRepository();
    final handles = <LogHandle>[];

    await tester.pumpWidget(
      _host(
        MidSetView(bus: bus, repository: repository, onSetLogged: handles.add),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one tap. The button names what it will save.
    await tester.tap(find.text('Done · 12 kg × 10'));
    await tester.pump();

    expect(handles, hasLength(1));
    // The snackbar names the same numbers the button named.
    expect(handles.single.describe, 'Set 2 saved · 12 kg × 10');

    // Still inside the undo window, so nothing has reached the server.
    expect(repository.flushes, isEmpty);

    await tester.pump(const Duration(seconds: 6));
    expect(repository.flushes, hasLength(1));
    expect(repository.flushes.single.exerciseId, 'goblet_squat');
    expect(repository.flushes.single.sets, hasLength(1));

    // What was recorded is what the button said, and the prescription is intact.
    final logged = repository.flushes.single.sets.single;
    expect(logged.outcome!.weightKg, 12);
    expect(logged.outcome!.reps, 10);
    expect(logged.prescribed.weightKg, 12);

    bus.dispose();
  });

  testWidgets('P1-RULE-09 — logging never raises a dialog', (tester) async {
    final bus = LogCommandBus();
    await tester.pumpWidget(_host(MidSetView(bus: bus)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done · 12 kg × 10'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Are you sure'), findsNothing);

    bus.dispose();
  });

  testWidgets('undo inside the window means nothing is ever written', (
    tester,
  ) async {
    final bus = LogCommandBus();
    final repository = InMemoryTrainRepository();
    final handles = <LogHandle>[];

    await tester.pumpWidget(
      _host(
        MidSetView(bus: bus, repository: repository, onSetLogged: handles.add),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done · 12 kg × 10'));
    await tester.pump(const Duration(seconds: 2));

    expect(handles.single.undo(), isTrue);
    await tester.pump(const Duration(seconds: 10));

    expect(
      repository.flushes,
      isEmpty,
      reason:
          'the write never left the device, so there is nothing queued '
          'to resurface when she reconnects',
    );

    bus.dispose();
  });

  testWidgets(
    'P0-LOG-03 — the whole move in one tap, and the session goes on',
    (tester) async {
      final bus = LogCommandBus();
      final repository = InMemoryTrainRepository();
      final moveHandles = <LogHandle>[];
      final setHandles = <LogHandle>[];

      await tester.pumpWidget(
        _host(
          MidSetView(
            bus: bus,
            repository: repository,
            onMoveLogged: moveHandles.add,
            onSetLogged: setHandles.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await pickMore(tester, 'I did all 3 sets');
      await tester.pump(const Duration(seconds: 6));

      expect(moveHandles, hasLength(1));
      expect(setHandles, isEmpty, reason: 'this is a move, not a single set');
      expect(
        repository.flushes,
        hasLength(1),
        reason: 'one write per move, not one per set',
      );
      expect(repository.flushes.single.sets, hasLength(3));
      expect(repository.flushes.single.sets.every((s) => s.isLogged), isTrue);

      bus.dispose();
    },
  );

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const MidSetView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('الحركة 2 من 5'), findsNothing);
    expect(find.text('تمام · 12 كجم × 10'), findsOneWidget);
    expect(find.textContaining('لسه مفيش سجل'), findsNothing);
    expect(find.text('المجموعة 2 من 3'), findsOneWidget);
    expect(await moreRow(tester, 'خلّصت الـ 3 مجموعات'), isNotNull);
    expect(find.text('Done · 12 kg × 10'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MidSetView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the button she taps between breaths must never be clipped',
    );
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the Pause sheet, its "…" and the note sheet fit at text scale '
        '2.0 in ${locale.languageCode}', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const MidSetView(), locale: locale, textScale: 2),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(MidSetView)));

      final row = await moreRow(tester, l10n.addNote);
      expect(row, isNotNull);
      expect(tester.getSize(row!).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(RegExp(l10n.addNote)), findsWidgets);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r07-note-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('r07-note-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('the top bar has only Pause, and Pause has Resume and End', (
    tester,
  ) async {
    var ended = 0;
    await tester.pumpWidget(
      _host(
        MidSetView(
          end: SessionEnd(
            setsLogged: 0,
            onFinish: () {},
            onDiscard: () => ended++,
          ),
          onClose: () {},
          onChange: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-end')), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byKey(const ValueKey('r07-change')), findsNothing);
    expect(find.text('Resume'), findsNothing);

    await openPause(tester);
    expect(find.byKey(const ValueKey('pause-resume')), findsOneWidget);
    expect(find.text('End workout'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pause-resume')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pause-resume')), findsNothing);

    await openPause(tester);
    await tester.tap(find.byKey(const ValueKey('pause-end')));
    await tester.pumpAndSettle();
    // Nothing logged yet, so End offers Discard and Keep going.
    await tester.tap(find.byKey(const ValueKey('end-discard')));
    await tester.pumpAndSettle();
    expect(ended, 1);
  });

  testWidgets('the "Tap Change" hint comes with the Change it names', (
    tester,
  ) async {
    var changed = 0;
    PlannedMove loaded({double? kg}) => PlannedMove(
      exerciseId: 'goblet_squat',
      name: 'Goblet squat',
      prescriptionLabel: '3 × 10',
      sets: [
        for (var i = 1; i <= 3; i++)
          PrescribedSet(
            exerciseId: 'goblet_squat',
            order: i,
            reps: 10,
            weightKg: kg,
          ),
      ],
    );
    const hint =
        'Tap Change to add the weight you lifted, so next time starts from it.';
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: loaded(),
          progressionLine: hint,
          onChange: () => changed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('r07-add-weight')));
    await tester.pump();
    expect(changed, 1);

    // A second session with reps only: her last result stays beside the hint.
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: loaded(),
          progressionLine: hint,
          lastLogged: const SetOutcome(reps: 10),
          onChange: () => changed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r07-last-time')), findsOneWidget);
    expect(find.byKey(const ValueKey('r07-add-weight')), findsOneWidget);

    // With a weight on the set there is nothing to add, so no button.
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: loaded(kg: 12),
          progressionLine: 'Last time you did 12 kg × 10. Stay there.',
          onChange: () => changed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r07-add-weight')), findsNothing);
  });

  testWidgets('every other tool is in the "…": change, all moves, cues', (
    tester,
  ) async {
    var changed = 0;
    var allMoves = 0;
    await tester.pumpWidget(
      _host(
        MidSetView(
          onChange: () => changed++,
          onClose: () => allMoves++,
          move: PlannedMove(
            exerciseId: 'glute_bridge',
            name: 'Glute bridge',
            prescriptionLabel: '3 × 12',
            cues: const ['Ribs down'],
            sets: [
              for (var i = 1; i <= 3; i++)
                PrescribedSet(exerciseId: 'glute_bridge', order: i, reps: 12),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ribs down'), findsNothing);

    await pickMore(tester, 'Change');
    expect(changed, 1);
    await pickMore(tester, 'All moves');
    expect(allMoves, 1);
    await pickMore(tester, 'Form cues');
    expect(find.text('Ribs down'), findsOneWidget);
  });
}
