/// Workouts the owner writes in the console, in the shape the member app trains.
///
/// A programme (`programs/{id}`) carries sessions; a session carries moves; a
/// move is one exercise, a number of sets, and either reps or a hold. That maps
/// one to one onto what Train already runs: a session becomes a [WorkoutDay]
/// (R03 and R07), a move becomes a [PlannedMove] whose sets are
/// [PrescribedSet]s, and a session is a [LibraryWorkout] row on R11. Nothing in
/// the member app learns a second idea of a workout.
///
/// ## Where members read it
///
/// Like the recipe library, and for the same cost reason: `meta/workouts`
/// holds `{version: N}` and `workoutLibrary/v{N}` holds every published
/// programme in one document. A member's app reads the version at most once a
/// day and the library only when the version moved (`workout_sync.dart`).
///
/// ## The rules, written once
///
/// [workoutProblems] is what the member app holds every programme to, and the
/// console runs the very same function before it writes anything. A set that
/// breaks one is refused whole on the phone, so the console refuses it first.
///
/// ## Life stage
///
/// Every published session says which life stages it suits, and a woman is
/// offered a session only when hers is on that list ([suits]). Pregnant or
/// after a birth, she sees only sessions written for that, and none of their
/// moves may carry a contraindication from
/// `LifeStageSafetyPolicy.pregnancyAndEarlyPostpartumFloor`. Each move carries
/// its exercise's tags so the phone can check that itself rather than trust
/// the console. R03 still shows the doctor card to her either way.
library;

import 'package:meta/meta.dart';

import '../../../domain/safety/contraindication_tag.dart';
import '../../../domain/safety/life_stage_safety_policy.dart'
    show LifeStageSafetyPolicy;
import '../../onboarding/domain/intake.dart' show LifeStage;

/// `draft` stays in the console; `published` reaches members.
enum ProgrammeStatus {
  draft,
  published;

  static ProgrammeStatus fromWire(Object? wire) =>
      values.where((v) => v.name == wire).firstOrNull ?? draft;
}

LifeStage? lifeStageFromWire(Object? wire) =>
    LifeStage.values.where((s) => s.wireName == wire).firstOrNull;

/// The limits the member app accepts. One place, read by both sides.
abstract final class WorkoutLimits {
  static const int maxSets = 10;
  static const int maxReps = 100;
  static const int minHoldSeconds = 5;
  static const int maxHoldSeconds = 600;
  static const int maxRestSeconds = 600;
  static const int maxMinutes = 180;
  static const int maxMoves = 20;
  static const int maxSessions = 14;
  static const int maxText = 300;
}

@immutable
class AuthoredMove {
  const AuthoredMove({
    required this.exerciseId,
    required this.nameEn,
    required this.nameAr,
    required this.sets,
    this.reps,
    this.holdSeconds,
    this.restSeconds = 60,
    this.notesEn = '',
    this.notesAr = '',
    this.safetyEn = '',
    this.safetyAr = '',
    this.contraindications = const [],
    this.quiet = false,
    this.floorOnly = false,
    this.needsEquipment = false,
  });

  final String exerciseId;
  final String nameEn;
  final String nameAr;
  final int sets;

  /// Exactly one of [reps] and [holdSeconds].
  final int? reps;
  final int? holdSeconds;
  final int restSeconds;
  final String notesEn;
  final String notesAr;

  /// A line she reads before the move: "Stop if you feel pressure low down."
  final String safetyEn;
  final String safetyAr;

  /// The exercise's own tags, copied in at publish time.
  final List<String> contraindications;
  final bool quiet;
  final bool floorOnly;
  final bool needsEquipment;

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'nameEn': nameEn,
    'nameAr': nameAr,
    'sets': sets,
    'reps': reps,
    'holdSeconds': holdSeconds,
    'restSeconds': restSeconds,
    'notesEn': notesEn,
    'notesAr': notesAr,
    'safetyEn': safetyEn,
    'safetyAr': safetyAr,
    'contraindications': contraindications,
    'quiet': quiet,
    'floorOnly': floorOnly,
    'needsEquipment': needsEquipment,
  };

  static AuthoredMove fromJson(Map<String, Object?> j) => AuthoredMove(
    exerciseId: _s(j['exerciseId']),
    nameEn: _s(j['nameEn']),
    nameAr: _s(j['nameAr']),
    sets: _i(j['sets']) ?? 0,
    reps: _i(j['reps']),
    holdSeconds: _i(j['holdSeconds']),
    restSeconds: _i(j['restSeconds']) ?? 0,
    notesEn: _s(j['notesEn']),
    notesAr: _s(j['notesAr']),
    safetyEn: _s(j['safetyEn']),
    safetyAr: _s(j['safetyAr']),
    contraindications: [
      for (final t in (j['contraindications'] as List?) ?? const [])
        if (t is String) t,
    ],
    quiet: j['quiet'] == true,
    floorOnly: j['floorOnly'] == true,
    needsEquipment: j['needsEquipment'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is AuthoredMove && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(exerciseId, sets, reps, holdSeconds);
}

@immutable
class AuthoredSession {
  const AuthoredSession({
    required this.sessionId,
    required this.titleEn,
    required this.titleAr,
    required this.minutes,
    required this.lifeStages,
    required this.moves,
  });

  final String sessionId;
  final String titleEn;
  final String titleAr;
  final int minutes;

  /// Who it is written for. A woman whose stage is not here is not offered it.
  final Set<LifeStage> lifeStages;
  final List<AuthoredMove> moves;

  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;

  bool get quiet => moves.every((m) => m.quiet);
  bool get needsEquipment => moves.any((m) => m.needsEquipment);

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'minutes': minutes,
    'lifeStages': [
      for (final s in LifeStage.values)
        if (lifeStages.contains(s)) s.wireName,
    ],
    'moves': [for (final m in moves) m.toJson()],
  };

  static AuthoredSession fromJson(Map<String, Object?> j) => AuthoredSession(
    sessionId: _s(j['sessionId']),
    titleEn: _s(j['titleEn']),
    titleAr: _s(j['titleAr']),
    minutes: _i(j['minutes']) ?? 0,
    lifeStages: {
      for (final w in (j['lifeStages'] as List?) ?? const [])
        ?lifeStageFromWire(w),
    },
    moves: [
      for (final m in (j['moves'] as List?) ?? const [])
        if (m is Map) AuthoredMove.fromJson(m.cast<String, Object?>()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is AuthoredSession && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(sessionId, minutes, moves.length);
}

@immutable
class AuthoredProgramme {
  const AuthoredProgramme({
    required this.programId,
    required this.titleEn,
    required this.titleAr,
    required this.status,
    required this.sessions,
    this.version = 1,
  });

  final String programId;
  final String titleEn;
  final String titleAr;
  final ProgrammeStatus status;
  final List<AuthoredSession> sessions;
  final int version;

  Map<String, Object?> toJson() => {
    'programId': programId,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'status': status.name,
    'version': version,
    'sessions': [for (final s in sessions) s.toJson()],
  };

  static AuthoredProgramme fromJson(Map<String, Object?> j) =>
      AuthoredProgramme(
        programId: _s(j['programId']),
        titleEn: _s(j['titleEn']),
        titleAr: _s(j['titleAr']),
        status: ProgrammeStatus.fromWire(j['status']),
        version: _i(j['version']) ?? 1,
        sessions: [
          for (final s in (j['sessions'] as List?) ?? const [])
            if (s is Map) AuthoredSession.fromJson(s.cast<String, Object?>()),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is AuthoredProgramme && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(programId, version, sessions.length);
}

String _s(Object? v) => v is String ? v : '';
int? _i(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

bool _jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Whether a woman at [stage] is offered [session]. No answer is `none`.
bool suits(AuthoredSession session, LifeStage? stage) =>
    session.lifeStages.contains(stage ?? LifeStage.none);

/// Life stages whose sessions may not hold a move tagged with the floor.
const Set<LifeStage> kProtectedStages = {
  LifeStage.pregnant,
  LifeStage.postpartum,
};

/// Why [programme] may not reach a member, or empty when it may. A draft is
/// held only to the shape that lets the console open it again.
List<String> workoutProblems(AuthoredProgramme programme) {
  final problems = <String>[];
  final id = programme.programId;
  void fail(String why) => problems.add('$id: $why');

  if (id.trim().isEmpty) fail('no id');
  if (programme.status == ProgrammeStatus.draft) return problems;

  if (programme.titleEn.trim().isEmpty || programme.titleAr.trim().isEmpty) {
    fail('a title is missing in one language');
  }
  if (programme.sessions.isEmpty) fail('no sessions');
  if (programme.sessions.length > WorkoutLimits.maxSessions) {
    fail('too many sessions');
  }
  final seen = <String>{};
  final forbidden = {
    for (final t in LifeStageSafetyPolicy.pregnancyAndEarlyPostpartumFloor)
      t.wireName,
  };

  for (final s in programme.sessions) {
    final where = 'session ${s.sessionId}';
    if (s.sessionId.trim().isEmpty || !seen.add(s.sessionId)) {
      fail('$where: missing or repeated id');
    }
    if (s.titleEn.trim().isEmpty || s.titleAr.trim().isEmpty) {
      fail('$where: a title is missing in one language');
    }
    if (s.minutes < 1 || s.minutes > WorkoutLimits.maxMinutes) {
      fail('$where: minutes out of range');
    }
    if (s.lifeStages.isEmpty) fail('$where: no life stage declared');
    if (s.moves.isEmpty) fail('$where: no moves');
    if (s.moves.length > WorkoutLimits.maxMoves) fail('$where: too many moves');
    for (final m in s.moves) {
      final move = '$where, ${m.exerciseId}';
      if (m.exerciseId.trim().isEmpty) fail('$move: no exercise');
      if (m.nameEn.trim().isEmpty || m.nameAr.trim().isEmpty) {
        fail('$move: a name is missing in one language');
      }
      if (m.sets < 1 || m.sets > WorkoutLimits.maxSets) {
        fail('$move: sets out of range');
      }
      final hasReps = m.reps != null;
      final hasHold = m.holdSeconds != null;
      if (hasReps == hasHold) fail('$move: needs reps or a hold, not both');
      if (hasReps && (m.reps! < 1 || m.reps! > WorkoutLimits.maxReps)) {
        fail('$move: reps out of range');
      }
      if (hasHold &&
          (m.holdSeconds! < WorkoutLimits.minHoldSeconds ||
              m.holdSeconds! > WorkoutLimits.maxHoldSeconds)) {
        fail('$move: hold out of range');
      }
      if (m.restSeconds < 0 || m.restSeconds > WorkoutLimits.maxRestSeconds) {
        fail('$move: rest out of range');
      }
      for (final text in [
        m.notesEn,
        m.notesAr,
        m.safetyEn,
        m.safetyAr,
        m.nameEn,
        m.nameAr,
      ]) {
        if (text.length > WorkoutLimits.maxText) fail('$move: text too long');
      }
      // An untagged move is unknown, and unknown is unsafe: the same rule the
      // exercise library holds every row to.
      if (m.contraindications.isEmpty) fail('$move: no contraindication tags');
      for (final tag in m.contraindications) {
        if (ContraindicationTag.fromWire(tag) == null) {
          fail('$move: unknown tag $tag');
        }
      }
      if (s.lifeStages.any(kProtectedStages.contains) &&
          m.contraindications.any(forbidden.contains)) {
        fail('$move: not safe for pregnancy or after a birth');
      }
    }
  }
  return problems;
}

/// The member library: every published programme, in one document.
@immutable
class WorkoutLibrary {
  const WorkoutLibrary({required this.version, required this.programmes});

  static const WorkoutLibrary empty = WorkoutLibrary(
    version: 0,
    programmes: [],
  );

  final int version;
  final List<AuthoredProgramme> programmes;

  Map<String, Object?> toJson() => {
    'version': version,
    'programmes': [for (final p in programmes) p.toJson()],
  };

  /// Parses and checks a library document. Throws [FormatException] when any
  /// programme breaks a rule: a set is taken whole or not at all.
  static WorkoutLibrary parse(Map<String, Object?> json) {
    final version = _i(json['version']);
    if (version == null || version < 1) {
      throw const FormatException('no version');
    }
    final programmes = [
      for (final p in (json['programmes'] as List?) ?? const [])
        if (p is Map) AuthoredProgramme.fromJson(p.cast<String, Object?>()),
    ];
    final problems = [
      for (final p in programmes) ...workoutProblems(p),
      for (final p in programmes)
        if (p.status != ProgrammeStatus.published)
          '${p.programId}: not published',
    ];
    if (problems.isNotEmpty) throw FormatException(problems.join('; '));
    return WorkoutLibrary(version: version, programmes: programmes);
  }

  /// Every session a woman at [stage] may be offered, with its programme.
  List<({AuthoredProgramme programme, AuthoredSession session})> sessionsFor(
    LifeStage? stage,
  ) => [
    for (final p in programmes)
      for (final s in p.sessions)
        if (suits(s, stage)) (programme: p, session: s),
  ];
}

/// The R11 row id of a session. Never a date: a day key goes on the session
/// she starts, not on the row she taps.
String libraryRowId(String programId, String sessionId) =>
    'library:$programId/$sessionId';
