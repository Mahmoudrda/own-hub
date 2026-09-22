// P0-COACH-07 — **the month view costs one read, never thirty.**
//
// The case reads: "The 30-day grid renders from the plan version summary.
// Firestore reads for this screen are 1 or 0 (cached), never 30." The fake
// counts its reads, so this is a measurement rather than an assertion about
// intent.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/coached_repository.dart';
import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/domain/message_repository.dart';
import 'package:own_hub/features/coached/domain/relationship.dart';

const _ref = RelationshipRef(coachUid: 'c7k9farida', clientUid: 'u3m2rania');

/// A 30-day plan with rest on days 4, 8, 12, 16, 20, 24, 28 and a free day on
/// 30 — a shape unlike the mockup's, so the grid is read rather than recognised.
PlanVersion _version() => PlanVersion(
  version: 'v4',
  calendar: List<PlanDayKind>.generate(PlanVersion.calendarLength, (i) {
    final day = i + 1;
    if (day == 30) return PlanDayKind.free;
    return day % 4 == 0 ? PlanDayKind.rest : PlanDayKind.train;
  }),
  publishedAt: DateTime(2026, 9, 11, 7, 15),
  effectiveFrom: DateTime(2026, 9, 12),
  startsOn: DateTime(2026, 9, 12),
  authorUid: 'c7k9farida',
);

void main() {
  group('G05 costs one read', () {
    test('thirty cells, one document', () async {
      final repo = InMemoryCoachedRepository(versions: [_version()]);
      final reader = CoachedPlanReader(repo);

      final days = await reader.calendar(
        version: 'v4',
        today: DateTime(2026, 9, 19),
        completedDayNumbers: const {1, 2, 3, 5, 6, 7},
      );

      expect(days, hasLength(30));
      expect(
        repo.reads,
        1,
        reason:
            'a read per day would be thirty. The calendar field exists for '
            'exactly this reason.',
      );
      expect(repo.readPaths, ['versions/v4']);
    });

    test('the grid reads the coach\'s shape, not a default one', () async {
      final repo = InMemoryCoachedRepository(versions: [_version()]);
      final days = await CoachedPlanReader(repo)
          .calendar(version: 'v4', today: DateTime(2026, 9, 19));

      expect(days[3].kind, PlanDayKind.rest, reason: 'day 4');
      expect(days[4].kind, PlanDayKind.train, reason: 'day 5');
      expect(days[29].kind, PlanDayKind.free, reason: 'day 30');
    });

    test('completion comes from her logs, never from the plan', () async {
      final repo = InMemoryCoachedRepository(versions: [_version()]);
      final days = await CoachedPlanReader(repo).calendar(
        version: 'v4',
        today: DateTime(2026, 9, 19),
        completedDayNumbers: const {1, 2, 5},
      );

      expect(days.where((d) => d.done).map((d) => d.dayNumber), [1, 2, 5]);
      // Day 3 was prescribed and not done. It is not marked done.
      expect(days[2].done, isFalse);
    });

    test('today is located by date, not by position', () async {
      final repo = InMemoryCoachedRepository(versions: [_version()]);
      final days = await CoachedPlanReader(repo)
          .calendar(version: 'v4', today: DateTime(2026, 9, 19, 21, 30));
      final today = days.singleWhere((d) => d.isToday);
      expect(today.dayNumber, 8);
    });

    test('an unknown version reads null rather than an empty month', () async {
      final repo = InMemoryCoachedRepository(versions: [_version()]);
      final days = await CoachedPlanReader(repo)
          .calendar(version: 'v9', today: DateTime(2026, 9, 19));
      expect(days, isEmpty);
      expect(repo.reads, 1);
    });
  });

  group('absence means rest', () {
    test('a day with no assignment is null, not an error', () async {
      final repo = InMemoryCoachedRepository(
        assignments: {
          '2026-09-19': const CoachAssignment(
            dateKey: '2026-09-19',
            planVersion: 'v4',
          ),
        },
      );
      expect(await repo.assignment('2026-09-20'), isNull);
      expect(await repo.assignment('2026-09-19'), isNotNull);
    });
  });

  group('the relationship is a point get on a deterministic id', () {
    test('one read, by id, with no query', () async {
      final repo = InMemoryCoachedRepository(
        relationship: const Relationship(
          ref: _ref,
          state: RelationshipState.active,
        ),
      );

      final rel = await repo.relationship(_ref);
      expect(rel!.relId, 'c7k9farida__u3m2rania');
      expect(repo.reads, 1);
      expect(repo.readPaths.single, startsWith('relationships/'));
    });

    test('a relationship id that is not hers reads null', () async {
      final repo = InMemoryCoachedRepository(
        relationship: const Relationship(
          ref: _ref,
          state: RelationshipState.active,
        ),
      );
      const other = RelationshipRef(
        coachUid: 'c8p4mervat',
        clientUid: 'u3m2rania',
      );
      expect(await repo.relationship(other), isNull);
    });
  });

  group('the pin', () {
    test('pins the assignment\'s version and offers no way to move it', () {
      final repo = InMemoryCoachedRepository();
      final pinned = CoachedPlanReader(repo).pin(
        const CoachAssignment(dateKey: '2026-09-19', planVersion: 'v4'),
        at: DateTime(2026, 9, 19, 6, 30),
      );
      expect(pinned.version, 'v4');
    });

    test('dayNumberFor is null outside the engagement', () {
      final repo = InMemoryCoachedRepository();
      final reader = CoachedPlanReader(repo);
      final version = _version();

      expect(reader.dayNumberFor(version, DateTime(2026, 9, 12)), 1);
      expect(reader.dayNumberFor(version, DateTime(2026, 10, 11)), 30);
      expect(reader.dayNumberFor(version, DateTime(2026, 10, 12)), isNull);
      expect(reader.dayNumberFor(version, DateTime(2026, 9, 11)), isNull);
    });
  });

  group('negative controls', () {
    test('the interface cannot express publishing', () {
      final source = File('lib/features/coached/domain/coached_repository.dart')
          .readAsStringSync();
      final abstractBlock = source.substring(
        source.indexOf('abstract class CoachedRepository'),
        source.indexOf('/// An in-memory implementation'),
      );
      // `publishedVersions` is a READ of what was published, and it is the
      // only input a "plan updated" card may be built from. What must not
      // exist is a WRITE — so the ban names the acts rather than the word.
      for (final banned in [
        'publishPlan',
        'publishCoachPlan',
        'writeAssignment',
        'saveVersion',
        'setAssignment',
      ]) {
        expect(
          abstractBlock.contains(banned),
          isFalse,
          reason: 'CoachedRepository must not be able to $banned',
        );
      }
      // And no method on it returns anything but a read.
      // `.*` rather than `[^>]*`: Future<List<PlanVersion>> nests its angle
      // brackets, and a character class that cannot span them silently drops
      // the one method this assertion most needs to see.
      final methods = RegExp(
        r'^\s*Future<.*>\s+(\w+)\(',
        multiLine: true,
      ).allMatches(abstractBlock).map((m) => m.group(1)!).toList();
      expect(methods, [
        'relationship',
        'assignment',
        'version',
        'publishedVersions',
        'setReadCursor',
      ]);
    });

    test('a stranger cannot move a read cursor', () {
      final repo = InMemoryCoachedRepository();
      expect(
        () => repo.setReadCursor(_ref, 'u9z1someone', DateTime(2026, 9, 19)),
        throwsA(isA<StateError>()),
      );
    });
  });
}
