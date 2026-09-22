/// The append-only points ledger — `users/{uid}/awards/{awardId}`.
///
/// This is the object that makes a point mean something. Three properties, and
/// all three are structural rather than enforced by review:
///
/// 1. **Append-only.** There is no `remove`, no `delete`, no `clear` and no
///    setter on the points total. "Nothing earned is ever taken away" is not a
///    promise this class keeps; it is a promise it is incapable of breaking.
///    `test/domain/rewards/rewards_rules_test.dart` scans the source for a
///    method that would take something away, with a positive control proving the
///    scan bites.
///
/// 2. **Idempotent.** [record] refuses an award id it has already seen, and
///    refusing means **the increment never executes**. That is spine C4 as
///    corrected — *"an increment never travels alone"* — and it is why a Cloud
///    Function's at-least-once delivery is free of consequence here. `P0-RWD-01`
///    is this behaviour.
///
/// 3. **Capped.** The daily ceiling is applied inside the same call, so there is
///    no window in which points are added and then trimmed. `P0-RWD-02`.
///
/// In production this is a Firestore transaction: create `awards/{awardId}` and
/// apply `increment(points)` atomically, so a duplicate id aborts the whole
/// thing. This class is the same transaction in memory, and a test can drive the
/// replay that a phone would only produce on a bad train journey.
library;

import 'package:meta/meta.dart';

import 'award_table.dart';
import 'daily_cap.dart';

/// Why an award added nothing.
enum LedgerRefusal {
  /// The award id was already in the ledger. A replay, and a no-op.
  duplicate,

  /// The daily ceiling.
  capped,
}

/// The outcome of offering one award to the ledger.
@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.award,
    required this.granted,
    required this.refusal,
  });

  final Award award;

  /// Points actually added to her total.
  final int granted;

  /// Null when the award landed in full.
  final LedgerRefusal? refusal;

  bool get recorded => refusal != LedgerRefusal.duplicate;
}

/// Her awards, and the total they add up to.
class AwardLedger {
  AwardLedger({
    this.cap = const DailyCap(),
    DailyCapState? today,
    Iterable<String> existingAwardIds = const <String>[],
    this.points = 0,
  }) : _today = today ?? const DailyCapState.fresh(''),
       _ids = {...existingAwardIds};

  final DailyCap cap;

  final Set<String> _ids;
  DailyCapState _today;

  /// Her points total. Rises or stays; there is no code path that lowers it.
  ///
  /// Settable only from inside this class, and the only statement that assigns
  /// it is a `+=` in [record]. There is no setter, no `reset` and no method that
  /// subtracts — which is what makes "nothing earned is ever taken away" a
  /// property of the type rather than a promise about how it is used.
  int points;

  /// How many awards are on the ledger.
  int get awardCount => _ids.length;

  /// Today's cap state, for the caller that persists it.
  DailyCapState get capState => _today;

  /// Whether this award has already been made.
  bool contains(String awardId) => _ids.contains(awardId);

  /// Offers an award to the ledger.
  ///
  /// The order is the point: **the id is checked first**, so a replayed award
  /// neither pays again nor consumes any of her daily budget. Checking the cap
  /// first would let a duplicate eat headroom that a genuine new award then
  /// could not use — the same log costing her points she had not spent.
  LedgerEntry record(Award award, {required String dayKey}) {
    if (_ids.contains(award.awardId)) {
      return LedgerEntry(
        award: award,
        granted: 0,
        refusal: LedgerRefusal.duplicate,
      );
    }

    final decision = cap.apply(state: _today, dayKey: dayKey, award: award);

    // The award document is created whether or not the cap allowed points
    // through, which is what stops a capped award being retried tomorrow for
    // full value. The ledger records that it happened, not only that it paid.
    _ids.add(award.awardId);
    _today = decision.state;
    points += decision.granted;

    return LedgerEntry(
      award: award,
      granted: decision.granted,
      refusal: decision.granted == award.points ? null : LedgerRefusal.capped,
    );
  }
}
