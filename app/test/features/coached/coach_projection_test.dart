// The coach's three projections: what reaches her, what never can, and what an
// absent key means.
//
// This is also where a **reconciliation** with G9 is pinned down by test rather
// than left as a comment. G9's `CycleSharingPolicy` reads the grant from
// `CycleDocument.sharing`; the spine amendment G11 works to says the grant
// "lives ONCE" on `relationships/{relId}.sharing`. Both exist in the codebase
// today, so `CyclePanelProjector` requires **both** to be live and the tests
// below pin that: a switch on the relationship with no grant on the cycle
// document yields "not shared", and so does the reverse. Defence in depth is
// the right answer while the two documents both exist; the reconciliation is
// reported rather than silently resolved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/coach_projection.dart';
import 'package:own_hub/features/coached/domain/sharing.dart';
import 'package:own_hub/features/cycle/domain/cycle_document.dart'
    show CycleDocument, CycleMode, CycleSharing;
import 'package:own_hub/features/cycle/domain/cycle_sharing_policy.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';

const _relId = 'c7k9farida__u3m2rania';

/// Her cycle document, with the grant bound to this relationship.
CycleDocument _cycle({
  bool energyAppetite = false,
  bool symptoms = false,
  bool datesAndPatterns = false,
  String? grantedFor = _relId,
}) => CycleDocument(
  mode: CycleMode.datesAndSymptoms,
  cycleLengthDays: 31,
  sharing: CycleSharing(
    energyAppetite: energyAppetite,
    symptoms: symptoms,
    datesAndPatterns: datesAndPatterns,
    grantedForRelId: grantedFor,
  ),
  recentStarts: const ['2026-09-03', '2026-08-04'],
);

const _days = <CoarseDay>[
  CoarseDay(energy: Energy.low, appetite: Appetite.high, cramps: Cramps.mild),
  CoarseDay(energy: Energy.ok, appetite: Appetite.ok, cramps: Cramps.none),
];

ProjectionInputs _inputs({CycleDocument? cycle}) => ProjectionInputs(
  allergies: const ['sesame'],
  dietary: const ['vegetarian'],
  avoid: const ['left shoulder'],
  goal: 'feel_better',
  days: 4,
  sessionLength: 25,
  place: 'home',
  equipment: const ['band'],
  lifeStage: 'postpartum',
  weekId: '2026-W38',
  sessionsPlanned: 4,
  sessionsLogged: 3,
  mealDaysLogged: 6,
  swapsUsed: 2,
  lastSessionAt: DateTime(2026, 9, 17, 6, 40),
  adherencePct: 73,
  quietWeeks: 1,
  restWeekUsed: false,
  cycle: cycle,
  coarseDays: _days,
  currentPeriodDay: 3,
);

void main() {
  group('shared/constraints carries no cycle data, under any switch', () {
    test('the projection is her constraints and nothing else', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final constraints = writer.buildConstraints(
        _inputs(
          cycle: _cycle(
            energyAppetite: true,
            symptoms: true,
            datesAndPatterns: true,
          ),
        ),
      );

      expect(constraints.allergies, ['sesame']);
      expect(constraints.dietary, ['vegetarian']);
      expect(constraints.avoid, ['left shoulder']);
      expect(constraints.lifeStage, 'postpartum');

      // Every switch is on, and the constraints document still carries nothing
      // cycle-derived — because there is no field it could be put in.
      expect(constraints.toString(), isNot(contains('period')));
      expect(constraints.toString(), isNot(contains('symptom')));
    });

    test('the type has no member a cycle value could occupy', () {
      final source = _sourceOf(
        'lib/features/coached/domain/coach_projection.dart',
      );
      final classBody = source.substring(
        source.indexOf('class SharedConstraints'),
        source.indexOf('/// `relationships/{relId}/rollups/'),
      );
      final fields = RegExp(
        r'^\s*final\s+\S+\s+(\w+);',
        multiLine: true,
      ).allMatches(classBody).map((m) => m.group(1)!).toList();

      expect(fields, isNotEmpty);
      for (final field in fields) {
        expect(
          RegExp(
            r'(cycle|period|symptom|energy|appetite|bleed|cramp|phase|ovul)',
            caseSensitive: false,
          ).hasMatch(field),
          isFalse,
          reason: 'SharedConstraints.$field could carry cycle data',
        );
      }
      // And there is no map or dynamic to smuggle one through.
      expect(classBody.contains('Map<'), isFalse);
      expect(classBody.contains('dynamic'), isFalse);
    });

    test('buildConstraints has no cycle parameter', () {
      final source = _sourceOf(
        'lib/features/coached/domain/coach_projection.dart',
      );
      final signature = RegExp(r'SharedConstraints buildConstraints\(([^)]*)\)')
          .firstMatch(source)!
          .group(1)!;
      expect(signature, contains('ProjectionInputs'));
      expect(signature.toLowerCase(), isNot(contains('cycle')));
    });
  });

  group('cycle data reaches a coach through exactly one door', () {
    test('granted on both documents — the panel is present', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final switches = const SharingSwitches().set(
        SharingKey.symptoms,
        true,
        relId: _relId,
      );

      final view = writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(cycle: _cycle(symptoms: true)),
      );

      final entry = view.read(ClientViewKey.symptoms);
      expect(entry, isA<SharedEntry>());
      expect((entry as SharedEntry).value, isA<SymptomsProjection>());
      expect((entry.value as SymptomsProjection).days, hasLength(2));
    });

    test('dates and patterns carry no ovulation or fertile window', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final switches = const SharingSwitches().set(
        SharingKey.datesAndPatterns,
        true,
        relId: _relId,
      );

      final view = writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(cycle: _cycle(datesAndPatterns: true)),
      );

      final projection =
          (view.read(ClientViewKey.datesAndPatterns) as SharedEntry).value
              as DatesAndPatternsProjection;
      expect(projection.currentPeriodDay, 3);
      expect(projection.recentStarts, hasLength(2));
      // The type has no field for either, which is the enforcement; this is
      // the reminder that it is deliberate.
      expect(projection.toString(), isNot(contains('ovulation')));
    });

    test(
      'switched on for the relationship but not granted on the cycle document',
      () {
        final writer = CoachProjectionWriter(store: CoachProjectionStore());
        final switches = const SharingSwitches().set(
          SharingKey.energyAppetite,
          true,
          relId: _relId,
        );

        final view = writer.rebuild(
          relId: _relId,
          switches: switches,
          live: true,
          inputs: _inputs(cycle: _cycle()),
        );

        expect(view.has(ClientViewKey.energyAppetite), isFalse);
      },
    );

    test('granted on the cycle document but not switched on here', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());

      final view = writer.rebuild(
        relId: _relId,
        switches: SharingSwitches.off,
        live: true,
        inputs: _inputs(cycle: _cycle(energyAppetite: true)),
      );

      expect(view.has(ClientViewKey.energyAppetite), isFalse);
    });

    test('a grant made for another relationship is orphaned', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final switches = const SharingSwitches().set(
        SharingKey.symptoms,
        true,
        relId: _relId,
      );

      final view = writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(
          cycle: _cycle(symptoms: true, grantedFor: 'c8p4mervat__u3m2rania'),
        ),
      );

      expect(view.has(ClientViewKey.symptoms), isFalse);
    });

    test('the relationship is over — nothing is projected', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      final switches = const SharingSwitches().set(
        SharingKey.symptoms,
        true,
        relId: _relId,
      );

      final view = writer.rebuild(
        relId: _relId,
        switches: switches,
        live: false,
        inputs: _inputs(cycle: _cycle(symptoms: true)),
      );

      expect(view.keys, isEmpty);
    });

    test('logs is not a cycle category and cannot be projected as one', () {
      expect(
        () => const CyclePanelProjector().build(
          key: SharingKey.logs,
          switches: const SharingSwitches(),
          relId: _relId,
          live: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('an absent key is never a zero, a blank, or "no symptoms"', () {
    test('NotShared is never written into the document', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);

      writer.rebuild(
        relId: _relId,
        switches: SharingSwitches.off,
        live: true,
        inputs: _inputs(cycle: _cycle()),
      );

      final view = store.clientView(_relId)!;
      expect(view.keys, isEmpty);
      // Not "present and NotShared" — absent. A marker in the document is a
      // field for a stale client to render.
      expect(view.has(ClientViewKey.symptoms), isFalse);
      expect(view.read(ClientViewKey.symptoms), const NotSharedEntry());
    });

    test('the reader offers no default, so no widget can invent one', () {
      // Code only. The file's own comment says "there is no getOrElse, no
      // valueOr and no default", which is the rule being documented rather
      // than broken.
      final source = _codeOf(
        'lib/features/coached/domain/coach_projection.dart',
      );
      expect(source.contains('valueOr'), isFalse);
      expect(source.contains('getOrElse'), isFalse);
      expect(RegExp(r'\?\?\s*0\b').hasMatch(source), isFalse);
    });
  });

  group('rollups exist only while logs is on', () {
    test('on → written; off → deleted', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);

      writer.rebuild(
        relId: _relId,
        switches: const SharingSwitches().set(
          SharingKey.logs,
          true,
          relId: _relId,
        ),
        live: true,
        inputs: _inputs(),
      );
      expect(store.rollup(_relId, '2026-W38')!.sessionsLogged, 3);

      writer.rebuild(
        relId: _relId,
        switches: SharingSwitches.off,
        live: true,
        inputs: _inputs(),
      );
      expect(store.rollups(_relId), isEmpty);
    });

    test('a rollup is week-keyed, so rebuilding is idempotent', () {
      final store = CoachProjectionStore();
      final writer = CoachProjectionWriter(store: store);
      final switches = const SharingSwitches().set(
        SharingKey.logs,
        true,
        relId: _relId,
      );

      writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(),
      );
      writer.rebuild(
        relId: _relId,
        switches: switches,
        live: true,
        inputs: _inputs(),
      );

      expect(store.rollups(_relId), hasLength(1));
    });
  });
}

String _sourceOf(String path) => File(path).readAsStringSync();

/// [path] with every comment-only line removed.
String _codeOf(String path) => _sourceOf(path)
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !(t.startsWith('//') || t.startsWith('///') || t.startsWith('*'));
    })
    .join('\n');
