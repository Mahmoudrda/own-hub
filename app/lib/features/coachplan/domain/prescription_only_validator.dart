/// §2.1 at the storage layer — G14 §5's first row.
///
/// > `PrescriptionOnlyValidator.assert(node)`, called by
/// > `PlanDraftRepository.save()`, `SplitRepository.save()` and
/// > `SplitApplicator.materialise()` … **No document I write has an `actual*`
/// > field at any depth**, so rule 1 is not a discipline, it is a shape.
///
/// The shape comes first: [PrescribedMove] has nowhere to put a result, so a
/// widget cannot pre-fill one. This walker is the second line, and it exists
/// because a document is a `Map<String, Object?>` by the time it reaches a
/// repository, and a map will hold anything at all.
///
/// ## Why it walks, rather than checking the top level
///
/// "At any depth" is the requirement. A result hidden at
/// `days.2026-09-16.workout.moves[2].actualReps` is the realistic defect — the
/// top-level keys of every document here are fixed and reviewed, and nobody
/// would add `actualReps` beside `status`. So the walker descends through maps
/// **and through lists of maps**, and reports the path it found it at, because
/// a failure that names `actualReps` without saying where wastes the hour
/// after it fires.
///
/// ## Why the ban lists are named `kForbidden…`
///
/// `product_rules_test.dart` exempts the body of a declaration whose own name
/// says it is a deny list. A list that **bans** a key has to name the key in
/// order to ban it, and failing it there leaves an implementer two moves:
/// delete the guard, or rename the keys until the scanner stops seeing them.
/// The second is worse, because the ban survives in name while matching
/// nothing.
library;

/// Keys that would make a prescription into a record. G14 §5, verbatim.
const Set<String> kForbiddenResultKeys = <String>{
  'actualWeight',
  'actualReps',
  'actualSeconds',
  'actualHoldSec',
  'done',
  'completed',
  'adherence',
  'loggedAt',
};

/// Keys a `baseline{}` may never carry — C7, and rule 11 behind it.
///
/// A baseline that cannot hold a body weight cannot be ranked by one, which is
/// the same technique as the one above: make it unstorable rather than
/// forbidden.
const Set<String> kForbiddenBodyMeasureKeys = <String>{
  'weightKg',
  'weight',
  'bmi',
  'bodyFat',
  'weightLost',
};

/// A result-shaped key found in something that is only a prescription.
class ActualFieldInPrescription implements Exception {
  const ActualFieldInPrescription({required this.key, required this.path});

  /// The offending key, so the message names the field and not just the file.
  final String key;

  /// Where it was found — `days.2026-09-16.workout.moves[2]`.
  final String path;

  @override
  String toString() =>
      'ActualFieldInPrescription("$key" at "$path") — §2.1: a prescribed '
      'value is never a result';
}

/// A body measurement found on an assessment baseline.
class BodyMeasureInBaseline implements Exception {
  const BodyMeasureInBaseline(this.key);

  final String key;

  @override
  String toString() =>
      'BodyMeasureInBaseline("$key") — C7: no weight key of any kind, so '
      'nothing here can ever be ranked by one';
}

/// Walks a document and refuses anything result-shaped.
class PrescriptionOnlyValidator {
  const PrescriptionOnlyValidator._();

  /// Throws [ActualFieldInPrescription] on the first offending key.
  ///
  /// Called by every repository in this feature before a write, so there is no
  /// entry point — a screen, a split application, an assistant handover — that
  /// reaches storage without passing here.
  static void assertPrescriptionOnly(Object? node, {String path = ''}) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = '${entry.key}';
        final childPath = path.isEmpty ? key : '$path.$key';
        if (kForbiddenResultKeys.contains(key)) {
          throw ActualFieldInPrescription(key: key, path: path);
        }
        assertPrescriptionOnly(entry.value, path: childPath);
      }
      return;
    }
    if (node is Iterable) {
      var index = 0;
      for (final child in node) {
        assertPrescriptionOnly(child, path: '$path[${index++}]');
      }
    }
  }

  /// True when [node] carries no result-shaped key at any depth.
  ///
  /// For a screen that wants to ask rather than to be thrown at. Nothing in
  /// this feature writes on the strength of it — the write path throws.
  static bool isPrescriptionOnly(Object? node) {
    try {
      assertPrescriptionOnly(node);
      return true;
    } on ActualFieldInPrescription {
      return false;
    }
  }

  /// Throws [BodyMeasureInBaseline] if a baseline names a body measurement.
  static void assertNoBodyMeasure(Map<String, Object?> baseline) {
    for (final key in baseline.keys) {
      if (kForbiddenBodyMeasureKeys.contains(key)) {
        throw BodyMeasureInBaseline(key);
      }
    }
  }
}
