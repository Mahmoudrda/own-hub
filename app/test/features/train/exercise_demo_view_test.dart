// R15: one move's clip inside the page's own frame. Poster first, then the
// clip, muted and looping with no controls; a tap pauses it; two angles when
// there are two; an honest line when it needs a connection.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/presentation/exercise_clip_frame.dart';
import 'package:own_hub/features/train/presentation/exercise_demo_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';

import '../../helpers/exercise_library_fixture.dart';
import '../../helpers/primary_actions.dart';

Widget _host(
  Widget child, {
  bool motionOff = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: motionOff,
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Poster fetches that wait until the test lets them go.
class _SlowPosters extends FakeExerciseMedia {
  final Map<String, Completer<File?>> _held = {};

  @override
  Future<File?> fetch(ExerciseMedia media) {
    if (!media.path.endsWith('.webp')) return super.fetch(media);
    return (_held[media.path] ??= Completer<File?>()).future;
  }

  void release(String path) => _held[path]?.complete(
    File('${Directory.systemTemp.path}/ownhub_fake_${path.split('/').last}'),
  );
}

/// A clip that never arrives, and a download the test can move along.
class _StuckClip extends FakeExerciseMedia {
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  @override
  Future<File?> fetch(ExerciseMedia media) {
    if (media.path.endsWith('.webp')) return super.fetch(media);
    return Completer<File?>().future;
  }

  @override
  ValueListenable<double?> progressOf(ExerciseMedia media) => progress;
}

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    FakeClipPlayer.made.clear();
  });
  tearDown(() => AppRouter.featureFlags = saved);

  final library = sampleExerciseLibrary();
  final pulldown = library.byId('lat_pulldown_wide')!;
  final bridge = library.byId('glute_bridge')!;

  testWidgets(
    'the clip plays inside the page frame, muted by its player, with no controls',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ExerciseDemoView(
            exercise: bridge,
            media: FakeExerciseMedia(),
            players: FakeClipPlayer.make,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final player = FakeClipPlayer.made.single;
      expect(player.opened, isNotNull);
      expect(
        player.plays,
        1,
        reason: 'it starts by itself when motion is allowed',
      );
      final clip = find.byKey(const ValueKey('fake-clip'));
      expect(clip, findsOneWidget);
      expect(
        find.ancestor(of: clip, matching: find.byType(AppMedia)),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Glute bridge'), findsOneWidget);
      expect(find.text('Glutes'), findsOneWidget);
      expect(find.text('Back of thighs'), findsOneWidget);
      expect(find.text('Floor only'), findsOneWidget);
      expect(find.text('Home or gym'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expectAtMostOnePrimaryAction(tester, where: 'R15');
    },
  );

  testWidgets(
    'a tap pauses it under the app\'s play mark, and plays it again',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ExerciseDemoView(
            exercise: bridge,
            media: FakeExerciseMedia(),
            players: FakeClipPlayer.make,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final player = FakeClipPlayer.made.single;
      await tester.tap(find.byKey(const ValueKey('r15-clip')));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(
        tester.widget<AppMedia>(find.byType(AppMedia)).playOverChild,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('r15-clip')));
      await tester.pumpAndSettle();
      expect(player.playing, isTrue);
    },
  );

  testWidgets('with Reduce Motion it waits for her tap', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: bridge,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
        motionOff: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made.single.plays, 0);
    expect(
      tester.widget<AppMedia>(find.byType(AppMedia)).playOverChild,
      isTrue,
    );
  });

  testWidgets('two angles: a switch, and the old clip is let go', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: pulldown,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r15-angles')), findsOneWidget);
    await tester.tap(find.text('Side'));
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made, hasLength(2));
    expect(FakeClipPlayer.made.first.disposed, isTrue);
    expect(
      FakeClipPlayer.made.last.opened!.path,
      endsWith('lat_pulldown_wide_side_bbbb2222.mp4'),
    );
  });

  testWidgets(
    'a redraw with the same move keeps its clip; changed files start it again',
    (tester) async {
      _phone(tester);
      final media = FakeExerciseMedia();
      Widget page(LibraryExercise e) => _host(
        ExerciseDemoView(
          exercise: e,
          media: media,
          players: FakeClipPlayer.make,
        ),
      );
      await tester.pumpWidget(page(bridge));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(bridge));
      await tester.pumpAndSettle();
      expect(
        FakeClipPlayer.made,
        hasLength(1),
        reason: 'shared state redrew the page; nothing changed',
      );
      expect(FakeClipPlayer.made.single.disposed, isFalse);

      final corrected = LibraryExercise(
        id: bridge.id,
        nameEn: bridge.nameEn,
        nameAr: bridge.nameAr,
        kind: bridge.kind,
        primaryMuscles: bridge.primaryMuscles,
        secondaryMuscles: bridge.secondaryMuscles,
        bodyRegion: bridge.bodyRegion,
        pattern: bridge.pattern,
        equipment: bridge.equipment,
        place: bridge.place,
        level: bridge.level,
        quiet: bridge.quiet,
        floorOnly: bridge.floorOnly,
        tags: bridge.tags,
        clips: [
          ExerciseClip(
            media: const ExerciseMedia(
              path: 'content/exercises/glute_bridge/glute_bridge_front_cccc3333.mp4',
              bytes: 1000,
            ),
            angle: ClipAngle.front,
            seconds: 6,
          ),
        ],
        poster: bridge.poster,
      );
      await tester.pumpWidget(page(corrected));
      await tester.pumpAndSettle();
      expect(FakeClipPlayer.made, hasLength(2));
      expect(FakeClipPlayer.made.first.disposed, isTrue);
      expect(
        FakeClipPlayer.made.last.opened!.path,
        endsWith('glute_bridge_front_cccc3333.mp4'),
      );
    },
  );

  testWidgets('a slow poster for the move she left never lands on the next', (
    tester,
  ) async {
    _phone(tester);
    final media = _SlowPosters();
    Widget page(LibraryExercise e) =>
        _host(ExerciseDemoView(exercise: e, media: media));
    await tester.pumpWidget(page(bridge));
    await tester.pump();
    await tester.pumpWidget(page(pulldown));
    await tester.pump();
    media.release(bridge.poster.path);
    await tester.pump();
    await tester.pump();
    final shown = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<FileImage>();
    expect(shown.where((i) => i.file.path.contains('glute_bridge')), isEmpty);
  });

  testWidgets('one angle: no switch', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: bridge,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r15-angles')), findsNothing);
  });

  testWidgets(
    'no connection the first time: it says so and offers to try again',
    (tester) async {
      _phone(tester);
      final media = FakeExerciseMedia(fetchable: false);
      await tester.pumpWidget(
        _host(
          ExerciseDemoView(
            exercise: bridge,
            media: media,
            players: FakeClipPlayer.make,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('needs a connection the first time'),
        findsOneWidget,
      );
      expect(FakeClipPlayer.made, isEmpty);
      media.fetchable = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('needs a connection the first time'),
        findsNothing,
      );
      expect(FakeClipPlayer.made.single.opened, isNotNull);
    },
  );

  testWidgets('leaving the page lets the clip go', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: bridge,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(FakeClipPlayer.made.single.disposed, isTrue);
  });

  testWidgets('with no move to show, one way back to the library', (
    tester,
  ) async {
    _phone(tester);
    var opened = 0;
    await tester.pumpWidget(
      _host(ExerciseDemoView(onOpenLibrary: () => opened++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a move from the library'), findsOneWidget);
    await tester.tap(find.text('Open the exercise library'));
    expect(opened, 1);
  });

  testWidgets('Arabic at 1.6x: nothing overflows', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: pulldown,
          media: FakeExerciseMedia(),
          players: FakeClipPlayer.make,
        ),
        locale: const Locale('ar'),
        scale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Lat pulldown, wide grip'), findsOneWidget);
    expect(find.text('لات بول داون مسكة واسعة'), findsNothing);
  });

  testWidgets('a clip on the way shows how far it has come, and says so '
      'honestly when the connection is slow', (tester) async {
    _phone(tester);
    final media = _StuckClip();
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: bridge,
          media: media,
          players: FakeClipPlayer.make,
        ),
      ),
    );
    await tester.pump();
    final l10n = AppL10n.of(tester.element(find.byType(ExerciseDemoView)));

    expect(find.text(l10n.gettingTheVideo), findsOneWidget);
    LinearProgressIndicator bar() =>
        tester.widget(find.byKey(const ValueKey('clip-progress')));
    expect(bar().value, 0, reason: 'a bar at rest until the size is known');

    media.progress.value = 0.4;
    await tester.pump();
    expect(bar().value, 0.4);

    await tester.pump(ExerciseClipFrame.slowAfter);
    expect(find.text(l10n.slowConnectionStillGettingTheVideo), findsOneWidget);
    expect(find.text(l10n.gettingTheVideo), findsNothing);
  });

  testWidgets('the poster is decoded at the size it is drawn', (tester) async {
    _phone(tester);
    final dir = Directory.systemTemp.createTempSync('ownhub_poster_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      _host(
        ExerciseDemoView(
          exercise: bridge,
          media: FakeExerciseMedia(),
          players: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(find.byType(Image));
    final poster = images.where((i) => i.image is ResizeImage).toList();
    expect(poster, isNotEmpty, reason: 'a poster is drawn with a cacheWidth');
    expect((poster.first.image as ResizeImage).width, lessThan(1200));
  });
}
