// The widget payload never carries her cycle, her life stage, her body or her
// programme.
//
// A Lock Screen widget is readable by anyone holding the phone, so this is
// held two ways. First by output: for every life stage, with the cycle row on
// and off, in both languages and for every day state, the encoded payload
// contains none of the words that would mean a leak. Second by construction:
// the two files that build and write the payload are parsed, as
// `cycle_no_analytics_call_sites_test.dart` does, and must import nothing
// from the cycle feature, the measurements, or her setup answers, and the
// projection must take no input but the day, the gate, the strings, the
// language and the clock.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/widget_projection.dart';
import 'package:own_hub/l10n/app_l10n.dart';

const List<String> _guarded = [
  'lib/features/today/domain/widget_projection.dart',
  'lib/app_state/home_widget_sync.dart',
];

/// Words that would mean the payload says something it must not.
final RegExp _leak = RegExp(
  r'cycle|period|pregnan|postpartum|weight|kcal|allerg|rebuild|programme|program',
  caseSensitive: false,
);

/// Imports that would give the payload a way to read what it must not.
bool _forbiddenImport(String uri) =>
    RegExp(r'cycle|measurement|intake|(^|/)train/|(^|/)progress/')
        .hasMatch(uri);

/// Every method declared in a parsed unit.
class _Methods extends RecursiveAstVisitor<void> {
  final List<MethodDeclaration> found = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    found.add(node);
    super.visitMethodDeclaration(node);
  }
}

List<String> _importsOf(String path) {
  final unit = parseString(
    content: File(path).readAsStringSync(),
    throwIfDiagnostics: false,
  ).unit;
  return [
    for (final directive in unit.directives)
      if (directive is ImportDirective) directive.uri.stringValue ?? '',
  ];
}

void main() {
  test('no life stage, cycle row or day state puts a sensitive word in it', () {
    for (final stage in LifeStage.values) {
      for (final cycleRow in [true, false]) {
        for (final state in DayState.values) {
          for (final lang in ['en', 'ar']) {
            final day = TodayDay(
              date: DateTime(2026, 10, 6, 9),
              state: state,
              arc: const FirstWeekArc(hasAnyLog: true),
              week: const WeekProgress(sessionsLogged: 2, sessionsTarget: 4),
              mealLoggedAt: DateTime(2026, 10, 6, 8),
              showCycleCard: cycleRow,
              plates: const [PlateSuggestion(foodId: 'ful', kcal: 410)],
              programWeek: 3,
              programTotalWeeks: 8,
            );
            final encoded = jsonEncode(
              WidgetProjection.build(
                day: day,
                open: true,
                l10n: lookupAppL10n(Locale(lang)),
                lang: lang,
                now: DateTime(2026, 10, 6, 10),
              ),
            );
            final where = '${stage.name} $cycleRow ${state.name} $lang';
            expect(encoded, isNot(matches(_leak)), reason: where);
            // The plate's kcal and the programme week never travel.
            expect(encoded, isNot(contains('410')), reason: where);
            expect(encoded, isNot(contains('ful')), reason: where);
            expect(
              (jsonDecode(encoded) as Map).keys.toSet(),
              kWidgetPayloadKeys,
              reason: where,
            );
          }
        }
      }
    }
  });

  test('the projection and the writer import nothing sensitive', () {
    for (final path in _guarded) {
      final bad = _importsOf(path).where(_forbiddenImport).toList();
      expect(bad, isEmpty, reason: path);
    }
  });

  test('the import guard would bite', () {
    expect(_forbiddenImport('../../cycle/domain/cycle_document.dart'), isTrue);
    expect(_forbiddenImport('cycle_state.dart'), isTrue);
    expect(_forbiddenImport('../onboarding/domain/intake.dart'), isTrue);
    expect(_forbiddenImport('../../train/domain/workout_day.dart'), isTrue);
    expect(_forbiddenImport('../../today/domain/today_day.dart'), isFalse);
  });

  test('the projection takes the day, the gate, strings, language, clock', () {
    final unit = parseString(
      content: File(_guarded.first).readAsStringSync(),
      throwIfDiagnostics: false,
    ).unit;
    final methods = _Methods();
    unit.visitChildren(methods);
    final build = methods.found.singleWhere((m) => m.name.lexeme == 'build');
    final names = {
      for (final p in build.parameters!.parameters) p.name!.lexeme,
    };
    expect(names, {'day', 'open', 'l10n', 'lang', 'now'});
  });
}
