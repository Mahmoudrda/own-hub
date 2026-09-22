// P1-CYC-03, P0-CYC-13, P0-CYC-14, P0-CYC-15 — sharing is off by default, the
// switches are independent, and a grant dies with the relationship it was given
// for.
//
// G9 §3.4's `orphaned` state is the one that makes the product's own promise
// true — "Cycle sharing switched itself off when the coaching ended" — and it is
// evaluated at READ time, so it holds on a handset that is offline and has never
// synced a revocation. These tests exercise the policy directly, with no writes
// between the revocation and the read, because that is the only way to prove the
// guarantee does not depend on one.
//
// The Phase 2 half is what is asserted here. `P0-CYC-14` and `P0-CYC-15` reach
// W02/W09 and G16, which are phase 3 — the projection they read is built now.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/cycle_repository.dart';
import 'package:own_hub/features/cycle/domain/cycle_sharing_policy.dart';

const String _relId = 'coach_sara__client_mai';
const String _otherRelId = 'coach_hoda__client_mai';

CoachRelationship _relationship({
  String relId = _relId,
  RelationshipStatus status = RelationshipStatus.active,
}) => CoachRelationship(
  relId: relId,
  coachUid: 'coach_sara',
  clientUid: 'client_mai',
  status: status,
);

Future<InMemoryCycleRepository> _setUp() async {
  final repository = InMemoryCycleRepository();
  await repository.completeSetup(mode: CycleMode.datesAndSymptoms);
  return repository;
}

void main() {
  const policy = CycleSharingPolicy();

  group('P0-CYC-13 — off by default, and independent', () {
    test('a new document has every sharing switch false', () async {
      final repository = await _setUp();
      final sharing = repository.current!.sharing;

      expect(sharing.energyAppetite, isFalse);
      expect(sharing.symptoms, isFalse);
      expect(sharing.datesAndPatterns, isFalse);
      expect(sharing.grantedForRelId, isNull);
      expect(sharing.isAllOff, isTrue);
    });

    test('setup cannot turn one on — there is no parameter to pass', () async {
      // The structural claim. `completeSetup` and `savePreferences` take no
      // sharing argument at all, so Y01 and Y02 have nothing to grant with.
      final repository = await _setUp();
      await repository.savePreferences(
        cycleLengthDays: 31,
        adaptation: CycleAdaptation.y02Defaults,
      );

      expect(repository.current!.sharing.isAllOff, isTrue);
      // …and the preferences she did set were saved, so this is not passing
      // because the write silently did nothing.
      expect(repository.current!.cycleLengthDays, 31);
      expect(repository.current!.adaptation.workoutSuggestions, isTrue);
    });

    test('turning one on leaves the other two off', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: true,
        relId: _relId,
      );

      final sharing = repository.current!.sharing;
      expect(sharing.energyAppetite, isTrue);
      expect(sharing.symptoms, isFalse);
      expect(sharing.datesAndPatterns, isFalse);
      expect(sharing.grantedForRelId, _relId);
    });

    test('a second switch does not disturb the first', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: true,
        relId: _relId,
      );
      await repository.setSharing(
        category: CycleCategory.datesAndPatterns,
        on: true,
        relId: _relId,
      );

      final sharing = repository.current!.sharing;
      expect(sharing.energyAppetite, isTrue);
      expect(sharing.datesAndPatterns, isTrue);
      expect(sharing.symptoms, isFalse);
    });
  });

  group('the projection a coach may read', () {
    test('an off switch is notShared, never an empty panel', () async {
      final repository = await _setUp();

      final projection = policy.projectionFor(
        cycle: repository.current,
        relationship: _relationship(),
        relId: _relId,
        category: CycleCategory.symptoms,
      );

      // An explicit value. "Not shared" is not "no symptoms", and a coach
      // reading absence as wellness is a clinical error the UI would cause.
      expect(projection, isA<NotShared>());
      expect(projection.category, CycleCategory.symptoms);
    });

    test(
      'a live grant returns the projection for that category only',
      () async {
        final repository = await _setUp();
        await repository.setSharing(
          category: CycleCategory.energyAppetite,
          on: true,
          relId: _relId,
        );

        final granted = policy.projectionFor(
          cycle: repository.current,
          relationship: _relationship(),
          relId: _relId,
          category: CycleCategory.energyAppetite,
          days: const [CoarseDay(), CoarseDay()],
        );
        expect(granted, isA<EnergyAppetiteProjection>());

        // The category she did NOT turn on stays shut.
        final other = policy.projectionFor(
          cycle: repository.current,
          relationship: _relationship(),
          relId: _relId,
          category: CycleCategory.symptoms,
        );
        expect(other, isA<NotShared>());
      },
    );

    test('the window is capped at seven days', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.symptoms,
        on: true,
        relId: _relId,
      );

      final projection = policy.projectionFor(
        cycle: repository.current,
        relationship: _relationship(),
        relId: _relId,
        category: CycleCategory.symptoms,
        // Twelve handed in; seven is the contract.
        days: List.filled(12, const CoarseDay()),
      ) as SymptomsProjection;

      expect(projection.days.length, CycleSharingPolicy.projectionWindowDays);
    });
  });

  group('P0-CYC-14 — revoking removes the derived panel', () {
    test('turning a switch off flips the projection to notShared', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: true,
        relId: _relId,
      );

      expect(
        policy.projectionFor(
          cycle: repository.current,
          relationship: _relationship(),
          relId: _relId,
          category: CycleCategory.energyAppetite,
        ),
        isA<EnergyAppetiteProjection>(),
      );

      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: false,
        relId: _relId,
      );

      expect(
        policy.projectionFor(
          cycle: repository.current,
          relationship: _relationship(),
          relId: _relId,
          category: CycleCategory.energyAppetite,
        ),
        isA<NotShared>(),
      );
    });

    test('the last switch off clears the relationship binding', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.symptoms,
        on: true,
        relId: _relId,
      );
      await repository.setSharing(
        category: CycleCategory.symptoms,
        on: false,
        relId: _relId,
      );

      // Nothing is shared, so nothing is bound. A stale relationship id on an
      // all-off map would answer "who was this for" for a grant that is gone.
      expect(repository.current!.sharing.grantedForRelId, isNull);
    });
  });

  group('P0-CYC-15 — a grant never survives its relationship', () {
    test('an ended relationship reads as notShared with no new write', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.datesAndPatterns,
        on: true,
        relId: _relId,
      );

      // The switch is still true on the document. Nothing has been revoked and
      // nothing has synced — this is the offline case §3.4 is about.
      expect(repository.current!.sharing.datesAndPatterns, isTrue);

      final projection = policy.projectionFor(
        cycle: repository.current,
        relationship: _relationship(status: RelationshipStatus.ended),
        relId: _relId,
        category: CycleCategory.datesAndPatterns,
      );

      expect(projection, isA<NotShared>());
      expect(
        policy.stateFor(
          cycle: repository.current,
          relationship: _relationship(status: RelationshipStatus.ended),
          relId: _relId,
          category: CycleCategory.datesAndPatterns,
        ),
        SharingGrantState.orphaned,
      );
    });

    test('an expired relationship is orphaned too', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.symptoms,
        on: true,
        relId: _relId,
      );

      expect(
        policy.stateFor(
          cycle: repository.current,
          relationship: _relationship(status: RelationshipStatus.expired),
          relId: _relId,
          category: CycleCategory.symptoms,
        ),
        SharingGrantState.orphaned,
      );
    });

    test('a new coach does not inherit the previous grant', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.symptoms,
        on: true,
        relId: _relId,
      );

      // A different, fully active relationship. The switch is true, but it was
      // never granted for this one.
      final projection = policy.projectionFor(
        cycle: repository.current,
        relationship: _relationship(relId: _otherRelId),
        relId: _otherRelId,
        category: CycleCategory.symptoms,
      );

      expect(projection, isA<NotShared>());
      expect(
        policy.stateFor(
          cycle: repository.current,
          relationship: _relationship(relId: _otherRelId),
          relId: _otherRelId,
          category: CycleCategory.symptoms,
        ),
        SharingGrantState.orphaned,
      );
    });

    test('a missing relationship document is orphaned, not granted', () async {
      final repository = await _setUp();
      await repository.setSharing(
        category: CycleCategory.energyAppetite,
        on: true,
        relId: _relId,
      );

      expect(
        policy.stateFor(
          cycle: repository.current,
          relationship: null,
          relId: _relId,
          category: CycleCategory.energyAppetite,
        ),
        SharingGrantState.orphaned,
      );
    });
  });

  group('no document at all', () {
    test('a woman who never set up shares nothing', () {
      for (final category in CycleCategory.values) {
        expect(
          policy.projectionFor(
            cycle: null,
            relationship: _relationship(),
            relId: _relId,
            category: category,
          ),
          isA<NotShared>(),
        );
      }
    });
  });
}
