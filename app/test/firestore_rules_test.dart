// Structural guards for firestore.rules.
//
// These are NOT a substitute for emulator tests, which must exercise real
// requests and are listed in the runbook. They exist because the most dangerous
// property of this file is invisible to a behavioural test written today: it is
// what happens when someone ADDS a block tomorrow.
//
// Firestore ORs `allow` statements across every matching block and a specific
// rule cannot revoke a broader grant. So a second `match /users/{uid}` — added in
// good faith by a future feature — silently widens access no matter how careful
// the original block was. That is a structural property, and this is where it is
// caught.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;
  late List<String> lines;

  setUpAll(() {
    final file = File('../firebase/firestore.rules');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'firestore.rules is a deployment artifact and must exist',
    );
    rules = file.readAsStringSync();
    lines = rules.split('\n');
  });

  int countMatches(String pattern) =>
      RegExp(RegExp.escape(pattern)).allMatches(rules).length;

  group('the OR-composition hazard stays closed', () {
    test('exactly one match block for users/{uid}', () {
      // Two blocks means the permissive one wins, whatever the other says.
      expect(
        countMatches('match /users/{uid} {'),
        1,
        reason:
            'a second users/{uid} block ORs with this one and can only '
            'widen access — extend the existing slice instead',
      );
    });

    test('exactly one match block for coaches/{coachUid}', () {
      expect(
        countMatches('match /coaches/{coachUid} {'),
        1,
        reason:
            'three groups write under coaches/{coachUid}; they must be '
            'OR-ed slices inside one block, not separate blocks',
      );
    });

    test('the file ends with a deny-by-default catch-all', () {
      final tail = lines.where((l) => l.trim().isNotEmpty).toList();
      final joined = tail.sublist(tail.length - 6).join('\n');
      expect(joined, contains('match /{document=**}'));
      expect(joined, contains('allow read, write: if false;'));
    });
  });

  group('the global invariants exist and are applied', () {
    test('the three invariants are defined', () {
      for (final fn in [
        'noRunCounter()',
        'verificationUntouched()',
        'rewardsUntouched()',
      ]) {
        expect(rules, contains('function $fn'), reason: '$fn must be defined');
      }
    });

    test('they are composed into one clause applied to client writes', () {
      expect(rules, contains('function clientInvariants()'));
      expect(
        rules,
        contains(
          'noRunCounter() && verificationUntouched() && rewardsUntouched()',
        ),
        reason:
            'the invariants must be AND-ed together, so a slice cannot '
            'satisfy one and escape the others',
      );
      expect(
        countMatches('clientInvariants()'),
        greaterThanOrEqualTo(3),
        reason: 'defined once, then applied to create and update',
      );
    });
  });

  group('spine C5 — verification is server-written, and nothing else', () {
    test('no rule permits a client to write the verification map', () {
      expect(rules, contains('!touches([\'verification\'])'));
    });

    test('the verification job collection is closed to clients entirely', () {
      // Asserted without depending on the exact run of spaces, so reformatting
      // the file cannot fail the test — a test that breaks on whitespace is one
      // people learn to ignore.
      for (final path in ['verificationJobs/{jobId}', 'nidRegistry/{hash}']) {
        final from = rules.indexOf('match /$path');
        expect(from, greaterThan(-1), reason: '$path must be declared');
        expect(
          rules.substring(from, from + 120),
          contains('allow read, write: if false;'),
          reason: '$path holds identity data and must be server-only',
        );
      }
    });
  });

  group('rewards cannot be minted by a client', () {
    test('points, weeks, bests and awards are server-written', () {
      // Literal substring checks: no escaping, nothing to get subtly wrong.
      for (final path in [
        'weeks/{weekId}',
        'bests/{exerciseId}',
        'awards/{awardId}',
      ]) {
        expect(
          rules,
          contains('match /$path'),
          reason: '$path must be declared',
        );
      }
      // Each of those three declares a client read and no client write.
      for (final path in [
        'weeks/{weekId}',
        'bests/{exerciseId}',
        'awards/{awardId}',
      ]) {
        final from = rules.indexOf('match /$path');
        final block = rules.substring(from, from + 120);
        expect(
          block,
          contains('allow write: if false;'),
          reason: 'a client that can write $path can mint its own progress',
        );
      }
      expect(rules, contains("!touches(['rewards', 'weeklyGoal'])"));
    });
  });

  group('rule 2 — a message cannot carry a plan', () {
    test('plan fields are forbidden on a message document', () {
      expect(
        rules,
        contains("['planVersion', 'assignments', 'published']"),
        reason:
            'if a message can hold plan fields, "the coach changed my plan '
            'in chat" becomes a shape this collection can hold',
      );
    });

    test('plans are never client-written', () {
      expect(rules, contains('match /plans/{uid}/{document=**}'));
      // Brace balanced rather than the first 400 characters.
      //
      // The character count was a silent trip-wire on the length of a comment.
      // It broke the day the `plans` read rule was rewritten to close a
      // privilege escalation: the fix carries a long explanation and two
      // helper functions above `allow write`, which pushed the line this test
      // looks for past character 400. The rule was correct the whole time and
      // the guard reported it as broken, which is the worst failure a guard
      // has, because the obvious way to "fix" it is to raise the number until
      // it passes and never look again.
      expect(
        _matchBlock(rules, 'match /plans/'),
        contains('allow write: if false;'),
        reason:
            'a client that can write a plan can prescribe training to '
            'another woman, which is the one thing a coach is verified for',
      );
    });
  });

  group('spine C10 — consent is checked at read time', () {
    test('a client result is readable only while consent is granted', () {
      expect(
        rules,
        contains("resource.data.consentState == 'granted'"),
        reason:
            'checking consent at read time is what makes withdrawal take '
            'effect everywhere at once',
      );
    });
  });

  group('moderation', () {
    test('a reporter can file but never read the queue', () {
      final start = rules.indexOf('match /reports/{reportId}');
      final end = rules.indexOf('match /deletionRequests/');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final block = rules.substring(start, end);

      // Asserted by MEANING, not by spelling.
      //
      // This matched the literal string 'allow read, update, delete: if false;'
      // and went red the moment that line was split into `get, list` — which is
      // exactly what `read` expands to — plus `update, delete`. The rewrite
      // denied strictly more than before and validated four fields that had
      // been unchecked, and the guard called it a regression. A guard that
      // fails on a change in the safe direction gets edited away by whoever is
      // in a hurry, and then it is not a guard.
      expect(block, contains('allow get, list: if false;'));
      expect(block, contains('allow update, delete: if false;'));
    });

    test('the three forgeries the old rule allowed are closed', () {
      final start = rules.indexOf('match /reports/{reportId}');
      final block = rules.substring(
        start,
        rules.indexOf('match /deletionRequests/'),
      );

      // Only reporterUid was checked. So the one-hour first-response clock
      // could be set to any time by the client that started it, `note` was
      // unbounded, and `reason` was free text rather than the triage set the
      // safety team sorts by.
      expect(
        block,
        contains("serverStamped('createdAt')"),
        reason: 'a forgeable createdAt is a forgeable SLA deadline',
      );
      expect(block, contains("get('note', '').size() <= 1000"));
      expect(block, contains('request.resource.data.reason in'));
      expect(block, contains('man_account'));
    });

    test('she can watch her own deletion, and never write it', () {
      final start = rules.indexOf('match /deletionRequests/{uid}');
      expect(
        start,
        greaterThan(-1),
        reason:
            'deletionRequests was absent from this file entirely, so A02 could '
            'not read the progress of its own deletion',
      );
      final block = rules.substring(start, start + 240);

      expect(block, contains('allow get:   if isSelf(uid);'));
      expect(block, contains('allow list:  if false;'));
      expect(
        block,
        contains('allow write: if false;'),
        reason:
            'a client that could set state:done could tell her she was deleted '
            'when she was not',
      );
    });
  });
}

/// The whole `match` block beginning at [needle], brace balanced.
///
/// Comment lines are dropped before counting, because the rules file explains
/// itself at length and a `{` inside prose would close the block early. Nested
/// blocks are kept: a `match` may now declare helper functions of its own, and
/// the rule this file is checking usually sits after them.
String _matchBlock(String rules, String needle) {
  final start = rules.indexOf(needle);
  if (start < 0) return '';
  final lines = rules.substring(start).split('\n');
  final out = StringBuffer();
  var depth = 0;
  var opened = false;
  for (final line in lines) {
    final code = line.trimLeft().startsWith('//') ? '' : line;
    out.writeln(line);
    for (final rune in code.runes) {
      if (rune == 0x7B) {
        depth++;
        opened = true;
      } else if (rune == 0x7D) {
        depth--;
      }
    }
    if (opened && depth <= 0) break;
  }
  return out.toString();
}
