// The clip player is written so a silent clip can never stop her music and
// never shows a player of its own. A widget test cannot reach the platform
// player, so this reads the source.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = File(
    'lib/features/train/presentation/exercise_clip_player.dart',
  ).readAsStringSync();

  test('muted, looping, mixed with her own audio', () {
    expect(player, contains('mixWithOthers: true'));
    expect(player, contains('setVolume(0)'));
    expect(player, contains('setLooping(true)'));
    expect(player, contains('VideoPlayerController.file('));
    expect(player, isNot(contains('VideoPlayerController.networkUrl')));
  });

  test('video_player is imported in that file alone, and no controls widget anywhere', () {
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('package:video_player/') &&
          !f.path.endsWith('exercise_clip_player.dart')) {
        offenders.add(f.path);
      }
      if (text.contains('VideoProgressIndicator') ||
          text.contains('package:chewie/')) {
        offenders.add('${f.path} (player controls)');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the clip store never asks for a download URL', () {
    final store = File('lib/features/train/data/exercise_media_store.dart')
        .readAsStringSync();
    expect(store, isNot(contains('getDownloadURL')));
    expect(store, contains('writeToFile'));
    expect(store, contains('getApplicationCacheDirectory'));
  });
}
