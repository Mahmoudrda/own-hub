// R07 — the move's clip, at the top of the page.
//
// A move the library holds plays in the page's own frame with its cues under
// it; a move it does not hold is the page as it was. A clip that will not play
// leaves no dead player behind, and a player is let go when the move changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/exercise_clip_frame.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/screen_art_strip.dart';

import '../../helpers/exercise_library_fixture.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

PlannedMove _move(String id, String name) => PlannedMove(
  exerciseId: id,
  name: name,
  prescriptionLabel: '3 × 10',
  cues: const ['Ribs down', 'Squeeze at the top'],
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

void main() {
  final library = sampleExerciseLibrary();

  setUp(FakeClipPlayer.made.clear);

  testWidgets('a move with a clip shows it, with its cues in a drawer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: _move('glute_bridge', 'Glute bridge'),
          clip: library.byId('glute_bridge'),
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseClipFrame), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('r07-clip'))).height, 220);
    expect(find.text('Form cues'), findsOneWidget);
    expect(find.text('Ribs down'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('r07-form-cues')));
    await tester.pumpAndSettle();
    expect(find.text('Ribs down'), findsOneWidget);
    expect(find.text('Squeeze at the top'), findsOneWidget);
  });

  testWidgets('a move with no clip is the page as it was', (tester) async {
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: _move('dead_bug', 'Dead bug'),
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseClipFrame), findsNothing);
    expect(find.text('Form cues'), findsNothing);
    expect(find.byType(ScreenArtStrip), findsNothing);
    expect(FakeClipPlayer.made, isEmpty);
  });

  testWidgets('a clip that will not play is replaced by the art', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: _move('glute_bridge', 'Glute bridge'),
          clip: library.byId('glute_bridge'),
          media: FakeExerciseMedia(fetchable: false),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseClipFrame), findsNothing);
    expect(find.byType(ScreenArtStrip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the player is let go when the move changes', (tester) async {
    final media = FakeExerciseMedia();
    Widget page(String id, String name) => _host(
      MidSetView(
        move: _move(id, name),
        clip: library.byId(id),
        media: media,
        players: FakeClipPlayer.make,
      ),
    );

    await tester.pumpWidget(page('glute_bridge', 'Glute bridge'));
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made, hasLength(1));
    expect(FakeClipPlayer.made.first.disposed, isFalse);

    await tester.pumpWidget(page('goblet_squat', 'Goblet squat'));
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made.first.disposed, isTrue);
    expect(FakeClipPlayer.made, hasLength(2));
    expect(FakeClipPlayer.made.last.disposed, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(FakeClipPlayer.made.last.disposed, isTrue);
  });

  testWidgets('a set screen covered by the next one lets its player go', (
    tester,
  ) async {
    final media = FakeExerciseMedia();
    await tester.pumpWidget(
      _host(
        MidSetView(
          move: _move('glute_bridge', 'Glute bridge'),
          clip: library.byId('glute_bridge'),
          media: media,
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // The same move's set screen is pushed again, as each set does, and then
    // a rest on top of that.
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MidSetView(
          move: _move('glute_bridge', 'Glute bridge'),
          clip: library.byId('glute_bridge'),
          media: media,
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made, hasLength(2));
    expect(FakeClipPlayer.made.first.disposed, isTrue);
    expect(FakeClipPlayer.made.last.disposed, isFalse);

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('resting')),
      ),
    );
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made.last.disposed, isTrue);
    expect(
      FakeClipPlayer.made.where((p) => !p.disposed),
      isEmpty,
      reason: 'no set screen under the rest keeps a clip looping',
    );

    navigator.pop();
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made.where((p) => !p.disposed), hasLength(1));
  });
}
