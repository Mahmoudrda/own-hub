// P1-CYC-04 — "cycle data is never sent to analytics under any circumstance".
//
// G9 §5 asks for the strongest available form of this guarantee, and it is not
// "no cycle field is passed to analytics". It is:
//
//   > **`lib/features/cycle/` contains zero `AnalyticsGateway` call sites.** The
//   > strongest available form: the feature does not emit events at all… There
//   > is no G9-owned event, no G9 property request, and nothing to review.
//
// The existing `AnalyticsGateway` already makes the crude leak impossible — enum
// keys, a closed value set, no `Map<String, dynamic>` overload — so a symptom
// cannot be sent as free text. What it does NOT stop is sending a *bucketed*
// symptom as an int, which is a perfectly well-typed call. This test closes that
// path by removing the call site entirely.
//
// ## Why this parses instead of grepping
//
// A regex over source cannot tell a call site from the same words inside a
// comment or a string literal, and this file's whole job is to be trustworthy.
// The files it guards discuss analytics at length in their doc comments —
// `symptom_suggestion_resolver.dart` and the plan quotes in `cycle_document.dart`
// both name `AnalyticsGateway` in prose — so a grep-based guard would either
// fail on correct code or be weakened with exceptions until it stopped biting.
//
// `PHASE1-FIXES.md` #14 is the precedent: the rule-7 guard shipped with a regex
// that could never match, and "a source-scanning guard that matches nothing is
// indistinguishable from one that works". So this walks the syntax tree, where a
// comment is not a node and a string literal is not an identifier.
//
// And per that same lesson, every detector here is proven against source that
// MUST trip it before it is trusted against the tree that must not.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Names that only ever appear because analytics is being used.
const Set<String> _analyticsNames = {
  'AnalyticsGateway',
  'AnalyticsEvent',
  'AnalyticsProp',
  'AnalyticsValue',
  'AnalyticsSink',
  'NullAnalyticsSink',
  'AnalyticsUserProperty',
  'FirebaseAnalytics',
  'FirebaseAnalyticsSink',
};

/// Collects analytics identifiers and imports from a parsed unit.
class _AnalyticsVisitor extends RecursiveAstVisitor<void> {
  final List<String> hits = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_analyticsNames.contains(node.name)) hits.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue ?? '';
    if (uri.contains('analytics')) hits.add('import $uri');
    super.visitImportDirective(node);
  }
}

List<String> _analyticsHitsIn(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final visitor = _AnalyticsVisitor();
  unit.visitChildren(visitor);
  return visitor.hits;
}

/// The feature, and the app-level state that holds her cycle for it.
List<File> _cycleSources() => [
  ...Directory('lib/features/cycle')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart')),
  File('lib/app_state/cycle_state.dart'),
];

void main() {
  test('the cycle feature exists and is being scanned', () {
    // A guard over an empty directory passes vacuously. This is the same
    // failure mode as the rule-9 scan that passed for weeks by not looking at
    // lib/features/train/.
    final files = _cycleSources();
    expect(
      files.length,
      greaterThanOrEqualTo(15),
      reason:
          'the scan found ${files.length} files — if the feature moved, this '
          'guard is protecting nothing',
    );
  });

  test('no cycle file has an analytics call site', () {
    final offenders = <String>[];

    for (final file in _cycleSources()) {
      final hits = _analyticsHitsIn(file.readAsStringSync());
      if (hits.isNotEmpty) {
        offenders.add('${file.path}: ${hits.toSet().join(', ')}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'PDPL / spine C12. Cycle data is never sent to analytics under any '
          'circumstance, and G9 keeps that true by emitting no events at all. '
          'Screen views come from G8\'s router, which sends screen_id and '
          'nothing else. Found: ${offenders.join(' | ')}',
    );
  });

  group('the guard would actually bite', () {
    // Positive controls. Each of these MUST be detected, or the test above is
    // protection that can never fire.
    test('it catches a gateway call', () {
      const offender = '''
        import '../../../domain/analytics/analytics_gateway.dart';
        class CycleTracker {
          final AnalyticsGateway gateway;
          void log() => gateway.track(AnalyticsEvent.screenViewed);
        }
      ''';
      expect(_analyticsHitsIn(offender), isNotEmpty);
    });

    test('it catches a bucketed symptom, which is the remaining path', () {
      // Well-typed, passes the gateway's own API, and is exactly the leak G9
      // §5 says this test exists to close.
      const offender = '''
        void report(int cramps) {
          gateway.track(AnalyticsEvent.screenViewed, {
            AnalyticsProp.countBucket: AnalyticsValue.bucket(cramps, [1, 2, 3]),
          });
        }
      ''';
      expect(_analyticsHitsIn(offender), isNotEmpty);
    });

    test('it catches the Firebase SDK directly', () {
      const offender = '''
        void log() => FirebaseAnalytics.instance.logEvent(name: 'period_day');
      ''';
      expect(_analyticsHitsIn(offender), isNotEmpty);
    });

    test('it catches the import alone, even with no call', () {
      const offender =
          "import 'package:own_hub/domain/analytics/analytics_gateway.dart';";
      expect(_analyticsHitsIn(offender), isNotEmpty);
    });
  });

  group('the guard does not fire on correct code', () {
    test('prose in a doc comment is not a call site', () {
      // The real files do exactly this — they explain the ban at length. A
      // guard that failed here would teach people to stop explaining, or to
      // delete the guard. Both are worse than no guard.
      const allowed = '''
        /// G9 has zero AnalyticsGateway call sites. There is no AnalyticsEvent
        /// for cycle data and no AnalyticsProp may carry a symptom.
        class CycleDocument {}
      ''';
      expect(_analyticsHitsIn(allowed), isEmpty);
    });

    test('the words inside a string literal are not a call site', () {
      const allowed = '''
        const note = 'AnalyticsGateway is deliberately not used here';
      ''';
      expect(_analyticsHitsIn(allowed), isEmpty);
    });
  });
}
