// R03's Edit workout switch: every move shows Swap, Remove and a handle, there
// is an "Add a move" row, and a bar to save the day as a workout of hers or put
// it back. Swapping shows the move's video first. After a change to a day she
// keeps she is asked once whether to update it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/exercise_library_fixture.dart';

PlannedMove _move(String id, String name, {int reps = 10, int? restSeconds}) =>
    PlannedMove(
      exerciseId: id,
      name: name,
      prescriptionLabel: '3 × $reps',
      restSeconds: restSeconds,
      sets: [
        for (var i = 1; i <= 3; i++)
          PrescribedSet(exerciseId: id, order: i, reps: reps),
      ],
    );

WorkoutDay _day(List<PlannedMove> moves) => WorkoutDay(
  id: '2026-10-21',
  title: 'Lower',
  summary: '15 minutes, ${moves.length} moves',
  constraints: 'Gym',
  moves: moves,
);

final _three = [
  _move('glute_bridge', 'Glute bridge'),
  _move('lat_pulldown_wide', 'Lat pulldown'),
  _move('dumbbell_hammer_curl', 'Hammer curl'),
];

/// Feeds the edited moves back the way the router does.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    this.start = false,
    this.kind,
    this.onUpdate,
    this.onSave,
    this.onEditStarted,
    this.moves,
  });

  final bool start;
  final SavedKind? kind;
  final bool Function(List<PlannedMove>)? onUpdate;
  final ValueChanged<List<PlannedMove>>? onSave;
  final VoidCallback? onEditStarted;
  final List<PlannedMove>? moves;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late WorkoutDay day = _day(widget.moves ?? _three);
  int started = 0;
  List<PlannedMove> latest = const [];

  @override
  Widget build(BuildContext context) {
    final library = sampleExerciseLibrary();
    return WorkoutDayView(
      day: day,
      startInEditMode: widget.start,
      onEditModeStarted: widget.onEditStarted,
      savedKind: widget.kind,
      onUpdateSaved: widget.onUpdate,
      onSaveAsMine: widget.onSave ?? (_) {},
      onMovesChanged: (moves) => setState(() {
        latest = moves;
        day = _day(moves);
      }),
      onPickMoves: () async => [_move('goblet_squat', 'Goblet squat')],
      onStart: () => started++,
      alternativesFor: (_) async => const [
        MoveAlternative(
          exerciseId: 'goblet_squat',
          name: 'Goblet squat',
          reason: 'Same pattern with a weight',
        ),
      ],
      exerciseFor: library.byId,
      media: FakeExerciseMedia(),
      players: FakeClipPlayer.make,
    );
  }
}

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

/// The five seconds of Undo run out, so the bar is not over the buttons.
Future<void> _letUndoGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _editOn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('r03-edit-toggle')));
  await tester.pumpAndSettle();
}

List<String> _names(WidgetTester tester) => [
  for (final n in [
    'Glute bridge',
    'Lat pulldown',
    'Hammer curl',
    'Goblet squat',
  ])
    if (find.text(n).evaluate().isNotEmpty) n,
];

void main() {
  setUp(FakeClipPlayer.made.clear);

  testWidgets('Edit workout is a switch at the top and starts off', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-edit-toggle')), findsOneWidget);
    expect(find.text('Edit workout'), findsOneWidget);
    expect(find.byKey(const ValueKey('r03-swap-0')), findsNothing);
    expect(find.byKey(const ValueKey('r03-reset')), findsNothing);
    expect(find.text("Start, everything's ready"), findsOneWidget);
  });

  testWidgets('on: Swap, Remove and a handle on every move, Add, Save, Reset', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);

    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('r03-swap-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('r03-remove-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('r03-handle-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('r03-edit-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('r03-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('r03-save-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('r03-reset')), findsOneWidget);
    // Start waits on the other side of the switch.
    expect(find.text("Start, everything's ready"), findsNothing);

    await _editOn(tester);
    expect(find.byKey(const ValueKey('r03-swap-0')), findsNothing);
    expect(find.text("Start, everything's ready"), findsOneWidget);
  });

  testWidgets('startInEditMode opens with it on and spends the request', (
    tester,
  ) async {
    _tall(tester);
    var spent = 0;
    await tester.pumpWidget(
      _host(_Harness(start: true, onEditStarted: () => spent++)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r03-remove-0')), findsOneWidget);
    expect(spent, 1);
  });

  testWidgets('Remove takes a move out and Undo brings it back', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);

    await tester.tap(find.byKey(const ValueKey('r03-remove-1')));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Glute bridge', 'Hammer curl']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Glute bridge', 'Lat pulldown', 'Hammer curl']);
    await _letUndoGo(tester);
  });

  testWidgets('the last move cannot be removed', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _host(_Harness(moves: [_move('glute_bridge', 'Glute bridge')])),
    );
    await tester.pumpAndSettle();
    await _editOn(tester);
    final remove = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('r03-remove-0')),
        matching: find.byType(TextButton),
      ),
    );
    expect(remove.onPressed, isNull);
  });

  testWidgets('Add a move appends the picked move', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);
    await tester.tap(find.byKey(const ValueKey('r03-add')));
    await tester.pumpAndSettle();
    expect(_names(tester), [
      'Glute bridge',
      'Lat pulldown',
      'Hammer curl',
      'Goblet squat',
    ]);
  });

  testWidgets('Swap shows the move’s video first, then Use this move', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);

    await tester.tap(find.byKey(const ValueKey('r03-swap-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('r03-swap-choice-goblet_squat')),
    );
    await tester.pumpAndSettle();

    // The video is in the sheet, and nothing has changed yet.
    expect(find.byKey(const ValueKey('move-preview')), findsOneWidget);
    expect(FakeClipPlayer.made, isNotEmpty);
    expect(find.text('Same pattern with a weight'), findsWidgets);
    expect(find.text('Glute bridge'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-preview-use')));
    await tester.pumpAndSettle();
    expect(find.text('Glute bridge'), findsNothing);
    expect(find.text('Goblet squat'), findsOneWidget);
    await _letUndoGo(tester);
  });

  testWidgets('a swapped move keeps the rest the plan gave it', (tester) async {
    _tall(tester);
    final key = GlobalKey<State<_Harness>>();
    await tester.pumpWidget(
      _host(
        _Harness(
          key: key,
          moves: [
            _move('glute_bridge', 'Glute bridge', restSeconds: 75),
            _move('lat_pulldown_wide', 'Lat pulldown'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _editOn(tester);
    await tester.tap(find.byKey(const ValueKey('r03-swap-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('r03-swap-choice-goblet_squat')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-preview-use')));
    await tester.pumpAndSettle();

    final latest = (key.currentState! as _HarnessState).latest;
    expect(latest.first.exerciseId, 'goblet_squat');
    expect(latest.first.restSeconds, 75);
    await _letUndoGo(tester);
  });

  testWidgets('reordering with the arrows moves a move and keeps its load', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);
    await tester.tap(find.byKey(const ValueKey('r03-edit-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-later')));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('Lat pulldown')).dy;
    final next = tester.getTopLeft(find.text('Glute bridge')).dy;
    expect(top, lessThan(next));
  });

  testWidgets('dragging the handle reorders', (tester) async {
    _tall(tester);
    final key = GlobalKey<State<_Harness>>();
    await tester.pumpWidget(_host(_Harness(key: key)));
    await tester.pumpAndSettle();
    await _editOn(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('r03-handle-0'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    for (var y = 0; y < 8; y++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final state = key.currentState! as _HarnessState;
    expect(state.latest.map((m) => m.exerciseId).first, isNot('glute_bridge'));
    expect(state.latest.map((m) => m.exerciseId).toSet().length, 3);
  });

  testWidgets('Reset puts the day back as it was when editing began', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_host(const _Harness()));
    await tester.pumpAndSettle();
    await _editOn(tester);
    await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
    await tester.pumpAndSettle();
    await _letUndoGo(tester);
    expect(_names(tester), ['Lat pulldown', 'Hammer curl']);

    await tester.tap(find.byKey(const ValueKey('r03-reset')));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Glute bridge', 'Lat pulldown', 'Hammer curl']);
  });

  testWidgets('Save as my workout hands over the edited moves', (tester) async {
    _tall(tester);
    List<PlannedMove>? saved;
    await tester.pumpWidget(_host(_Harness(onSave: (m) => saved = m)));
    await tester.pumpAndSettle();
    await _editOn(tester);
    await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
    await tester.pumpAndSettle();
    await _letUndoGo(tester);
    await tester.tap(find.byKey(const ValueKey('r03-save-mine')));
    expect(saved!.map((m) => m.exerciseId), [
      'lat_pulldown_wide',
      'dumbbell_hammer_curl',
    ]);
  });

  group('Update my saved workout?', () {
    testWidgets('Just this time updates nothing, and she is asked once', (
      tester,
    ) async {
      _tall(tester);
      var updates = 0;
      await tester.pumpWidget(
        _host(
          _Harness(
            kind: SavedKind.plan,
            onUpdate: (_) {
              updates++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);
      await _editOn(tester);

      expect(find.text('Update my plan?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('r03-update-no')));
      await tester.pumpAndSettle();
      expect(updates, 0);

      // Changing more does not ask again.
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);
      await _editOn(tester);
      expect(find.text('Update my plan?'), findsNothing);
      expect(updates, 0);
    });

    testWidgets('Update hands over the edited moves', (tester) async {
      _tall(tester);
      List<PlannedMove>? updated;
      await tester.pumpWidget(
        _host(
          _Harness(
            kind: SavedKind.workout,
            onUpdate: (m) {
              updated = m;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);
      await _editOn(tester);

      expect(find.text('Update my saved workout?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('r03-update-yes')));
      await tester.pumpAndSettle();
      expect(updated!.length, 2);
    });

    testWidgets('nothing kept, nothing announced', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(_Harness(kind: SavedKind.plan, onUpdate: (_) => false)),
      );
      await tester.pumpAndSettle();
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-update-yes')));
      await tester.pumpAndSettle();
      expect(find.text('Updated in your plan'), findsNothing);
      await _letUndoGo(tester);
    });

    testWidgets('going back with a change asks before it leaves', (
      tester,
    ) async {
      _tall(tester);
      var updates = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (home) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(home).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _Harness(
                      kind: SavedKind.plan,
                      onUpdate: (_) {
                        updates++;
                        return true;
                      },
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);

      unawaited(
        tester.state<NavigatorState>(find.byType(Navigator)).maybePop(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update my plan?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('r03-update-yes')));
      await tester.pumpAndSettle();
      expect(updates, 1);
      // She has left the screen.
      expect(find.byKey(const ValueKey('r03-edit-toggle')), findsNothing);
      await _letUndoGo(tester);
    });

    testWidgets('going back with nothing changed just goes', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (home) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(home).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _Harness(kind: SavedKind.plan, onUpdate: (_) => true),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      unawaited(
        tester.state<NavigatorState>(find.byType(Navigator)).maybePop(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update my plan?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('no change, no question', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(_Harness(kind: SavedKind.plan, onUpdate: (_) => true)),
      );
      await tester.pumpAndSettle();
      await _editOn(tester);
      await _editOn(tester);
      expect(find.text('Update my plan?'), findsNothing);
    });

    testWidgets('Start asks first when a change has not been asked about', (
      tester,
    ) async {
      _tall(tester);
      final key = GlobalKey<State<_Harness>>();
      await tester.pumpWidget(
        _host(_Harness(key: key, kind: SavedKind.plan, onUpdate: (_) => true)),
      );
      await tester.pumpAndSettle();
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await tester.pumpAndSettle();
      await _letUndoGo(tester);
      // Leave edit mode by the switch, answer, then start.
      await _editOn(tester);
      await tester.tap(find.byKey(const ValueKey('r03-update-no')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Start, everything's ready"));
      await tester.pumpAndSettle();
      expect((key.currentState! as _HarnessState).started, 1);
    });
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('edit mode fits a phone at text scale 2.0 in $locale', (
      tester,
    ) async {
      _tall(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        _host(const _Harness(start: true), locale: locale, scale: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r03-remove-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('r03-reset')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
