/// Her own plan: a copy of one of the coach splits she changed, or a plan she
/// started blank.
///
/// A day is an [AuthoredSession], the same shape the splits are written in, so
/// the safety lines, rests and notes of a move she keeps survive her edits. A
/// target weight is the one thing a session cannot carry, so each day also keeps
/// one per move.
///
/// Nothing here is a result. A target weight is a prescription like any other.
///
/// Her days are never cut to her minutes: she chose exactly these moves.
/// [fitSession] and [weekSlotsFor] are the two places the router would
/// otherwise run `scaleSession` over them, which for a short day treats the last
/// move as a stretch and drops moves to fit. A copy of a split is taken from the
/// session as the coach wrote it, never from a cut one.
library;

import 'package:meta/meta.dart';

import '../../onboarding/domain/intake.dart' show LifeStage;
import '../../../domain/training/prescribed_set.dart';
import 'custom_workout.dart';
import 'programme_week.dart';
import 'train_repository.dart';
import 'workout_library.dart';

/// The `programId` of the programme her plan stands in as.
const String kMyPlanId = 'my_plan';

/// The `programId` of the programme a coach's workout plan stands in as.
const String kCoachPlanId = 'coach_plan';

/// Most days a plan holds: one week's worth.
const int kMaxPlanDays = 7;
const int kMaxCoachPlanWeeks = 4;

const int _maxName = 80;
const int _maxNote = WorkoutLimits.maxText;
const String _dayPrefix = 'mine_';

/// Whether [programme] is her coach's plan standing in for a split.
bool isCoachPlanProgramme(AuthoredProgramme programme) =>
    programme.programId == kCoachPlanId;

/// Whether [session] is one of her own days.
bool isMyPlanSession(AuthoredSession session) =>
    session.sessionId.startsWith(_dayPrefix);

/// Whether [programme] is her plan standing in for a split.
bool isMyPlanProgramme(AuthoredProgramme programme) =>
    programme.programId == kMyPlanId;

/// One day of her plan.
@immutable
class MyPlanDay {
  const MyPlanDay({
    required this.session,
    this.sourceId,
    this.targetKg = const <double?>[],
    this.week = 1,
  });

  final AuthoredSession session;

  /// The split's session this day was taken from, so it can be put back. Null
  /// for a day she made.
  final String? sourceId;

  /// A target weight per move, in the order of the session's moves. Null is
  /// bodyweight or no target.
  final List<double?> targetKg;

  /// 1 to 4. A plan of one week has all its days in week 1.
  final int week;

  double? kgAt(int move) => move < targetKg.length ? targetKg[move] : null;

  Map<String, Object?> toJson() => <String, Object?>{
    'session': session.toJson(),
    'sourceId': ?sourceId,
    'kg': targetKg,
    if (week > 1) 'week': week,
  };

  static MyPlanDay? tryParse(Object? raw) {
    try {
      if (raw is! Map) return null;
      final session = _cleanSession(raw['session']);
      if (session == null) return null;
      final kg = raw['kg'];
      final source = raw['sourceId'];
      return MyPlanDay(
        session: session,
        sourceId: source is String && source.length <= 64 ? source : null,
        targetKg: [
          for (var i = 0; i < session.moves.length; i++)
            _cleanKg(kg is List && i < kg.length ? kg[i] : null),
        ],
        week: _cleanWeek(raw['week']),
      );
    } catch (_) {
      // A day that is not shaped like one costs that day, not the plan.
      return null;
    }
  }
}

double? _cleanKg(Object? v) {
  if (v is! num || !v.isFinite || v < kMinWeightKg) return null;
  return v.clamp(kMinWeightKg, kMaxWeightKg).toDouble();
}

int _cleanWeek(Object? v) => v is int ? v.clamp(1, kMaxCoachPlanWeeks) : 1;

MyPlanDay _sameWeek(MyPlanDay d, int week) => MyPlanDay(
  session: d.session,
  sourceId: d.sourceId,
  targetKg: d.targetKg,
  week: week,
);

String _clip(String text, int max) {
  final one = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length > max ? one.substring(0, max).trim() : one;
}

AuthoredSession? _cleanSession(Object? raw) {
  if (raw is! Map) return null;
  final parsed = AuthoredSession.fromJson(raw.cast<String, Object?>());
  final id = parsed.sessionId;
  if (id.isEmpty || id.length > 40) return null;
  final moves = <AuthoredMove>[for (final m in parsed.moves) ?_cleanMove(m)]
      .take(kMaxCustomMoves)
      .toList();
  if (moves.isEmpty) return null;
  final titleEn = _clip(parsed.titleEn, kMaxCustomNameLength);
  final titleAr = _clip(parsed.titleAr, kMaxCustomNameLength);
  return AuthoredSession(
    sessionId: id,
    titleEn: titleEn.isEmpty ? titleAr : titleEn,
    titleAr: titleAr.isEmpty ? titleEn : titleAr,
    minutes: parsed.minutes.clamp(1, WorkoutLimits.maxMinutes),
    lifeStages: parsed.lifeStages.isEmpty
        ? {LifeStage.none}
        : parsed.lifeStages,
    moves: moves,
  );
}

AuthoredMove? _cleanMove(AuthoredMove m) {
  if (m.exerciseId.isEmpty || m.exerciseId.length > 64) return null;
  final reps = m.reps;
  final hold = m.holdSeconds;
  if (reps == null && hold == null) return null;
  final name = _clip(m.nameEn.isEmpty ? m.nameAr : m.nameEn, _maxName);
  final nameAr = _clip(m.nameAr.isEmpty ? m.nameEn : m.nameAr, _maxName);
  return AuthoredMove(
    exerciseId: m.exerciseId,
    nameEn: name,
    nameAr: nameAr,
    sets: m.sets.clamp(kMinSets, kMaxSets),
    reps: reps?.clamp(kMinReps, WorkoutLimits.maxReps),
    holdSeconds: reps != null || hold == null
        ? null
        : hold.clamp(kMinHoldSeconds, WorkoutLimits.maxHoldSeconds),
    restSeconds: m.restSeconds.clamp(0, WorkoutLimits.maxRestSeconds),
    notesEn: _clip(m.notesEn, _maxNote),
    notesAr: _clip(m.notesAr, _maxNote),
    safetyEn: _clip(m.safetyEn, _maxNote),
    safetyAr: _clip(m.safetyAr, _maxNote),
    contraindications: m.contraindications.take(20).toList(),
    quiet: m.quiet,
    floorOnly: m.floorOnly,
    needsEquipment: m.needsEquipment,
    supersetWithNext: m.supersetWithNext,
  );
}

/// Her plan.
@immutable
class MyPlan {
  const MyPlan({
    this.days = const <MyPlanDay>[],
    this.sourceProgrammeId,
    this.name = '',
    this.revision = 1,
  });

  /// A plan with no days, for starting from scratch.
  const MyPlan.blank() : this();

  /// A copy of the sessions of [template] a woman at [stage] is offered, as the
  /// coach wrote them, and from then on hers to change.
  factory MyPlan.fork(AuthoredProgramme template, {LifeStage? stage}) {
    final days = <MyPlanDay>[];
    for (final session in programmeSessionsFor(template, stage)) {
      if (days.length >= kMaxPlanDays) break;
      days.add(_dayFromOriginal(session, 'mine_${days.length + 1}'));
    }
    return MyPlan(days: days, sourceProgrammeId: template.programId);
  }

  final List<MyPlanDay> days;

  /// The split this was copied from, or null when she started blank.
  final String? sourceProgrammeId;

  /// A name she gave it. Empty is "My plan".
  final String name;

  /// Moves on every change, so a cached reading can tell.
  final int revision;

  bool get isBlank => days.isEmpty;
  bool get isFull => daysOfWeek(weekCount).length >= kMaxPlanDays;

  /// The highest week any day is in (1 for a plan of one week).
  int get weekCount => days.fold<int>(1, (m, d) => d.week > m ? d.week : m);

  List<int> daysOfWeek(int week) => [
    for (var i = 0; i < days.length; i++)
      if (days[i].week == week) i,
  ];

  /// Whole plan copied once more as the next week: every day of the last week
  /// gets a new id and week + 1. Same plan when 4 weeks are already there.
  MyPlan withRepeatedLastWeek() {
    if (weekCount >= kMaxCoachPlanWeeks) return this;
    final last = daysOfWeek(weekCount);
    if (last.isEmpty) return this;
    final next = [...days];
    var plan = this;
    for (final i in last) {
      final id = plan._freshId();
      final s = days[i].session;
      final copy = MyPlanDay(
        session: AuthoredSession(
          sessionId: id,
          titleEn: s.titleEn,
          titleAr: s.titleAr,
          minutes: s.minutes,
          lifeStages: s.lifeStages,
          moves: s.moves,
        ),
        sourceId: days[i].sourceId,
        targetKg: days[i].targetKg,
        week: weekCount + 1,
      );
      next.add(copy);
      plan = MyPlan(
        days: List.unmodifiable(next),
        sourceProgrammeId: sourceProgrammeId,
        name: name,
        revision: revision,
      );
    }
    return _with(next);
  }

  MyPlan _with(List<MyPlanDay> next) => MyPlan(
    days: List.unmodifiable(next),
    sourceProgrammeId: sourceProgrammeId,
    name: name,
    revision: revision + 1,
  );

  String _freshId() {
    final taken = {for (final d in days) d.session.sessionId};
    var n = days.length + 1;
    while (taken.contains('$_dayPrefix$n')) {
      n++;
    }
    return '$_dayPrefix$n';
  }

  /// Day [i] with these moves, keeping its name, its notes and its place.
  MyPlan withMoves(int i, List<PlannedMove> moves) {
    if (i < 0 || i >= days.length || moves.isEmpty) return this;
    final day = days[i];
    final next = [...days];
    next[i] = _sameWeek(
      _dayFromMoves(
        id: day.session.sessionId,
        titleEn: day.session.titleEn,
        titleAr: day.session.titleAr,
        moves: moves,
        like: day.session,
        lifeStages: day.session.lifeStages,
        sourceId: day.sourceId,
      ),
      day.week,
    );
    return _with(next);
  }

  /// A new day of her own, named [name], or [titleEn] and [titleAr] ("Day 3")
  /// when she gave it no name. It suits every life stage: what a stage may not
  /// do is held back move by move when the day is read, as for a split.
  MyPlan withNewDay(
    String name,
    List<PlannedMove> moves, {
    required String titleEn,
    required String titleAr,
  }) {
    if (isFull || moves.isEmpty) return this;
    final title = cleanWorkoutName(name);
    return _with([
      ...days,
      _sameWeek(
        _dayFromMoves(
          id: _freshId(),
          titleEn: title.isEmpty ? titleEn : title,
          titleAr: title.isEmpty ? titleAr : title,
          moves: moves,
          lifeStages: {...LifeStage.values},
        ),
        weekCount,
      ),
    ]);
  }

  /// [day] put back at place [i], for Undo.
  MyPlan insertDay(int i, MyPlanDay day) {
    if (isFull) return this;
    final next = [...days];
    next.insert(i.clamp(0, next.length), day);
    return _with(next);
  }

  /// The same plan with no days, still copied from the same split.
  MyPlan cleared() => _with(const <MyPlanDay>[]);

  /// A copy of day [i], added at the end.
  MyPlan withCopyOf(int i, {String suffixEn = '', String suffixAr = ''}) {
    if (isFull || i < 0 || i >= days.length) return this;
    final day = days[i];
    final id = _freshId();
    final s = day.session;
    return _with([
      ...days,
      MyPlanDay(
        session: AuthoredSession(
          sessionId: id,
          titleEn: _clip('${s.titleEn}$suffixEn', kMaxCustomNameLength),
          titleAr: _clip('${s.titleAr}$suffixAr', kMaxCustomNameLength),
          minutes: s.minutes,
          lifeStages: s.lifeStages,
          moves: s.moves,
        ),
        targetKg: day.targetKg,
        week: weekCount,
      ),
    ]);
  }

  MyPlan withoutDay(int i) {
    if (i < 0 || i >= days.length) return this;
    return _with([
      for (var j = 0; j < days.length; j++)
        if (j != i) days[j],
    ]);
  }

  MyPlan withDayMoved(int from, int to) {
    if (from < 0 || from >= days.length || to < 0 || to >= days.length) {
      return this;
    }
    final next = [...days];
    next.insert(to, next.removeAt(from));
    return _with(next);
  }

  /// Day [i] taken from [original], a session of the split as the coach wrote
  /// it. Its target weights start again.
  MyPlan withDayFrom(int i, AuthoredSession original) {
    if (i < 0 || i >= days.length) return this;
    final next = [...days];
    final fresh = _dayFromOriginal(original, days[i].session.sessionId);
    // Which session of the split this day stands for stays what it was, so
    // "put it back" returns the day she started with and not the one she took
    // moves from.
    next[i] = MyPlanDay(
      session: fresh.session,
      sourceId: days[i].sourceId ?? original.sessionId,
      targetKg: fresh.targetKg,
      week: days[i].week,
    );
    return _with(next);
  }

  /// Day [i] put back as the split wrote it, or this plan unchanged when the
  /// day was not taken from the split (or the split no longer has it).
  MyPlan restoreDay(int i, AuthoredProgramme template, {LifeStage? stage}) {
    if (i < 0 || i >= days.length) return this;
    final source = days[i].sourceId;
    if (source == null) return this;
    for (final s in programmeSessionsFor(template, stage)) {
      if (s.sessionId == source) return withDayFrom(i, s);
    }
    return this;
  }

  /// Whether day [i] can be put back from [template].
  bool canRestore(int i, AuthoredProgramme template, LifeStage? stage) {
    if (i < 0 || i >= days.length) return false;
    final source = days[i].sourceId;
    if (source == null) return false;
    return programmeSessionsFor(
      template,
      stage,
    ).any((s) => s.sessionId == source);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'source': ?sourceProgrammeId,
    if (name.isNotEmpty) 'name': name,
    'revision': revision,
    'days': [for (final d in days) d.toJson()],
  };

  /// Null for anything that is not a plan. A bad day costs that day.
  static MyPlan? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final rows = raw['days'];
    if (rows is! List) return null;
    final seen = <String>{};
    final days = <MyPlanDay>[
      for (final row in rows)
        if (MyPlanDay.tryParse(row) case final day?
            when seen.add(day.session.sessionId))
          day,
    ].take(kMaxPlanDays * kMaxCoachPlanWeeks).toList();
    final source = raw['source'];
    final name = raw['name'];
    final revision = raw['revision'];
    return MyPlan(
      days: days,
      sourceProgrammeId: source is String && source.length <= 64
          ? source
          : null,
      name: name is String ? cleanWorkoutName(name) : '',
      revision: revision is int && revision > 0 ? revision : 1,
    );
  }
}

MyPlanDay _dayFromOriginal(AuthoredSession original, String id) {
  return MyPlanDay(
    session: AuthoredSession(
      sessionId: id,
      titleEn: original.titleEn,
      titleAr: original.titleAr,
      minutes: original.minutes,
      lifeStages: original.lifeStages,
      moves: original.moves,
    ),
    sourceId: original.sessionId,
    targetKg: List<double?>.filled(original.moves.length, null),
  );
}

MyPlanDay _dayFromMoves({
  required String id,
  required String titleEn,
  required String titleAr,
  required List<PlannedMove> moves,
  required Set<LifeStage> lifeStages,
  AuthoredSession? like,
  String? sourceId,
}) {
  final customs = [for (final m in moves) customMoveOf(m)];
  // The load is read off the first set as it stands. The editor's steppers keep
  // to their own bounds, but a split's long hold (ten minutes on the treadmill)
  // must not be cut to them just because she removed another move.
  PrescribedSet? firstSet(PlannedMove m) =>
      m.sets.isEmpty ? null : m.sets.first;
  AuthoredMove? earlier(String exerciseId) {
    for (final m in like?.moves ?? const <AuthoredMove>[]) {
      if (m.exerciseId == exerciseId) return m;
    }
    return null;
  }

  final authored = <AuthoredMove>[];
  for (var i = 0; i < moves.length; i++) {
    final move = moves[i];
    final custom = customs[i];
    final was = earlier(move.exerciseId);
    final cue = move.cues.isEmpty ? '' : move.cues.last;
    authored.add(
      AuthoredMove(
        exerciseId: move.exerciseId,
        nameEn: was?.nameEn ?? move.name,
        nameAr: was?.nameAr ?? move.name,
        sets: move.sets.isEmpty ? custom.sets : move.sets.length,
        reps: firstSet(move)?.holdSeconds == null
            ? (firstSet(move)?.reps ?? custom.reps)
            : null,
        holdSeconds: firstSet(move)?.holdSeconds,
        restSeconds: was?.restSeconds ?? (custom.timed ? 45 : 60),
        notesEn: was?.notesEn ?? cue,
        notesAr: was?.notesAr ?? cue,
        safetyEn: was?.safetyEn ?? '',
        safetyAr: was?.safetyAr ?? '',
        contraindications: was?.contraindications ?? const [],
        quiet: move.quiet,
        floorOnly: move.floorOnly,
        needsEquipment: move.needsEquipment,
      ),
    );
  }
  final cleaned = _cleanSession(
    AuthoredSession(
      sessionId: id,
      titleEn: titleEn,
      titleAr: titleAr,
      minutes: estimateMinutesOf(customs),
      lifeStages: lifeStages,
      moves: authored,
    ).toJson(),
  )!;
  return MyPlanDay(
    session: cleaned,
    sourceId: sourceId,
    targetKg: [
      for (var i = 0; i < moves.length; i++)
        _cleanKg(firstSet(moves[i])?.weightKg),
    ],
  );
}

// ---------------------------------------------------------------- reading --

/// Her plan as the programme Train follows, or null when she has none or no day
/// of it suits [stage]. A day that does not suit her stage is left out, the way
/// a split's sessions are.
AuthoredProgramme? myPlanProgramme(MyPlan? plan, LifeStage? stage) {
  if (plan == null) return null;
  final sessions = [
    for (final d in plan.days)
      if (suits(d.session, stage)) d.session,
  ];
  if (sessions.isEmpty) return null;
  final named = plan.name.isEmpty ? null : plan.name;
  return AuthoredProgramme(
    programId: kMyPlanId,
    titleEn: named ?? '',
    titleAr: named ?? '',
    status: ProgrammeStatus.published,
    sessions: sessions,
    version: plan.revision,
  );
}

/// The workout plan her coach shared as the programme Train follows, or null
/// when it has no day that suits [stage]. Its days carry the same session ids
/// as a plan's, so it is told apart by its own `programId`, never by the id of
/// a session.
AuthoredProgramme? coachPlanProgramme(
  MyPlan? workout, {
  String name = '',
  int revision = 1,
  LifeStage? stage,
}) {
  final base = myPlanProgramme(workout, stage);
  if (base == null) return null;
  return AuthoredProgramme(
    programId: kCoachPlanId,
    titleEn: name,
    titleAr: name,
    status: ProgrammeStatus.published,
    sessions: base.sessions,
    version: revision,
  );
}

/// What Home, Train and Program follow: her plan when she has one with a day
/// that suits her, else [template].
AuthoredProgramme resolveProgramme(
  AuthoredProgramme template,
  MyPlan? plan,
  LifeStage? stage,
) => myPlanProgramme(plan, stage) ?? template;

/// The indexes of [plan]'s days a woman at [stage] is offered, in order.
List<int> _offered(MyPlan plan, LifeStage? stage) => [
  for (var i = 0; i < plan.days.length; i++)
    if (suits(plan.days[i].session, stage)) i,
];

/// The day of [plan] that [slot] opens: the offered days rotate, as a split's
/// sessions do. Null when no day suits [stage].
int? planDayForSlot(MyPlan plan, int slot, LifeStage? stage) {
  final offered = _offered(plan, stage);
  if (offered.isEmpty) return null;
  return offered[slot % offered.length];
}

/// The slot that opens day [dayIndex]. Null when that day is not offered to
/// [stage].
int? slotForPlanDay(MyPlan plan, int dayIndex, LifeStage? stage) {
  final slot = _offered(plan, stage).indexOf(dayIndex);
  return slot < 0 ? null : slot;
}

/// The target weights of the day whose session is [sessionId], or empty.
List<double?> targetsFor(MyPlan? plan, String sessionId) {
  if (plan == null) return const <double?>[];
  for (final d in plan.days) {
    if (d.session.sessionId == sessionId) return d.targetKg;
  }
  return const <double?>[];
}

/// The target weights for [shown], a day of [plan] that may have been cut
/// shorter to fit her minutes. Each move keeps the weight of the same exercise
/// in the full day (matched in order), so a cut never moves a weight onto
/// another move.
List<double?> targetsForShown(MyPlan? plan, AuthoredSession shown) {
  if (plan == null) return const <double?>[];
  for (final d in plan.days) {
    if (d.session.sessionId != shown.sessionId) continue;
    final full = d.session.moves;
    final used = <int>{};
    final out = <double?>[];
    for (final move in shown.moves) {
      double? kg;
      for (var i = 0; i < full.length; i++) {
        if (used.contains(i) || full[i].exerciseId != move.exerciseId) continue;
        used.add(i);
        kg = i < d.targetKg.length ? d.targetKg[i] : null;
        break;
      }
      out.add(kg);
    }
    return out;
  }
  return const <double?>[];
}

/// [plan] with today's moves written into the day that [slot] opens. With no
/// plan yet it is forked from [template] first, so the first edit she keeps is
/// what makes a plan. Null when no day of it suits [stage].
MyPlan? planWithDayMoves({
  required MyPlan? current,
  required AuthoredProgramme template,
  required LifeStage? stage,
  required int slot,
  required List<PlannedMove> moves,
}) {
  final plan = current ?? MyPlan.fork(template, stage: stage);
  final day = planDayForSlot(plan, slot, stage);
  if (day == null) return null;
  return plan.withMoves(day, moves);
}

// ------------------------------------------------------------ the week -----

/// [session] cut to [minutes] unless it is one of her own days.
AuthoredSession fitSession(
  AuthoredProgramme programme,
  AuthoredSession session,
  int minutes,
) => isMyPlanProgramme(programme) ? session : scaleSession(session, minutes);

/// How many sessions make her week: her plan's days, else [intakeDays].
int planDaysPerWeek(
  AuthoredProgramme programme,
  List<AuthoredSession> sessions,
  int intakeDays,
) => isMyPlanProgramme(programme) && sessions.isNotEmpty
    ? sessions.length
    : intakeDays;

/// `weekSlots` that leaves her own days as she wrote them.
List<WeekSlot> weekSlotsFor(
  AuthoredProgramme programme,
  List<AuthoredSession> sessions, {
  required int days,
  required int minutes,
  required int done,
}) {
  if (!isMyPlanProgramme(programme)) {
    return weekSlots(sessions, days: days, minutes: minutes, done: done);
  }
  return [
    if (sessions.isNotEmpty)
      for (var i = 0; i < days; i++)
        (index: i, session: sessions[i % sessions.length], done: i < done),
  ];
}
