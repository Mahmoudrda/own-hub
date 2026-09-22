/// The half of a personal best that outlives the session.
///
/// [PersonalBestDetector] computes and stores nothing: it is handed the bests
/// she already holds, and it returns the ones this session beat. Something has
/// to keep the running maximum and count what was earned, and until now nothing
/// did — `MeasuredSet` was constructed only inside the detector's own file, so
/// no session ever reached it and `rewards.bestsCount` never moved.
///
/// That was not only a missing feature. `TierLadder.shipped` promotes on
/// **counted weeks and personal bests** — Regular needs 3, Strong 8,
/// Unshakeable 15 — so with the count frozen at zero, three of the five tiers
/// were unreachable however long a woman trained.
///
/// ## Two different questions, two different keys
///
/// `users/{uid}/bests/{exerciseId}` is the running maximum, keyed by exercise:
/// there is one, it is the best she has ever done, and it is overwritten every
/// time she beats it.
///
/// `rewards.bestsCount` is a lifetime tally, and it is keyed by
/// **[personalBestId] — one per exercise per session**. The two are deliberately
/// different. R07 flushes per set, so one session can beat the same exercise
/// twice; the second lift is a better maximum and must be stored, but it is not
/// a second achievement and must not be counted again. That is the same key
/// `AwardTable` already mints a best's points under, so the count and the points
/// cannot disagree about what happened.
///
/// ## Idempotent twice over
///
/// A replayed flush is refused on both paths. The detector is self-idempotent
/// once a best is materialised — a lift compared against itself is not greater —
/// and [personalBestId] catches the case where that protection is absent,
/// namely a retry that arrives before the best was persisted. The id is checked
/// on the increment and not on the write, so a replay never inflates the count
/// and a genuine second improvement is never lost.
///
/// ## Rule 11
///
/// The load field is `loadKg`, inherited from [PersonalBest] and never
/// renamed. A best is a weight on a bar compared with her own past, so there is
/// no other woman in the comparison and nothing here can rank one. This class
/// has no parameter through which her body weight could arrive.
library;

import 'package:meta/meta.dart';

import '../training/session.dart';
import 'personal_best_detector.dart';

/// The deterministic id a best is counted under: one per exercise per session.
///
/// Identical by construction to `AwardTable`'s `best:$exerciseId:$sessionId`, so
/// the tally and the points are keyed on the same fact.
String personalBestId({
  required String exerciseId,
  required String sessionId,
}) => 'best:$exerciseId:$sessionId';

/// What one flush did to her bests.
@immutable
class SessionBests {
  const SessionBests({
    this.written = const <PersonalBest>[],
    this.counted = const <PersonalBest>[],
  });

  /// Nothing was beaten.
  static const SessionBests none = SessionBests();

  /// Every running maximum this flush raised.
  final List<PersonalBest> written;

  /// The subset that incremented `bestsCount` — the first best on that exercise
  /// in that session. These are the ones worth celebrating and worth points.
  final List<PersonalBest> counted;

  bool get isEmpty => written.isEmpty;
}

/// Her running bests, and the lifetime count the tier ladder reads.
///
/// Mutable and append-only, exactly as `AwardLedger` is: there is no method that
/// lowers [bestsCount] and none that removes a best. Nothing earned is ever
/// taken away is a property of the type rather than a promise about its use.
class PersonalBestLedger {
  PersonalBestLedger({
    this.detector = const PersonalBestDetector(),
    Map<String, PersonalBest>? bests,
    Iterable<String> countedIds = const <String>[],
    this.bestsCount = 0,
  }) : bests = bests ?? <String, PersonalBest>{},
       _counted = {...countedIds};

  final PersonalBestDetector detector;

  /// `users/{uid}/bests/{exerciseId}`, materialised. Pass the map a store
  /// already holds and it is updated in place, so the screen reading it and the
  /// ledger writing it cannot hold two ideas of her best.
  final Map<String, PersonalBest> bests;

  final Set<String> _counted;

  /// `rewards.bestsCount`. Rises or stays; the only statement that touches it
  /// adds one.
  int bestsCount;

  /// The ids already counted, for the caller that persists them.
  Set<String> get countedIds => Set<String>.unmodifiable(_counted);

  /// Whether this exercise has already been counted in this session.
  bool hasCounted({required String exerciseId, required String sessionId}) =>
      _counted.contains(
        personalBestId(exerciseId: exerciseId, sessionId: sessionId),
      );

  /// Runs detection over one flush and records what it found.
  ///
  /// [source] is the credit enum's, not the Train feature's — see
  /// `features/train/domain/measured_sets.dart`, which is the only place the two
  /// are joined. A source that is not `live` never reaches the ledger at all,
  /// because the detector refuses it first.
  SessionBests apply({
    required SessionSource source,
    required String sessionId,
    required String dateKey,
    required List<MeasuredSet> measuredSets,
    required Map<String, ExerciseMeta> exercises,
  }) {
    final found = detector.detect(
      source: source,
      sessionId: sessionId,
      dateKey: dateKey,
      measuredSets: measuredSets,
      exercises: exercises,
      current: bests,
    );
    if (found.isEmpty) return SessionBests.none;

    final counted = <PersonalBest>[];
    for (final best in found) {
      // The running maximum is always brought up to date: she lifted it, so P03
      // must show it, whether or not this is the first best of the session.
      bests[best.exerciseId] = best;

      final id = personalBestId(
        exerciseId: best.exerciseId,
        sessionId: sessionId,
      );
      // `add` returns false for an id already present, which is the whole of
      // the idempotency rule — a replay neither counts again nor pays again.
      if (_counted.add(id)) {
        bestsCount += 1;
        counted.add(best);
      }
    }

    return SessionBests(written: found, counted: counted);
  }
}
