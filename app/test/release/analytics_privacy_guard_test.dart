// Usage statistics can only come from a handful of files, and none of them
// can hand an event anything about her body, her identity or her words.
//
// Extends `cycle_no_analytics_call_sites_test.dart` from one feature to the
// whole app, by the same method: the source is parsed, so a comment or a
// string literal is never mistaken for a call, and every detector is proven
// against code that must trip it before it is trusted.
//
//  1. Only seven files may name the analytics API at all: the gateway, the
//     two sinks, the session, `firebase_boot.dart`, `main.dart` and the
//     router. Every screen, every
//     feature (the cycle, measurements, allergies, setup answers, the ID
//     check's capture and decision) reaches statistics only through a
//     callback the router builds, so this list is the whole audit.
//  2. Inside those files, no `track(...)` call's arguments mention a word that
//     belongs to her body or her identity. A bucketed life stage is a
//     well-typed call; this is what refuses it.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

const Set<String> _analyticsNames = {
  'AnalyticsGateway',
  'AnalyticsEvent',
  'AnalyticsProp',
  'AnalyticsValue',
  'AnalyticsSink',
  'AnalyticsUserProperty',
  'NullAnalyticsSink',
  'FirebaseAnalytics',
  'FirebaseAnalyticsSink',
};

const Set<String> _allowedFiles = {
  'lib/domain/analytics/analytics_gateway.dart',
  'lib/app_state/debug_analytics_sink.dart',
  'lib/app_state/firebase_analytics_sink.dart',
  'lib/app_state/analytics_session.dart',
  'lib/app_state/firebase_boot.dart',
  'lib/main.dart',
  'lib/routing/app_router.dart',
};

/// Words that, inside an event's arguments, mean something about her went in.
const Set<String> _bannedWords = {
  'life',
  'stage',
  'weight',
  'kg',
  'bmi',
  'waist',
  'hip',
  'cycle',
  'period',
  'symptom',
  'symptoms',
  'mood',
  'allergy',
  'allergies',
  'allergen',
  'pregnant',
  'pregnancy',
  'postpartum',
  'measurement',
  'measurements',
  'intake',
  'phone',
  'e164',
  'national',
  'nid',
  'title',
  'uid',
  'text',
  'controller',
  'message',
  'note',
  'query',
  'transcript',
  'selfie',
  'face',
  'niqab',
  'injury',
  'checkin',
};

List<String> _words(String identifier) => identifier
    .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
    .toLowerCase()
    .split(RegExp(r'[\s_]+'))
    .where((w) => w.isNotEmpty)
    .toList();

class _NameHits extends RecursiveAstVisitor<void> {
  final List<String> hits = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_analyticsNames.contains(node.name)) hits.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    // The API and the sinks; not `analytics_consent.dart`, which is her
    // choice and is read by the deletion wipe and the router.
    final uri = node.uri.stringValue ?? '';
    if (RegExp(
      r'domain/analytics/|firebase_analytics|analytics_sink|analytics_session',
    ).hasMatch(uri)) {
      hits.add('import $uri');
    }
    super.visitImportDirective(node);
  }
}

class _TrackArguments extends RecursiveAstVisitor<void> {
  final List<String> leaks = [];
  int calls = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'track' ||
        node.methodName.name == 'setUserProperty') {
      calls++;
      final ids = <String>[];
      node.argumentList.accept(_Identifiers(ids));
      for (final id in ids) {
        for (final word in _words(id)) {
          if (_bannedWords.contains(word)) leaks.add('$id ("$word")');
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _Identifiers extends RecursiveAstVisitor<void> {
  _Identifiers(this.out);
  final List<String> out;

  /// The event's and the properties' own names are the vocabulary, not her.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (const {
      'AnalyticsEvent',
      'AnalyticsProp',
      'AnalyticsUserProperty',
    }.contains(node.prefix.name)) {
      return;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    out.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

CompilationUnit _parse(String source) =>
    parseString(content: source, throwIfDiagnostics: false).unit;

List<String> _nameHits(String source) {
  final visitor = _NameHits();
  _parse(source).visitChildren(visitor);
  return visitor.hits;
}

_TrackArguments _trackArguments(String source) {
  final visitor = _TrackArguments();
  _parse(source).visitChildren(visitor);
  return visitor;
}

Iterable<File> _libFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

void main() {
  test('the scan sees the whole app', () {
    expect(_libFiles().length, greaterThan(300));
  });

  test('only the seven audited files name the analytics API', () {
    final offenders = <String>[];
    for (final file in _libFiles()) {
      if (_allowedFiles.contains(file.path)) continue;
      final hits = _nameHits(file.readAsStringSync());
      if (hits.isNotEmpty) {
        offenders.add('${file.path}: ${hits.toSet().join(', ')}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no event is handed anything about her body, identity or words', () {
    var calls = 0;
    final leaks = <String>[];
    for (final path in _allowedFiles) {
      final found = _trackArguments(File(path).readAsStringSync());
      calls += found.calls;
      leaks.addAll(found.leaks.map((l) => '$path: $l'));
    }
    expect(calls, greaterThan(25), reason: 'the scan must see the call sites');
    expect(leaks, isEmpty, reason: leaks.join('\n'));
  });

  group('the guard would actually bite', () {
    test('a gateway call in a feature file', () {
      expect(
        _nameHits('''
          void log(AnalyticsGateway g) => g.track(AnalyticsEvent.screenViewed);
        '''),
        isNotEmpty,
      );
    });

    test('a bucketed life stage', () {
      final found = _trackArguments('''
        void f() => analytics.track(AnalyticsEvent.intakeCompleted, {
          AnalyticsProp.countBucket: AnalyticsValue.bucket(
            intakeRepository.read().lifeStage.index, [1, 2]),
        });
      ''');
      expect(found.leaks, isNotEmpty);
    });

    test('her number, a title or a weight', () {
      for (final arg in [
        'AnalyticsValue.token(_e164)',
        'AnalyticsValue.token(recipe.titleEn)',
        'AnalyticsValue.bucket(entry.weightKg, [50])',
      ]) {
        final found = _trackArguments(
          'void f() => analytics.track(AnalyticsEvent.mealLogged, '
          '{AnalyticsProp.source: $arg});',
        );
        expect(found.leaks, isNotEmpty, reason: arg);
      }
    });
  });

  group('the guard does not fire on correct code', () {
    test('a comment or a string is not a call', () {
      expect(
        _nameHits('''
          /// No AnalyticsGateway here, and no AnalyticsEvent for cycle data.
          const note = 'AnalyticsGateway is not used';
        '''),
        isEmpty,
      );
    });

    test('a day-one flag and a tour stop are fine', () {
      final found = _trackArguments('''
        void f() => analytics.track(AnalyticsEvent.sessionStarted, {
          AnalyticsProp.isFirstTime: AnalyticsValue.flag(todayRepository.day.isDayOne),
          AnalyticsProp.tourStop: _tourStopToken(stop),
        });
      ''');
      expect(found.calls, 1);
      expect(found.leaks, isEmpty);
    });
  });
}
