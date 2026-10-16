/// Plays the owner's real exercise clips inside the real app (R14, R15; D42),
/// on a simulator or a phone, through the platform player the app ships with.
///
/// Widget tests stand in a fake for the player; this is the check that the
/// clips themselves open, play and keep playing on the device's own decoder,
/// drawn inside the page's frame. The clips are read from the folder they were
/// uploaded from, so no account and no network are needed:
///
///   flutter test integration_test/exercise_clip_playback_test.dart -d DEVICE \
///     --dart-define=CLIPS=/path/to/upload \
///     --dart-define=CATALOGUE=/path/to/6-v2/content/exercise_library/catalogue.json
///
/// A simulator can read the host's files; a phone cannot, so on a phone the
/// folder must be copied into the app's documents first.
library;

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/data/exercise_media_store.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';
import 'package:video_player/video_player.dart';

const String _clips = String.fromEnvironment('CLIPS');
const String _catalogue = String.fromEnvironment('CATALOGUE');

/// The upload folder: `<id>/<file>` for every clip and poster.
class _Folder implements ExerciseMediaStore {
  const _Folder(this.root);

  final String root;

  File _file(ExerciseMedia media) {
    final rest = media.path.substring('$kExerciseMediaPrefix/'.length);
    return File('$root/$rest');
  }

  @override
  Future<File?> local(ExerciseMedia media) async {
    final file = _file(media);
    return await file.exists() && await file.length() == media.bytes ? file : null;
  }

  @override
  Future<File?> fetch(ExerciseMedia media) => local(media);

  @override
  ValueListenable<double?> progressOf(ExerciseMedia media) =>
      ValueNotifier<double?>(null);

  @override
  Future<void> keepOnly(Set<String> paths) async {}

  @override
  Future<void> eraseAll() async {}
}

/// The member library the publish tool would build, sizes read from the files.
ExerciseLibrary _library() {
  final catalogue = (jsonDecode(File(_catalogue).readAsStringSync()) as Map).cast<String, Object?>();
  int size(String id, String file) => File('$_clips/$id/$file').lengthSync();
  return ExerciseLibrary.parse({
    'version': 1,
    'exercises': [
      for (final r in (catalogue['exercises']! as List).cast<Map<String, Object?>>())
        {
          'id': r['exerciseId'],
          'nameEn': r['name_en'],
          'nameAr': r['name_ar'],
          'kind': r['kind'],
          'primaryMuscles': r['primaryMuscles'],
          'secondaryMuscles': r['secondaryMuscles'],
          'bodyRegion': r['bodyRegion'],
          'pattern': r['pattern'],
          'equipment': r['equipment'],
          'place': r['place'],
          'level': r['level'],
          'quiet': r['quiet'],
          'floorOnly': r['floorOnly'],
          'tags': r['contraindicationTags'],
          'clips': [
            for (final c in (r['clips']! as List).cast<Map<String, Object?>>())
              {
                'file': c['file'],
                'angle': c['angle'],
                'bytes': size(r['exerciseId']! as String, c['file']! as String),
                'seconds': c['seconds'],
              },
          ],
          'poster': {
            'file': (r['poster']! as Map)['file'],
            'bytes': size(r['exerciseId']! as String, (r['poster']! as Map)['file']! as String),
          },
        },
    ],
  })!;
}

Future<void> _wait(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every clip opens, plays and loops on the device player', (tester) async {
    expect(_clips, isNotEmpty, reason: 'pass --dart-define=CLIPS=');
    final library = _library();
    AppRouter.featureFlags = FeatureFlags.everything;
    ExerciseLibraryState.instance
      ..library = library
      ..media = _Folder(_clips);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
        initialRoute: appRoutes['R14']!.name,
      ),
    );
    await _wait(tester, const Duration(seconds: 2));
    // ignore: avoid_print
    print('CLIPCHECK|screen|R14|${library.exercises.length} moves');

    final failures = <String>[];
    var checked = 0;
    for (final exercise in library.exercises) {
      for (var angle = 0; angle < exercise.clips.length; angle++) {
        final clip = exercise.clips[angle];
        final file = await const _Folder(_clips).fetch(clip.media);
        if (file == null) {
          failures.add('${exercise.id}: file missing or wrong size');
          continue;
        }
        final controller = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        try {
          await controller.initialize();
          await controller.setVolume(0);
          await controller.setLooping(true);
          await controller.play();
          await _wait(tester, const Duration(milliseconds: 700));
          final value = controller.value;
          final ok = value.isInitialized &&
              !value.hasError &&
              value.isPlaying &&
              value.position > Duration.zero &&
              (value.size.width - 720).abs() < 1 &&
              (value.size.height - 1280).abs() < 1 &&
              (value.duration.inMilliseconds / 1000 - clip.seconds).abs() < 0.2;
          if (!ok) {
            failures.add(
              '${exercise.id}/${clip.angle.wireName}: init ${value.isInitialized} error ${value.errorDescription} '
              'playing ${value.isPlaying} at ${value.position} size ${value.size} length ${value.duration}',
            );
          }
          checked++;
        } catch (error) {
          failures.add('${exercise.id}/${clip.angle.wireName}: $error');
        } finally {
          await controller.dispose();
        }
      }
    }
    // ignore: avoid_print
    print('CLIPCHECK|clips|$checked played|${failures.length} failed');
    for (final f in failures) {
      // ignore: avoid_print
      print('CLIPCHECK|fail|$f');
    }
    expect(failures, isEmpty);

    // And one move through the screens, the way she reaches it: R14, a tap,
    // R15 with the clip playing inside the page's frame.
    final glutes = [
      for (final e in library.exercises)
        if (e.section == MuscleSection.glutes) e,
    ]..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    final first = glutes.first;
    await tester.ensureVisible(find.text(first.nameEn).first);
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text(first.nameEn).first);
    await _wait(tester, const Duration(seconds: 3));
    final player = find.byType(VideoPlayer);
    expect(player, findsOneWidget);
    expect(find.ancestor(of: player, matching: find.byType(AppMedia)), findsOneWidget);
    final controller = tester.widget<VideoPlayer>(player).controller;
    expect(controller.value.isPlaying, isTrue);
    expect(controller.value.volume, 0);
    // ignore: avoid_print
    print('CLIPCHECK|screen|R15|${first.id} playing at ${controller.value.position}');
    await _wait(tester, const Duration(seconds: 4));
    // ignore: avoid_print
    print('CLIPCHECK|screen|R15|still playing ${controller.value.isPlaying} at ${controller.value.position}');
    expect(controller.value.isPlaying, isTrue);
  });
}
