// R04 — Exercise video.
//
// The assertion that matters most here is about what is NOT there: the 124 demo
// loops do not exist, so this screen must show a deliberate placeholder and must
// never reach for a URL of its own.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/exercise_video_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';

import '../../helpers/exercise_library_fixture.dart';

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
  testWidgets('three cues, not a paragraph', (tester) async {
    await tester.pumpWidget(_host(const ExerciseVideoView()));
    await tester.pumpAndSettle();

    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Heels flat, knees out over your toes'), findsOneWidget);
    expect(find.text('Chest up, weight held at your chest'), findsOneWidget);
    expect(find.text('Stand up strong, squeeze at the top'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the quieter alternative is offered before she asks', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ExerciseVideoView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Knees sore?'), findsOneWidget);
    expect(find.text('Swap this move'), findsOneWidget);
  });

  testWidgets('shows a placeholder, because the footage does not exist yet', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ExerciseVideoView()));
    await tester.pumpAndSettle();

    // A deliberate placeholder, not a broken image and not a network fetch.
    expect(find.byType(AppMedia), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('asks the repository for the asset rather than inventing a URL', (
    tester,
  ) async {
    // If this screen ever built its own Storage URL it would cost roughly
    // $1,352/month in egress, which is why delivery lives behind an interface.
    const videos = UnreleasedVideoRepository();
    expect(videos.urlFor('goblet_squat_540p'), isNull);
    expect(videos.isDownloaded('goblet_squat_540p'), isFalse);

    await tester.pumpWidget(_host(const ExerciseVideoView(videos: videos)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the duration is a formatted value, in Western digits', (
    tester,
  ) async {
    // P0-A11Y-01: "0:24" stays "0:24" in Arabic. There is no dictionary key for
    // a clock, and there should not be — there is nothing in it to translate.
    await tester.pumpWidget(
      _host(
        const ExerciseVideoView(duration: Duration(seconds: 24)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0:24'), findsOneWidget);
  });

  testWidgets('both actions fire', (tester) async {
    var back = 0;
    var swap = 0;
    await tester.pumpWidget(
      _host(
        ExerciseVideoView(onBackToWorkout: () => back++, onSwap: () => swap++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to the workout'));
    await tester.tap(find.text('Swap this move'));
    await tester.pumpAndSettle();

    expect(back, 1);
    expect(swap, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const ExerciseVideoView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('القرفصاء بالدمبل'), findsOneWidget);
    expect(find.text('ارجعي للتمرين'), findsOneWidget);
    expect(find.text('Back to the workout'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ExerciseVideoView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a move the library holds plays its clip inside the frame', (
    tester,
  ) async {
    FakeClipPlayer.made.clear();
    final bridge = sampleExerciseLibrary().byId('glute_bridge')!;
    await tester.pumpWidget(
      _host(
        ExerciseVideoView(
          clip: bridge,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clip = find.byKey(const ValueKey('fake-clip'));
    expect(clip, findsOneWidget);
    expect(
      find.ancestor(of: clip, matching: find.byType(AppMedia)),
      findsOneWidget,
    );
    expect(FakeClipPlayer.made.single.plays, 1);
  });

  testWidgets('no swap is offered when there is nothing to swap in', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ExerciseVideoView(canSwap: false)));
    await tester.pumpAndSettle();

    expect(find.text('Swap this move'), findsNothing);
  });
}
