// R07: the note under the move name, the plate line (barbell moves only) and
// the History row. The note, the plates and History are in the Pause sheet's
// "…", so the set itself stays one figure and one button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/bar_preference.dart';
import 'package:own_hub/app_state/move_notes.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/change_set_view.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/pause_menu.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

final _move = PlannedMove(
  exerciseId: 'hip_thrust',
  name: 'Hip thrust',
  prescriptionLabel: '3 × 10 at 40 kg',
  needsEquipment: true,
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: 'hip_thrust', order: i, weightKg: 40, reps: 10),
  ],
);

void main() {
  setUp(() {
    MoveNotes.instance.reset();
    BarPreference.instance.reset();
  });
  tearDown(() {
    MoveNotes.instance.reset();
    BarPreference.instance.reset();
  });

  testWidgets('a barbell move shows the plate line and the picture', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MidSetView(move: _move, equipment: const [LibraryEquipment.barbell]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plate-diagram')), findsNothing);
    await pickMore(tester, 'Plates');
    expect(find.text('20 kg bar + 10 kg each side'), findsOneWidget);
    expect(find.byKey(const ValueKey('plate-diagram')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('plate-change-bar')))
          .shortestSide,
      greaterThanOrEqualTo(48),
    );
  });

  for (final equipment in <List<LibraryEquipment>?>[
    null,
    const [LibraryEquipment.machine],
    const [LibraryEquipment.dumbbells],
  ]) {
    testWidgets('no plate line for $equipment', (tester) async {
      await tester.pumpWidget(
        _host(MidSetView(move: _move, equipment: equipment)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plate-helper')), findsNothing);
      expect(find.textContaining('each side'), findsNothing);
      expect(await moreRow(tester, 'Plates'), isNull);
    });
  }

  testWidgets('the History row is there only with a callback', (tester) async {
    await tester.pumpWidget(_host(MidSetView(move: _move)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r07-history')), findsNothing);
    expect(await moreRow(tester, 'History'), isNull);
    await closeSheets(tester);

    var opened = 0;
    await tester.pumpWidget(
      _host(MidSetView(move: _move, onOpenHistory: () => opened++)),
    );
    await tester.pumpAndSettle();
    final row = await moreRow(tester, 'History');
    expect(row, isNotNull);
    expect(tester.getSize(row!).height, greaterThanOrEqualTo(48));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('add, edit and remove a note', (tester) async {
    await tester.pumpWidget(_host(MidSetView(move: _move)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r07-note-text')), findsNothing);

    await pickMore(tester, 'Add note');
    await tester.enterText(
      find.byKey(const ValueKey('r07-note-field')).last,
      '  seat 4, pin 3 ',
    );
    await tester.tap(find.byKey(const ValueKey('r07-note-save')));
    await tester.pumpAndSettle();
    expect(find.text('seat 4, pin 3'), findsOneWidget);
    expect(MoveNotes.instance.forMove('hip_thrust'), 'seat 4, pin 3');

    await pickMore(tester, 'Edit note');
    await tester.tap(find.byKey(const ValueKey('r07-note-remove')));
    await tester.pumpAndSettle();
    expect(MoveNotes.instance.forMove('hip_thrust'), isNull);
    expect(find.byKey(const ValueKey('r07-note-text')), findsNothing);
    expect(await moreRow(tester, 'Add note'), isNotNull);
  });

  testWidgets('a note already kept is shown under the name', (tester) async {
    MoveNotes.instance.setFor('hip_thrust', 'pad on the second hole');
    await tester.pumpWidget(
      _host(MidSetView(move: _move), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('pad on the second hole'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R08 shows the plate line for the chosen weight on a barbell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChangeSetView(
          prescribed: _move.sets.first,
          moveName: 'Hip thrust',
          weightOptionsKg: const [37.5, 40, 42.5],
          equipment: const [LibraryEquipment.barbell],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('20 kg bar + 10 kg each side'), findsOneWidget);
    await tester.tap(find.text('42.5 kg'));
    await tester.pumpAndSettle();
    expect(find.text('20 kg bar + 11.25 kg each side'), findsOneWidget);
  });
}
