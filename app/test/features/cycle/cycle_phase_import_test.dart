// P1-CYC-01 — "a cycle phase is not an input to any suggestion", the import half.
//
// G9 §5: "`PhaseEstimator` · `lib/features/cycle/presentation/calendar/` …
// Physically confined to the calendar's presentation folder.
// `cycle_phase_import_test.dart` fails the build if anything under `domain/` or
// any other feature imports it."
//
// This is what turns rule 4 from a convention into a structural fact. The claim
// is not "the suggestion path happens not to call the estimator today". It is
// that the suggestion path *cannot*, because the import is a build failure.
//
// The companion guard is `resolver_signature_test.dart`, which proves the other
// half: even if a phase were reachable, it could not be passed to the one
// function that produces a suggestion.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one folder allowed to import the estimator.
const String _allowedFolder = 'lib/features/cycle/presentation/calendar/';

/// The estimator's file name, as it appears in an import uri.
const String _estimator = 'phase_estimator.dart';

List<File> _allAppSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

/// The import uris declared by [source].
List<String> _importsOf(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  return [
    for (final directive in unit.directives)
      if (directive is ImportDirective) directive.uri.stringValue ?? '',
  ];
}

String _normalise(String path) => path.replaceAll(r'\', '/');

void main() {
  test('the estimator is where the plan puts it', () {
    // If it moved, every assertion below is guarding a path that no longer
    // exists — which would pass while proving nothing.
    expect(
      File('$_allowedFolder$_estimator').existsSync(),
      isTrue,
      reason:
          'PhaseEstimator lives in presentation/calendar/ and nowhere else. '
          'Moving it is what this test exists to notice.',
    );
  });

  test('nothing outside the calendar folder imports the phase estimator', () {
    final offenders = <String>[];

    for (final file in _allAppSources()) {
      final path = _normalise(file.path);
      if (path.contains(_allowedFolder)) continue;

      final imports = _importsOf(file.readAsStringSync());
      if (imports.any((uri) => uri.contains(_estimator))) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '§2.4: a date never changes what the app suggests. A phase is '
          'reachable from the calendar\'s dashed cells and from nowhere that '
          'decides anything. Offenders: ${offenders.join(', ')}',
    );
  });

  test('no domain file imports anything from the calendar folder', () {
    // Broader than the line above and deliberately so: importing the folder is
    // how the estimator would arrive indirectly, through a barrel file or a
    // helper that re-exports it.
    final offenders = <String>[];

    for (final file in _allAppSources()) {
      final path = _normalise(file.path);
      if (!path.contains('/domain/')) continue;

      final imports = _importsOf(file.readAsStringSync());
      if (imports.any((uri) => uri.contains('calendar/'))) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'the domain layer must not reach into the calendar\'s presentation '
          'folder. Offenders: ${offenders.join(', ')}',
    );
  });

  group('the guard would actually bite', () {
    // `PHASE1-FIXES.md` #14: a new guard needs a test proving it bites before it
    // is trusted to protect anything.
    test('it detects a direct import of the estimator', () {
      const offender = '''
        import 'calendar/phase_estimator.dart';
        class SymptomSuggestionResolver {}
      ''';
      expect(
        _importsOf(offender).any((uri) => uri.contains(_estimator)),
        isTrue,
      );
    });

    test('it detects a relative import from the domain layer', () {
      const offender = '''
        import '../presentation/calendar/phase_estimator.dart';
      ''';
      expect(
        _importsOf(offender).any((uri) => uri.contains(_estimator)),
        isTrue,
      );
    });

    test('it detects a package-style import', () {
      const offender = '''
        import 'package:own_hub/features/cycle/presentation/calendar/phase_estimator.dart';
      ''';
      expect(
        _importsOf(offender).any((uri) => uri.contains(_estimator)),
        isTrue,
      );
    });

    test('it does not fire on an unrelated import', () {
      const allowed = "import 'package:flutter/material.dart';";
      expect(
        _importsOf(allowed).any((uri) => uri.contains(_estimator)),
        isFalse,
      );
    });
  });
}
