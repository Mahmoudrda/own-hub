/// What life as a coached client reads, and what it costs.
///
/// Every read here is a point `get` on a **deterministic id** — the relationship
/// id, a date key, a version, an ISO week. There is no `.where()`, no
/// `.orderBy()` and no collection-group query in this interface, which is what
/// keeps the client hot path off the index budget entirely.
///
/// ## The one-read promise, made testable
///
/// G05 draws thirty days. Drawn from thirty assignment documents it costs
/// thirty reads every time she opens it; drawn from `versions/{v}.calendar[30]`
/// it costs one. [InMemoryCoachedRepository] **counts its reads**, and
/// `coached_repository_test.dart` asserts the month view costs one and never
/// thirty. A counter is the only way that promise stays true after the next
/// refactor: without it, a helpful `for (final day in days) await
/// assignment(day)` looks identical in review.
///
/// ## Absence means rest
///
/// [CoachedRepository.assignment] returns null for a day the plan prescribes
/// rest. That is an answer, not an error and not a spinner — G2's rule,
/// inherited without modification.
///
/// ## Nothing here writes a plan
///
/// There is no publish method, no assignment write and no version write. The
/// only transition into a published plan is the coach's publish callable, which
/// lives on the other side of the product. This interface cannot express it.
library;

import 'package:meta/meta.dart';

import 'g2_contract.dart';
import 'message_repository.dart';
import 'plan_update_card.dart';
import 'relationship.dart';

/// The reads G01–G17 make.
abstract class CoachedRepository {
  /// `relationships/{relId}` — one point get on an id both parties compute.
  Future<Relationship?> relationship(RelationshipRef ref);

  /// `plans/{uid}/assignments/{yyyy-MM-dd}`. Null means rest.
  Future<CoachAssignment?> assignment(String dateKey);

  /// `plans/{uid}/versions/{v}` — **one document**, carrying `calendar[30]`.
  Future<PlanVersion?> version(String version);

  /// Every version the coach has published, oldest first.
  ///
  /// Used by `PlanUpdateCard` and by nothing else. It is a read of published
  /// versions, which is the only thing a "plan updated" card may be made of.
  Future<List<PlanVersion>> publishedVersions();

  /// Moves this reader's cursor on the thread. Two parties, two distinct keys.
  Future<void> setReadCursor(RelationshipRef ref, String uid, DateTime at);
}

/// An in-memory implementation that counts what it reads.
///
/// Strict in the two places the real backend is strict: an unknown version is
/// null rather than an empty calendar, and an assignment for a day the plan
/// never mentioned is null rather than an invented rest day.
class InMemoryCoachedRepository implements CoachedRepository {
  InMemoryCoachedRepository({
    Relationship? relationship,
    Map<String, CoachAssignment>? assignments,
    List<PlanVersion>? versions,
  }) : _held = relationship,
       _assignments = <String, CoachAssignment>{...?assignments},
       _versions = <PlanVersion>[...?versions];

  Relationship? _held;
  final Map<String, CoachAssignment> _assignments;
  final List<PlanVersion> _versions;

  /// Documents read since construction. The evidence behind G05's promise.
  int reads = 0;

  /// The paths read, in order, for a test that wants to say *which* reads.
  final List<String> readPaths = <String>[];

  /// Read cursors, one key per party.
  final Map<String, DateTime> cursors = <String, DateTime>{};

  /// Puts a relationship in place, without counting as a read.
  set relationshipSeed(Relationship? value) => _held = value;

  void seedVersion(PlanVersion version) => _versions.add(version);

  void seedAssignment(CoachAssignment assignment) =>
      _assignments[assignment.dateKey] = assignment;

  void resetReads() {
    reads = 0;
    readPaths.clear();
  }

  @override
  Future<Relationship?> relationship(RelationshipRef ref) async {
    _count('relationships/${ref.relId}');
    final held = _held;
    if (held == null || held.relId != ref.relId) return null;
    return held;
  }

  @override
  Future<CoachAssignment?> assignment(String dateKey) async {
    _count('assignments/$dateKey');
    // Absence is rest. Never an error, never an invented day.
    return _assignments[dateKey];
  }

  @override
  Future<PlanVersion?> version(String version) async {
    _count('versions/$version');
    for (final v in _versions) {
      if (v.version == version) return v;
    }
    return null;
  }

  @override
  Future<List<PlanVersion>> publishedVersions() async {
    // One read per version document. A coached engagement has a handful.
    for (final v in _versions) {
      _count('versions/${v.version}');
    }
    return List.unmodifiable(
      List<PlanVersion>.of(_versions)
        ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt)),
    );
  }

  @override
  Future<void> setReadCursor(
    RelationshipRef ref,
    String uid,
    DateTime at,
  ) async {
    if (!ref.includes(uid)) {
      throw StateError('$uid is not a party to ${ref.relId}.');
    }
    cursors[uid] = at;
  }

  void _count(String path) {
    reads++;
    readPaths.add(path);
  }
}

/// One cell of G05's month grid.
@immutable
class PlanDay {
  const PlanDay({
    required this.dayNumber,
    required this.kind,
    required this.date,
    this.done = false,
    this.isToday = false,
  });

  /// 1…30, as she reads it.
  final int dayNumber;

  final PlanDayKind kind;
  final DateTime date;

  /// Whether she actually trained. **Counted from her logs**, never from the
  /// plan: a day the plan asked for is not a day she did.
  final bool done;

  final bool isToday;

  @override
  String toString() => 'PlanDay($dayNumber ${kind.name}${done ? ' done' : ''})';
}

/// Reads a published coached plan — and pins the version a session runs on.
class CoachedPlanReader {
  const CoachedPlanReader(this.repository);

  final CoachedRepository repository;

  /// G05's thirty cells, from **one** document.
  ///
  /// [completedDayNumbers] comes from her own session history, which the caller
  /// already holds; passing it in is what keeps this a one-read call rather
  /// than thirty-one.
  Future<List<PlanDay>> calendar({
    required String version,
    required DateTime today,
    Set<int> completedDayNumbers = const <int>{},
  }) async {
    final doc = await repository.version(version);
    if (doc == null) return const <PlanDay>[];

    final days = <PlanDay>[];
    for (var i = 1; i <= PlanVersion.calendarLength; i++) {
      final date = doc.startsOn.add(Duration(days: i - 1));
      days.add(
        PlanDay(
          dayNumber: i,
          kind: doc.dayAt(i),
          date: date,
          done: completedDayNumbers.contains(i),
          isToday:
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day,
        ),
      );
    }
    return List.unmodifiable(days);
  }

  /// The day number [date] falls on, or null when it is outside the engagement.
  int? dayNumberFor(PlanVersion version, DateTime date) {
    final start = DateTime(
      version.startsOn.year,
      version.startsOn.month,
      version.startsOn.day,
    );
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(start).inDays + 1;
    if (diff < 1 || diff > PlanVersion.calendarLength) return null;
    return diff;
  }

  /// Pins the version a session will run on, once.
  ///
  /// Returns a [PinnedPlanVersion], which has no method that could refresh it.
  /// A revision published mid-session therefore cannot reach the session, and
  /// the type is where that is true rather than a comment asking nobody to
  /// re-read.
  PinnedPlanVersion pin(CoachAssignment assignment, {required DateTime at}) =>
      PinnedPlanVersion(assignment.planVersion, pinnedAt: at);
}
