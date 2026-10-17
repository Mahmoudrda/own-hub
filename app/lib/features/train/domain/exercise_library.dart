/// The exercise library she browses (R14) and one move's demo (R15), D42.
///
/// The owner films the moves, uploads each clip and poster with
/// `functions/tools/upload_media.py`, and publishes one reviewed catalogue with
/// `functions/tools/publish_exercise_library.py`. The phone reads that
/// catalogue from `meta/exerciseLibrary`; `contracts/exercise_library_contract.json`
/// is the shape both sides are tested against.
///
/// **A bad row is dropped, not the library.** The workout library refuses a
/// whole version on one problem, because a programme is a sequence and half of
/// one is wrong. A library of single moves is not: if a later tool writes a
/// word this build does not know, refusing everything would freeze every older
/// phone on its old catalogue. Each row is checked on its own, and a row that
/// fails any check, its safety tags included, is not shown at all.
library;

import 'package:meta/meta.dart';

import '../../../domain/safety/contraindication_tag.dart';
import '../../../domain/safety/exercise_candidate_filter.dart'
    show ScreenableExercise;
import '../../../domain/safety/life_stage_safety_policy.dart' as safety;
import '../../onboarding/domain/intake.dart'
    show Equipment, LifeStage, TrainingPlace;

/// Where every clip and poster lives: `content/exercises/{id}/{file}`.
const String kExerciseMediaPrefix = 'content/exercises';

/// The catalogue shape this build reads.
const int kExerciseLibrarySchema = 1;

/// Per-file ceilings, the same as the publish tool's.
const int kMaxClipBytes = 10 * 1024 * 1024;
const int kMaxPosterBytes = 1024 * 1024;
const int kMaxExerciseText = 300;

final RegExp _id = RegExp(r'^[a-z0-9_]{1,64}$');
final RegExp _clipFile = RegExp(r'^[a-z0-9_-]{1,90}\.mp4$');
final RegExp _posterFile = RegExp(r'^[a-z0-9_-]{1,90}\.webp$');

const Set<String> kBodyRegions = {
  'upper_body',
  'lower_body',
  'core',
  'full_body',
};

const Set<String> kExercisePatterns = {
  'squat',
  'hinge',
  'lunge',
  'hip_thrust_bridge',
  'push_horizontal',
  'push_vertical',
  'pull_horizontal',
  'pull_vertical',
  'isolation_lower',
  'isolation_upper',
  'core_anti_extension',
  'core_flexion',
  'core_rotation',
  'carry',
  'mobility',
};

T? _wire<T extends Enum>(List<T> values, Object? wire, String Function(T) of) {
  if (wire is! String) return null;
  for (final value in values) {
    if (of(value) == wire) return value;
  }
  return null;
}

enum Muscle {
  glutes('glutes'),
  quads('quads'),
  hamstrings('hamstrings'),
  adductors('adductors'),
  abductors('abductors'),
  calves('calves'),
  core('core'),
  obliques('obliques'),
  lowerBack('lower_back'),
  chest('chest'),
  lats('lats'),
  upperBack('upper_back'),
  frontDelts('front_delts'),
  sideDelts('side_delts'),
  rearDelts('rear_delts'),
  biceps('biceps'),
  triceps('triceps'),
  forearms('forearms');

  const Muscle(this.wireName);
  final String wireName;

  static Muscle? fromWire(Object? wire) =>
      _wire(values, wire, (m) => m.wireName);
}

/// The headings R14 groups moves under, in the order she reads them: words
/// she would use, not the anatomy the catalogue records.
enum MuscleSection {
  glutes,
  frontOfThighs,
  backOfThighs,
  innerAndOuterThighs,
  calves,
  absAndSides,
  lowerBack,
  chest,
  upperBack,
  shoulders,
  arms,
}

MuscleSection sectionOf(Muscle muscle) => switch (muscle) {
  Muscle.glutes => MuscleSection.glutes,
  Muscle.quads => MuscleSection.frontOfThighs,
  Muscle.hamstrings => MuscleSection.backOfThighs,
  Muscle.adductors || Muscle.abductors => MuscleSection.innerAndOuterThighs,
  Muscle.calves => MuscleSection.calves,
  Muscle.core || Muscle.obliques => MuscleSection.absAndSides,
  Muscle.lowerBack => MuscleSection.lowerBack,
  Muscle.chest => MuscleSection.chest,
  Muscle.lats || Muscle.upperBack => MuscleSection.upperBack,
  Muscle.frontDelts ||
  Muscle.sideDelts ||
  Muscle.rearDelts => MuscleSection.shoulders,
  Muscle.biceps || Muscle.triceps || Muscle.forearms => MuscleSection.arms,
};

/// Strength, or a stretch: warm-up drills are filed with the stretches.
enum ExerciseKind {
  strength('strength'),
  stretch('stretch');

  const ExerciseKind(this.wireName);
  final String wireName;

  static ExerciseKind? fromWire(Object? wire) =>
      _wire(values, wire, (k) => k.wireName);
}

/// Where the move can be done: anywhere with the kit, or only in a gym.
enum ExercisePlace {
  both('both'),
  gym('gym');

  const ExercisePlace(this.wireName);
  final String wireName;

  static ExercisePlace? fromWire(Object? wire) =>
      _wire(values, wire, (p) => p.wireName);
}

enum ExerciseLevel {
  beginner('beginner'),
  intermediate('intermediate');

  const ExerciseLevel(this.wireName);
  final String wireName;

  static ExerciseLevel? fromWire(Object? wire) =>
      _wire(values, wire, (l) => l.wireName);
}

enum LibraryEquipment {
  none('none'),
  mat('mat'),
  dumbbells('dumbbells'),
  bands('bands'),
  kettlebell('kettlebell'),
  bench('bench'),
  step('step'),
  barbell('barbell'),
  cable('cable'),
  machine('machine'),
  smithMachine('smith_machine');

  const LibraryEquipment(this.wireName);
  final String wireName;

  /// A machine only a gym has.
  bool get isGymMachine =>
      this == machine || this == cable || this == smithMachine;

  static LibraryEquipment? fromWire(Object? wire) =>
      _wire(values, wire, (e) => e.wireName);
}

enum ClipAngle {
  front('front'),
  side('side'),
  rear('rear'),
  otherSide('otherSide');

  const ClipAngle(this.wireName);
  final String wireName;

  static ClipAngle? fromWire(Object? wire) =>
      _wire(values, wire, (a) => a.wireName);
}

/// One stored file and its exact size: the size is how the phone knows a
/// download finished.
@immutable
class ExerciseMedia {
  const ExerciseMedia({required this.path, required this.bytes});

  /// `content/exercises/{id}/{file}`.
  final String path;
  final int bytes;

  String get file => path.substring(path.lastIndexOf('/') + 1);

  @override
  bool operator ==(Object other) =>
      other is ExerciseMedia && other.path == path && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(path, bytes);
}

@immutable
class ExerciseClip {
  const ExerciseClip({
    required this.media,
    required this.angle,
    required this.seconds,
  });

  final ExerciseMedia media;
  final ClipAngle angle;
  final double seconds;
}

@immutable
class LibraryExercise {
  const LibraryExercise({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.kind,
    required this.primaryMuscles,
    this.secondaryMuscles = const <Muscle>[],
    required this.bodyRegion,
    required this.pattern,
    required this.equipment,
    required this.place,
    required this.level,
    required this.quiet,
    required this.floorOnly,
    required this.tags,
    this.setupEn,
    this.setupAr,
    required this.clips,
    required this.poster,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final ExerciseKind kind;
  final List<Muscle> primaryMuscles;
  final List<Muscle> secondaryMuscles;
  final String bodyRegion;
  final String pattern;
  final List<LibraryEquipment> equipment;
  final ExercisePlace place;
  final ExerciseLevel level;
  final bool quiet;
  final bool floorOnly;
  final Set<ContraindicationTag> tags;
  final String? setupEn;
  final String? setupAr;

  /// One or two, the first being the one shown first.
  final List<ExerciseClip> clips;
  final ExerciseMedia poster;

  /// The heading it is listed under: its first primary muscle's.
  MuscleSection get section => sectionOf(primaryMuscles.first);

  /// Every heading its primary muscles belong to, in their order.
  List<MuscleSection> get sections => [
    for (final muscle in primaryMuscles) sectionOf(muscle),
  ].fold(<MuscleSection>[], (out, s) => out.contains(s) ? out : [...out, s]);

  /// Nothing to hold or stand on.
  bool get needsNothing =>
      equipment.length == 1 && equipment.single == LibraryEquipment.none;

  bool get usesGymMachine => equipment.any((e) => e.isGymMachine);

  ScreenableExercise get screenable => ScreenableExercise(
    exerciseId: id,
    tags: tags,
    quiet: quiet,
    floorOnly: floorOnly,
  );

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  String? setup(String languageCode) =>
      languageCode == 'ar' ? setupAr : setupEn;

  /// Her search, over the name in both languages.
  bool matches(String text) {
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return nameEn.toLowerCase().contains(needle) || nameAr.contains(needle);
  }

  /// This row, or null when anything about it is not right.
  static LibraryExercise? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || !_id.hasMatch(id)) return null;

    String? text(Object? value) =>
        value is String &&
            value.trim().isNotEmpty &&
            value.length <= kMaxExerciseText
        ? value
        : null;

    final nameEn = text(json['nameEn']);
    final nameAr = text(json['nameAr']);
    if (nameEn == null || nameAr == null) return null;
    final setupEn = json['setupEn'] == null ? null : text(json['setupEn']);
    final setupAr = json['setupAr'] == null ? null : text(json['setupAr']);
    if ((json['setupEn'] == null) != (json['setupAr'] == null)) return null;
    if (json['setupEn'] != null && (setupEn == null || setupAr == null)) {
      return null;
    }

    final kind = ExerciseKind.fromWire(json['kind']);
    final place = ExercisePlace.fromWire(json['place']);
    final level = ExerciseLevel.fromWire(json['level']);
    final region = json['bodyRegion'];
    final pattern = json['pattern'];
    if (kind == null || place == null || level == null) return null;
    if (region is! String || !kBodyRegions.contains(region)) return null;
    if (pattern is! String || !kExercisePatterns.contains(pattern)) return null;
    if ((kind == ExerciseKind.stretch) != (pattern == 'mobility')) return null;

    List<T>? all<T>(Object? list, T? Function(Object?) parse) {
      if (list is! List) return null;
      final out = <T>[];
      for (final item in list) {
        final parsed = parse(item);
        if (parsed == null || out.contains(parsed)) return null;
        out.add(parsed);
      }
      return out;
    }

    final primary = all(json['primaryMuscles'], Muscle.fromWire);
    final secondary = all(
      json['secondaryMuscles'] ?? const [],
      Muscle.fromWire,
    );
    if (primary == null || primary.isEmpty || secondary == null) return null;
    if (primary.any(secondary.contains)) return null;
    final equipment = all(json['equipment'], LibraryEquipment.fromWire);
    if (equipment == null || equipment.isEmpty) return null;
    if (equipment.contains(LibraryEquipment.none) && equipment.length > 1) {
      return null;
    }
    // Safety tags fail closed: an empty, unknown or contradictory list drops
    // the move rather than showing it as if it restricted nothing.
    final tags = all(json['tags'], (w) {
      return w is String ? ContraindicationTag.fromWire(w) : null;
    });
    if (tags == null || tags.isEmpty) return null;
    if (tags.contains(ContraindicationTag.none) && tags.length > 1) return null;

    final quiet = json['quiet'];
    final floorOnly = json['floorOnly'];
    if (quiet is! bool || floorOnly is! bool) return null;

    ExerciseMedia? media(Object? value, RegExp pattern, int ceiling) {
      if (value is! Map) return null;
      final file = value['file'];
      final bytes = value['bytes'];
      if (file is! String || !pattern.hasMatch(file)) return null;
      if (bytes is! int || bytes <= 0 || bytes > ceiling) return null;
      return ExerciseMedia(
        path: '$kExerciseMediaPrefix/$id/$file',
        bytes: bytes,
      );
    }

    final rawClips = json['clips'];
    if (rawClips is! List || rawClips.isEmpty || rawClips.length > 2) {
      return null;
    }
    final clips = <ExerciseClip>[];
    for (final raw in rawClips) {
      final clip = media(raw, _clipFile, kMaxClipBytes);
      final angle = raw is Map ? ClipAngle.fromWire(raw['angle']) : null;
      final seconds = raw is Map ? raw['seconds'] : null;
      if (clip == null || angle == null || seconds is! num || seconds <= 0) {
        return null;
      }
      if (clips.any((c) => c.angle == angle || c.media.path == clip.path)) {
        return null;
      }
      clips.add(
        ExerciseClip(media: clip, angle: angle, seconds: seconds.toDouble()),
      );
    }
    final poster = media(json['poster'], _posterFile, kMaxPosterBytes);
    if (poster == null) return null;

    return LibraryExercise(
      id: id,
      nameEn: nameEn,
      nameAr: nameAr,
      kind: kind,
      primaryMuscles: List.unmodifiable(primary),
      secondaryMuscles: List.unmodifiable(secondary),
      bodyRegion: region,
      pattern: pattern,
      equipment: List.unmodifiable(equipment),
      place: place,
      level: level,
      quiet: quiet,
      floorOnly: floorOnly,
      tags: Set.unmodifiable(tags),
      setupEn: setupEn,
      setupAr: setupAr,
      clips: List.unmodifiable(clips),
      poster: poster,
    );
  }

  /// The row as the catalogue carries it, for the phone's cache.
  Map<String, Object?> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameAr': nameAr,
    'kind': kind.wireName,
    'primaryMuscles': [for (final m in primaryMuscles) m.wireName],
    'secondaryMuscles': [for (final m in secondaryMuscles) m.wireName],
    'bodyRegion': bodyRegion,
    'pattern': pattern,
    'equipment': [for (final e in equipment) e.wireName],
    'place': place.wireName,
    'level': level.wireName,
    'quiet': quiet,
    'floorOnly': floorOnly,
    'tags': [for (final t in tags) t.wireName],
    if (setupEn != null) 'setupEn': setupEn,
    if (setupAr != null) 'setupAr': setupAr,
    'clips': [
      for (final c in clips)
        {
          'file': c.media.file,
          'angle': c.angle.wireName,
          'bytes': c.media.bytes,
          'seconds': c.seconds,
        },
    ],
    'poster': {'file': poster.file, 'bytes': poster.bytes},
  };
}

@immutable
class ExerciseLibrary {
  const ExerciseLibrary({required this.version, required this.exercises});

  static const ExerciseLibrary empty = ExerciseLibrary(
    version: 0,
    exercises: <LibraryExercise>[],
  );

  final int version;
  final List<LibraryExercise> exercises;

  bool get isEmpty => exercises.isEmpty;

  /// Every file the library names, for the phone's cache to keep.
  Set<String> get mediaPaths => {
    for (final e in exercises) ...[
      e.poster.path,
      for (final c in e.clips) c.media.path,
    ],
  };

  LibraryExercise? byId(String? id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The library in [json], or null when the document itself is not one: no
  /// version, no list, or not one row this build can show.
  static ExerciseLibrary? parse(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final rows = json['exercises'];
    if (version is! int || version <= 0 || rows is! List) return null;
    final exercises = <LibraryExercise>[];
    for (final row in rows) {
      final exercise = LibraryExercise.tryParse(row);
      if (exercise == null || exercises.any((e) => e.id == exercise.id)) {
        continue;
      }
      exercises.add(exercise);
    }
    if (exercises.isEmpty) return null;
    return ExerciseLibrary(
      version: version,
      exercises: List.unmodifiable(exercises),
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'schema': kExerciseLibrarySchema,
    'exercises': [for (final e in exercises) e.toJson()],
  };
}

/// Her life stage as the safety policy reads it.
///
/// O04 does not ask how long ago she gave birth, so `postpartum` takes the
/// first six weeks, the more protective reading, as R11 does.
safety.LifeStage safetyStageFor(LifeStage? stage) => switch (stage) {
  LifeStage.pregnant => safety.LifeStage.pregnant,
  LifeStage.postpartum => safety.LifeStage.postpartum0to6w,
  LifeStage.none || LifeStage.painInjury || null => safety.LifeStage.none,
};

/// The moves she is shown, and whether any were held back for her stage.
///
/// Pregnancy and the first weeks after a birth hide every move carrying one of
/// the policy's floor tags. Nothing else is hidden: a library she browses is
/// not a plan, and the coach's own restrictions arrive with her programme.
({List<LibraryExercise> shown, bool someHidden}) screenForLifeStage(
  List<LibraryExercise> all,
  LifeStage? stage,
) {
  final avoid = safety.LifeStageSafetyPolicy.derivedAvoid(
    safetyStageFor(stage),
  );
  if (avoid.isEmpty) return (shown: all, someHidden: false);
  final shown = [
    for (final e in all)
      if (e.screenable.tagsKnown && !e.screenable.blocks(avoid)) e,
  ];
  return (shown: shown, someHidden: shown.length != all.length);
}

/// What she can do a move with, in the library's own words.
///
/// Nothing is always allowed. At home only what she said she has; at a ladies
/// gym, or both, every piece of kit and every machine.
bool _canDoHere(LibraryExercise e, TrainingPlace place, Set<Equipment> owned) {
  if (place != TrainingPlace.home) return true;
  if (e.place == ExercisePlace.gym) return false;
  final have = <LibraryEquipment>{
    LibraryEquipment.none,
    for (final item in owned)
      switch (item) {
        Equipment.none => LibraryEquipment.none,
        Equipment.mat => LibraryEquipment.mat,
        Equipment.dumbbells => LibraryEquipment.dumbbells,
        Equipment.bands => LibraryEquipment.bands,
        Equipment.bench => LibraryEquipment.bench,
        Equipment.barbell => LibraryEquipment.barbell,
        Equipment.cable => LibraryEquipment.cable,
        Equipment.smithMachine => LibraryEquipment.smithMachine,
        Equipment.machine => LibraryEquipment.machine,
      },
  };
  return e.equipment.every(have.contains);
}

/// The moves R05 offers in place of [current]: strength moves under the same
/// heading, that she can do where she trains with what she has, never the move
/// itself. [shown] is already screened for her life stage
/// ([screenForLifeStage]).
List<LibraryExercise> swapCandidatesFor(
  List<LibraryExercise> shown,
  LibraryExercise current, {
  required TrainingPlace place,
  required Set<Equipment> equipment,
  int limit = 5,
}) {
  final out = [
    for (final e in shown)
      if (e.id != current.id &&
          e.kind == ExerciseKind.strength &&
          e.section == current.section &&
          _canDoHere(e, place, equipment))
        e,
  ];
  // Same movement first; the order the library lists them otherwise.
  return [
    for (final e in out)
      if (e.pattern == current.pattern) e,
    for (final e in out)
      if (e.pattern != current.pattern) e,
  ].take(limit).toList(growable: false);
}

/// Strength moves that work [section] as a primary muscle, which she can do
/// where she trains with what she has, for P06 to suggest. [shown] is already
/// screened for her life stage ([screenForLifeStage]). Moves whose own
/// heading is [section] first; the library's order otherwise.
List<LibraryExercise> movesForSection(
  List<LibraryExercise> shown,
  MuscleSection section, {
  required TrainingPlace place,
  required Set<Equipment> equipment,
  int limit = 3,
}) {
  final out = [
    for (final e in shown)
      if (e.kind == ExerciseKind.strength &&
          e.sections.contains(section) &&
          _canDoHere(e, place, equipment))
        e,
  ];
  return [
    for (final e in out)
      if (e.section == section) e,
    for (final e in out)
      if (e.section != section) e,
  ].take(limit).toList(growable: false);
}

/// Strength moves that work [muscle] as a primary muscle, which she can do
/// where she trains with what she has, for P06's card on one muscle. [shown]
/// is already screened for her life stage ([screenForLifeStage]). Moves that
/// name [muscle] first come first; the library's order otherwise.
List<LibraryExercise> movesForMuscle(
  List<LibraryExercise> shown,
  Muscle muscle, {
  required TrainingPlace place,
  required Set<Equipment> equipment,
  int limit = 3,
}) {
  final out = [
    for (final e in shown)
      if (e.kind == ExerciseKind.strength &&
          e.primaryMuscles.contains(muscle) &&
          _canDoHere(e, place, equipment))
        e,
  ];
  return [
    for (final e in out)
      if (e.primaryMuscles.first == muscle) e,
    for (final e in out)
      if (e.primaryMuscles.first != muscle) e,
  ].take(limit).toList(growable: false);
}
