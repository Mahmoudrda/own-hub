// Her own plan survives a restart, reads as none from an old snapshot, goes
// with a wipe and is in no cloud document.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/my_plan_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthoredProgramme _template() => AuthoredProgramme(
  programId: 'split_fixture',
  titleEn: 'Split',
  titleAr: 'خطة',
  status: ProgrammeStatus.published,
  sessions: [
    for (final id in ['a', 'b'])
      AuthoredSession(
        sessionId: id,
        titleEn: 'Day $id',
        titleAr: 'يوم $id',
        minutes: 45,
        lifeStages: const {LifeStage.none},
        moves: [
          for (final m in ['m1', 'm2', 'm3'])
            AuthoredMove(
              exerciseId: m,
              nameEn: m,
              nameAr: m,
              sets: 3,
              reps: 10,
            ),
        ],
      ),
  ],
);

PlannedMove _planned(String id, {double? kg}) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [PrescribedSet(exerciseId: id, order: 1, reps: 10, weightKg: kg)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = MyPlanState.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
  });

  tearDown(() async {
    await const ThisPhoneWipe().clearPersistence();
  });

  test('a fresh phone has no plan and writes no section', () {
    expect(state.hasPlan, isFalse);
    expect(AppSnapshot.capture().containsKey('myPlan'), isFalse);
  });

  test('looking at a split keeps nothing', () async {
    final shown = state.preview(_template(), LifeStage.none);
    expect(shown.days.length, 2);
    expect(state.current, same(shown));
    expect(state.hasPlan, isFalse);
    expect(AppSnapshot.capture().containsKey('myPlan'), isFalse);
    expect(state.previewBlank().isBlank, isTrue);
    expect(state.hasPlan, isFalse);
  });

  test(
    'the first change kept makes it hers; a plan she has is the one shown',
    () {
      final shown = state.preview(_template(), LifeStage.none);
      state.save(shown.withoutDay(0));
      expect(state.hasPlan, isTrue);
      expect(state.pending, isNull);
      final again = state.preview(_template(), LifeStage.none);
      expect(again.days.length, 1);
      expect(state.previewBlank().days.length, 1);
    },
  );

  group('what waits on her keeping a copy', () {
    test(
      'looking, and leaving, never run it; the first change runs it once',
      () {
        var ran = 0;
        final shown = state.preview(
          _template(),
          LifeStage.none,
          onConfirm: () => ran++,
        );
        expect(ran, 0);
        state.previewBlank();
        expect(ran, 0);

        state.preview(_template(), LifeStage.none, onConfirm: () => ran++);
        state.save(shown.withoutDay(0));
        expect(ran, 1);
        state.save(state.plan!.withoutDay(0));
        expect(ran, 1);
      },
    );

    test('opening a day to edit runs it without keeping a plan', () {
      var ran = 0;
      state.preview(_template(), LifeStage.none, onConfirm: () => ran++);
      state.confirmPending();
      state.confirmPending();
      expect(ran, 1);
      expect(state.hasPlan, isFalse);
    });

    test('dropping the copy, or the plan, forgets it', () {
      var ran = 0;
      state.preview(_template(), LifeStage.none, onConfirm: () => ran++);
      state.backToOriginal();
      state.save(MyPlan.fork(_template(), stage: LifeStage.none));
      expect(ran, 0);

      state.reset();
      state.preview(_template(), LifeStage.none, onConfirm: () => ran++);
      state.reset();
      state.save(const MyPlan.blank());
      expect(ran, 0);
    });

    test('the moves of a copy she is looking at go into that copy', () {
      final other = AuthoredProgramme(
        programId: 'other_split',
        titleEn: 'Other',
        titleAr: 'تانية',
        status: ProgrammeStatus.published,
        sessions: _template().sessions.reversed.toList(),
      );
      state.preview(other, LifeStage.none);
      state.saveDayMoves(
        template: _template(),
        stage: LifeStage.none,
        slot: 0,
        moves: [_planned('only')],
      );
      expect(state.plan!.sourceProgrammeId, 'other_split');
      expect(state.plan!.days[0].session.moves.single.exerciseId, 'only');
    });
  });

  test('swap, remove, add and reorder make the snapshot round trip', () async {
    state.save(MyPlan.fork(_template(), stage: LifeStage.none));
    final saved = state.saveDayMoves(
      template: _template(),
      stage: LifeStage.none,
      slot: 0,
      moves: [_planned('m3', kg: 15), _planned('new_move'), _planned('m1')],
    );
    expect(saved, isTrue);
    state.save(state.plan!.withDayMoved(1, 0).withCopyOf(0));
    final before = jsonEncode(state.plan!.toJson());

    final document = jsonEncode(AppSnapshot.capture());
    await const ThisPhoneWipe().clearPersistence();
    expect(state.hasPlan, isFalse);

    AppSnapshot.restore(document);

    expect(jsonEncode(state.plan!.toJson()), before);
    final day = state.plan!.days.firstWhere(
      (d) => d.session.moves.any((m) => m.exerciseId == 'new_move'),
    );
    expect(day.session.moves.map((m) => m.exerciseId), [
      'm3',
      'new_move',
      'm1',
    ]);
    expect(day.kgAt(0), 15);
  });

  test('the first change she keeps forks, and cancelling forks nothing', () {
    // Nothing is written until she keeps a change.
    expect(state.hasPlan, isFalse);
    state.saveDayMoves(
      template: _template(),
      stage: LifeStage.none,
      slot: 1,
      moves: [_planned('only')],
    );
    expect(state.plan!.sourceProgrammeId, 'split_fixture');
    expect(state.plan!.days.length, 2);
    expect(state.plan!.days[1].session.moves.single.exerciseId, 'only');
  });

  test('a snapshot from before it existed reads as no plan', () {
    state.save(MyPlan.fork(_template(), stage: LifeStage.none));
    final old =
        jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
    old.remove('myPlan');
    state.reset();
    AppSnapshot.restore(jsonEncode(old));
    expect(state.hasPlan, isFalse);
  });

  test('a bad section is ignored and the rest still restores', () {
    final document = jsonEncode({
      ...AppSnapshot.capture(),
      'myPlan': 'not a plan',
    });
    state.reset();
    expect(() => AppSnapshot.restore(document), returnsNormally);
    expect(state.hasPlan, isFalse);
  });

  test('back to the original drops it and anything being shown', () {
    state.preview(_template(), LifeStage.none);
    state.backToOriginal();
    expect(state.current, isNull);
    state.save(MyPlan.fork(_template(), stage: LifeStage.none));
    state.backToOriginal();
    expect(state.hasPlan, isFalse);
  });

  test('the wipe clears it', () async {
    state.save(const MyPlan.blank());
    expect(nothingOfHersRemains, isFalse);
    await const ThisPhoneWipe().clearPersistence();
    expect(state.hasPlan, isFalse);
    expect(nothingOfHersRemains, isTrue);
  });

  test('it is in the snapshot and in no cloud document', () {
    state.save(MyPlan.fork(_template(), stage: LifeStage.none));
    expect(AppSnapshot.capture().containsKey('myPlan'), isTrue);
    const names = {'myPlan', 'mine_1', 'mine_2', 'sourceId', 'source'};
    void scan(Object? node, String where) {
      if (node is Map) {
        for (final entry in node.entries) {
          expect(names.contains(entry.key), isFalse, reason: where);
          scan(entry.value, where);
        }
      } else if (node is Iterable) {
        for (final item in node) {
          scan(item, where);
        }
      } else if (node is String) {
        expect(names.contains(node), isFalse, reason: '$where $node');
      }
    }

    for (final doc in CloudDocuments.capture()) {
      scan(doc.data, '${doc.collection}/${doc.id}');
    }
  });
}
