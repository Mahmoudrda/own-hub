// A small exercise library and fakes for the clip store and the player, so the
// exercise library's screens can be tested without a platform channel.

import 'package:flutter/foundation.dart';

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:own_hub/features/train/data/exercise_media_store.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/presentation/exercise_clip_player.dart';

Map<String, Object?> exerciseRow(
  String id, {
  String nameEn = 'Move',
  String nameAr = 'حركة',
  String kind = 'strength',
  List<String> primary = const ['glutes'],
  List<String> secondary = const [],
  String region = 'lower_body',
  String? pattern,
  List<String> equipment = const ['mat'],
  String place = 'both',
  String level = 'beginner',
  bool quiet = true,
  bool floorOnly = false,
  List<String> tags = const ['none'],
  int clips = 1,
}) => {
  'id': id,
  'nameEn': nameEn,
  'nameAr': nameAr,
  'kind': kind,
  'primaryMuscles': primary,
  'secondaryMuscles': secondary,
  'bodyRegion': region,
  'pattern': pattern ?? (kind == 'stretch' ? 'mobility' : 'squat'),
  'equipment': equipment,
  'place': place,
  'level': level,
  'quiet': quiet,
  'floorOnly': floorOnly,
  'tags': tags,
  'clips': [
    {
      'file': '${id}_front_aaaa1111.mp4',
      'angle': 'front',
      'bytes': 1000,
      'seconds': 6.0,
    },
    if (clips > 1)
      {
        'file': '${id}_side_bbbb2222.mp4',
        'angle': 'side',
        'bytes': 900,
        'seconds': 5.0,
      },
  ],
  'poster': {'file': '${id}_aaaa1111.webp', 'bytes': 100},
};

/// Six moves across four headings, one of them unsafe in pregnancy, one a
/// stretch, one gym-only on a machine, one with two angles.
ExerciseLibrary sampleExerciseLibrary() => ExerciseLibrary.parse({
  'version': 3,
  'schema': 1,
  'exercises': [
    exerciseRow(
      'glute_bridge',
      nameEn: 'Glute bridge',
      nameAr: 'جلوت بريدج',
      secondary: ['hamstrings'],
      pattern: 'hip_thrust_bridge',
      floorOnly: true,
      tags: ['supine_load'],
    ),
    exerciseRow(
      'goblet_squat',
      nameEn: 'Goblet squat',
      nameAr: 'جوبلت سكوات',
      primary: ['quads'],
      equipment: ['dumbbells'],
      tags: ['deep_knee_flexion'],
    ),
    exerciseRow(
      'lat_pulldown_wide',
      nameEn: 'Lat pulldown, wide grip',
      nameAr: 'لات بول داون مسكة واسعة',
      primary: ['lats'],
      secondary: ['biceps'],
      region: 'upper_body',
      pattern: 'pull_vertical',
      equipment: ['cable'],
      place: 'gym',
      clips: 2,
    ),
    exerciseRow(
      'standing_forward_fold',
      nameEn: 'Standing forward fold',
      nameAr: 'إطالة خلفية من الوقوف',
      kind: 'stretch',
      primary: ['hamstrings'],
      equipment: ['none'],
    ),
    exerciseRow(
      'band_pass_through',
      nameEn: 'Band shoulder pass-through',
      nameAr: 'باس ثرو للكتف بالأستك',
      kind: 'stretch',
      primary: ['front_delts'],
      region: 'upper_body',
      equipment: ['bands'],
    ),
    exerciseRow(
      'dumbbell_hammer_curl',
      nameEn: 'Dumbbell hammer curl',
      nameAr: 'هامر كيرل بالدمبل',
      primary: ['biceps', 'forearms'],
      region: 'upper_body',
      pattern: 'isolation_upper',
      equipment: ['dumbbells'],
      level: 'intermediate',
    ),
  ],
})!;

/// Files it "has", by path, and what it hands back when asked to fetch.
class FakeExerciseMedia implements ExerciseMediaStore {
  FakeExerciseMedia({this.fetchable = true});

  /// Whether a fetch succeeds. Flip it to test the offline state.
  bool fetchable;
  final List<String> fetched = <String>[];
  bool erased = false;
  Set<String>? kept;

  File _file(ExerciseMedia media) =>
      File('${Directory.systemTemp.path}/ownhub_fake_${media.file}');

  @override
  Future<File?> local(ExerciseMedia media) async => null;

  @override
  Future<File?> fetch(ExerciseMedia media) async {
    fetched.add(media.path);
    return fetchable ? _file(media) : null;
  }

  @override
  ValueListenable<double?> progressOf(ExerciseMedia media) =>
      ValueNotifier<double?>(null);

  @override
  Future<void> keepOnly(Set<String> paths) async => kept = paths;

  @override
  Future<void> eraseAll() async => erased = true;
}

/// Records what R15 asked of it and draws a plain box for the picture.
class FakeClipPlayer implements ExerciseClipPlayer {
  FakeClipPlayer({this.opens = true});

  final bool opens;
  File? opened;
  bool _playing = false;
  bool disposed = false;
  int plays = 0;

  static final List<FakeClipPlayer> made = <FakeClipPlayer>[];

  static ExerciseClipPlayer make() {
    final player = FakeClipPlayer();
    made.add(player);
    return player;
  }

  @override
  Future<bool> open(File clip) async {
    opened = clip;
    return opens;
  }

  @override
  Future<void> play() async {
    plays++;
    _playing = true;
  }

  @override
  Future<void> pause() async => _playing = false;

  @override
  bool get playing => _playing;

  @override
  double get aspectRatio => 9 / 16;

  @override
  Widget view() => const SizedBox.expand(key: ValueKey('fake-clip'));

  @override
  Future<void> dispose() async => disposed = true;
}
