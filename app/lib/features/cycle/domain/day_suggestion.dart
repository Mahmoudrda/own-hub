/// What Y03 may render today — a **sealed** type, because §2.5 is enforced by
/// the type and not by a branch.
///
/// Plan §5: "`DaySuggestion` is a **sealed** type: `NoSuggestion` | `KeepPlan` |
/// `GentlerOption(alternative)` | `Suppressed(guidance, careRoute)`.
/// `Suppressed` **has no workout, alternative or session field at all.** There
/// is nothing for Y11 to render even if a widget tried, and adding one is a
/// compile-time change that the review sees."
///
/// That is the whole design. A boolean `isSuppressed` beside a nullable
/// `workout` would let a widget render a workout on a severe day by forgetting
/// one `if`; here there is no field to read, so the mistake does not compile.
/// `no_workout_in_suppressed_test.dart` parses this file and fails the build if
/// a field whose name looks like a workout is ever added to [Suppressed].
///
/// Sealed also means `switch` over a [DaySuggestion] is exhaustive, so adding a
/// sixth outcome breaks every renderer until each one has decided what to do
/// with it — which is the correct amount of friction for this particular type.
library;

import 'package:meta/meta.dart';

import 'symptom_context.dart';

/// Where a gentler session came from.
///
/// G9 OQ-4: Y06's "coach-approved" label needs `workout.easierOption` from G2
/// and a session-level apply from G4, and **neither exists**. The plan's
/// instruction if they are declined is explicit: the card is labelled "App
/// suggestion" and "the words 'coach-approved' must then be cut rather than
/// faked".
///
/// So this enum has two values and only one of them is currently constructible
/// from real data. [coachApproved] exists so that the day G2 publishes an
/// easier option there is a value for it, not so that a widget can claim one
/// today.
enum SessionProvenance {
  /// Chosen by the app from the bundled library. Y03 and Y06 both draw this
  /// distinction on screen already.
  appSuggestion,

  /// Pre-approved by her coach. **Unreachable until G2 publishes
  /// `workout.easierOption`** — see OQ-4.
  coachApproved,
}

/// A whole alternative session, not a per-move swap.
///
/// Y06 offers "a whole alternative session ('gentle mobility, 15 min, floor
/// only')", which is why this carries minutes and a floor-only flag rather than
/// a list of moves: swapping one move is G4's `SwapMoveUseCase` and is a
/// different thing.
@immutable
class GentlerSession {
  const GentlerSession({
    required this.minutes,
    required this.floorOnly,
    required this.provenance,
  });

  final int minutes;
  final bool floorOnly;
  final SessionProvenance provenance;
}

/// The medical guidance Y11 shows.
///
/// Carries a **content version** rather than the words themselves: the copy is
/// bundled and versioned behind `careContentVersion` in Remote Config (plan §2
/// row 5), so a clinically reviewed correction ships without an app release.
@immutable
class SevereGuidance {
  const SevereGuidance({required this.contentVersion});

  final String contentVersion;
}

/// One place she could go for care.
@immutable
class CareEntry {
  const CareEntry({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// The bundled in-app fallback for "Find care near you".
///
/// **There is no Egyptian directory, so [bundled] is null.** G9 OQ-11: "'Find
/// care near you' needs an Egyptian source; the product currently cites NHS
/// guidance, which is British… The guidance text needs a named clinical
/// reviewer — the screen gives medical advice, and an unreviewed sentence there
/// is the highest-liability string in the app."
///
/// Inventing entries here — a plausible hospital name, a guessed ambulance
/// number — is the exact defect class `PHASE1-FIXES.md` #3 and #13 record, and
/// on this screen it could send a woman in pain to a number that does not
/// answer. So the directory is modelled, the routing around it is built, and it
/// is **empty until a named clinical reviewer supplies one**.
@immutable
class CareDirectory {
  const CareDirectory({
    required this.version,
    required this.entries,
    required this.emergencyNumber,
  });

  /// The bundled directory, or null when none has been authored.
  ///
  /// Null today. See the class comment.
  static const CareDirectory? bundled = null;

  final String version;
  final List<CareEntry> entries;
  final String emergencyNumber;
}

/// How Y11 gets her to care: a maps intent, with the bundled list as fallback.
///
/// §4's second honest limit: "The Y11 route to care needs signal for maps; the
/// fallback is a bundled emergency number rendered offline, so the screen never
/// dead-ends." [directory] being null is precisely the state in which that
/// promise **cannot** be kept, which is why it is nullable rather than defaulted
/// to something empty that reads as "no care available".
@immutable
class CareRoute {
  const CareRoute({required this.directory});

  /// The offline fallback. Null when no directory has been authored — see
  /// [CareDirectory.bundled].
  final CareDirectory? directory;

  /// Whether the in-app fallback can actually render.
  ///
  /// False today. Y11 uses this to decide whether it may promise a fallback,
  /// rather than promising one and showing an empty list.
  bool get hasFallback => directory != null && directory!.entries.isNotEmpty;
}

/// What today's check-in produced. Five states, one type.
@immutable
sealed class DaySuggestion {
  const DaySuggestion();

  /// The logged symptoms that produced this.
  ///
  /// Non-null everywhere and **non-empty** on the two variants that change what
  /// she sees, asserted in their constructors. §5: "A suggestion with no logged
  /// reason is unconstructible, so 'a date alone changed it' cannot be
  /// expressed."
  List<LoggedSymptom> get reason;
}

/// §3.3 `noCheckIn` — nothing logged. Y03 shows "How are you feeling?" and her
/// plan, unchanged. Never a suggestion.
@immutable
final class NoSuggestion extends DaySuggestion {
  const NoSuggestion();

  @override
  List<LoggedSymptom> get reason => const <LoggedSymptom>[];
}

/// §3.3 `usual` — logged, and no qualifying symptom. Her planned session,
/// unchanged, and no gentler card.
///
/// This is what `P1-RULE-04` asserts: high energy and no cramps on period day 2
/// leaves the usual strength session in place.
@immutable
final class KeepPlan extends DaySuggestion {
  const KeepPlan({this.reason = const <LoggedSymptom>[]});

  /// What she logged. May be empty — she logged something, but nothing that
  /// qualifies.
  @override
  final List<LoggedSymptom> reason;
}

/// §3.3 `gentlerOffered` — the "A gentler option today" card.
@immutable
final class GentlerOption extends DaySuggestion {
  // The assert below is what makes a reasonless suggestion unconstructible,
  // and `isNotEmpty` is not a constant expression — so this constructor cannot
  // be const. The guarantee is worth more than the lint.
  // ignore: prefer_const_constructors_in_immutables
  GentlerOption({required this.reason, required this.alternative})
    : assert(
        reason.isNotEmpty,
        'A gentler option names what she logged. An option with no logged '
        'reason would be a date having changed a suggestion, which is exactly '
        'what rule 4 forbids.',
      );

  @override
  final List<LoggedSymptom> reason;

  final GentlerSession alternative;
}

/// §3.3 `suppressed` — severe cramps or heavy bleeding.
///
/// **Note the fields.** Guidance and a route to care. There is no workout, no
/// alternative and no session, so Y11 has nothing to render even if a widget
/// tried — which is the enforcement, not a convention.
@immutable
final class Suppressed extends DaySuggestion {
  // Non-const for the same reason as GentlerOption above: the assert is the
  // enforcement, and it cannot run in a const constructor.
  // ignore: prefer_const_constructors_in_immutables
  Suppressed({
    required this.reason,
    required this.guidance,
    required this.careRoute,
  }) : assert(
         reason.isNotEmpty,
         'A suppression names what she logged — severe cramps, heavy bleeding.',
       );

  @override
  final List<LoggedSymptom> reason;

  final SevereGuidance guidance;
  final CareRoute careRoute;
}
