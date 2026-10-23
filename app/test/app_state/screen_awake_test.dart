// The screen stays awake while a workout is live, and lets go the moment it
// is not: at finish, at discard, at reset, and while the app is in the
// background.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/screen_awake.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

PlannedMove _move(String id, int sets) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [
    for (var i = 1; i <= sets; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

final WorkoutDay _day = WorkoutDay(
  id: '2026-10-13',
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: [_move('squat', 3), _move('bridge', 2)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = WorkoutSessionState.instance;
  final saved = ScreenAwake.instance;
  late List<bool> calls;
  late InMemoryTrainRepository repository;

  setUp(() {
    calls = <bool>[];
    ScreenAwake.instance = ScreenAwake(apply: (on) async => calls.add(on));
    state.reset();
    calls.clear();
    RewardsState.instance.reset();
    TrainingStreakState.instance.reset();
    repository = InMemoryTrainRepository();
  });
  tearDown(() {
    state.reset();
    ScreenAwake.instance = saved;
  });

  Future<void> started() async {
    state.start(_day, repository);
    await Future<void>.delayed(Duration.zero);
  }

  test('starting a workout keeps the screen on', () async {
    await started();
    expect(calls, [true]);
  });

  test(
    'a start that is ignored because one is live does not buzz the lock',
    () async {
      await started();
      state.start(_day, repository);
      expect(calls, [true]);
    },
  );

  test('finishing lets the screen sleep again', () async {
    await started();
    state.setLogged();
    await state.finish(
      repository: repository,
      today: InMemoryTodayRepository(),
      progress: ProgressStore(),
    );
    expect(calls, [true, false]);
  });

  test('discarding lets the screen sleep again', () async {
    await started();
    state.setLogged();
    await state.finish(
      repository: repository,
      today: InMemoryTodayRepository(),
      progress: ProgressStore(),
      reason: EndedReason.abandoned,
    );
    expect(calls, [true, false]);
  });

  test('restoring a session under way keeps the screen on', () {
    state.restoreLive(
      day: _day,
      session: const TrainSession(
        id: 'live-7',
        source: SessionSource.live,
        dateKey: '2026-10-13',
        sets: [],
      ),
      moveIndex: 0,
      setIndex: 1,
      loggedSets: 1,
    );
    expect(calls, [true]);
  });

  test('reset lets the screen sleep again', () async {
    await started();
    state.reset();
    expect(calls, [true, false]);
  });

  test('the background releases it and coming back takes it again', () async {
    await started();
    final awake = ScreenAwake.instance;
    awake.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(calls, [true]);
    awake.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(calls, [true, false]);
    awake.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(calls, [true, false, true]);
  });

  test('the real app lifecycle drives it too', () async {
    await started();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    expect(calls, [true, false, true]);
  });

  test(
    'returning to the app with no workout does not hold the screen',
    () async {
      await started();
      state.reset();
      calls.clear();
      final awake = ScreenAwake.instance;
      awake.didChangeAppLifecycleState(AppLifecycleState.paused);
      awake.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, isEmpty);
    },
  );

  test('a phone that refuses never breaks the workout', () async {
    ScreenAwake.instance = ScreenAwake(
      apply: (on) async => throw PlatformException(code: 'no'),
    );
    await started();
    expect(state.isLive, isTrue);
  });

  group('the native channels', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ownhub.app/settings'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ownhub.app/screen'),
        null,
      );
    });

    test('Android asks the settings channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final seen = <String>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ownhub.app/settings'),
        (call) async {
          seen.add('${call.method}:${call.arguments}');
          return true;
        },
      );
      final awake = ScreenAwake();
      awake.set(true);
      awake.set(false);
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['keepScreenOn:true', 'keepScreenOn:false']);
    });

    test('iPhone asks its own channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final seen = <String>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ownhub.app/screen'),
        (call) async {
          seen.add('${call.method}:${call.arguments}');
          return true;
        },
      );
      final awake = ScreenAwake();
      awake.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['keepScreenOn:true']);
    });

    test('a channel that refuses is swallowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final seen = <String>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ownhub.app/settings'),
        (call) async {
          seen.add(call.method);
          throw PlatformException(code: 'refused');
        },
      );
      final awake = ScreenAwake();
      awake.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['keepScreenOn']);
    });
  });
}
