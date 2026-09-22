/// A split — G14 §1.1 and §1.3. **A template, not a plan.**
///
/// The first of the four consequences that shape the whole feature:
///
/// > The template is copied **by value** into a draft; the published version
/// > keeps `templateRef` as *provenance only* and never dereferences it. There
/// > is therefore no code path by which editing a split reaches a published
/// > plan — **not a guard, an absence**.
///
/// The absence is visible in this file: a [Split] holds no client, no plan, no
/// draft and no version. It cannot name a person ([ownerKind] is the only role
/// it knows), so there is nothing here for a cascade to follow.
///
/// ## One model, two owners
///
/// D7 gives the trainee the same builder. G14 §1.3 lists exactly three
/// differences between the coach's copy and hers, and no fourth:
///
/// | | Coach | Client |
/// |---|---|---|
/// | `ownerKind` | `coach` | `self` |
/// | `appliedCount` | present | **absent** — nothing to count |
/// | `approvedAlternatives` | present | **absent** — "approved" means approved
///   *by a coach*; a woman choosing her own easier move is just editing her own
///   split |
///
/// [toWire] omits both for a client-owned split rather than writing zero or an
/// empty list, because the ruleset denies the *keys*, and because a `0` is a
/// count of something and there is nothing here to count.
library;

import 'package:meta/meta.dart';

import '../prescription.dart';

/// Whose split this is. The discriminator that makes the two paths one model.
enum SplitOwnerKind {
  coach('coach'),
  self('self');

  const SplitOwnerKind(this.wireName);

  final String wireName;
}

/// Where the shape came from. Mirrors the client field, for D7 parity.
enum SplitSource {
  library('library'),
  own('own');

  const SplitSource(this.wireName);

  final String wireName;
}

/// A day slot is either a session or a rest day. K20's rest rows are a
/// *decision*, not an empty row: "marked as planned rest — it costs you
/// nothing".
enum DaySlotKind {
  session('session'),
  rest('rest');

  const DaySlotKind(this.wireName);

  final String wireName;
}

/// The shortest and longest cycle K20 offers. Hard-bounded by G14 §1.1, and
/// `daySlots.length == cycleLength` is checked by `SplitValidator`.
const int kMinCycleLength = 3;
const int kMaxCycleLength = 7;

/// The longest a split's name may be.
const int kMaxSplitNameLength = 60;

/// One day of the cycle.
@immutable
class SplitDaySlot {
  SplitDaySlot({
    required this.dayIndex,
    required this.kind,
    this.title,
    this.minutes,
    this.restBetweenSetsSec,
    List<PrescribedMove> moves = const <PrescribedMove>[],
    List<ApprovedAlternative> approvedAlternatives =
        const <ApprovedAlternative>[],
  }) : moves = List<PrescribedMove>.unmodifiable(moves),
       approvedAlternatives = List<ApprovedAlternative>.unmodifiable(
         approvedAlternatives,
       );

  /// A rest day, which carries no title, no minutes and no moves.
  SplitDaySlot.rest({required int dayIndex})
    : this(dayIndex: dayIndex, kind: DaySlotKind.rest);

  /// 1-based, and 1..cycleLength.
  final int dayIndex;

  final DaySlotKind kind;

  /// Null exactly when this is a rest day.
  final String? title;

  /// One of [kSessionMinuteOptions].
  final int? minutes;

  /// One of [kRestBetweenSetsOptions].
  final int? restBetweenSetsSec;

  final List<PrescribedMove> moves;

  /// Carried into a draft only when the split's `carryApproved` is on, and
  /// never present at all on a client-owned split.
  final List<ApprovedAlternative> approvedAlternatives;

  bool get isRest => kind == DaySlotKind.rest;

  /// A new slot holding new instances of everything inside it.
  SplitDaySlot copy() => SplitDaySlot(
    dayIndex: dayIndex,
    kind: kind,
    title: title,
    minutes: minutes,
    restBetweenSetsSec: restBetweenSetsSec,
    moves: <PrescribedMove>[for (final move in moves) move.copy()],
    approvedAlternatives: <ApprovedAlternative>[
      for (final alternative in approvedAlternatives) alternative.copy(),
    ],
  );

  Map<String, Object?> toWire({required SplitOwnerKind ownerKind}) =>
      <String, Object?>{
        'dayIndex': dayIndex,
        'kind': kind.wireName,
        if (title != null) 'title': title,
        if (minutes != null) 'minutes': minutes,
        if (restBetweenSetsSec != null)
          'restBetweenSetsSec': restBetweenSetsSec,
        if (moves.isNotEmpty)
          'moves': <Map<String, Object?>>[
            for (final move in moves) move.toWire(),
          ],
        // D7: the key does not exist on her own split, rather than existing
        // and being empty.
        if (ownerKind == SplitOwnerKind.coach &&
            approvedAlternatives.isNotEmpty)
          'approvedAlternatives': <Map<String, Object?>>[
            for (final alternative in approvedAlternatives)
              alternative.toWire(),
          ],
      };

  @override
  String toString() => 'SplitDaySlot($dayIndex, ${kind.wireName})';
}

/// The template itself.
@immutable
class Split {
  Split({
    required this.splitId,
    required this.name,
    required this.cycleLength,
    required List<SplitDaySlot> daySlots,
    required this.ownerKind,
    this.source = SplitSource.own,
    this.carryApproved = false,
    this.appliedCount = 0,
    this.updatedAt,
  }) : daySlots = List<SplitDaySlot>.unmodifiable(daySlots);

  /// Minted once by the client and reused on every retry, so an offline replay
  /// collides with itself instead of creating a second split (spine C1).
  final String splitId;

  final String name;

  /// 3–7. K20's chip row.
  final int cycleLength;

  /// Ordered, and exactly [cycleLength] long.
  final List<SplitDaySlot> daySlots;

  final SplitOwnerKind ownerKind;
  final SplitSource source;

  /// K20's "Keep her easier options". Default off: an approved substitution is
  /// a clinical judgement about one woman, and carrying it to everyone by
  /// default would export that judgement without anybody deciding to.
  final bool carryApproved;

  /// K19's "on 7 clients". **Displayed, never an `orderBy`** (rule 11). It is
  /// written by the publish Function with `FieldValue.increment`; nothing on a
  /// device may move it, which `SplitRepository` enforces.
  final int appliedCount;

  /// Null before the first save.
  final DateTime? updatedAt;

  bool get isCoachOwned => ownerKind == SplitOwnerKind.coach;

  /// The slot for a 1-based day index, or null.
  SplitDaySlot? slotFor(int dayIndex) {
    for (final slot in daySlots) {
      if (slot.dayIndex == dayIndex) return slot;
    }
    return null;
  }

  int get sessionDayCount => daySlots.where((slot) => !slot.isRest).length;
  int get restDayCount => daySlots.where((slot) => slot.isRest).length;

  /// An edited copy. K20's only mutation, and it writes **nothing** anywhere
  /// else: see `SplitApplicator` for why a draft cannot be reached from here.
  Split withChanges({
    String? name,
    int? cycleLength,
    List<SplitDaySlot>? daySlots,
    bool? carryApproved,
    SplitSource? source,
    DateTime? updatedAt,
  }) => Split(
    splitId: splitId,
    name: name ?? this.name,
    cycleLength: cycleLength ?? this.cycleLength,
    daySlots: daySlots ?? this.daySlots,
    ownerKind: ownerKind,
    source: source ?? this.source,
    carryApproved: carryApproved ?? this.carryApproved,
    // Deliberately not copyable from the outside: a device may never move the
    // count, so `withChanges` carries the stored value forward untouched.
    appliedCount: appliedCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// The document, as stored.
  ///
  /// Note what is absent: no `clientUid`, no `assignedTo`, no `clients`. A
  /// template is not about a person, so there is no field on it that names one
  /// — which is also what the ruleset checks.
  Map<String, Object?> toWire() => <String, Object?>{
    'splitId': splitId,
    'name': name,
    'cycleLength': cycleLength,
    'daySlots': <Map<String, Object?>>[
      for (final slot in daySlots) slot.toWire(ownerKind: ownerKind),
    ],
    'carryApproved': carryApproved,
    'source': source.wireName,
    'ownerKind': ownerKind.wireName,
    if (ownerKind == SplitOwnerKind.coach) 'appliedCount': appliedCount,
  };

  @override
  String toString() =>
      'Split($splitId, ${ownerKind.wireName}, $cycleLength days)';
}
