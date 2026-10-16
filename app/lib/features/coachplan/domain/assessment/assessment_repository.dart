/// `assessments/*` — **append-only**, and the fake proves it.
///
/// `P0-ASMT-05`: "No UI path edits a recorded assessment. A direct write is
/// denied by rules; the only permitted update is the status flip to
/// superseded. Deletion is denied outright. Correcting means recording a new
/// one."
///
/// The interface is shaped to match. There is no `update`, and [delete] exists
/// only to throw — a repository with no delete method at all would be quietly
/// satisfied by a caller that never tried, while this one fails loudly and
/// names the rule if anybody does.
///
/// ## Why "latest" is a pointer and not a query
///
/// G14 §2: W02's hot path is `get assessments/{rel.latestAssessmentId}` — a
/// direct document read via the pointer G11 maintains on the relationship. The
/// composite index exists for K22's five-row history and nothing else. So
/// [latestFor] takes the id, and [history] is the only method that scans.
library;

import 'assessment_record.dart';

/// Refused because a recorded answer may not change.
class AssessmentIsAppendOnly implements Exception {
  const AssessmentIsAppendOnly(this.assessmentId, {this.attempted});

  final String assessmentId;

  /// What the caller tried to do, for the message.
  final String? attempted;

  @override
  String toString() =>
      'AssessmentIsAppendOnly($assessmentId${attempted == null ? '' : ', '
                '$attempted'}) — correct it by recording a new one';
}

abstract class AssessmentRepository {
  /// W02's hot path: a direct read by the pointer on the relationship.
  Future<AssessmentRecord?> byId(String assessmentId);

  /// Writes a new assessment. Idempotent on the deterministic id.
  Future<void> record(AssessmentRecord record);

  /// K22's child-and-parent write, in one transaction: either the child exists
  /// and the parent is superseded, or neither happened.
  Future<void> recordSuperseding({
    required AssessmentRecord child,
    required String parentId,
  });

  /// K22's history action. At most five.
  Future<List<AssessmentRecord>> history({
    required String clientUid,
    String? coachUid,
    int limit = 5,
  });
}

class InMemoryAssessmentRepository implements AssessmentRepository {
  InMemoryAssessmentRepository({
    List<AssessmentRecord> records = const <AssessmentRecord>[],
  }) {
    for (final record in records) {
      _store[record.assessmentId] = record;
    }
  }

  final Map<String, AssessmentRecord> _store = <String, AssessmentRecord>{};

  int reads = 0;
  int writes = 0;

  @override
  Future<AssessmentRecord?> byId(String assessmentId) async {
    final found = _store[assessmentId];
    if (found != null) reads += 1;
    return found;
  }

  @override
  Future<void> record(AssessmentRecord record) async {
    final existing = _store[record.assessmentId];
    if (existing != null) {
      // Spine C1: the same id replayed is the same save, so it overwrites
      // itself. A *different* answer under the same id is an edit, and an
      // assessment is append-only.
      if (existing.toWire().toString() != record.toWire().toString()) {
        throw AssessmentIsAppendOnly(
          record.assessmentId,
          attempted: 'rewrite a recorded answer',
        );
      }
      return;
    }
    _store[record.assessmentId] = record;
    writes += 1;
  }

  @override
  Future<void> recordSuperseding({
    required AssessmentRecord child,
    required String parentId,
  }) async {
    final parent = _store[parentId];
    if (parent == null) {
      throw AssessmentIsAppendOnly(
        parentId,
        attempted:
            'supersede a missing '
            'assessment',
      );
    }
    if (child.assessment.parentAssessmentId != parentId) {
      throw AssessmentIsAppendOnly(
        parentId,
        attempted: 'supersede without the child naming it as its parent',
      );
    }

    // One transaction. The child is written and the parent flipped together,
    // so there is no window in which the chain has two recorded heads.
    final before = Map<String, AssessmentRecord>.of(_store);
    try {
      await record(child);
      _store[parentId] = parent.superseded();
      writes += 1;
    } on Object {
      _store
        ..clear()
        ..addAll(before);
      rethrow;
    }
  }

  @override
  Future<List<AssessmentRecord>> history({
    required String clientUid,
    String? coachUid,
    int limit = 5,
  }) async {
    final rows =
        _store.values
            .where(
              (r) =>
                  r.clientUid == clientUid &&
                  (coachUid == null || r.coachUid == coachUid),
            )
            .toList()
          ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final page = rows.take(limit).toList(growable: false);
    reads += page.length;
    return page;
  }

  /// Present so that an attempt is a loud failure rather than a silent
  /// absence. A constraint record is never deleted.
  Future<void> delete(String assessmentId) async {
    throw AssessmentIsAppendOnly(assessmentId, attempted: 'delete');
  }

  Map<String, AssessmentRecord> get contents =>
      Map<String, AssessmentRecord>.unmodifiable(_store);
}
