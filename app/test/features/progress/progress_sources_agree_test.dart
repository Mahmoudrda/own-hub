// P05 (her progress card) and P06 (her muscles) must tell one story: a session
// is in both once it is finished and credited, and in neither before.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _tue = DateTime(2026, 10, 13, 10);

MuscleReport _p06() => buildMuscleReport(
  log: loggedMovesFrom(AppRouter.trainRepository),
  musclesOf: (id) => musclesFor(id, ExerciseLibrary.empty),
  today: _tue,
);

double _setsTrained(MuscleReport r) =>
    r.setsIn(MuscleWindow.week, MuscleSection.glutes);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
  });
  tearDown(() async => const ThisPhoneWipe().clearPersistence());

  test(
    'a finished, credited session is on both cards; an open one on neither',
    () async {
      final repo = AppRouter.trainRepository;
      final session = await repo.startSession(
        WorkoutDay(
          id: dayKey(_tue),
          title: 'Glutes',
          summary: '',
          constraints: '',
          moves: const [
            PlannedMove(
              exerciseId: 'glute_bridge',
              name: 'Glute bridge',
              prescriptionLabel: '',
              sets: [
                PrescribedSet(exerciseId: 'glute_bridge', order: 1, reps: 10),
              ],
            ),
          ],
        ),
      );
      await repo.flushMove(
        sessionId: session.id,
        exerciseId: 'glute_bridge',
        sets: [
          for (var i = 1; i <= 3; i++)
            LoggedSet(
              prescribed: PrescribedSet(
                exerciseId: 'glute_bridge',
                order: i,
                reps: 10,
              ),
            ).recording(const SetOutcome(reps: 10)),
        ],
      );

      // Mid-session: P05 counts 0 sessions, so P06 must show 0 sets.
      expect(AppRouter.progressStore.rewards.sessionsLogged, 0);
      expect(_setsTrained(_p06()), 0);

      await repo.finishSession(sessionId: session.id, durationSec: 900);
      RewardsState.instance.creditSession(
        sessionId: session.id,
        source: SessionSource.live,
        today: AppRouter.todayRepository,
        progress: AppRouter.progressStore,
        now: _tue,
      );

      expect(AppRouter.progressStore.rewards.sessionsLogged, 1);
      expect(_setsTrained(_p06()), 3);
    },
  );
}
