/// Her week of a starting programme: which session is which, kept whole for a
/// session of 30 minutes or more and trimmed only for a short day, and how far
/// through the week she is.
///
/// The 10, 15 and 20 minute versions are cut from the full sessions here, never
/// authored twice, so every shorter session is made of moves that already
/// passed `workoutProblems` and the rule that a pregnancy session holds no
/// floor tag.
///
/// No weekday is named anywhere in this file. Her week is a count of sessions
/// (§2 rule 3): the first slot she has not done is the one she does next.
library;

import '../../../domain/clock/app_clock.dart';
import '../../../domain/week/week_key.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import 'train_repository.dart';
import 'workout_library.dart';

/// The shortest session that is left whole. From here up the coach's lists are
/// the plan: every move and every set of a day is kept at any length she picks,
/// and the minutes shown are the day's own.
const int kWholeSessionMinutes = 30;

/// What a short session of [minutes] (under [kWholeSessionMinutes]) holds: how
/// many of the strength moves, the most sets of each, and whether the closing
/// stretch is kept.
({int moves, int sets, bool stretch}) sessionShape(int minutes) =>
    switch (minutes) {
      <= 10 => (moves: 4, sets: 2, stretch: false),
      <= 15 => (moves: 4, sets: 3, stretch: false),
      <= 20 => (moves: 5, sets: 3, stretch: false),
      _ => (moves: 6, sets: 5, stretch: true),
    };

/// A move's time in seconds when she does it: the work of each set (2.5 s a rep,
/// or the hold), the rest between sets, and 15 s to get set up.
double _moveSeconds(AuthoredMove m) {
  final effort = m.holdSeconds ?? (m.reps ?? 0) * 2.5;
  return m.sets * effort + (m.sets - 1) * m.restSeconds + 15;
}

/// How long [session] takes her, in minutes, from its sets, reps, holds and
/// rests. The same figure `build_programme_tiers.py` was tuned against.
double estimatedMinutes(AuthoredSession session) =>
    session.moves.fold<double>(0, (t, m) => t + _moveSeconds(m)) / 60;

/// [session] cut to a short day of [minutes], 10 to 29. From 30 minutes the
/// session is returned whole, and so is one with no more than a stretch and one
/// move.
///
/// The moves are in the order the programme wrote them: the first four always
/// cover a lower-body pattern, an upper push or pull, a core move and a hinge
/// or glute move, so even the shortest session is balanced.
AuthoredSession scaleSession(AuthoredSession session, int minutes) {
  if (minutes >= kWholeSessionMinutes || session.moves.length < 3) {
    return session;
  }
  final shape = sessionShape(minutes);
  final work = session.moves.sublist(0, session.moves.length - 1);
  final stretch = session.moves.last;

  AuthoredMove capped(AuthoredMove m, {int? rest}) => AuthoredMove(
    exerciseId: m.exerciseId,
    nameEn: m.nameEn,
    nameAr: m.nameAr,
    sets: m.sets < shape.sets ? m.sets : shape.sets,
    reps: m.reps,
    holdSeconds: m.holdSeconds,
    restSeconds: rest ?? m.restSeconds,
    notesEn: rest == null ? m.notesEn : '',
    notesAr: rest == null ? m.notesAr : '',
    safetyEn: m.safetyEn,
    safetyAr: m.safetyAr,
    contraindications: m.contraindications,
    quiet: m.quiet,
    floorOnly: m.floorOnly,
    needsEquipment: m.needsEquipment,
  );

  AuthoredSession build(int count) {
    final kept = work.take(count).toList();
    final longest = kept.fold<int>(
      0,
      (r, m) => m.restSeconds > r ? m.restSeconds : r,
    );
    return AuthoredSession(
      sessionId: session.sessionId,
      titleEn: session.titleEn,
      titleAr: session.titleAr,
      minutes: minutes,
      lifeStages: session.lifeStages,
      moves: [
        for (var i = 0; i < kept.length; i++)
          // A superset whose second move was cut is no longer a superset: the
          // first gets the usual rest back and loses its note.
          if (i == kept.length - 1 &&
              kept.length.isOdd &&
              kept[i].restSeconds < longest)
            capped(kept[i], rest: longest)
          else
            capped(kept[i]),
        if (shape.stretch) stretch,
      ],
    );
  }

  final count = work.length < shape.moves ? work.length : shape.moves;
  return build(count);
}

/// The strength moves of [session]: all of them except the closing stretch, a
/// single held set with no rest. A short session has no stretch, so its last
/// move is kept.
List<AuthoredMove> workMoves(AuthoredSession session) {
  final moves = session.moves;
  if (moves.isEmpty) return const [];
  final last = moves.last;
  final isStretch =
      moves.length > 1 &&
      last.sets == 1 &&
      last.holdSeconds != null &&
      last.restSeconds == 0;
  return isStretch ? moves.sublist(0, moves.length - 1) : moves;
}

/// The sessions of [programme] a woman at [stage] is offered, in the order they
/// rotate.
List<AuthoredSession> programmeSessionsFor(
  AuthoredProgramme programme,
  LifeStage? stage,
) => [
  for (final s in programme.sessions)
    if (suits(s, stage)) s,
];

/// Sessions she has finished this week that count towards her programme: the
/// ones she trained or recalled, never a walk or a class, and never one that
/// ended with nothing logged.
int sessionsDoneThisWeek(Iterable<TrainSession> history, {DateTime? now}) {
  final week = WeekKey.current(now ?? AppClock.now());
  var done = 0;
  for (final s in history) {
    if (!s.completed ||
        s.source == SessionSource.unplanned ||
        s.endedReason == EndedReason.abandoned) {
      continue;
    }
    final day = DateTime.tryParse(s.dateKey);
    if (day != null && WeekKey.of(day) == week) done++;
  }
  return done;
}

/// One slot of her week.
typedef WeekSlot = ({int index, AuthoredSession session, bool done});

/// Her week: [days] slots, rotating through [sessions], each cut to [minutes],
/// the first [done] of them done.
List<WeekSlot> weekSlots(
  List<AuthoredSession> sessions, {
  required int days,
  required int minutes,
  required int done,
}) => [
  if (sessions.isNotEmpty)
    for (var i = 0; i < days; i++)
      (
        index: i,
        session: scaleSession(sessions[i % sessions.length], minutes),
        done: i < done,
      ),
];

/// The slot she does next, or null when this week's are all done.
int? nextSlot(int days, int done) => done < days ? done : null;
