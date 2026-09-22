/// How many women a coach can carry at once — `K04`, and the number `K18` and
/// `H02` render as "12 spots left".
///
/// # Why this is a type and not two ints
///
/// `taken` and `max` have **different writers**. G12 §1.2: `max` is hers, `taken`
/// is Cloud-Function-only, and the security rules exclude `taken` from the
/// client's write mask. A pair of plain integers on a form gives a screen the
/// ability to send both, and last-write-wins would then let a stale `taken` from
/// an offline device resurrect a spot that no longer exists (G12 §4). So the
/// only way to change `taken` from this layer is [withOneMoreTaken], which is
/// called by the accept transaction and by nothing else, and [withMax] carries
/// `taken` through untouched.
///
/// # The ceiling is sixty
///
/// The owner set the product cap at **60 clients**. G12 §1.2 and §2.1 were
/// written against 200 — `capacity.max <= 200` in the rules, and a scalability
/// table with a 200-client row. Sixty is the number that ships, and the
/// divergence is recorded here rather than left for someone to find in a rules
/// file. Nothing in G12's scalability argument depends on the larger figure:
/// `K07` is two document reads at any roster size, and the desk queue caps at
/// thirty with an overflow count either way.
///
/// # Nothing here ranks anybody
///
/// §2 rule 11. `taken` is a count of her own clients, never a position against
/// another coach's. There is no comparison operator on this type and no ordering
/// derived from it — and G12 §1.5 requires a single-field index **exemption** on
/// `capacity.taken`, because Firestore auto-indexes it and a sortable `taken` is
/// a ready-made "least busy coach" leaderboard.
library;

import 'package:meta/meta.dart';

/// Her roster, and the ceiling she set on it.
@immutable
class CoachCapacity {
  const CoachCapacity._({required this.max, required this.taken});

  /// The product cap. Sixty, by the owner's decision.
  static const int ceiling = 60;

  /// The smallest roster worth advertising. One, because a coach who can take
  /// nobody should not be listed as taking someone.
  static const int floor = 1;

  /// Builds a validated capacity.
  ///
  /// Throws [ArgumentError] rather than clamping. A clamp would let `K04` send
  /// 200 and silently store 60, so she would read one number on her form and
  /// another on her page — and `K18`'s "12 of 20 taken" is a promise to the
  /// client, not a display preference.
  factory CoachCapacity({required int max, int taken = 0}) {
    if (max < floor || max > ceiling) {
      throw ArgumentError.value(
        max,
        'max',
        'A coach carries between $floor and $ceiling clients at once.',
      );
    }
    if (taken < 0) {
      throw ArgumentError.value(taken, 'taken', 'cannot be negative');
    }
    if (taken > max) {
      throw ArgumentError.value(
        taken,
        'taken',
        'taken ($taken) cannot exceed max ($max). An increment that could '
            'overshoot is the defect spine C4 exists to prevent.',
      );
    }
    return CoachCapacity._(max: max, taken: taken);
  }

  /// A coach who has not answered `K04` yet.
  ///
  /// Deliberately **not** a default of twenty. Twenty is the prototype's sample,
  /// and a screen that offers it as a pre-filled answer is stating her capacity
  /// on her behalf. `K04` asks; nothing answers for her.
  static const CoachCapacity unset = CoachCapacity._(max: 0, taken: 0);

  /// Her ceiling. Written by her, on `K04`.
  final int max;

  /// How many spots are held. **Cloud-Function-only** — see the file note.
  final int taken;

  /// Whether she has answered `K04`.
  bool get isSet => max >= floor;

  /// Spots left. Never negative, and never larger than [max].
  int get spotsLeft => isSet ? max - taken : 0;

  /// Whether one more woman fits.
  bool get hasRoom => isSet && taken < max;

  /// Whether the roster is empty — the condition `K24` branches on.
  bool get isEmpty => taken == 0;

  /// Her ceiling moved. `taken` is carried through, never re-sent.
  ///
  /// Refuses to drop the ceiling below the women she already has: G12 §3.3's
  /// promise is that her paperwork never costs a client her coach, and a `max`
  /// under `taken` would make every existing client an overflow.
  CoachCapacity withMax(int next) {
    if (next < taken) {
      throw ArgumentError.value(
        next,
        'max',
        'Lowering the ceiling below the $taken women already with her would '
            'strand them. Ask her to finish with someone first.',
      );
    }
    return CoachCapacity(max: next, taken: taken);
  }

  /// One spot held.
  ///
  /// Returns null when the roster is full, rather than throwing or clamping.
  /// `P0-ENQ-03` is two devices accepting the last spot at once: the caller
  /// asserts the enquiry's status **and** takes this in the same transaction, so
  /// the loser fails on the status test rather than on a counter read. A null
  /// here is the second line, not the first.
  CoachCapacity? withOneMoreTaken() =>
      hasRoom ? CoachCapacity(max: max, taken: taken + 1) : null;

  /// One spot released — coaching ended, or an accept was rolled back.
  CoachCapacity withOneFewerTaken() =>
      CoachCapacity(max: max, taken: taken > 0 ? taken - 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is CoachCapacity && other.max == max && other.taken == taken;

  @override
  int get hashCode => Object.hash(max, taken);

  @override
  String toString() => 'CoachCapacity($taken of $max)';
}
