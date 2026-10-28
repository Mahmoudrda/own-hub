// M8: a meal added gets a soft tap and taking it back gets the reverse of it,
// and neither ever answers a log that would reward eating too little: not a
// near-empty log, not a voice log, not for a woman whose targets are withheld.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/feel_prefs.dart';
import 'package:own_hub/app_state/meal_cue.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';

import '../../helpers/fake_sound.dart';

const String _day = '2026-10-17';

MealItem _item(
  String id, {
  int kcal = 300,
  MealOrigin origin = MealOrigin.suggestion,
}) => MealItem(
  itemId: id,
  foodId: 'nowhere-$id',
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 10, 17, 8, 30),
  source: MealSource.search,
  origin: origin,
  kcal: kcal,
  proteinG: 12,
  name: id,
);

MealLogPrepared _prepared(MealItem item) => MealLogPrepared(
  write: MealWrite.transform(
    dayId: _day,
    slot: MealSlot.breakfast,
    tz: 'Africa/Cairo',
    libVersion: 1,
    added: [item],
  ),
  items: [item],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSoundBackend backend;
  late MealLogSession session;
  final savedWithheld = MealCue.targetsWithheld;

  LogHandle log(MealItem item) =>
      session.submit(_prepared(item), slot: MealSlot.breakfast, describe: 'x');

  setUp(() {
    backend = setUpFakeSound();
    MealCue.targetsWithheld = () => false;
    session = MealLogSession(
      repository: InMemoryMealRepository(),
      bus: LogCommandBus(window: const Duration(seconds: 5)),
      rememberPlates: false,
    );
  });
  tearDown(() {
    session.reset();
    MealCue.targetsWithheld = savedWithheld;
    tearDownFakeSound();
  });

  test('a meal added plays the soft tap', () {
    log(_item('ful'));
    expect(backend.names, ['food_logged']);
  });

  test('taking it back inside the window plays the reverse', () {
    final handle = log(_item('ful'));
    expect(session.undo(handle), isTrue);
    expect(backend.names, ['food_logged', 'undo']);
  });

  test('the snackbar takes a meal back through settle, and that plays it', () {
    final handle = log(_item('ful'));
    expect(handle.undo(), isTrue);
    session.settle();
    expect(backend.names, ['food_logged', 'undo']);
    session.settle();
    expect(backend.names, ['food_logged', 'undo'], reason: 'once');
  });

  test('a meal that was written is not answered as if it were undone', () {
    log(_item('ful'));
    session.flushNow();
    session.settle();
    expect(backend.names, ['food_logged']);
  });

  test('taking a logged meal out later is silent', () async {
    log(_item('ful'));
    session.flushNow();
    await Future<void>.delayed(Duration.zero);
    final stored = await session.repository.day(_day);
    final handle = session.remove(
      dayId: _day,
      slot: MealSlot.breakfast,
      items: stored.itemsIn(MealSlot.breakfast),
      describe: 'removed',
    );
    session.undo(handle);
    expect(backend.names, ['food_logged']);
  });

  group('never a reward for eating too little', () {
    test('a near-empty log is silent', () {
      log(_item('coffee', kcal: MealCue.minKcal - 1));
      expect(backend.played, isEmpty);
    });

    test('a log at the smallest size that counts as a meal plays', () {
      log(_item('snack', kcal: MealCue.minKcal));
      expect(backend.names, ['food_logged']);
    });

    test('withheld targets mean no food sound at all, on a log or an undo', () {
      MealCue.targetsWithheld = () => true;
      final handle = log(_item('ful'));
      session.undo(handle);
      expect(backend.played, isEmpty);
    });

    test('a voice log is silent', () {
      final handle = log(_item('ful', origin: MealOrigin.voice));
      session.undo(handle);
      expect(backend.played, isEmpty);
    });

    test('her switch off silences it', () async {
      await FeelPrefs.instance.setSounds(false);
      log(_item('ful'));
      expect(backend.played, isEmpty);
    });
  });
}
