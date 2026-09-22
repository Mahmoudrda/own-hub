/// `coaches/{c}/private/desk` — one document, and the whole of `K07`, `K24`,
/// `K25` and `K06`.
///
/// # Why one document
///
/// `P0-CSCALE-01`: *"Exactly 2 document reads regardless of roster size."* G12
/// §2.1 is the argument — a coach with sixty clients must not cause sixty reads
/// when she opens Today, so the queue is a **Cloud-Function-maintained
/// aggregate** capped at thirty items, each carrying only what a row renders,
/// with everything below the cap collapsed into [CoachDesk.overflowCount].
///
/// [CoachDesk] enforces the cap in its constructor rather than trusting the
/// writer. A fake that accepted a forty-item queue would let `K07` pass its
/// tests against a shape the Cloud Function will never produce, which is the
/// failure `InMemoryCycleRepository` was written to avoid.
///
/// # `K24` is a state, not a route
///
/// HANDOFF 16, and `P1-RULE-13` checks it by inspecting the route table.
/// [CoachTodayState.resolve] is the branch: same widget, same route, different
/// rendering because the roster is empty. `app_router.dart` lists `K24` in
/// `firstRunStates`, so it is not a destination and nothing can navigate to
/// "Today, empty" over a Today that is not.
///
/// # No streak lives here
///
/// §2 rule 3. [CoachFirstWeek] has four steps, three states and **no failed
/// state** — [CoachStepState] has no value meaning failed, so one is not
/// constructible. Nothing expires, and `K25` says so out loud. The client-side
/// arc made the same choice for the same reason (`features/today`).
library;

import 'package:meta/meta.dart';

import 'coach_capacity.dart';
import 'coach_verification.dart';
import 'payments.dart';

/// Why someone is in the queue. An id, so `K07` renders a translated line rather
/// than a sentence a Cloud Function composed in one language.
enum DeskReason {
  /// A weekly review is due.
  reviewDue,

  /// A check-in is waiting.
  checkIn,

  /// A new enquiry. Leads to `K09`.
  newEnquiry,

  /// A message she has not answered.
  message,
}

/// One row of `K07`.
///
/// Note how little is here: G12 §2.1 budgets ~200 B per item, and everything a
/// row draws is on it. Nothing else about the client is carried, because
/// carrying more would mean projecting more than the sharing switches allow.
@immutable
class DeskQueueItem {
  const DeskQueueItem({
    required this.relId,
    required this.displayName,
    required this.reason,
    required this.waitingSince,
  });

  final String relId;
  final String displayName;
  final DeskReason reason;

  /// What "oldest first" is ordered by.
  final DateTime waitingSince;

  /// The letter `K07` draws in the avatar.
  String get initial => displayName.trim().isEmpty
      ? ''
      : displayName.trim().substring(0, 1).toUpperCase();

  Duration waitedBy(DateTime now) => now.difference(waitingSince);
}

/// One step of `K25`. Four, and each produces something a client will see.
enum CoachFirstWeekStep {
  publishPage,
  saveSplit,
  setUpAssessment,
  answerEnquiry,
}

/// Done, current, or waiting. **There is no failed value, on purpose.**
enum CoachStepState { done, now, waiting }

/// Her first week — `K25`, and the row `K24` links to it with.
///
/// No timer, no expiry, no failure. The health-app evidence the design cites is
/// that visible failure indicators erode the motivation they were built to
/// create, so the steps simply wait.
@immutable
class CoachFirstWeek {
  const CoachFirstWeek({
    this.completed = const <CoachFirstWeekStep>{},
    this.certificatesCleared = false,
  });

  /// Which steps she has finished. A set, not a counter: a step never
  /// un-completes, so two devices cannot disagree destructively.
  final Set<CoachFirstWeekStep> completed;

  /// Whether a human has cleared her certificates — `K25`'s sage card, and
  /// `P0-CVER-02`'s "K25 step marks certificates cleared".
  ///
  /// Kept **off the public root** deliberately (G12 §1.3): `K25`'s own copy says
  /// no client sees her progress through it, and that is a schema requirement
  /// rather than a UI preference.
  final bool certificatesCleared;

  int get stepCount => CoachFirstWeekStep.values.length;

  int get doneCount => completed.length;

  bool get isComplete => doneCount >= stepCount;

  /// The state of one step.
  ///
  /// The first unfinished step is `now`; the rest wait. Nothing is ever `failed`
  /// because there is no such value.
  CoachStepState stateOf(CoachFirstWeekStep step) {
    if (completed.contains(step)) return CoachStepState.done;
    for (final s in CoachFirstWeekStep.values) {
      if (!completed.contains(s)) {
        return s == step ? CoachStepState.now : CoachStepState.waiting;
      }
    }
    return CoachStepState.waiting;
  }

  CoachFirstWeek withStep(CoachFirstWeekStep step) => CoachFirstWeek(
    completed: {...completed, step},
    certificatesCleared: certificatesCleared,
  );

  CoachFirstWeek withCertificatesCleared() =>
      CoachFirstWeek(completed: completed, certificatesCleared: true);
}

/// The desk document.
@immutable
class CoachDesk {
  /// Builds a desk, enforcing the queue cap.
  ///
  /// Throws [ArgumentError] on an over-long queue rather than truncating: a
  /// silent truncation would hide the one thing this cap exists to guarantee,
  /// and the Cloud Function that produced it needs to fail loudly.
  factory CoachDesk({
    List<DeskQueueItem> queue = const <DeskQueueItem>[],
    int overflowCount = 0,
    CoachVerificationState verification =
        CoachVerificationState.setupIncomplete,
    CoachFirstWeek firstWeek = const CoachFirstWeek(),
    EarningsState earnings = const EarningsState.unavailable(
      PaymentUnavailableReason.notImplemented,
    ),
    DateTime? builtAt,
  }) {
    if (queue.length > queueCap) {
      throw ArgumentError.value(
        queue.length,
        'queue',
        'The desk queue caps at $queueCap items with everything below it in '
            'overflowCount (G12 §2.1). A longer queue is a Cloud Function bug, '
            'and K07 must stay at two document reads at any roster size.',
      );
    }
    if (overflowCount < 0) {
      throw ArgumentError.value(overflowCount, 'overflowCount', 'negative');
    }
    final sorted = [...queue]
      ..sort((a, b) => a.waitingSince.compareTo(b.waitingSince));
    return CoachDesk._(
      queue: sorted,
      overflowCount: overflowCount,
      verification: verification,
      firstWeek: firstWeek,
      earnings: earnings,
      builtAt: builtAt,
    );
  }

  const CoachDesk._({
    required this.queue,
    required this.overflowCount,
    required this.verification,
    required this.firstWeek,
    required this.earnings,
    required this.builtAt,
  });

  /// G12 §2.1. Thirty items, ~200 B each, and everything else is a count.
  static const int queueCap = 30;

  /// Oldest first — `K07`'s ordering, so she never has to hunt for who has been
  /// waiting longest. Sorted on construction, not by the screen.
  final List<DeskQueueItem> queue;

  /// How many are waiting beyond the cap.
  final int overflowCount;

  final CoachVerificationState verification;
  final CoachFirstWeek firstWeek;

  /// Her month, from the seam. [EarningsUnavailable] by default, because that
  /// is what the seam can supply today, and a screen given it shows **nothing
  /// about money** rather than a zero.
  final EarningsState earnings;

  /// When the Cloud Function last rebuilt this. `K07` states it as "as of
  /// HH:MM" when the document came from cache (G12 §4).
  final DateTime? builtAt;

  /// Everyone waiting, including those past the cap.
  int get waitingCount => queue.length + overflowCount;

  /// The longest wait, or null when nobody is waiting.
  DateTime? get oldestWaitingSince =>
      queue.isEmpty ? null : queue.first.waitingSince;

  /// Enquiries in the queue. `K07` routes these to `K09`.
  List<DeskQueueItem> get enquiries =>
      queue.where((i) => i.reason == DeskReason.newEnquiry).toList();
}

/// The three renderings of one route. G12 §3.4.
enum CoachTodayState {
  /// `K24` with the amber "checking your certificates" card.
  dayOneUnverified,

  /// `K24` without it.
  dayOneVerified,

  /// `K07`.
  working;

  /// Whether this is a day-one branch — what the widget switches on.
  bool get isDayOne => this != CoachTodayState.working;

  /// Whether the amber verification card is drawn.
  bool get showsVerificationCard => this == CoachTodayState.dayOneUnverified;
}

/// Chooses the branch.
///
/// **The roster decides, not the route.** Accepting a first client flips this
/// from a day-one value to [CoachTodayState.working] with no navigation, which
/// is the whole of `P0-CDAY-01`'s last sentence.
///
/// Note it reads [CoachCapacity.taken] rather than the queue: a coach with
/// twelve clients and a quiet evening has an empty queue and is emphatically not
/// on day one. Branching on the queue would show her the empty state the moment
/// she caught up, which is the opposite of a reward.
abstract final class CoachToday {
  static CoachTodayState resolve({
    required CoachDesk desk,
    required CoachCapacity capacity,
  }) {
    if (!capacity.isEmpty) return CoachTodayState.working;
    return desk.verification.holdsCoachClaim
        ? CoachTodayState.dayOneVerified
        : CoachTodayState.dayOneUnverified;
  }
}
