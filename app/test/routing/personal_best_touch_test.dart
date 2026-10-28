// A best she beat on one set buzzes once, on the rest after that set. The next
// set's rest, which beat nothing, does not buzz again.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

import '../qa/round1/round1_harness.dart' show topScreen, wipe;

const _heavy = 'HapticFeedbackType.heavyImpact';

void main() {
  final saved = AppRouter.featureFlags;
  late List<String?> felt;

  setUp(() {
    felt = <String?>[];
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    wipe();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String?);
          }
          return null;
        });
  });
  tearDown(() {
    AppRouter.featureFlags = saved;
    CustomWorkoutState.instance.draft = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    wipe();
  });

  testWidgets('one heavy touch across two rests when only set 1 beat a best', (
    tester,
  ) async {
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    CustomWorkoutState.instance.draft = TodayDraft(
      day: WorkoutDay(
        id: 'best-touch',
        title: 'Legs',
        summary: '',
        constraints: '',
        moves: [
          PlannedMove(
            exerciseId: 'glute_bridge',
            name: 'Glute bridge',
            prescriptionLabel: '3 × 10',
            sets: [
              for (var i = 1; i <= 3; i++)
                PrescribedSet(exerciseId: 'glute_bridge', order: i, reps: 10),
            ],
          ),
        ],
      ),
      dayKey: dayKey(AppClock.now()),
    );
    AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
    await tester.pumpAndSettle();

    Future<void> logSet() async {
      await tester.tap(find.textContaining('Done'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // Set 1 is saved; its rest opens with no best yet.
    await logSet();
    expect(topScreen(tester), 'R09');
    expect(felt.where((f) => f == _heavy), isEmpty);

    // The write lands a few seconds later and it beat her best: the chip
    // appears and she feels it once, however often the page redraws.
    final session = WorkoutSessionState.instance;
    session.noteLiveBests(session.sessionId, const [
      PersonalBest(
        exerciseId: 'glute_bridge',
        metric: BestMetric.load,
        dateKey: '2026-10-28',
        sessionId: 'x',
        loadKg: 12,
        reps: 10,
        previous: PreviousBest(loadKg: 10, reps: 10),
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New best'), findsOneWidget);
    expect(felt.where((f) => f == _heavy), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(felt.where((f) => f == _heavy), hasLength(1));

    // Set 2 beat nothing: its rest has no chip and no heavy touch.
    await tester.tap(find.text("I'm ready, next set"));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await logSet();
    expect(topScreen(tester), 'R09');
    expect(find.text('New best'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(felt.where((f) => f == _heavy), hasLength(1));
    await tester.pump(const Duration(seconds: 70));
  });
}
