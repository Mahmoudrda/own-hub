// Implements TEST-CASES.csv: P0-LOG-04 (logged from memory earns less and sets
// no personal best) and P0-LOG-12 (an unplanned walk is scored as unplanned).
//
// P0-LOG-12 exists because this exact rule was got wrong once: adding a third
// source silently promoted walks to full credit. These tests are written so that
// mistake cannot be made again quietly.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/training/session.dart';

void main() {
  const credit = SessionCredit();

  group('P0-LOG-04 / P0-LOG-12 — only a live session earns full credit', () {
    test('a live session earns full points and may set a personal best', () {
      expect(credit.earnsFullCredit(SessionSource.live), isTrue);
      expect(credit.eligibleForPersonalBest(SessionSource.live), isTrue);
      expect(credit.pointsFor(SessionSource.live), 30);
    });

    test('a recalled session earns less and sets no personal best', () {
      // She did the work. We just cannot vouch for the numbers, and R12 says so
      // on screen rather than quietly awarding nothing.
      expect(credit.earnsFullCredit(SessionSource.recalled), isFalse);
      expect(credit.eligibleForPersonalBest(SessionSource.recalled), isFalse);
      expect(credit.pointsFor(SessionSource.recalled), 15);
    });

    test('an unplanned walk is treated exactly like a recalled session', () {
      // The regression this guards: written as `== recalled`, this case fell
      // through to full credit and personal-best eligibility.
      expect(credit.earnsFullCredit(SessionSource.unplanned), isFalse);
      expect(credit.eligibleForPersonalBest(SessionSource.unplanned), isFalse);
      expect(
        credit.pointsFor(SessionSource.unplanned),
        credit.pointsFor(SessionSource.recalled),
      );
    });

    test('exactly one source earns full credit', () {
      final full = SessionSource.values.where(credit.earnsFullCredit).toList();
      expect(
        full,
        [SessionSource.live],
        reason:
            'if a second source ever earns full credit it must be a '
            'deliberate decision, visible in this diff',
      );
    });

    test('a new source cannot be added without classifying it', () {
      // The structural guard. Add SessionSource.trial and this fails until
      // someone decides what it earns.
      expect(
        allSourcesAreClassified,
        isTrue,
        reason:
            'every SessionSource must appear in fullCreditSources or '
            'reducedCreditSources',
      );
    });
  });

  group('every source still counts toward her week', () {
    test(
      'rule 3 counts weeks, it does not judge how the work was recorded',
      () {
        for (final source in SessionSource.values) {
          expect(credit.countsTowardWeek(source), isTrue, reason: source.name);
        }
      },
    );
  });

  group('spine C8 — a live session is born with nothing logged', () {
    const prescribed = PrescribedSet(
      exerciseId: 'goblet_squat',
      order: 1,
      weightKg: 12,
      reps: 10,
    );

    test('a live session with a pre-filled set is rejected', () {
      final session = TrainingSession(
        id: 's1',
        source: SessionSource.live,
        startedAt: DateTime.utc(2026, 9, 18),
        sets: [
          const LoggedSet(prescribed: prescribed)
              .recording(const SetOutcome(weightKg: 12, reps: 10)),
        ],
      );
      expect(session.satisfiesNoPrefillOnCreate, isFalse);
    });

    test('a live session with empty sets is fine', () {
      final session = TrainingSession(
        id: 's1',
        source: SessionSource.live,
        startedAt: DateTime.utc(2026, 9, 18),
        sets: const [LoggedSet(prescribed: prescribed)],
      );
      expect(session.satisfiesNoPrefillOnCreate, isTrue);
    });

    test('a recalled session is exempt, because it is logged afterwards', () {
      final session = TrainingSession(
        id: 's2',
        source: SessionSource.recalled,
        startedAt: DateTime.utc(2026, 9, 18),
        sets: [
          const LoggedSet(prescribed: prescribed)
              .recording(const SetOutcome(weightKg: 12, reps: 10)),
        ],
      );
      expect(session.satisfiesNoPrefillOnCreate, isTrue);
    });
  });

  group('an unplanned session carries no plan reference', () {
    test('a walk needs no assignment to exist', () {
      // The shape that was impossible before the spine was amended: the original
      // model required an assignmentId, so a walk could not be stored at all.
      final walk = TrainingSession(
        id: 'w1',
        source: SessionSource.unplanned,
        startedAt: DateTime.utc(2026, 9, 18, 7, 30),
        activity: 'walk',
      );
      expect(walk.planVersion, isNull);
      expect(walk.assignmentId, isNull);
      expect(walk.activity, 'walk');
      expect(walk.loggedSetCount, 0);
    });
  });
}
