// R13 — Move logged.
//
// Implements the second half of P0-LOG-03. The assertion that matters is the one
// about what did NOT happen: logging a move must not end the session. Before
// this screen existed, the same tap declared the whole workout finished with
// three moves untrained.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/move_logged_view.dart';
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
  testWidgets('returns her to the list, with the move struck off', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MoveLoggedView()));
    await tester.pumpAndSettle();

    expect(find.text('Goblet squat saved · 3 sets'), findsOneWidget);
    // "2 of 5 moves done" was a fixed string; it is now counted off the same
    // list the rows below are drawn from.
    expect(find.text('2 of 5'), findsOneWidget);
    expect(find.text('Quiet · no equipment · floor'), findsOneWidget);
    // The whole list is still there, with the next move live.
    expect(find.text('Glute bridge'), findsOneWidget);
    expect(find.text('Step-back lunge'), findsOneWidget);
    expect(find.text('Hip thrust hold'), findsOneWidget);
    expect(find.text('Dead bug'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P0-LOG-03 — the session does not end', (tester) async {
    var next = 0;
    var finished = 0;

    await tester.pumpWidget(
      _host(
        MoveLoggedView(
          onNextMove: () => next++,
          onFinishHere: () => finished++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The primary action continues the session. Ending it is a separate,
    // quieter choice she has to make deliberately.
    //
    // The label names the move that is actually next, read off the same list
    // the rows are drawn from. It was the fixed `nextMoveStepBackLunge`, which
    // said "step-back lunge" with a goblet squat coming up and said it again
    // on the last move, when nothing was next at all.
    await tester.tap(find.text('Next move · Step-back lunge'));
    await tester.pumpAndSettle();

    expect(next, 1);
    expect(
      finished,
      0,
      reason: 'logging a move must never finish the workout for her',
    );
  });

  testWidgets('finishing early is offered, and still counts', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      _host(MoveLoggedView(onFinishHere: () => finished++)),
    );
    await tester.pumpAndSettle();

    // Ending early cannot be taken back, so the first tap says what is left
    // and the second one ends it.
    await tester.tap(find.text('Finish here'));
    await tester.pump();
    expect(finished, 0);
    await tester.tap(find.text('Finish now · 3 moves left'));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('on the last move the button stops naming a next one', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MoveLoggedView(loggedCount: 5)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Next move'), findsNothing);
    expect(find.text('Finish workout'), findsOneWidget);
  });

  testWidgets('the undo offer is identical to the one after a single set', (
    tester,
  ) async {
    final bus = LogCommandBus();
    final repository = InMemoryTrainRepository();
    var undone = 0;

    final handle = bus.submit(
      UndoableLog(
        describe: 'Goblet squat saved · 3 sets',
        commit: () => repository.flushMove(
          sessionId: 's',
          exerciseId: 'goblet_squat',
          sets: const [],
        ),
      ),
    );

    await tester.pumpWidget(
      _host(MoveLoggedView(handle: handle, onUndo: () => undone++)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(undone, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(repository.flushes, isEmpty);

    bus.dispose();
  });

  testWidgets('no dialog on the logging path', (tester) async {
    await tester.pumpWidget(_host(const MoveLoggedView()));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('the list comes from data, not from the widget', (tester) async {
    await tester.pumpWidget(
      _host(
        const MoveLoggedView(
          loggedCount: 1,
          moves: [
            PlannedMove(
              exerciseId: 'a',
              name: 'Wall sit',
              prescriptionLabel: '3 × 30 seconds',
              sets: [],
            ),
            PlannedMove(
              exerciseId: 'b',
              name: 'Bird dog',
              prescriptionLabel: '3 × 8 each side',
              sets: [],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wall sit'), findsOneWidget);
    expect(find.text('Bird dog'), findsOneWidget);
    expect(find.text('Glute bridge'), findsNothing);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const MoveLoggedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    // "تم حفظ" rather than "حُفظت". The message is now built from a template,
    // and an Arabic verb agrees in gender with its subject — which here is the
    // move name, and varies across all 124 of them. No single conjugation is
    // correct for every move, so the sentence is restructured to one that needs
    // no agreement at all.
    expect(find.text('حفظنا القرفصاء بالدمبل · 3 مجموعات'), findsOneWidget);
    expect(find.text('2 من 5'), findsOneWidget);
    expect(find.text('الحركة الجاية · لانج للخلف'), findsOneWidget);
    expect(find.text('Finish here'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MoveLoggedView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
