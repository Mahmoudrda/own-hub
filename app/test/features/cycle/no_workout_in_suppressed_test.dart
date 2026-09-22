// P1-CYC-02 / P1-RULE-05 — "severe symptoms suppress the training suggestion",
// enforced by the type rather than by a branch.
//
// G9 §5: "`Suppressed` **has no workout, alternative or session field at all.**
// There is nothing for Y11 to render even if a widget tried, and adding one is a
// compile-time change that the review sees (the same type-separation argument C8
// makes for prescribed vs actual)."
//
// So this test reads the shape of the type, not the behaviour of a screen. A
// widget test can only prove that today's Y11 does not draw a workout; this
// proves that no Y11 *could*, because there is no field to draw one from.
//
// The parse is over the real file, so the assertion tracks the code rather than
// a copy of it.

// analyzer 10 deprecates ClassDeclaration.name and .members in favour of
// .namePart and .body. The deprecated members still work on the pinned SDK
// and switching would couple these guards to an API newer than the one the
// rest of the toolchain targets, so the call sites stay and this records why.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/day_suggestion.dart';
import 'package:own_hub/features/cycle/domain/severe_symptom_gate.dart';
import 'package:own_hub/features/cycle/domain/symptom_context.dart';
import 'package:own_hub/features/cycle/domain/symptom_suggestion_resolver.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';

const String _source = 'lib/features/cycle/domain/day_suggestion.dart';

/// Anything that would let a widget put a workout on the severe screen.
final RegExp _workoutShaped = RegExp(
  r'workout|alternative|session|exercise|training|move|gentler',
  caseSensitive: false,
);

/// The declared field names of [className] in [source].
List<String> _fieldsOf(String source, String className) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;

  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration) continue;
    if (declaration.name.lexeme != className) continue;

    return [
      for (final member in declaration.members)
        if (member is FieldDeclaration)
          for (final variable in member.fields.variables) variable.name.lexeme,
    ];
  }

  return const <String>[];
}

void main() {
  late String source;

  setUpAll(() {
    final file = File(_source);
    expect(file.existsSync(), isTrue, reason: '$_source must exist');
    source = file.readAsStringSync();
  });

  test('Suppressed declares no workout-shaped field', () {
    final fields = _fieldsOf(source, 'Suppressed');

    // Guards the guard: if the class were renamed or the parse silently
    // returned nothing, an empty list would pass vacuously.
    expect(
      fields,
      isNotEmpty,
      reason: 'Suppressed must exist and declare its fields in $_source',
    );

    final offenders = fields.where(_workoutShaped.hasMatch).toList();

    expect(
      offenders,
      isEmpty,
      reason:
          '§2.5: severe symptoms REMOVE the workout, they do not soften it. '
          'Suppressed carries guidance and a route to care, and nothing a '
          'widget could render a session from. Found: $offenders',
    );
  });

  test('GentlerOption does carry an alternative — the control', () {
    // Proves the field detector actually sees fields. Without this, the
    // assertion above would pass for a parse that found nothing at all, which
    // is the exact failure `PHASE1-FIXES.md` #14 records.
    final fields = _fieldsOf(source, 'GentlerOption');
    expect(fields, contains('alternative'));
    expect(fields.where(_workoutShaped.hasMatch), isNotEmpty);
  });

  test('the detector catches a workout field added to Suppressed', () {
    const offender = '''
      final class Suppressed extends DaySuggestion {
        const Suppressed({required this.reason, required this.workout});
        final List<LoggedSymptom> reason;
        final GentlerSession workout;
      }
    ''';
    expect(
      _fieldsOf(offender, 'Suppressed').where(_workoutShaped.hasMatch),
      isNotEmpty,
    );
  });

  test('a severe day produces Suppressed, and it is not a GentlerOption', () {
    // The behavioural half, so the structural assertion above is anchored to
    // the value the resolver actually returns.
    const resolver = SymptomSuggestionResolver();

    // Deliberately NOT the prototype's "low energy, mild cramps" fixture: a
    // test that asserts the sample values passes for a constant as happily as
    // for a computation.
    final suggestion = resolver.resolve(
      const TodayCheckIn(energy: Energy.high, cramps: Cramps.severe),
    );

    expect(suggestion, isA<Suppressed>());
    expect(suggestion, isNot(isA<GentlerOption>()));
    expect(suggestion.reason, contains(LoggedSymptom.severeCramps));
  });

  test('heavy bleeding suppresses too, with high energy and no cramps', () {
    // The other half of the gate, which no other test reaches — and note the
    // energy is HIGH, so nothing else on this check-in would soften anything.
    const resolver = SymptomSuggestionResolver();

    final suggestion = resolver.resolve(
      const TodayCheckIn(energy: Energy.high, bleeding: Bleeding.heavy),
    );

    expect(suggestion, isA<Suppressed>());
    expect(suggestion.reason, contains(LoggedSymptom.heavyBleeding));
  });

  test('the gate is the single definition of severe', () {
    const gate = SevereSymptomGate();

    expect(gate.evaluate(const TodayCheckIn(cramps: Cramps.severe)), isTrue);
    expect(gate.evaluate(const TodayCheckIn(bleeding: Bleeding.heavy)), isTrue);

    // Moderate is not severe. The boundary is the whole point of the rule.
    expect(gate.evaluate(const TodayCheckIn(cramps: Cramps.moderate)), isFalse);
    expect(
      gate.evaluate(const TodayCheckIn(bleeding: Bleeding.medium)),
      isFalse,
    );
    expect(gate.evaluate(TodayCheckIn.absent), isFalse);
  });
}
