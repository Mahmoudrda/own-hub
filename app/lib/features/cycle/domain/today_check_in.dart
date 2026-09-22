/// Today's check-in — the **only** input to §2.4 and §2.5.
///
/// The document itself is G3's (`users/{uid}/checkins/{yyyy-MM-dd}`); this is
/// the value object G9 reads it as. G9 stores **no** symptom, ever (plan §1.1,
/// "Not stored, deliberately"), and duplicating the check-in is the failure that
/// line exists to prevent.
///
/// ## What this type deliberately cannot hold
///
/// **There is no date field on it.** That is not an oversight — it is the load
/// bearing half of rule 4. `SymptomSuggestionResolver.resolve` takes one
/// parameter, and that parameter is this type, so if this type carried a date
/// then a date would be reachable at the point a suggestion is decided. The
/// resolver's signature and this class's field list are one guarantee in two
/// places, and `resolver_signature_test.dart` asserts both.
///
/// For the same reason there is no `cycleDay`, no `phase`, no `periodDayIndex`
/// and no clock. A phase cannot influence a suggestion because a phase cannot be
/// passed to the only function that produces one.
///
/// ## Every field is nullable, and empty is valid
///
/// Plan §7.2, the two requirements attached to ratifying G3's enums: "(a) every
/// field stays nullable and a check-in with no fields is a valid document —
/// `noCheckIn` is a state, not an error; (b) the reader must never fall back to
/// a previous day."
///
/// [absent] is a first-class value rather than a null [TodayCheckIn], so the
/// "she has not logged today" case is something the type system carries instead
/// of something each caller has to remember to null-check. A new day always
/// starts here: nothing is carried over, because "a diary that assumes
/// continuity has stopped being a diary, and a carried-over severe symptom would
/// suppress a workout on a day she feels fine" (§3.3).
library;

import 'package:meta/meta.dart';

/// G3's `energy` enum, ratified verbatim in plan §7.2. Y04 renders
/// Low · Okay · High.
enum Energy { low, ok, high }

/// G3's `cramps` enum. `severe` is half of §2.5's gate.
enum Cramps { none, mild, moderate, severe }

/// G3's `appetite` enum. Display mapping is `low→less`, `ok→usual`,
/// `high→more`; the stored values stay G3's.
enum Appetite { low, ok, high }

/// G3's `sleep` enum. Behind Y04's "More to log".
enum Sleep { poor, ok, good }

/// G3's `bloating` enum. Behind Y04's "More to log".
enum Bloating { none, mild, moderate, severe }

/// G3's `bleeding` enum. `heavy` is the other half of §2.5's gate.
enum Bleeding { none, spotting, light, medium, heavy }

/// The six fields Y04 can write, all optional.
///
/// See the library comment for what this type cannot hold and why.
@immutable
class TodayCheckIn {
  const TodayCheckIn({
    this.energy,
    this.cramps,
    this.appetite,
    this.sleep,
    this.bloating,
    this.bleeding,
  });

  /// No check-in today.
  ///
  /// A value, not a null. `noCheckIn` is a state (§3.3's first row) and the
  /// screens render "How are you feeling?" and **her plan, unchanged** for it —
  /// never a suggestion.
  static const TodayCheckIn absent = TodayCheckIn();

  final Energy? energy;
  final Cramps? cramps;
  final Appetite? appetite;
  final Sleep? sleep;
  final Bloating? bloating;
  final Bleeding? bleeding;

  /// True when nothing at all has been logged.
  ///
  /// §3.3: `noCheckIn` is "no `checkins/{today}` document, **or every field
  /// null**" — so a document that exists with all fields cleared is the same
  /// state as no document, rather than a fifth kind of nothing.
  bool get isEmpty =>
      energy == null &&
      cramps == null &&
      appetite == null &&
      sleep == null &&
      bloating == null &&
      bleeding == null;

  bool get isNotEmpty => !isEmpty;

  TodayCheckIn copyWith({
    Energy? energy,
    Cramps? cramps,
    Appetite? appetite,
    Sleep? sleep,
    Bloating? bloating,
    Bleeding? bleeding,
  }) {
    return TodayCheckIn(
      energy: energy ?? this.energy,
      cramps: cramps ?? this.cramps,
      appetite: appetite ?? this.appetite,
      sleep: sleep ?? this.sleep,
      bloating: bloating ?? this.bloating,
      bleeding: bleeding ?? this.bleeding,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodayCheckIn &&
      other.energy == energy &&
      other.cramps == cramps &&
      other.appetite == appetite &&
      other.sleep == sleep &&
      other.bloating == bloating &&
      other.bleeding == bleeding;

  @override
  int get hashCode =>
      Object.hash(energy, cramps, appetite, sleep, bloating, bleeding);
}
