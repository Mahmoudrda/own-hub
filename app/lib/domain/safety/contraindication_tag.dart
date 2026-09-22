/// The one vocabulary the safety chain speaks — G14 §1.5.
///
/// The avoid list (rule 13) and a `refer` outcome (rule 14) both mean "do not
/// let a session prescribe this". They resolve into the **same** ten tokens, or
/// the two disagree — which is the exact failure rule 13 was written to close.
///
/// ## Why an enum, and not a `Set<String>`
///
/// A tag outside the vocabulary must be **unrepresentable**, not merely
/// invalid. A string-typed tag is validated at one boundary and then trusted
/// everywhere else, and the failure is silent in the worst direction: a tag
/// nothing can match reads as an authored constraint and filters nothing. The
/// seeded library's own guard says so —
/// `test/features/admin/seed_library_test.dart`: "a tag outside it intersects
/// nothing, so it reads as authored and filters nothing — the failure this seed
/// exists to end."
///
/// So there is no constructor taking a `String`. The only way in is
/// [ContraindicationTag.fromWire], which answers `null`, and
/// [ContraindicationTag.parseAll], which refuses.
///
/// ## Why `parseAll` throws instead of dropping
///
/// Dropping an unrecognised token turns `[deep_knee_flexion, knee]` into one
/// tag, and the result *looks* like a resolved constraint set that is quietly
/// short by one. Refusing hands the caller a fail-closed decision to make —
/// which `ClientConstraintResolver` makes by resolving to "unknown".
///
/// ## `none` is a member, and it restricts nothing
///
/// The seeded content writes `none` for an unrestricted move, so the token has
/// to exist. What it must never do is intersect: if `none` could match an avoid
/// list it would suppress every unrestricted exercise in the library — the
/// filter inverted. [restricts] is the single place that is decided.
library;

/// The closed set. Ten restrictions, plus the explicit absence of one.
enum ContraindicationTag {
  highImpact('high_impact'),
  jumping('jumping'),
  deepKneeFlexion('deep_knee_flexion'),
  loadedTwisting('loaded_twisting'),
  pelvicFloorLoad('pelvic_floor_load'),
  breathHoldValsalva('breath_hold_valsalva'),
  pronePosition('prone_position'),
  supineLoad('supine_load'),
  overheadLoad('overhead_load'),
  wristLoad('wrist_load'),

  /// Authored, and says there is nothing to avoid. Never a blocking tag.
  none('none');

  const ContraindicationTag(this.wireName);

  /// The string the content pack and the assessment document both carry.
  /// Never the Dart name — a rename must not change stored data.
  final String wireName;

  /// False for [none] alone. Every consumer asks this rather than comparing.
  bool get restricts => this != ContraindicationTag.none;

  /// Every token, as stored. Matches `seed_library_test.dart`'s list exactly.
  static Set<String> get wireVocabulary => {
    for (final tag in values) tag.wireName,
  };

  /// The tag for [wire], or null when the token is outside the vocabulary.
  ///
  /// Case- and whitespace-insensitive, for the reason `AllergyGuard` folds
  /// case: a guard that missed on capitalisation would fail open.
  static ContraindicationTag? fromWire(String wire) {
    final normalised = wire.trim().toLowerCase();
    for (final tag in values) {
      if (tag.wireName == normalised) return tag;
    }
    return null;
  }

  /// Every tag in [wires], or [UnknownContraindicationTag] if any is unknown.
  ///
  /// All-or-nothing on purpose. See the library note.
  static Set<ContraindicationTag> parseAll(Iterable<String> wires) {
    final parsed = <ContraindicationTag>{};
    for (final wire in wires) {
      final tag = fromWire(wire);
      if (tag == null) throw UnknownContraindicationTag(wire);
      parsed.add(tag);
    }
    return parsed;
  }
}

/// A stored tag that is outside G14 §1.5's vocabulary.
///
/// Thrown rather than swallowed so the caller fails closed instead of acting on
/// a constraint set that is silently incomplete.
class UnknownContraindicationTag implements Exception {
  const UnknownContraindicationTag(this.wire);

  /// The offending token, named so the failure points at the content.
  final String wire;

  @override
  String toString() =>
      'UnknownContraindicationTag("$wire") — not one of G14 §1.5\'s tokens';
}
