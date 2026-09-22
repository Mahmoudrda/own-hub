// `P1-RULE-12` and `P1-RULE-15` — what a coach may know about a client.
//
// The assertion that matters is that a revoked switch **removes the field**
// rather than hiding it. A test that revoked by setting a flag would prove
// nothing: the security property is that the value is not in the document, so a
// rules mistake has nothing to leak.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/client_view.dart';

const _relId = 'coach-42_client-93';
final _asOf = DateTime(2026, 9, 8, 18, 2);

ClientView _fullyShared() => ClientView(
  relId: _relId,
  displayName: 'Rania Fouad',
  constraints: const ClientConstraints(
    avoid: ['overhead press', 'deep lunges'],
    allergies: ['sesame'],
    equipment: ['two dumbbells'],
    sessionMinutes: 25,
    daysPerWeek: 3,
  ),
  week: const ClientWeekSignal(
    sessionsLogged: 1,
    sessionsTarget: 3,
    quietWeeksInARow: 2,
    restWeekAlreadyUsed: true,
  ),
  cycle: 'luteal',
  asOf: _asOf,
);

void main() {
  group('P1-RULE-15 — a withheld field is absent, not hidden', () {
    test('revoking logs removes the week signal entirely', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      projection.revoke(_relId, week: true);
      final view = await projection.forRelationship(_relId);

      expect(view.week, isNull);
      expect(view.constraints, isNotNull);
      expect(view.cycle, isNotNull);
    });

    test('revoking cycle leaves nothing to read', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      projection.revoke(_relId, cycle: true);
      final view = await projection.forRelationship(_relId);

      expect(
        view.cycle,
        isNull,
        reason: 'Cycle data is unreachable unless that switch is on.',
      );
    });

    test('the switches are independent', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      projection.revoke(_relId, constraints: true);
      final view = await projection.forRelationship(_relId);

      expect(view.constraints, isNull);
      expect(view.week, isNotNull);
      expect(view.cycle, isNotNull);
    });

    test('revoking everything leaves an empty view, not an error', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      projection.revoke(_relId, constraints: true, week: true, cycle: true);
      final view = await projection.forRelationship(_relId);

      expect(view.isEmpty, isTrue);
      expect(view.displayName, 'Rania Fouad');
    });

    test('a relationship with no projection reads as empty', () async {
      final projection = InMemoryClientViewProjection();
      final view = await projection.forRelationship('coach-42_nobody');

      expect(view.isEmpty, isTrue);
      expect(view.constraints, isNull);
      expect(view.week, isNull);
      expect(view.cycle, isNull);
    });

    test('a fully shared view is not empty — the negative control', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      final view = await projection.forRelationship(_relId);
      expect(view.isEmpty, isFalse);
      expect(view.cycle, 'luteal');
    });
  });

  group('P1-RULE-12 — constraints are read-only', () {
    test('the reader returns unknown rather than null', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(ClientView(relId: _relId, displayName: 'Rania Fouad'));
      final reader = ClientConstraintsReader(projection);

      final constraints = await reader.forRelationship(_relId);
      expect(constraints.isKnown, isFalse);
      expect(constraints.avoid, isEmpty);
      expect(constraints.allergies, isEmpty);
    });

    test('it reads what the projection carries and nothing more', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());
      final reader = ClientConstraintsReader(projection);

      final constraints = await reader.forRelationship(_relId);
      expect(constraints.avoid, ['overhead press', 'deep lunges']);
      expect(constraints.allergies, ['sesame']);
      expect(constraints.sessionMinutes, 25);
      expect(constraints.isKnown, isTrue);
    });

    test('a revoked assessment makes them unknown again', () async {
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());
      final reader = ClientConstraintsReader(projection);

      projection.revoke(_relId, constraints: true);
      final constraints = await reader.forRelationship(_relId);
      expect(constraints.isKnown, isFalse);
    });

    test('unknown is not the same as nothing to avoid', () {
      expect(ClientConstraints.unknown.isKnown, isFalse);
      const answeredWithNothing = ClientConstraints(sessionMinutes: 20);
      expect(answeredWithNothing.isKnown, isTrue);
      expect(answeredWithNothing.avoid, isEmpty);
    });
  });

  group('K16 — the banner says only what it knows', () {
    test('two quiet weeks warrants it', () {
      const signal = ClientWeekSignal(
        quietWeeksInARow: 2,
        restWeekAlreadyUsed: true,
      );
      expect(signal.warrantsBanner, isTrue);
    });

    test('one does not', () {
      expect(
        const ClientWeekSignal(quietWeeksInARow: 1).warrantsBanner,
        isFalse,
      );
    });

    test('an unshared week draws no banner at all', () {
      expect(const ClientWeekSignal().warrantsBanner, isFalse);
    });
  });

  test('every read is accounted for', () async {
    final projection = InMemoryClientViewProjection();
    projection.put(_fullyShared());

    await projection.forRelationship(_relId);
    await projection.forRelationship(_relId);
    expect(projection.reads, 2);
  });

  test(
    'the projection is keyed by relationship, never by a client uid',
    () async {
      // The whole design, restated as behaviour: a coach asks about someone she
      // coaches, by the id of the coaching, and there is no other question to ask.
      final projection = InMemoryClientViewProjection();
      projection.put(_fullyShared());

      final wrongKey = await projection.forRelationship('client-93');
      expect(wrongKey.isEmpty, isTrue);
    },
  );
}
