/// Her week of a starting programme: which session is which, trimmed to her
/// minutes, and how far through the week she is.
///
/// A programme carries a few full-length sessions (a lead move in each pattern,
/// six strength moves and a closing stretch). The 10, 15 and 20 minute versions
/// are cut from them here, never authored twice, so every shorter session is
/// made of moves that already passed `workoutProblems` and the rule that a
/// pregnancy session holds no floor tag.
///
/// No weekday is named anywhere in this file. Her week is a count of sessions
/// (§2 rule 3): the first slot she has not done is the one she does next.
library;

import '../../../domain/clock/app_clock.dart';
import '../../../domain/week/week_key.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import 'train_repository.dart';
import 'workout_library.dart';

/// What a session of [minutes] holds: how many of the strength moves, how many
/// sets of each, and whether the closing stretch is kept.
({int moves, int sets, bool stretch}) sessionShape(int minutes) =>
    switch (minutes) {
      <= 10 => (moves: 4, sets: 2, stretch: false),
      <= 15 => (moves: 4, sets: 3, stretch: false),
      <= 20 => (moves: 5, sets: 3, stretch: false),
      _ => (moves: 6, sets: 3, stretch: true),
    };

/// [session] cut to [minutes]. A session with no more than a stretch and one
/// move is returned as it is.
///
/// The moves are in the order the programme wrote them: the first four always
/// cover a lower-body pattern, an upper push or pull, a core move and a hinge
/// or glute move, so even the shortest session is balanced.
AuthoredSession scaleSession(AuthoredSession session, int minutes) {
  if (session.moves.length < 3) return session;
  final shape = sessionShape(minutes);
  final work = session.moves.sublist(0, session.moves.length - 1);
  final stretch = session.moves.last;
  final keep = work.take(shape.moves);
  return AuthoredSession(
    sessionId: session.sessionId,
    titleEn: session.titleEn,
    titleAr: session.titleAr,
    minutes: minutes,
    lifeStages: session.lifeStages,
    moves: [
      for (final m in keep)
        AuthoredMove(
          exerciseId: m.exerciseId,
          nameEn: m.nameEn,
          nameAr: m.nameAr,
          sets: m.sets < shape.sets ? m.sets : shape.sets,
          reps: m.reps,
          holdSeconds: m.holdSeconds,
          restSeconds: m.restSeconds,
          notesEn: m.notesEn,
          notesAr: m.notesAr,
          safetyEn: m.safetyEn,
          safetyAr: m.safetyAr,
          contraindications: m.contraindications,
          quiet: m.quiet,
          floorOnly: m.floorOnly,
          needsEquipment: m.needsEquipment,
        ),
      if (shape.stretch) stretch,
    ],
  );
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
/// ones she trained or recalled, never a walk or a class.
int sessionsDoneThisWeek(Iterable<TrainSession> history, {DateTime? now}) {
  final week = WeekKey.current(now ?? AppClock.now());
  var done = 0;
  for (final s in history) {
    if (!s.completed || s.source == SessionSource.unplanned) continue;
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
