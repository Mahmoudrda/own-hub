// P1-CYC-01 / P1-RULE-04 — "a cycle phase is not an input to any suggestion",
// the signature half.
//
// G9 §5, and this is the sentence the whole feature is shaped around:
//
//   > **Enforced by absence of capability**, the pattern G3 used for the streak.
//   > The method takes **one** parameter — today's check-in — and its signature
//   > carries no date, no `CycleDocument`, no phase and no clock. A phase cannot
//   > influence a suggestion because a phase cannot be passed to the only
//   > function that produces one.
//
// A test that called `resolve` and checked the answer would prove only that
// today's implementation ignores the date. This proves the stronger thing: there
// is no date to ignore, because there is nowhere to put one.
//
// The day someone adds `{DateTime? today}` for a plausible reason is the day
// rule 4 stops being structural, and that is the day this fails.

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
import 'package:own_hub/features/cycle/domain/symptom_context.dart';
import 'package:own_hub/features/cycle/domain/symptom_suggestion_resolver.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';

const String _source =
    'lib/features/cycle/domain/symptom_suggestion_resolver.dart';

/// Types that must never appear in the deciding function's signature.
final RegExp _banned = RegExp(
  r'DateTime|Clock|CycleDocument|Phase|PeriodEntry|cycleDay|LastPeriod',
  caseSensitive: false,
);

/// The parameter list of [method] on [className], as source text.
FormalParameterList? _paramsOf(String source, String className, String method) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;

  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration) continue;
    if (declaration.name.lexeme != className) continue;

    for (final member in declaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == method) {
        return member.parameters;
      }
    }
  }
  return null;
}

void main() {
  late String source;

  setUpAll(() {
    final file = File(_source);
    expect(file.existsSync(), isTrue, reason: '$_source must exist');
    source = file.readAsStringSync();
  });

  test('resolve takes exactly one parameter', () {
    final params = _paramsOf(source, 'SymptomSuggestionResolver', 'resolve');

    expect(
      params,
      isNotNull,
      reason:
          'SymptomSuggestionResolver.resolve must exist — if it was renamed, '
          'this guard is protecting nothing',
    );

    expect(
      params!.parameters.length,
      1,
      reason:
          '§2.4 is enforced by the argument list. One parameter: today\'s '
          'check-in. Found: ${params.toSource()}',
    );
  });

  test('that parameter is the check-in, and nothing else', () {
    final params = _paramsOf(source, 'SymptomSuggestionResolver', 'resolve')!;
    final only = params.parameters.single;

    expect(only.isRequiredPositional, isTrue);
    expect(only.toSource(), contains('TodayCheckIn'));
  });

  test('the signature names no date, clock, document or phase', () {
    final params = _paramsOf(source, 'SymptomSuggestionResolver', 'resolve')!;

    expect(
      _banned.hasMatch(params.toSource()),
      isFalse,
      reason:
          'a phase cannot influence a suggestion because it cannot be passed. '
          'Signature: ${params.toSource()}',
    );
  });

  test('TodayCheckIn itself carries no date', () {
    // The other half of the same guarantee. One parameter is worthless if that
    // parameter has a date on it.
    final unit = parseString(
      content: File('lib/features/cycle/domain/today_check_in.dart')
          .readAsStringSync(),
      throwIfDiagnostics: false,
    ).unit;

    final fields = <String>[];
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      if (declaration.name.lexeme != 'TodayCheckIn') continue;
      for (final member in declaration.members) {
        if (member is FieldDeclaration) {
          fields.add(member.fields.toSource());
        }
      }
    }

    expect(fields, isNotEmpty, reason: 'TodayCheckIn must declare its fields');
    expect(
      fields.where((f) => _banned.hasMatch(f)),
      isEmpty,
      reason: 'TodayCheckIn holds symptoms only. Found: $fields',
    );
  });

  group('the guard would actually bite', () {
    test('it catches a second parameter', () {
      const offender = '''
        class SymptomSuggestionResolver {
          DaySuggestion resolve(TodayCheckIn checkIn, DateTime today) => throw 0;
        }
      ''';
      final params = _paramsOf(
        offender,
        'SymptomSuggestionResolver',
        'resolve',
      )!;
      expect(params.parameters.length, 2);
      expect(_banned.hasMatch(params.toSource()), isTrue);
    });

    test('it catches an optional named date, which is the realistic one', () {
      // Nobody adds a positional date. They add `{DateTime? today}` because a
      // reviewer will read it as harmless.
      const offender = '''
        class SymptomSuggestionResolver {
          DaySuggestion resolve(TodayCheckIn checkIn, {DateTime? today}) =>
              throw 0;
        }
      ''';
      final params = _paramsOf(
        offender,
        'SymptomSuggestionResolver',
        'resolve',
      )!;
      expect(params.parameters.length, greaterThan(1));
      expect(_banned.hasMatch(params.toSource()), isTrue);
    });

    test('it catches a smuggled cycle document', () {
      const offender = '''
        class SymptomSuggestionResolver {
          DaySuggestion resolve(TodayCheckIn c, {CycleDocument? cycle}) =>
              throw 0;
        }
      ''';
      final params = _paramsOf(
        offender,
        'SymptomSuggestionResolver',
        'resolve',
      )!;
      expect(_banned.hasMatch(params.toSource()), isTrue);
    });
  });

  group('the behaviour the signature guarantees', () {
    const resolver = SymptomSuggestionResolver();

    test('nothing logged is never a suggestion', () {
      expect(resolver.resolve(TodayCheckIn.absent), isA<NoSuggestion>());
    });

    test('a logged day with no qualifying symptom keeps her plan', () {
      // P1-RULE-04's exact case: high energy and no cramps. The period day is
      // irrelevant and — the point — unreachable.
      final suggestion = resolver.resolve(
        const TodayCheckIn(
          energy: Energy.high,
          cramps: Cramps.none,
          appetite: Appetite.ok,
        ),
      );
      expect(suggestion, isA<KeepPlan>());
      expect(suggestion, isNot(isA<GentlerOption>()));
    });

    test('a qualifying symptom offers a gentler option and names it', () {
      // Moderate cramps with OK energy — deliberately not the prototype's
      // "low energy + mild cramps" pair, so a constant cannot pass for a
      // computation.
      final suggestion = resolver.resolve(
        const TodayCheckIn(energy: Energy.ok, cramps: Cramps.moderate),
      );

      expect(suggestion, isA<GentlerOption>());
      expect(suggestion.reason, [LoggedSymptom.moderateCramps]);
      expect(
        suggestion.reason,
        isNot(contains(LoggedSymptom.lowEnergy)),
        reason: 'the reason is what she logged, not what the mockup drew',
      );
    });

    test('the same check-in always resolves the same way', () {
      // There is no clock in the signature, so the answer cannot drift with
      // the time of day. Asserted rather than assumed.
      const checkIn = TodayCheckIn(energy: Energy.low);
      final first = resolver.resolve(checkIn);
      final second = resolver.resolve(checkIn);

      expect(first.runtimeType, second.runtimeType);
      expect(first.reason, second.reason);
    });
  });
}
