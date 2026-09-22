// Executable guards over the rewards engine and the Progress feature.
//
// `test/product_rules_test.dart` scans the whole of `lib/` for the project-wide
// rules. This file adds the guards that are specific to G6, and every one of
// them carries a POSITIVE CONTROL — a sample the pattern must match — because
// PHASE1-FIXES.md §14 records this codebase shipping a source scan whose regex
// could never fire: "a new guard needs a test proving it bites before it is
// trusted to protect anything."

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The D14 group below checks the authored ladder as VALUES, not as text. Every
// other guard in this file scans source with a regex; those two needed the real
// types, and this file had never imported them because it had never needed one.
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';

/// The folders this group owns.
List<File> _ownSource() => [
  ...Directory('lib/domain/rewards').listSync(recursive: true),
  ...Directory('lib/features/progress').listSync(recursive: true),
].whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// `path:line` for every non-comment line matching [pattern], across [files].
List<String> _hits(RegExp pattern, {List<File>? files}) {
  final out = <String>[];
  for (final file in files ?? _ownSource()) {
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

File _file(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file;
}

void main() {
  group('RULE 3 — weeks, not days, inside the rewards engine', () {
    final banned = RegExp(
      r'\b(streak|dayStreak|daysStreak|dailyStreak|daysInARow|consecutiveDays'
      r'|currentStreak|longestStreak|missedDays|daysMissed|missedDayCount)\b',
      caseSensitive: false,
    );

    test('no day-granularity counter exists in G6 code', () {
      expect(
        _hits(banned),
        isEmpty,
        reason:
            'Rule 3: the week is the only unit. G6 §6 additionally requires '
            'missedDays, dailyStreak and daysStreak to be banned — a count of '
            'missed days is precisely what P0-WEEK-02 forbids on screen.',
      );
    });

    test('the guard would actually bite', () {
      for (final offender in [
        'final int dailyStreak;',
        'int missedDays = 0;',
        'var daysInARow = computeRun();',
        'final streak = 3;',
        'int get daysStreak => _run;',
      ]) {
        expect(
          banned.hasMatch(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }

      // And must not fire on the legitimate vocabulary this engine uses.
      for (final allowed in [
        'final int dailyPoints;',
        'DailyCapState(dayKey: dayKey, pointsToday: 30);',
        'final int currentRun;',
        'expect(decision.outcome, RepairOutcome.missed);',
      ]) {
        expect(
          banned.hasMatch(allowed),
          isFalse,
          reason: 'the guard must not fire on: $allowed',
        );
      }
    });
  });

  group('D14 — the ladder is authored, and its shape is checked', () {
    // This group replaced D6's "no TierRung is constructed in lib/". That guard
    // existed so inferred thresholds could not ship as fact, and its own
    // comment set the terms for retiring it: "The day the owner writes the
    // table down, a ladder constant is added and this guard is updated in the
    // same diff — a visible decision." The owner wrote it down on 19 September
    // 2026, so the guard turns from "there must be no ladder" into "the ladder
    // must hold together".

    test('five rungs, one per tier, in the enum order', () {
      expect(TierLadder.shipped.rungs, hasLength(Tier.values.length));
      expect(
        [for (final rung in TierLadder.shipped.rungs) rung.tier],
        Tier.values,
        reason:
            'TierPolicy promotes by comparing tier indexes, so a ladder out of '
            'order would qualify her for a higher tier than one she cannot '
            'reach',
      );
    });

    test('thresholds only ever rise', () {
      // A dip would mean a higher tier was easier than a lower one, so she
      // could hold a label she could not have been promoted into.
      var weeks = -1;
      var bests = -1;
      for (final rung in TierLadder.shipped.rungs) {
        expect(
          rung.countedWeeks,
          greaterThan(weeks),
          reason: '${rung.tier.name} asks for fewer weeks than the tier below',
        );
        expect(rung.bestsCount, greaterThanOrEqualTo(bests));
        weeks = rung.countedWeeks;
        bests = rung.bestsCount;
      }
    });

    test('no tier asks for more recent weeks than the window holds', () {
      // `_holds` only ever consults the last kRecentWeekWindow closed weeks, so
      // a floor above that is a tier nobody can hold — it would read as a
      // permanent slip rather than as a mistake.
      for (final rung in TierLadder.shipped.rungs) {
        expect(
          rung.recencyFloor,
          lessThanOrEqualTo(kRecentWeekWindow),
          reason: '${rung.tier.name} could never be held',
        );
      }
    });

    test('the first tier cannot be fallen out of', () {
      expect(
        TierLadder.shipped.rungFor(Tier.firstSteps)!.recencyFloor,
        0,
        reason:
            'a woman who has just started must not be shown a slip from the '
            'first thing she reached',
      );
    });

    test('a bad fortnight never costs a tier', () {
      // The strictest floor is six of eight, so two missed weeks out of eight
      // still holds every tier. Rest-week repair runs before this, so a missed
      // week she has earned cover for is not even counted as missed.
      for (final rung in TierLadder.shipped.rungs) {
        expect(rung.recencyFloor, lessThanOrEqualTo(kRecentWeekWindow - 2));
      }
    });

    test('no tier is earned from body weight — rule 11 at the ladder', () {
      // D14 says tiers come from gym logs and weights lifted. `bestsCount` is
      // a count of personal bests, which is a load on a bar. If a rung ever
      // grew a field naming her own weight, this fails.
      final source = _file('lib/domain/rewards/tier_policy.dart')
          .readAsStringSync();
      final banned = RegExp(
        r'\b(weightKg|bodyWeight|weightLost|kgLost)\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(source), isFalse);
      // The control.
      expect(banned.hasMatch('final int weightKg;'), isTrue);
    });

    test('the unlock list is still unauthored, and that is separate', () {
      // Authoring tiers did not author unlocks. `UnlockPolicy` fails closed on
      // an unknown feature id, so an empty list opens nothing rather than
      // opening everything.
      final unlock = _file('lib/domain/rewards/unlock_policy.dart')
          .readAsStringSync();
      expect(unlock, contains('UnlockPolicy(<Unlock>[])'));
    });
  });

  group('nothing earned is ever taken away', () {
    test('UnlockPolicy never reads the display tier', () {
      // The whole promise of T05 rests on this one word being absent. A
      // one-character edit would break it silently, and no screenshot could
      // show it.
      final pattern = RegExp(r'\bdisplay\b');
      final offenders = _hits(
        pattern,
        files: [_file('lib/domain/rewards/unlock_policy.dart')],
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'unlocks must read earnedTier, which is monotonic. Reading the '
            'display tier means a slipped label closes a feature she earned.',
      );
      // The control.
      expect(pattern.hasMatch('return standing.display != null;'), isTrue);
    });

    test('the award ledger has no way to take points back', () {
      final banned = RegExp(
        r'\b(void|int|bool|Future)[^\n]*\b(remove|delete|clear|reset|deduct'
        r'|subtract|revoke)\w*\s*\(',
        caseSensitive: false,
      );
      final offenders = _hits(
        banned,
        files: [_file('lib/domain/rewards/award_ledger.dart')],
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'the ledger is append-only. "Nothing earned is ever taken away" is '
            'not a promise it keeps; it is one it cannot break.',
      );

      // The control.
      for (final offender in [
        'void removeAward(String id) {',
        'Future<void> clearPoints() async {',
        'int deduct(int points) {',
      ]) {
        expect(
          banned.hasMatch(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }
    });

    test('points are only ever added', () {
      final ledger = _file('lib/domain/rewards/award_ledger.dart')
          .readAsLinesSync();
      // `this.points = 0,` is an initialising formal in the constructor — it
      // sets the resumed total on the way in, not a statement that changes it
      // later. What this guard is looking for is an assignment in the body.
      final assignments = [
        for (final line in ledger)
          if (!_isComment(line) &&
              !line.contains('this.points') &&
              RegExp(r'(?<!\.)\bpoints\s*[-+*/]?=[^=]').hasMatch(line))
            line.trim(),
      ];

      expect(assignments, [
        'points += decision.granted;',
      ], reason: 'exactly one statement may change the total, and it adds');
    });
  });

  group('RULE 11 — displayed, never ranked', () {
    test('TierPolicy cannot see her weight', () {
      final pattern = RegExp(r'weight', caseSensitive: false);
      final offenders = _hits(
        pattern,
        files: [_file('lib/domain/rewards/tier_policy.dart')],
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'weight is not a parameter of evaluate(), so it is structurally '
            'unable to influence a tier',
      );
      expect(pattern.hasMatch('required num weightKg,'), isTrue);
    });

    test('AwardTable has no case keyed to weight or to a social count', () {
      final banned = RegExp(
        r'\b(weightKg|weightLost|bodyWeight|followers?Count|followerCount'
        r'|likes|leaderboard|rank(By|ing))\b',
        caseSensitive: false,
      );
      expect(
        _hits(banned, files: [_file('lib/domain/rewards/award_table.dart')]),
        isEmpty,
      );
      expect(banned.hasMatch('case WeightLost(:final kg) =>'), isTrue);
    });

    test('MeasurementsRepository offers exactly five methods, and no query', () {
      final source = _file(
        'lib/features/progress/domain/progress_repository.dart',
      ).readAsStringSync();

      final start = source.indexOf('abstract class MeasurementsRepository {');
      expect(start, greaterThan(-1));
      final end = source.indexOf('\n}', start);
      final block = source.substring(start, end);

      final methods = RegExp(
        r'^\s{2}(?:Future|Stream)<.*?>\s+(\w+)\(',
        multiLine: true,
      ).allMatches(block).map((m) => m.group(1)!).toSet();

      expect(
        methods,
        {'latest', 'historyForOwner', 'save', 'purgeLocal', 'dispose'},
        reason:
            'G6 §5: latest() and historyForOwner() only. A query method is how '
            '"order women by weight" becomes expressible.',
      );
    });

    test('nothing in Progress sorts by a body figure', () {
      final banned = RegExp(
        r'(orderBy\s*\(|sortBy|rankBy|leaderboard'
        r'|compareTo\s*\([^)]*(weight|loadKg)'
        r'|(weightKg|loadKg)[^\n]*\.compareTo)',
        caseSensitive: false,
      );

      expect(
        _hits(banned),
        isEmpty,
        reason: 'Rule 11: displayed, never ranked',
      );

      // The control — including the shape PHASE1-QA-VERDICT noted the old
      // rule-11 guard could NOT catch.
      for (final offender in [
        "query.orderBy('weightKg')",
        'items.sort((a, b) => a.weightKg.compareTo(b.weightKg));',
        'final sortByWeight = true;',
      ]) {
        expect(
          banned.hasMatch(offender),
          isTrue,
          reason: 'the guard must catch: $offender',
        );
      }

      // And must not fire on the date-key ordering the fakes legitimately do.
      expect(
        banned.hasMatch('all.sort((a, b) => b.dateKey.compareTo(a.dateKey));'),
        isFalse,
      );
    });

    test('Measurement is not comparable', () {
      final source = _file(
        'lib/features/progress/domain/progress_repository.dart',
      ).readAsStringSync();
      expect(
        source,
        isNot(contains('class Measurement implements Comparable')),
        reason: 'a comparable measurement is a sortable woman',
      );
    });
  });

  group('RULE 9 — undo, never a confirmation', () {
    test('no dialog anywhere in Progress or the rewards engine', () {
      // P04's add-weight is a logging action. G6 §9.15 notes P1-RULE-09's
      // screen list omits P04; it is treated as listed, because it is.
      final banned = RegExp(r'showDialog|AlertDialog|CupertinoAlertDialog');
      expect(
        _hits(banned),
        isEmpty,
        reason:
            'a confirmation on a log is the friction this product exists to '
            'remove, and asking a woman to confirm her own weight is the worst '
            'place in the app for one',
      );
      expect(
        banned.hasMatch('await showDialog<bool>(context: context,'),
        isTrue,
      );
    });

    test('P04 logs through the shared bus and nothing else', () {
      final source = _file(
        'lib/features/progress/presentation/body_privately_view.dart',
      ).readAsStringSync();

      expect(source, contains('LogCommandBus'));
      expect(source, contains('UndoableLog'));
      expect(source, contains('showUndoSnackBar'));

      // There must be exactly one call site, and it must be the commit closure.
      // Asserting the absence of `_repo.save(` outright was wrong: the commit
      // closure IS a call to it, so that assertion could only pass for a screen
      // that never saved anything at all.
      expect(
        RegExp(r'_repo\.save\(').allMatches(source).length,
        1,
        reason: 'one save call site, so there is one place to check',
      );
      expect(
        source,
        contains('commit: () => _repo.save(measurement)'),
        reason:
            'the only call to save() must be inside the UndoableLog commit '
            'closure, so an undone measurement never reaches storage',
      );
    });
  });
}
