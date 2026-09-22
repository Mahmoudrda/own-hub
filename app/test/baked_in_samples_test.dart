// The prototype's numbers, counted — and allowed only to fall.
//
// # The defect this measures
//
// Every instance has one shape: a sentence from the mockup, with the mockup's
// figures inside it, frozen into the dictionary and then rendered as though it
// were hers. "Level 7 · Regular" to a woman on level 1. "22 of 95 g" to a woman
// who logged something else. "Period day 2" on day four. Boiled eggs reported
// as a 540-calorie lunch, which is koshari's figure.
//
// Six were found and fixed. **Every one of them was found by accident**, while
// looking at something else — which is why this exists. A defect class that is
// only ever found by luck will keep arriving faster than it is removed.
//
// # Why a ratchet and not a ban
//
// Plenty of number-bearing strings are perfectly correct and must not be
// "fixed": `step1Of2` really is step one of two, the three pledge items really
// are numbered, `add30Seconds` really adds thirty seconds, and "call 122" is a
// real Egyptian emergency number. Telling those apart from the mockup's leftover
// samples needs judgement per string, so this counts rather than forbids.
//
// The count may only fall. That stops new ones arriving while the existing ones
// are worked through, which is precisely how six of them came to exist.
//
// # How to lower it
//
// Two proven routes, both used repeatedly in this codebase:
//
//   * **Parameterise it.** Add the English→Arabic pair to `6-v2/i18n/ar-extra.json`
//     with `{placeholders}`, add a `PARAMETERISED` block in `build-flutter.mjs`,
//     then `merge-i18n` → `build-flutter` → `flutter gen-l10n`. Read the generated
//     getter name afterwards; short words collide and come back fingerprinted
//     (`Library` → `libraryLabel`, `Import everything?` → `importEverything_damon`).
//   * **Withhold it.** `lib/domain/rewards/stated_figure.dart` renders a line only
//     to the woman it is true of. Where no real value exists yet, saying nothing
//     beats saying the mockup's number.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The measured baseline. **It may only ever move down.**
///
/// Raising it to make a red suite green would defeat the only purpose this file
/// has. If a legitimate new string genuinely carries a number — another numbered
/// step, say — prefer a parameterised form; if it truly cannot be parameterised,
/// that is a decision worth writing in `DECISIONS.md` rather than a number worth
/// editing here.
///
/// 221 → 177 → 117. The last pass worked through Train, Today, Eat, Progress,
/// Sign-up, Cycle, Onboarding and Account; what is left there was kept on
/// purpose and each survivor is either a product constant (30 points for a live
/// session, 80% of what a client pays, five bundled workout rows), a genuinely
/// numbered thing ("Step 2 of 4", the three pledge items), or a sentence
/// already guarded by `statedLine`/`statesHerFigure` so that it reaches only
/// the woman it is true of.
const int _ceiling = 117;

/// True for a string that states a figure it cannot know is hers.
///
/// Deliberately crude, and controlled by the tests below rather than trusted:
/// a value with a placeholder takes hers, a value with no letters is not a
/// sentence, and a value with no digit has no figure to be wrong about.
bool looksBakedIn(String value) =>
    !value.contains('{') &&
    RegExp(r'\d').hasMatch(value) &&
    RegExp('[A-Za-z]').hasMatch(value);

/// Dictionary keys matching [looksBakedIn] that some widget actually renders.
///
/// Rendered is the part that matters. The dictionary carries 485 such strings;
/// most are unused leftovers of the prototype and harm nobody. A string only
/// misleads a woman when a screen puts it in front of her.
List<String> _renderedBakedInSamples() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;

  final candidates = <String>[];
  arb.forEach((key, value) {
    if (key.startsWith('@')) return;
    if (value is String && looksBakedIn(value)) candidates.add(key);
  });

  // Generated localisation Dart is excluded: it DEFINES these getters, and
  // counting a definition as a use would report every string as rendered.
  final source = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  return [
    for (final key in candidates)
      if (RegExp('l10n\\.$key\\b').hasMatch(source)) key,
  ]..sort();
}

void main() {
  group('the detector actually bites', () {
    // A guard that matches nothing is indistinguishable from a guard whose
    // matcher is broken. This codebase has shipped two of those — the rule-7
    // pattern that could never fire, and the admin guard whose leading \b made
    // it miss `readMealLogs(uid)` — so the predicate is proven against text
    // that must match before it is trusted against a corpus that must not grow.

    test('it flags a sentence carrying the mockup figure', () {
      expect(looksBakedIn('Week 3 of 8'), isTrue);
      expect(looksBakedIn('Level 7 · Regular'), isTrue);
      expect(looksBakedIn('540 kcal · 18 g protein'), isTrue);
      expect(looksBakedIn('Walk this morning · 32 min'), isTrue);
    });

    test('it does not flag a parameterised form', () {
      // The fix, so the fix must not read as the defect.
      expect(looksBakedIn('Week {n} of {m}'), isFalse);
      expect(looksBakedIn('Level {n}'), isFalse);
      expect(looksBakedIn('{kcal} kcal · {protein} g protein'), isFalse);
      expect(looksBakedIn('This week, {done} of {target}'), isFalse);
    });

    test('it does not flag a bare numeral or ordinary copy', () {
      expect(looksBakedIn('122'), isFalse, reason: 'not a sentence');
      expect(looksBakedIn('2026-09-19'), isFalse);
      expect(looksBakedIn('Save'), isFalse, reason: 'no figure to be wrong');
      expect(looksBakedIn('Track periods and symptoms'), isFalse);
    });

    test('it finds real ones in the real dictionary', () {
      // Proves the corpus scan is wired, not merely the predicate. A silently
      // empty result would report a perfectly clean app over zero strings.
      final found = _renderedBakedInSamples();
      expect(found, isNotEmpty);
      expect(
        found,
        contains('n12Kg10'),
        reason:
            "R07's prescription card says '12 kg × 10', and it is the label of "
            '`MidSetView._defaultMove` — the move the screen invents when it is '
            'given none. `app_router.dart` builds R07 with no move at all, so '
            "the prototype's goblet squat is what the running app puts in front "
            'of every woman. The fix is her session\'s real move, threaded '
            'through the router; until then the fallback is the offender.\n\n'
            'This assertion used to name `week3Of8`. That one is fixed: Home '
            'takes `TodayDay.programWeek` and renders `weekWeekOfTotal`, or no '
            'badge at all, and `train_view` had already withdrawn the same '
            'fallback. If `n12Kg10` is fixed too, lower _ceiling and pick '
            'another known offender here.',
      );
    });
  });

  test('the mockup s numbers may only ever decrease', () {
    final found = _renderedBakedInSamples();

    expect(
      found.length,
      lessThanOrEqualTo(_ceiling),
      reason:
          'Rendered strings stating a figure with no placeholder form rose to '
          '${found.length}, above the $_ceiling recorded when this was first '
          'measured.\n\n'
          'Something new tells a woman one of the prototype\'s numbers as if it '
          'were hers. Parameterise it, or withhold it with stated_figure.dart. '
          'Do NOT raise the ceiling — that is the one change this file exists '
          'to prevent.\n\n'
          'Currently rendered:\n${found.join(', ')}',
    );
  });
}
