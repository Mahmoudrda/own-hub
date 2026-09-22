// The closed vocabulary — G14 §1.5.
//
// The seeded exercise library already writes exactly these strings
// (`lib/features/admin/domain/seed_library.dart`), and
// `test/features/admin/seed_library_test.dart` pins the same eleven tokens
// against the content. This file pins them against the *type*, so the two
// halves of the safety chain cannot drift apart: a tag outside the set must be
// unrepresentable, not merely invalid.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';

/// G14 §1.5, byte-identical to `_contraindicationVocabulary` in the seed test.
const Set<String> _g14Vocabulary = {
  'high_impact',
  'jumping',
  'deep_knee_flexion',
  'loaded_twisting',
  'pelvic_floor_load',
  'breath_hold_valsalva',
  'prone_position',
  'supine_load',
  'overhead_load',
  'wrist_load',
  'none',
};

void main() {
  group('the vocabulary is closed', () {
    test('it is exactly G14 §1.5 — ten tokens, plus the explicit none', () {
      expect(
        ContraindicationTag.values.map((t) => t.wireName).toSet(),
        _g14Vocabulary,
      );
      expect(ContraindicationTag.values, hasLength(11));
      expect(ContraindicationTag.wireVocabulary, _g14Vocabulary);
    });

    test('a token outside the set has no representation at all', () {
      // There is no constructor taking a String, so the only way in is
      // fromWire, and it refuses. An enum is what makes "unrepresentable"
      // true rather than "validated somewhere and hopefully everywhere".
      expect(ContraindicationTag.fromWire('knee'), isNull);
      expect(ContraindicationTag.fromWire('diastasis'), isNull);
      expect(ContraindicationTag.fromWire(''), isNull);
      expect(ContraindicationTag.fromWire('high impact'), isNull);
      expect(ContraindicationTag.fromWire('highImpact'), isNull);
    });

    test('parseAll refuses an unknown token instead of dropping it', () {
      // Dropping is the dangerous failure: an avoid list of
      // ["deep_knee_flexion", "knee"] silently becoming one tag reads as a
      // resolved constraint set while half of what she was asked about has
      // vanished. Refusing hands the caller a fail-closed decision.
      expect(
        () => ContraindicationTag.parseAll(const ['high_impact', 'knee']),
        throwsA(isA<UnknownContraindicationTag>()),
      );
      try {
        ContraindicationTag.parseAll(const ['knee']);
        fail('an unknown token must not parse');
      } on UnknownContraindicationTag catch (e) {
        expect(e.wire, 'knee', reason: 'the offending token must be named');
      }
    });

    test('a wholly known list parses to the same tags', () {
      expect(
        ContraindicationTag.parseAll(const [
          'supine_load',
          'pelvic_floor_load',
        ]),
        {ContraindicationTag.supineLoad, ContraindicationTag.pelvicFloorLoad},
      );
    });

    test('capitalisation and stray whitespace cannot make it miss', () {
      // AllergyGuard folds case and trims for exactly this reason: a guard that
      // missed on capitalisation would fail open.
      expect(
        ContraindicationTag.fromWire(' High_Impact '),
        ContraindicationTag.highImpact,
      );
      expect(
        ContraindicationTag.fromWire('PELVIC_FLOOR_LOAD'),
        ContraindicationTag.pelvicFloorLoad,
      );
    });

    test('none is in the vocabulary and restricts nothing', () {
      // The seed writes 'none' for an unrestricted move
      // (content_form_view_test.dart:212). If `none` were allowed to intersect
      // an avoid list it would suppress every unrestricted exercise in the
      // library — the filter inverted.
      expect(ContraindicationTag.fromWire('none'), ContraindicationTag.none);
      expect(ContraindicationTag.none.restricts, isFalse);
      for (final tag in ContraindicationTag.values) {
        if (tag == ContraindicationTag.none) continue;
        expect(tag.restricts, isTrue, reason: '${tag.wireName} must restrict');
      }
    });

    test('negative control — the guard would actually bite', () {
      // A vocabulary check that matches everything is indistinguishable from
      // one that is broken.
      expect(_g14Vocabulary, isNot(contains('knee')));
      expect(_g14Vocabulary, isNot(contains('shoulder')));
      expect(ContraindicationTag.wireVocabulary, isNot(contains('weight')));
    });
  });
}
