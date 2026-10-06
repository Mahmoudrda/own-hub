// R2-59 (round 2 QA). Structural proof, not a promise: starting from C15 (the
// niqab / "I would rather not" reviewer path), no literal `goTo(context, 'XX')`
// edge in `AppRouter._built` reaches `C10`, `C10b` or `C11` — the three ids in
// `_opensALens` (app_router.dart:4203).
//
// This is a source-level BFS over the same map `nav_reachability_test.dart`
// and `signup_consent_test.dart` already parse, extended to walk multiple hops
// rather than reading one builder block by eye. It does not touch
// `FeatureFlags.shipped` and is not about flag defaults, so it does not trip
// `flag_independence_test.dart`'s guard.
//
// This test is read-only against `lib/routing/app_router.dart`. It asserts
// nothing about runtime behaviour beyond what the literal source contains.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens that open a camera, mirrored from `app_router.dart:4203`. Kept as a
/// literal copy (not an import) because the point of this test is to check the
/// source text independently of whatever the production constant currently says.
const Set<String> _opensALens = {'C10', 'C10b', 'C11'};

/// Pulls every `'ID': (context) => ...` block out of the `_built` map, keyed by
/// screen id, exactly the way `signup_consent_test.dart#_builderBlock` reads one
/// entry at a time — this reads all of them once.
Map<String, String> _allBuilderBlocks() {
  final src = File('lib/routing/app_router.dart').readAsStringSync();
  final startMarker = 'static final Map<String, WidgetBuilder> _built = {';
  final mapStart = src.indexOf(startMarker);
  expect(mapStart, isNot(-1), reason: '_built map not found — has it moved?');

  final entryPattern = RegExp(r"\n {4}'([A-Z]\d{2}[a-z]?)': \(context\)");
  final matches = entryPattern.allMatches(src, mapStart + startMarker.length).toList();
  expect(matches, isNotEmpty, reason: 'no builder entries parsed out of _built');

  final blocks = <String, String>{};
  for (var i = 0; i < matches.length; i++) {
    final id = matches[i].group(1)!;
    final from = matches[i].start;
    final to = i + 1 < matches.length ? matches[i + 1].start : src.length;
    blocks[id] = src
        .substring(from, to)
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }
  return blocks;
}

/// Every literal `goTo(context, 'XX')` (or `_goCarryingHandle(context, 'XX'`)
/// target mentioned inside [block]. Deliberately ignores dynamic targets such
/// as `goTo(context, screenId)` (a nav-bar callback parameter) — those carry no
/// literal id for a static reader to follow, which is itself the property this
/// test needs: if C15's own reachable set could only be widened by a runtime
/// value, that value is not literally `'C10'`, `'C10b'` or `'C11'` anywhere in
/// the router.
List<String> _literalTargets(String block) {
  final pattern = RegExp(
    r"""(?:goTo|_goCarryingHandle)\(\s*context,\s*'([A-Z]\d{2}[a-z]?)'""",
  );
  return [for (final m in pattern.allMatches(block)) m.group(1)!];
}

void main() {
  // Guard against a suite that silently stops testing anything, e.g. because
  // the file moved or the map's declaration text changed shape.
  test('the builder map still parses to a non-trivial graph', () {
    final blocks = _allBuilderBlocks();
    expect(blocks.length, greaterThan(100));
    expect(blocks.containsKey('C15'), isTrue);
    expect(blocks.containsKey('C10'), isTrue);
  });

  test(
    'C15 (the niqab / declined-consent path) contains no literal edge into '
    'a lens screen, directly or transitively',
    () {
      final blocks = _allBuilderBlocks();

      // C09 is where she chooses again. C14 can send a woman whose review
      // lapsed back to "take the check again" (S8), and C14's preview can
      // lead to sign-up, which ends at C09 too. C09 offers the camera
      // (through the C09b consent) AND this same niqab path, so reaching it
      // is her choosing again, not the niqab path opening a lens. The walk
      // therefore stops there, and the test below proves C09 still offers
      // C15.
      //
      // C09b is the same kind of screen now: on the first run it carries C09's
      // promise above the consent, and offers the camera, the niqab path and
      // "I would rather not" side by side. A walk from C14's preview through
      // sign-up reaches it rather than C09, and reaching it is her choosing
      // again, with her agreement still required before any lens. The test
      // below proves it still offers C15.
      const freshChoice = <String>{'C09', 'C09b'};

      final visited = <String>{};
      final queue = <String>['C15'];
      final path = <String, String>{}; // child -> parent, for a readable trail

      while (queue.isNotEmpty) {
        final id = queue.removeAt(0);
        if (!visited.add(id)) continue;
        if (freshChoice.contains(id)) continue;
        final block = blocks[id];
        if (block == null) continue; // not a built screen; nothing to follow
        for (final target in _literalTargets(block)) {
          path.putIfAbsent(target, () => id);
          if (!visited.contains(target)) queue.add(target);
        }
      }

      final reachedLenses = visited.intersection(_opensALens);
      if (reachedLenses.isNotEmpty) {
        final trails = reachedLenses.map((lens) {
          final trail = <String>[lens];
          var cur = lens;
          // Bounded: the graph has cycles, and an unbounded walk here hung the
          // whole suite the first time this test failed.
          while (path.containsKey(cur) && cur != 'C15' && trail.length < 40) {
            cur = path[cur]!;
            trail.insert(0, cur);
          }
          return trail.join(' -> ');
        }).join('; ');
        fail('C15 reaches a lens screen via: $trails');
      }

      expect(
        visited.intersection(_opensALens),
        isEmpty,
        reason:
            'C15 must never literally goTo any of $_opensALens; '
            'reached screens were: ${(visited.toList()..sort())}',
      );

      // A sharper, positive assertion: what C15 DOES reach. Today that is
      // exactly {C15, C14} (booking a reviewer) plus whatever C14's own
      // literal edges are (its nav-bar `onSelectTab` target is dynamic, so it
      // contributes no further literal node). If this list grows to include a
      // capture screen id, the test above already fails it, but printing the
      // set here keeps the proof legible to a human re-running it.
      expect(visited, contains('C14'));
    },
  );

  test('C09, where she chooses again, still offers the niqab path', () {
    final blocks = _allBuilderBlocks();
    expect(_literalTargets(blocks['C09']!), contains('C15'));
  });

  test('C09b, where she chooses on the first run, offers C15 too', () {
    final blocks = _allBuilderBlocks();
    final targets = _literalTargets(blocks['C09b']!);
    expect(targets, contains('C15'));
    // Both ways to a reviewer: the niqab link and "I would rather not".
    expect(targets.where((t) => t == 'C15').length, greaterThanOrEqualTo(2));
  });

  test('_opensALens itself is still exactly the three capture screens', () {
    final src = File('lib/routing/app_router.dart').readAsStringSync();
    expect(
      src,
      contains("static const Set<String> _opensALens = {'C10', 'C10b', 'C11'};"),
      reason:
          'the guarded set changed shape; the BFS above and the constant '
          'copied into this test must be re-checked together',
    );
  });
}
