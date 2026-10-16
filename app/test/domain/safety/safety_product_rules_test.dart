// Executable guards over `lib/domain/safety/` itself.
//
// Written in the same idiom as `test/product_rules_test.dart`: scan the real
// source, filter comment lines so documenting a rule is never a violation, and
// prove every pattern bites before trusting that it found nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _folder = 'lib/domain/safety';

List<File> _safetySource() =>
    Directory(_folder)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

List<String> _hits(RegExp pattern, {String? inFile}) {
  final out = <String>[];
  for (final file in _safetySource()) {
    if (inFile != null && !file.path.endsWith(inFile)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_isComment(lines[i])) continue;
      if (pattern.hasMatch(lines[i])) {
        out.add('${file.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
  }
  return out;
}

void main() {
  test('the folder exists and the scan is actually reading it', () {
    // A source guard that reads an empty directory passes forever. This
    // codebase has already shipped one vacuous rule guard.
    expect(_safetySource(), isNotEmpty);
    expect(_safetySource().length, greaterThanOrEqualTo(5));
  });

  test('nothing here holds a body weight, or anything ranked', () {
    final banned = RegExp(
      r'\b(weight|weightKg|bodyWeight|weightLost|bmi|followers|'
      r'followerCount|leaderboard|rank)\w*\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: 'Rule 11: nothing ranks women, and no weight field exists here.',
    );
    // The guard bites.
    for (final offender in [
      'final double weightKg;',
      'final int followerCount;',
      'int get bmi => 0;',
    ]) {
      expect(banned.hasMatch(offender), isTrue, reason: offender);
    }
  });

  test('a prescribed value is never a result — no actual* at any depth', () {
    final banned = RegExp(
      r'\b(actual[A-Z]\w*|adherence|loggedAt|completedAt|isDone)\b',
    );
    expect(
      _hits(banned),
      isEmpty,
      reason: '§2.1: no document these types describe has an actual* field.',
    );
    for (final offender in [
      'final int actualReps;',
      'final num? actualWeight;',
      'final DateTime loggedAt;',
      'final double adherence;',
    ]) {
      expect(banned.hasMatch(offender), isTrue, reason: offender);
    }
  });

  test('no streak, no counter of consecutive anything', () {
    // No leading \b, and the control below is why. With one, `currentStreak`
    // did NOT match: the boundary would have to fall between `current` and
    // `Streak`, and both sides are word characters — so the guard would have
    // missed every realistic identifier and shipped as protection that could
    // never fire. `product_rules_test.dart` records the identical defect in
    // the rule 7 guard; this one was caught by its own positive control.
    final banned = RegExp(
      r'(streak\w*|consecutive\w*|daysInARow|inARow)',
      caseSensitive: false,
    );
    expect(_hits(banned), isEmpty, reason: 'C6: weeks, never a day counter.');
    for (final offender in [
      'int currentStreak = 0;',
      'final int consecutiveWeeks;',
    ]) {
      expect(banned.hasMatch(offender), isTrue, reason: offender);
    }
  });

  test('Western digits only — NumberFormat is never reached for', () {
    final banned = RegExp(r'\b(NumberFormat|DateFormat)\b');
    expect(
      _hits(banned),
      isEmpty,
      reason: 'P0-A11Y-01: intl emits Eastern digits under ar.',
    );
    expect(banned.hasMatch('NumberFormat.decimalPattern()'), isTrue);
  });

  test('free prose is never a safety input — painNotes is never parsed', () {
    // G14 §1.4: displayed to the coach, never parsed, never used to filter.
    // Two shapes, because prose reaches a filter two ways: a string method
    // called ON the notes, or the notes handed TO a matcher. The first version
    // of the second alternative required the call to open immediately before
    // the field (`RegExp(...painNotes`), so the commonest real form —
    // `RegExp(r"jump").allMatches(painNotes)` — slipped straight through it.
    // Its own positive control caught that.
    final parsing = RegExp(
      r'\bpainNotes\s*\??\s*\.\s*(contains|split|toLowerCase|toUpperCase|'
      r'match\w*|indexOf|startsWith|endsWith|replaceAll|trim)|'
      r'\b(RegExp|parse\w*|allMatches|hasMatch|firstMatch|contains|split|'
      r'indexOf|matches)\s*\([^)]*\bpainNotes\b',
    );
    expect(
      _hits(parsing),
      isEmpty,
      reason: 'A filter driven by prose is a safety claim nobody can honour.',
    );

    // Positive control: the field really is here, so the guard is looking at
    // something rather than passing on absence.
    expect(_hits(RegExp(r'\bpainNotes\b')), isNotEmpty);

    // And the guard bites.
    for (final offender in [
      'if (painNotes.contains("diastasis")) return tags;',
      'final hits = RegExp(r"jump").allMatches(painNotes);',
    ]) {
      expect(parsing.hasMatch(offender), isTrue, reason: offender);
    }
  });

  test('pure domain — no widgets, no Firestore, no I/O', () {
    // Four surfaces will depend on this chain. A single Flutter import here
    // would make it untestable without a widget tree and unusable from a
    // Cloud Function.
    final imports = <String>[];
    for (final file in _safetySource()) {
      for (final line in file.readAsLinesSync()) {
        final match = RegExp(r'''^import\s+['"]([^'"]+)['"]''')
            .firstMatch(line);
        if (match != null) imports.add(match.group(1)!);
      }
    }
    expect(imports, isNotEmpty);
    for (final import in imports) {
      final allowed =
          import == 'package:meta/meta.dart' || !import.startsWith('package:');
      expect(
        allowed,
        isTrue,
        reason:
            '$import is not permitted in the safety domain — it must stay '
            'pure: no widgets, no Firestore, no I/O.',
      );
      expect(import, isNot(startsWith('dart:io')));
      expect(import, isNot(contains('flutter')));
      expect(import, isNot(contains('firebase')));
      expect(import, isNot(contains('cloud_firestore')));
    }
  });

  test('the safety domain never reaches into a feature folder', () {
    // Layering: features depend on domain, never the other way round. The
    // onboarding LifeStage enum is a different, coarser vocabulary and
    // importing it would quietly weaken this one.
    expect(_hits(RegExp(r'features/')), isEmpty);
  });

  test('the publish gate cannot be influenced by a referral', () {
    // HANDOFF 14, structurally: the file that decides whether publishing is
    // allowed does not know referrals exist, so no future edit can make a
    // refer outcome block a publish without that import appearing in review.
    final policy = File('$_folder/life_stage_safety_policy.dart');
    expect(policy.existsSync(), isTrue);
    final code = policy
        .readAsLinesSync()
        .where((l) => !_isComment(l))
        .join('\n');
    expect(code, isNot(contains('referral_registry.dart')));
    expect(code, isNot(contains('ReferralRegistry')));
    expect(code, isNot(contains('ScreeningOutcome')));
  });

  test('the filter has no greyed-out or warning representation to render', () {
    // P0-ASMT-02: matching moves must be ABSENT. If the filter could mark a
    // move as blocked-but-present, a screen would eventually render it.
    final banned = RegExp(
      r'\b(greyed|grayed|warning|disabled|showAnyway|overrideAllowed)\w*\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned, inFile: 'exercise_candidate_filter.dart'),
      isEmpty,
      reason: 'A removed move is absent, never annotated.',
    );
    expect(banned.hasMatch('final bool greyedOut;'), isTrue);
  });

  test('a referral has no clock to expire against', () {
    // "A referral cannot expire, decay, or be cleared by silence."
    final banned = RegExp(
      r'DateTime\.now\(\)|\b(expire\w*|decay\w*|stale|ttl|validUntil)\b',
      caseSensitive: false,
    );
    expect(
      _hits(banned, inFile: 'referral_registry.dart'),
      isEmpty,
      reason: 'Nothing about a referral may depend on the current time.',
    );
    expect(banned.hasMatch('if (DateTime.now().isAfter(validUntil))'), isTrue);
  });

  test('nothing in the safety domain reads the clock at all', () {
    expect(_hits(RegExp(r'DateTime\.now\(\)')), isEmpty);
  });
}
