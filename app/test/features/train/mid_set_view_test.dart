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
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
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

void main() {
  testWidgets('states the set, the numbers and why they moved', (tester) async {
    await tester.pumpWidget(_host(const MidSetView()));
    await tester.pumpAndSettle();

    expect(find.text('Move 2 of 5'), findsOneWidget);
    expect(find.text('Goblet squat'), findsOneWidget);
    // Was "Set 2 of 3" from a fixed string, whatever the move prescribed; it
    // is now counted off `move.sets`, which is also what draws the rows below.
    expect(find.text('2 of 3'), findsWidgets);
    // Progression explains itself rather than arriving as a number she did not
    // ask for.
    expect(find.textContaining('Last Tuesday'), findsOneWidget);
    expect(find.text('This move'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

      await tester.tap(find.text('I did all 3 sets, log them'));
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

    expect(find.text('التمرين 2 من 5'), findsOneWidget);
    expect(find.text('تمّ · 12 كجم × 10'), findsOneWidget);
    expect(find.text('أدّيتُ المجموعات الثلاث، سجّليها'), findsOneWidget);
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
}
