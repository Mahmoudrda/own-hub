/// Finding the library session a promise names.
///
/// R01's "10 min · floor only", T04's "Start the 10 minutes" and Y06's "gentle
/// mobility" each promise a particular kind of session, and all three opened
/// her normal planned day instead: a longer workout behind a label that said
/// otherwise. These pick the session the label describes from the sessions she
/// is offered, or nothing, and a caller with nothing hides the button rather
/// than opening something else.
library;

import 'workout_library.dart';

typedef OfferedSession = ({
  AuthoredProgramme programme,
  AuthoredSession session,
});

/// The session that keeps a short promise: no longer than [maxMinutes], every
/// move on the floor when [floorOnly], every move quiet when [quiet], some
/// move with equipment when [withEquipment], and no more than [maxMoves] moves
/// when given. Of those, the one nearest the promised length, so "20 min" is
/// not answered with five.
OfferedSession? shortSessionFor(
  List<OfferedSession> offered, {
  required int maxMinutes,
  bool floorOnly = false,
  bool quiet = false,
  bool withEquipment = false,
  int? maxMoves,
}) {
  OfferedSession? best;
  for (final entry in offered) {
    final session = entry.session;
    final moves = session.moves;
    if (moves.isEmpty || session.minutes <= 0) continue;
    if (session.minutes > maxMinutes) continue;
    if (maxMoves != null && moves.length > maxMoves) continue;
    if (floorOnly && !moves.every((m) => m.floorOnly)) continue;
    if (quiet && !moves.every((m) => m.quiet)) continue;
    if (withEquipment && !moves.any((m) => m.needsEquipment)) continue;
    if (best == null || session.minutes > best.session.minutes) best = entry;
  }
  return best;
}

/// The gentlest mobility session she is offered: one named for mobility, or
/// one whose every move [isMobility] says is a mobility move. The shortest
/// wins. Null when the library holds none, and Y06 then offers no option.
OfferedSession? gentleMobilitySessionFor(
  List<OfferedSession> offered, {
  required bool Function(String exerciseId) isMobility,
}) {
  OfferedSession? best;
  for (final entry in offered) {
    final session = entry.session;
    if (session.moves.isEmpty) continue;
    final named = session.titleEn.toLowerCase().contains('mobility');
    final allMobility = session.moves.every((m) => isMobility(m.exerciseId));
    if (!named && !allMobility) continue;
    if (session.moves.any((m) => m.needsEquipment)) continue;
    if (best == null || session.minutes < best.session.minutes) best = entry;
  }
  return best;
}
