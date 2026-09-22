// §2 rule 3 / spine C6, applied to this feature: "this group counts no
// consecutive days and stores no counter; `recentStarts` is a bounded set of
// dates, asserted by `no_streak_test`" (G9 §5).
//
// `test/product_rules_test.dart` already scans the whole of `lib/` for
// streak-shaped identifiers, and `PHASE1-QA-REPORT.md` B3 warns that the guard
// "was widened to `/features/`, so a new `lib/features/eat/` and
// `lib/features/cycle/` are now in scope — verify it still holds once those
// folders exist rather than assuming".
//
// This is that verification, plus the part the global scan cannot make: that
// `recentStarts` is a bounded *set of dates* and not a count, and that G9 adds
// no counter of its own.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';

final DateTime _today = DateTime(2027, 3, 20);

/// Rule 3's vocabulary, plus the three G6 §6 asked to be added.
final RegExp _banned = RegExp(
  r'\b(streak|dayStreak|daysStreak|dailyStreak|daysInARow|consecutiveDays'
  r'|currentStreak|longestStreak|missedDays)\b',
  caseSensitive: false,
);

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

List<File> _cycleSources() =>
    Directory('lib/features/cycle')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

PeriodEntry _period(DateTime start) =>
    (PeriodEntry.validate(start: start, today: _today) as PeriodValid).entry;

void main() {
  test('the scan is actually looking at files', () {
    // A guard over an empty directory passes vacuously — the failure mode the
    // rule-9 scan shipped with for weeks.
    expect(_cycleSources().length, greaterThanOrEqualTo(15));
  });

  test('no streak-shaped identifier exists in the cycle feature', () {
    final offenders = <String>[];

    for (final file in _cycleSources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        if (_banned.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'rule 3: weeks, not days. No streak may exist in any form.',
    );
  });

  test('the guard would bite', () {
    // Proven against text that must match, per PHASE1-FIXES.md #14.
    for (final offender in [
      'int currentStreak = 0;',
      'final int daysInARow;',
      'var missedDays = 3;',
      'int get dailyStreak => 0;',
    ]) {
      expect(_banned.hasMatch(offender), isTrue, reason: offender);
    }

    // And must not fire on what the feature legitimately holds.
    for (final allowed in [
      'final List<String> recentStarts;',
      'static const int maxRecentStarts = 12;',
      'int? get lengthDays => end == null ? null : 1;',
    ]) {
      expect(_banned.hasMatch(allowed), isFalse, reason: allowed);
    }
  });

  test('recentStarts is a bounded list of dates, not a count', () async {
    final cycles = InMemoryCycleRepository();
    final periods = InMemoryPeriodRepository(cycles: cycles);
    await cycles.completeSetup(mode: CycleMode.datesAndSymptoms);

    await periods.save(_period(DateTime(2027, 1, 4)));
    await periods.save(_period(DateTime(2027, 2, 3)));

    final starts = cycles.current!.recentStarts;

    // Dates, in a bounded list. Nothing here accumulates.
    expect(starts, isA<List<String>>());
    expect(starts, ['2027-02-03', '2027-01-04']);
    expect(starts.length, lessThanOrEqualTo(CycleDocument.maxRecentStarts));
  });

  test('deleting a period makes the list shorter — nothing is monotonic', () async {
    // A counter only goes up. This goes down, which is the difference between a
    // bounded set of facts and a score.
    final cycles = InMemoryCycleRepository();
    final periods = InMemoryPeriodRepository(cycles: cycles);
    await cycles.completeSetup(mode: CycleMode.datesAndSymptoms);

    await periods.save(_period(DateTime(2027, 1, 4)));
    await periods.save(_period(DateTime(2027, 2, 3)));
    expect(cycles.current!.recentStarts.length, 2);

    await periods.remove('2027-02-03');
    expect(cycles.current!.recentStarts.length, 1);
  });

  test('no cycle field is named like a tally', () {
    // The document holds a mode, flags, a length, two switch maps, a cached
    // last period and a bounded list. Nothing counts anything.
    final cycle = CycleDocument(
      mode: CycleMode.datesAndSymptoms,
      recentStarts: const ['2027-02-03'],
    );

    expect(cycle.recentStarts.length, 1);
    // cycleLengthDays is a property of her body that she stated, not a tally
    // the app accumulated — and it stays null until she says otherwise.
    expect(cycle.cycleLengthDays, isNull);
  });
}
