// HANDOFF rule 6, as executable cases: P0-SHARE-01 through P0-SHARE-04, plus
// P1-HRULE-06.
//
// The fixture numbers here are deliberately unlike the ones elsewhere in the
// suite — a different coach uid, a different client uid, a 17-day engagement —
// so a test that passes by coincidence against `sara`/`day 9 of 30` fixtures
// fails here.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/coach_projection.dart';
import 'package:own_hub/features/coached/domain/message_repository.dart';
import 'package:own_hub/features/coached/domain/relationship.dart';
import 'package:own_hub/features/coached/domain/sharing.dart';

const _ref = RelationshipRef(coachUid: 'c7k9farida', clientUid: 'u3m2rania');
final _relId = _ref.relId;

/// A second relationship, for the inheritance case.
const _nextRef = RelationshipRef(
  coachUid: 'c8p4mervat',
  clientUid: 'u3m2rania',
);

ProjectionInputs _inputs() => ProjectionInputs(
  allergies: const ['sesame'],
  dietary: const ['vegetarian'],
  avoid: const ['left shoulder'],
  goal: 'feel_better',
  days: 4,
  sessionLength: 25,
  weekId: '2026-W38',
  sessionsPlanned: 4,
  sessionsLogged: 3,
  mealDaysLogged: 6,
  swapsUsed: 2,
  lastSessionAt: DateTime(2026, 9, 17, 6, 40),
  adherencePct: 73,
  quietWeeks: 1,
  restWeekUsed: false,
);

Relationship _relationship({
  SharingSwitches sharing = SharingSwitches.off,
  RelationshipState state = RelationshipState.active,
}) => Relationship(ref: _ref, state: state, sharing: sharing);

void main() {
  group('P0-SHARE-01 — the switches start off and are independent', () {
    test('every switch is off by default', () {
      const switches = SharingSwitches();
      for (final key in SharingKey.values) {
        expect(switches[key], isFalse, reason: '${key.name} must default off');
      }
      expect(switches.isAllOff, isTrue);
      expect(switches.grantedForRelId, isNull);
    });

    test('a relationship created with no sharing argument shares nothing', () {
      expect(_relationship().sharing, SharingSwitches.off);
    });

    test('turning one on turns no other on — every pair', () {
      for (final moved in SharingKey.values) {
        final after = const SharingSwitches().set(moved, true, relId: _relId);
        for (final other in SharingKey.values) {
          expect(
            after[other],
            other == moved,
            reason:
                'turning on ${moved.name} changed ${other.name}. The four are '
                'independent.',
          );
        }
      }
    });

    test('there is no master switch to call', () {
      // The rule's own words: there is deliberately no "share everything"
      // switch to build. The enum is where one would have to be declared, so
      // the enum is where the assertion belongs.
      expect(SharingKey.values, hasLength(4));
      expect(
        SharingKey.values.map((k) => k.name),
        containsAll(<String>[
          'logs',
          'energyAppetite',
          'symptoms',
          'datesAndPatterns',
        ]),
      );
      for (final key in SharingKey.values) {
        expect(
          RegExp(
            r'(all|every|master|everything)',
            caseSensitive: false,
          ).hasMatch(key.name),
          isFalse,
          reason: '${key.name} reads like a master switch.',
        );
      }
    });

    test('the coach sees only what she turned on', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);

      final switches = const SharingSwitches().set(
        SharingKey.energyAppetite,
        true,
        relId: _relId,
      );

      final view = writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(),
      );

      // Symptoms and dates are ABSENT — not present and empty, not present and
      // false. An absent key is what "not shared" is made of.
      expect(view.has(ClientViewKey.symptoms), isFalse);
      expect(view.has(ClientViewKey.datesAndPatterns), isFalse);
      expect(view.read(ClientViewKey.symptoms), const NotSharedEntry());
      expect(view.read(ClientViewKey.datesAndPatterns), const NotSharedEntry());

      // And the logs she did not share are absent too.
      expect(view.has(ClientViewKey.adherencePct), isFalse);
      expect(store.rollup(_relId, '2026-W38'), isNull);
    });
  });

  group('P0-SHARE-02 — revoking online deletes, it does not filter', () {
    test('the key and the rollup are gone from the stored document', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);
      final service = RelationshipSharingService(projections: writer);

      var rel = _relationship();
      rel = service
          .setSwitch(
            relationship: rel,
            key: SharingKey.logs,
            value: true,
            inputs: _inputs(),
          )
          .relationship;

      expect(store.rollup(_relId, '2026-W38')?.sessionsLogged, 3);
      expect(store.clientView(_relId)!.has(ClientViewKey.adherencePct), isTrue);

      rel = service
          .setSwitch(
            relationship: rel,
            key: SharingKey.logs,
            value: false,
            inputs: _inputs(),
          )
          .relationship;

      // Deleted, not filtered: inspecting the raw document server-side shows no
      // withheld field, because there is no field.
      expect(store.rollup(_relId, '2026-W38'), isNull);
      expect(store.clientView(_relId)!.keys, isEmpty);
      expect(store.deletions, contains('relationships/$_relId/rollups'));
    });

    test('an absent key never reads as a zero or a blank', () {
      const view = ClientView.empty;
      final entry = view.read(ClientViewKey.adherencePct);

      expect(entry, isA<NotSharedEntry>());
      // The type has no `valueOr`, no `getOrElse` and no nullable getter, so
      // there is no call a careless widget could make that would produce 0.
      expect(entry, isNot(isA<SharedEntry>()));
    });
  });

  group('P0-SHARE-03 — revoking offline, stated honestly', () {
    test('the switch flips locally and the sync state says so', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);
      final service = RelationshipSharingService(projections: writer);

      var rel = _relationship();
      rel = service
          .setSwitch(
            relationship: rel,
            key: SharingKey.symptoms,
            value: true,
            inputs: _inputs(),
          )
          .relationship;

      final offline = service.setSwitch(
        relationship: rel,
        key: SharingKey.symptoms,
        value: false,
        inputs: _inputs(),
        online: false,
      );

      // Her handset is correct immediately.
      expect(offline.relationship.sharing[SharingKey.symptoms], isFalse);
      // And the app says what is actually true: saved here, applied on sync.
      expect(offline.sync, SharingSyncState.savedOnDevice);
      // The server has not heard, so the projection it holds is unchanged. A
      // server cannot deny a read it has not been told about.
      expect(store.clientView(_relId), isNotNull);
    });

    test('online, the same call reports applied', () {
      final service = RelationshipSharingService(
        projections: CoachProjectionWriter(store: CoachProjectionStore()),
      );
      final result = service.setSwitch(
        relationship: _relationship(),
        key: SharingKey.logs,
        value: true,
        inputs: _inputs(),
      );
      expect(result.sync, SharingSyncState.applied);
    });
  });

  group('P0-SHARE-04 — the grant dies with the relationship', () {
    test('ending clears the switches and deletes all three projections', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);
      final service = RelationshipSharingService(projections: writer);

      var rel = _relationship();
      for (final key in SharingKey.values) {
        rel = service
            .setSwitch(
              relationship: rel,
              key: key,
              value: true,
              inputs: _inputs(),
            )
            .relationship;
      }
      expect(store.constraints(_relId), isNotNull);

      final ended = EndCoaching(projections: writer).end(rel);

      expect(ended.relationship.state, RelationshipState.ended);
      expect(ended.relationship.sharing, SharingSwitches.off);
      expect(ended.relationship.sharing.grantedForRelId, isNull);
      expect(ended.deletedPaths, hasLength(3));
      expect(store.constraints(_relId), isNull);
      expect(store.clientView(_relId), isNull);
      expect(store.rollups(_relId), isEmpty);
    });

    test('a grant is never inherited by the next coach', () {
      // Made for the first relationship…
      final granted = const SharingSwitches().set(
        SharingKey.datesAndPatterns,
        true,
        relId: _relId,
      );

      // …and read against the second. Same woman, different coach.
      expect(
        granted.isLiveFor(
          SharingKey.datesAndPatterns,
          relId: _nextRef.relId,
          live: true,
        ),
        isFalse,
      );
    });

    test('a device that was offline when the coaching ended still refuses', () {
      // The switch document on her handset still says true, because the
      // clearing write never reached it. The grant is still bound to the
      // relationship that ended, and `live` is false, so the read-time check
      // answers no without needing to have heard anything.
      final stale = const SharingSwitches().set(
        SharingKey.energyAppetite,
        true,
        relId: _relId,
      );
      expect(stale[SharingKey.energyAppetite], isTrue);
      expect(
        stale.isLiveFor(SharingKey.energyAppetite, relId: _relId, live: false),
        isFalse,
      );
    });

    test(
      'a new relationship with the same coach begins with everything off',
      () {
        final writer = CoachProjectionWriter(store: CoachProjectionStore());
        final rel = _relationship(
          sharing: const SharingSwitches().set(
            SharingKey.logs,
            true,
            relId: _relId,
          ),
        );
        final ended = EndCoaching(projections: writer).end(rel);

        final renewed = Relationship(
          ref: _ref,
          state: RelationshipState.intake,
          sharing: ended.relationship.sharing,
        );
        for (final key in SharingKey.values) {
          expect(renewed.sharing[key], isFalse);
        }
      },
    );
  });

  group('negative controls', () {
    test('a switch that was never turned on is not "revoked"', () {
      // Nothing to assert about a revocation that never happened — but the
      // store must also not have invented an empty projection for it.
      final store = CoachProjectionStore();
      expect(store.clientView(_relId), isNull);
      expect(store.deletions, isEmpty);
    });

    test('turning a switch off again deletes nothing twice', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);
      final service = RelationshipSharingService(projections: writer);

      var rel = _relationship();
      rel = service
          .setSwitch(
            relationship: rel,
            key: SharingKey.logs,
            value: true,
            inputs: _inputs(),
          )
          .relationship;
      service.setSwitch(
        relationship: rel,
        key: SharingKey.logs,
        value: false,
        inputs: _inputs(),
      );
      final afterFirst = store.deletions.length;
      service.setSwitch(
        relationship: rel.copyWith(sharing: SharingSwitches.off),
        key: SharingKey.logs,
        value: false,
        inputs: _inputs(),
      );
      expect(store.deletions.length, afterFirst);
    });

    test('setting a switch to the value it already has is not a grant', () {
      const off = SharingSwitches();
      final again = off.set(SharingKey.symptoms, false, relId: _relId);
      expect(again, SharingSwitches.off);
      expect(again.grantedForRelId, isNull);
    });
  });
}
