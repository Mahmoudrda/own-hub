import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/swap_move_view.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

const day = WorkoutDay(
  id: 'acceptance-day',
  title: 'Upper body',
  summary: '',
  constraints: '',
  planVersion: 'v1',
  moves: [
    PlannedMove(
      exerciseId: 'row',
      name: 'Row',
      prescriptionLabel: '2 sets',
      sets: [
        PrescribedSet(exerciseId: 'row', order: 0, reps: 10, weightKg: 10),
        PrescribedSet(exerciseId: 'row', order: 1, reps: 10, weightKg: 10),
      ],
    ),
  ],
);
const dumbbellProgram = StartingProgram(
  programId: 'dumbbell',
  weeks: 4,
  daysPerWeek: 3,
  sessionLength: 15,
  quiet: true,
  equipment: {Equipment.dumbbells},
);

class SwapRepository extends InMemoryTrainRepository {
  String? requested;
  @override
  Future<List<MoveAlternative>> alternativesFor(String exerciseId) async {
    requested = exerciseId;
    return const [
      MoveAlternative(
        exerciseId: 'band_row',
        name: 'Band row',
        reason: 'Same pattern',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await const ThisPhoneWipe().clearPersistence();
    WorkoutSessionState.instance.reset();
  });
  tearDown(() async {
    WorkoutSessionState.instance.reset();
    await const ThisPhoneWipe().clearPersistence();
  });
  test('F1 empty catalogue gives an honest no-match', () {
    expect(selectStartingProgram(const Intake(), catalogue: []), isNull);
  });
  test('F1 compatible equipment keeps the selected programme', () {
    expect(
      selectStartingProgram(
        const Intake(equipment: {Equipment.dumbbells}),
        catalogue: [dumbbellProgram],
      ),
      dumbbellProgram,
    );
  });
  test(
    'F1 unavailable equipment is rejected even if it is the only programme',
    () {
      expect(
        selectStartingProgram(
          const Intake(equipment: {Equipment.none}),
          catalogue: [dumbbellProgram],
        ),
        isNull,
      );
    },
  );
  test('F3 preserve old wire values and add real gym equipment', () {
    expect(
      Equipment.values.map((e) => e.wireName),
      containsAll([
        'none',
        'mat',
        'dumbbells',
        'bands',
        'bench',
        'barbell',
        'cable',
        'smith_machine',
        'machine',
      ]),
    );
  });
  test('F7 starting a session never manufactures actual results', () async {
    final session = await AppRouter.trainRepository.startSession(day);
    expect(session.sets, isNotEmpty);
    expect(session.sets.every((s) => s.outcome == null), isTrue);
  });
  test(
    'F5 active position survives clearing memory and restoring snapshot',
    () async {
      final state = WorkoutSessionState.instance;
      state.start(day, AppRouter.trainRepository);
      await Future<void>.delayed(Duration.zero);
      state.setLogged();
      final id = state.sessionId;
      final document = jsonEncode(AppSnapshot.capture());
      state.reset();
      await const ThisPhoneWipe().clearPersistence();
      expect(state.isLive, isFalse);
      AppSnapshot.restore(document);
      expect(
        state.isLive,
        isTrue,
        reason: 'restore the active session, not just its records',
      );
      expect(state.sessionId, id);
      expect(state.setIndex, 1);
      expect(state.day?.planVersion, 'v1');
      expect(state.currentMove?.exerciseId, 'row');
    },
  );
  testWidgets(
    'F4 the swap screen queries its actual exercise and uses the returned candidate',
    (tester) async {
      final repo = SwapRepository();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: SwapMoveView(
            repository: repo,
            sessionId: 'live-row',
            exerciseId: 'row',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.requested, 'row');
      expect(find.text('Band row'), findsOneWidget);
      expect(find.text('Glute bridge'), findsNothing);
      await tester.tap(find.text('Swap it'));
      await tester.pumpAndSettle();
      expect(repo.swaps.single.from, 'row');
      expect(repo.swaps.single.to, 'band_row');
      expect(repo.flushes, isEmpty);
    },
  );
}
