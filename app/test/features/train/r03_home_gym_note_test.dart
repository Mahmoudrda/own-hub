// R03 for a woman who trains at home only: a day that holds a gym machine move
// says so in one line and offers Swap on the first of them. A day with none, or
// a woman who trains at a gym, sees nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

PlannedMove _move(String id, String name) => PlannedMove(
  exerciseId: id,
  name: name,
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

WorkoutDay _day(List<PlannedMove> moves) => WorkoutDay(
  id: '2026-10-22',
  title: 'Upper',
  summary: '45 minutes, ${moves.length} moves',
  constraints: 'Gym',
  moves: moves,
);

final _withMachine = [
  _move('goblet_squat', 'Goblet squat'),
  _move('lat_pulldown_wide', 'Lat pulldown'),
  _move('seated_cable_row', 'Seated row'),
];
final _noMachine = [
  _move('goblet_squat', 'Goblet squat'),
  _move('plank', 'Plank'),
];

const _machines = {'lat_pulldown_wide', 'seated_cable_row'};

Widget _view(
  List<PlannedMove> moves, {
  bool homeOnly = true,
  String locale = 'en',
  double scale = 1,
}) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(Locale(locale)),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: StatefulBuilder(
        builder: (context, setState) => WorkoutDayView(
          day: _day(moves),
          homeOnly: homeOnly,
          usesGymMachine: _machines.contains,
          onMovesChanged: (_) {},
          alternativesFor: (_) async => const [
            MoveAlternative(
              exerciseId: 'push_up',
              name: 'Push-up',
              reason: 'Same pattern at home',
            ),
          ],
          onStart: () {},
        ),
      ),
    ),
  );
}

void _tall(WidgetTester tester, {Size size = const Size(800, 3000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _note =
    'This day uses gym machines. Swap a move for one you can do at home.';

void main() {
  testWidgets('a home-only woman is told, with a Swap on the machine move', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_view(_withMachine));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-gym-note')), findsOneWidget);
    expect(find.text(_note), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('r03-gym-swap')));
    await tester.pumpAndSettle();
    // Edit workout is on, and the swap sheet is open on the first machine move.
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('r03-edit-toggle')))
          .value,
      isTrue,
    );
    expect(find.text('Swap this move'), findsOneWidget);
    expect(find.text('Push-up'), findsWidgets);
  });

  testWidgets('no note at the gym, and none when no move is a machine', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_view(_withMachine, homeOnly: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-gym-note')), findsNothing);

    await tester.pumpWidget(_view(_noMachine));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-gym-note')), findsNothing);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('the note fits a phone at text scale 2.0 in $locale', (
      tester,
    ) async {
      _tall(tester, size: const Size(390, 844));
      await tester.pumpWidget(_view(_withMachine, locale: locale, scale: 2));
      await tester.pumpAndSettle();
      final swap = find.byKey(const ValueKey('r03-gym-swap'));
      await tester.ensureVisible(swap);
      expect(tester.getSize(swap).height, greaterThanOrEqualTo(48));
      expect(
        Directionality.of(tester.element(swap)),
        locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
