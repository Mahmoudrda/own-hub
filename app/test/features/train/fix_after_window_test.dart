// After the five seconds she can still put a set right, and end a session only
// on purpose.
//
// R13's list of moves opens a logged move's sets on R08, which replaces the set
// instead of logging it again. R08 closed without saving goes back rather than
// leaving a blank page. "Finish here" asks for a second tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/features/train/presentation/logged_from_memory_view.dart';
import 'package:own_hub/features/train/presentation/move_logged_view.dart';
import 'package:own_hub/features/train/presentation/session_removal.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

const PrescribedSet _one = PrescribedSet(
  exerciseId: 'glute_bridge',
  order: 1,
  reps: 12,
);
const PrescribedSet _two = PrescribedSet(
  exerciseId: 'glute_bridge',
  order: 2,
  reps: 12,
);

const List<PlannedMove> _moves = [
  PlannedMove(
    exerciseId: 'glute_bridge',
    name: 'Glute bridge',
    prescriptionLabel: '2 × 12',
    sets: [_one, _two],
  ),
  PlannedMove(
    exerciseId: 'dead_bug',
    name: 'Dead bug',
    prescriptionLabel: '2 × 8',
    sets: [],
  ),
];

void main() {
  group('R13 opens a logged move to change a set', () {
    testWidgets('one set goes straight to R08', (tester) async {
      LoggedSet? opened;
      await tester.pumpWidget(
        _host(
          MoveLoggedView(
            moves: _moves,
            loggedCount: 1,
            editableSets: (_) async => [
              LoggedSet(prescribed: _one).recording(const SetOutcome(reps: 12)),
            ],
            onEditSet: (_, set) => opened = set,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tap a move you logged to change a set.'), findsOne);
      await tester.tap(find.text('Glute bridge'));
      await tester.pumpAndSettle();
      expect(opened?.prescribed.order, 1);
    });

    testWidgets('several sets are offered by number first', (tester) async {
      LoggedSet? opened;
      await tester.pumpWidget(
        _host(
          MoveLoggedView(
            moves: _moves,
            loggedCount: 1,
            editableSets: (_) async => [
              LoggedSet(prescribed: _one).recording(const SetOutcome(reps: 12)),
              LoggedSet(prescribed: _two).recording(const SetOutcome(reps: 10)),
            ],
            onEditSet: (_, set) => opened = set,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Glute bridge'));
      await tester.pumpAndSettle();
      expect(find.text('Which set?'), findsOneWidget);
      await tester.tap(find.text('Set 2 saved · 10 reps'));
      await tester.pumpAndSettle();
      expect(opened?.prescribed.order, 2);
    });

    testWidgets('a move not logged yet opens nothing', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        _host(
          MoveLoggedView(
            moves: _moves,
            loggedCount: 1,
            editableSets: (_) async {
              asked++;
              return const <LoggedSet>[];
            },
            onEditSet: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dead bug'));
      await tester.pumpAndSettle();
      expect(asked, 0);
    });
  });

  group('R08 correcting a logged set', () {
    testWidgets('replaces the set once the window closes', (tester) async {
      final repository = InMemoryTrainRepository();
      await repository.flushMove(
        sessionId: 's',
        exerciseId: 'glute_bridge',
        sets: [
          LoggedSet(prescribed: _one).recording(const SetOutcome(reps: 12)),
        ],
      );
      LogHandle? handle;
      await tester.pumpWidget(
        _host(
          ChangeSetView(
            correcting: true,
            repository: repository,
            sessionId: 's',
            prescribed: _one,
            moveName: 'Glute bridge',
            weightOptionsKg: const <double>[],
            onSaved: (h) => handle = h,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · 10 reps'));
      await tester.pumpAndSettle();
      expect(handle?.describe, 'Set 1 saved · 10 reps');

      await tester.pump(const Duration(seconds: 6));
      expect(repository.flushes, hasLength(1));
      expect(
        repository
            .loggedSetsFor(sessionId: 's', exerciseId: 'glute_bridge')
            .single
            .outcome!
            .reps,
        10,
      );
    });

    testWidgets('closing the sheet without saving goes back', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_host(ChangeSetView(onClose: () => closed++)));
      await tester.pumpAndSettle();
      expect(find.text('What did you do?'), findsOneWidget);

      // Dismiss the sheet the way she would: tap the scrim above it.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });
  });

  group('R13 Finish here', () {
    testWidgets('asks for a second tap, naming what is left', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(
          MoveLoggedView(
            moves: _moves,
            loggedCount: 1,
            onFinishHere: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish here'));
      await tester.pump();
      expect(finished, 0);
      expect(find.text('Finish now · 1 moves left'), findsOneWidget);

      await tester.tap(find.text('Finish now · 1 moves left'));
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('stands down on its own', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(
          MoveLoggedView(
            moves: _moves,
            loggedCount: 1,
            onFinishHere: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish here'));
      await tester.pump(kFinishHereArmed + const Duration(milliseconds: 100));
      expect(find.text('Finish here'), findsOneWidget);
      expect(finished, 0);
    });
  });

  group('removing a logged session', () {
    testWidgets('R10 and R12 offer it only when told how', (tester) async {
      await tester.pumpWidget(_host(const LoggedFromMemoryView()));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session'), findsNothing);

      await tester.pumpWidget(_host(LoggedFromMemoryView(onRemove: () {})));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session'), findsOneWidget);

      await tester.pumpWidget(_host(FinishedView(onRemove: () {})));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Remove this session'), findsOneWidget);
    });

    testWidgets('asks first, then removes with Undo', (tester) async {
      final bus = LogCommandBus();
      addTearDown(bus.dispose);
      var removed = 0;
      var left = 0;
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => removeSessionWithUndo(
                  context,
                  bus: bus,
                  describe: 'Session removed · your week is at 0 of 3',
                  commit: () async => removed++,
                  then: () => left++,
                ),
                child: const Text('remove'),
              ),
            ),
          ),
        ),
      );

      // Keeping it is the filled answer, and keeps it.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this session?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(left, 0);

      // Removing offers Undo, and Undo means nothing was removed.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove it'));
      await tester.pump();
      // The sheet's own exit, then the bar's entrance.
      await tester.pump(const Duration(milliseconds: 600));
      expect(left, 1);
      expect(
        find.text('Session removed · your week is at 0 of 3'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));
      expect(removed, 0);

      // Left alone, the removal lands when the window closes.
      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove it'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(removed, 1);
    });
  });
}
