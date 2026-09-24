// What the snapshot carries, section by section, and what it refuses to carry.
//
// The journey test beside this one walks the app and proves the two things a
// woman would notice — her session and her meal survive being closed. This one
// is the inventory: every store named in the brief is filled through its own
// real write path, captured, put through JSON, restored into stores that have
// been emptied, and read back. A section that stops being carried fails here
// with the name of the section rather than showing up months later as "my
// settings keep resetting".
//
// The second half is the guard. A snapshot read off a phone is untrusted input:
// it can be truncated, corrupt, older, newer, or carry values this build has
// never heard of. None of that may reach a constructor assert or a store that
// validates, because the consequence of either is an app that cannot open.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cycle_state.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/training/session.dart' as training;
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One round trip through the format, with every store emptied in between.
///
/// Emptying is the part that makes this a test rather than a tautology: if the
/// stores were left as they were, a decoder that restored nothing would pass.
Future<int> _roundTrip() async {
  final document = jsonEncode(AppSnapshot.capture());
  await const ThisPhoneWipe().clearPersistence();
  expect(
    nothingOfHersRemains,
    isTrue,
    reason: 'the stores really are empty before anything is put back',
  );
  return AppSnapshot.restore(document);
}

const String _dayKey = '2026-09-01';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
  });

  tearDown(() async {
    await const ThisPhoneWipe().clearPersistence();
    await AppRouter.localePreference.write(AppLanguage.english);
  });

  group('everything of hers makes the round trip', () {
    test('her day, her week and the notices she has seen', () async {
      final today = AppRouter.todayRepository;
      today.recordSession('session-1');
      today.recordMeal(at: DateTime(2026, 9, 1, 13, 5));
      await today.markNoticeSeen(
        NoticeKind.quietWeek,
        WeekKey.of(DateTime(2026, 9, 1)),
      );
      final logged = today.day.week.sessionsLogged;

      await _roundTrip();

      expect(today.day.week.sessionsLogged, logged);
      expect(today.day.mealLoggedAt, DateTime(2026, 9, 1, 13, 5));
      expect(
        today.noticeSeen(
          NoticeKind.quietWeek,
          WeekKey.of(DateTime(2026, 9, 1)),
        ),
        isTrue,
      );
      expect(
        today.creditedSessions,
        contains('session-1'),
        reason: 'or the same session would be credited again after a restart',
      );
    });

    test('her weeks, her points and her measurements', () async {
      final store = AppRouter.progressStore;
      final key = WeekKey.of(DateTime(2026, 9, 1));
      store.weeks[key.id] = WeekDoc(
        week: key,
        sessionsTarget: 3,
        counted: true,
        creditedSessionIds: const ['session-1', 'session-2'],
      );
      store.rewards = const Rewards(points: 90, level: 2, sessionsLogged: 7);
      await AppRouter.measurementsRepository.save(
        Measurement(
          dayId: _dayKey,
          takenAt: DateTime(2026, 9, 1),
          weightKg: 61,
        ),
      );

      await _roundTrip();

      expect(store.weeks[key.id]?.creditedSessionIds, [
        'session-1',
        'session-2',
      ]);
      expect(store.weeks[key.id]?.counted, isTrue);
      expect(store.rewards.points, 90);
      expect(store.rewards.sessionsLogged, 7);
      expect(store.measurements[_dayKey]?.weightKg, 61);
    });

    test(
      'her personal bests, and the count that cannot be earned twice',
      () async {
        final ledger = AppRouter.personalBestLedger;
        ledger.apply(
          source: training.SessionSource.live,
          sessionId: 'session-1',
          dateKey: _dayKey,
          measuredSets: const [
            MeasuredSet(
              exerciseId: 'goblet_squat',
              actualWeight: 12,
              actualReps: 10,
            ),
          ],
          exercises: const {
            'goblet_squat': ExerciseMeta(
              exerciseId: 'goblet_squat',
              metric: BestMetric.load,
            ),
          },
        );
        expect(ledger.bestsCount, 1);

        await _roundTrip();

        expect(AppRouter.progressStore.bests['goblet_squat']?.loadKg, 12);
        expect(ledger.bestsCount, 1);
        expect(
          ledger.hasCounted(exerciseId: 'goblet_squat', sessionId: 'session-1'),
          isTrue,
          reason: 'a replayed flush must not count the same best a second time',
        );
        expect(
          identical(AppRouter.progressStore.bests, ledger.bests),
          isTrue,
          reason: 'one map, restored in place — never two ideas of her best',
        );
      },
    );

    test('her sessions and the moves she flushed', () async {
      final train = AppRouter.trainRepository;
      await train.logRecalled(dateKey: _dayKey, method: RecallMethod.plan);
      await train.flushMove(
        sessionId: 'recalled-$_dayKey-history',
        exerciseId: 'goblet_squat',
        sets: const [],
      );

      await _roundTrip();

      expect(train.sessions.map((s) => s.dateKey), contains(_dayKey));
      expect(train.sessions.first.source, SessionSource.recalled);
      expect(train.sessions.first.completed, isTrue);
      expect(train.flushes.map((f) => f.exerciseId), ['goblet_squat']);
    });

    test('her meals, with the figures frozen onto them', () async {
      final store = AppRouter.mealRepository.store;
      store.apply(
        MealWrite.transform(
          dayId: _dayKey,
          slot: MealSlot.lunch,
          tz: WeekKey.fallbackTimezone,
          libVersion: 1,
          added: [
            MealItem(
              itemId: 'item-1',
              foodId: 'koshari_bowl',
              servings: 1,
              size: 'M',
              loggedAt: DateTime(2026, 9, 1, 13, 5),
              source: MealSource.search,
              origin: MealOrigin.search,
              kcal: 540,
              proteinG: 18,
            ),
          ],
        ),
      );

      await _roundTrip();

      final day = store.days[_dayKey];
      expect(day?.itemsIn(MealSlot.lunch).single.foodId, 'koshari_bowl');
      expect(day?.itemsIn(MealSlot.lunch).single.kcal, 540);
      expect(day?.itemsIn(MealSlot.lunch).single.proteinG, 18);
      expect(day?.firstLogAt, DateTime(2026, 9, 1, 13, 5));
    });

    test('her cycle, her periods and her check-ins', () async {
      final cycles = AppRouter.cycleRepository;
      await cycles.completeSetup(
        mode: CycleMode.datesAndSymptoms,
        contextFlags: const {CycleContextFlag.irregular},
      );
      await cycles.savePreferences(
        cycleLengthDays: 30,
        adaptation: CycleAdaptation.y02Defaults,
      );
      final draft = PeriodEntry.validate(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
        today: DateTime.now(),
      );
      await AppRouter.periodRepository.save((draft as PeriodValid).entry);
      CycleAppState.instance.saveCheckIn(
        const TodayCheckIn(energy: Energy.low, cramps: Cramps.mild),
      );

      await _roundTrip();

      final cycle = cycles.current;
      expect(cycle?.mode, CycleMode.datesAndSymptoms);
      expect(cycle?.cycleLengthDays, 30);
      expect(cycle?.contextFlags, {CycleContextFlag.irregular});
      expect(cycle?.adaptation.homeCard, isTrue);
      expect(cycles.store.periods['2026-09-01']?.end, DateTime(2026, 9, 5));
      expect(
        CycleAppState
            .instance
            .savedCheckIns[AppRouter.dayId(DateTime.now())]
            ?.energy,
        Energy.low,
      );
      expect(
        AppRouter.todayCheckIn.cramps,
        Cramps.mild,
        reason: "today's check-in is today's, and it is still today",
      );
    });

    test('her privacy switches, and the blur that defaults on', () async {
      final privacy = AppRouter.privacyRepository;
      await privacy.setPrivacyKey(PrivacyKey.showBests, true);
      await privacy.setPrivacyKey(PrivacyKey.blurFacesDefault, false);
      await privacy.setNotifyPush(true);

      await _roundTrip();

      expect(privacy.settings().showBests, isTrue);
      expect(privacy.settings().blurFacesDefault, isFalse);
      expect(privacy.settings().profileVisible, isFalse);
      expect(privacy.notify().push, isTrue);
    });

    test('her allergies, and the difference between none and never asked', () async {
      await AppRouter.dietaryRepository.save(
        allergies: const {AllergenTag.nuts},
        dietary: const {DietaryTag.vegetarianWeekdays},
      );

      await _roundTrip();

      final profile = AppRouter.dietaryRepository.read();
      expect(profile.allergies, {AllergenTag.nuts});
      expect(profile.dietary, {DietaryTag.vegetarianWeekdays});

      // Asked, and named nothing, is a claim about her — and it is a different
      // fact from never having been asked. Both have to survive as themselves.
      await AppRouter.dietaryRepository.save(
        allergies: const <AllergenTag>{},
        dietary: const <DietaryTag>{},
      );
      await _roundTrip();
      expect(AppRouter.dietaryRepository.read().asked, isTrue);
      expect(AppRouter.dietaryRepository.read().allergies, isEmpty);

      await const ThisPhoneWipe().clearPersistence();
      await _roundTrip();
      expect(
        AppRouter.dietaryRepository.read().asked,
        isFalse,
        reason: 'a woman nobody asked stays a woman nobody asked',
      );
    });

    test('her setup answers', () async {
      await AppRouter.intakeRepository.merge(
        goal: TrainingGoal.loseSteadily,
        days: 4,
        minutes: 20,
        equipment: const {Equipment.dumbbells},
        lifeStage: LifeStage.postpartum,
      );

      await _roundTrip();

      final intake = AppRouter.intakeRepository.read();
      expect(intake.goal, TrainingGoal.loseSteadily);
      expect(intake.days, 4);
      expect(intake.minutes, 20);
      expect(intake.equipment, {Equipment.dumbbells});
      expect(intake.lifeStage, LifeStage.postpartum);
    });

    test('that she has been through setup at all', () async {
      // The value the second launch turns on. Without it the four questions
      // would open over Home every time the app started, which is the one
      // thing a woman notices faster than never being asked at all.
      expect(AppRouter.intakeRepository.setupDone, isFalse);
      AppRouter.intakeRepository.markSetupDone();

      await _roundTrip();
      expect(AppRouter.intakeRepository.setupDone, isTrue);

      // And deleting everything asks again, because a fresh start is fresh.
      await const ThisPhoneWipe().clearPersistence();
      await _roundTrip();
      expect(AppRouter.intakeRepository.setupDone, isFalse);
    });

    test('the language she chose', () async {
      await AppRouter.localePreference.write(AppLanguage.arabic);
      final document = jsonEncode(AppSnapshot.capture());
      await AppRouter.localePreference.write(AppLanguage.english);

      AppSnapshot.restore(document);
      expect(AppRouter.localePreference.read(), AppLanguage.arabic);
    });
  });

  group('a document this build did not write cannot break it', () {
    test('a value from a newer build is dropped, not guessed at', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      (whole['today']! as Map<String, Object?>)['state'] = 'someFutureState';
      (whole['cycle']! as Map<String, Object?>)['document'] = <String, Object?>{
        'mode': 'aModeThatDoesNotExist',
      };

      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
      expect(AppRouter.cycleRepository.current, isNull);
    });

    test('a section this build has never heard of is skipped', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['somethingAddedLater'] = <String, Object?>{'x': 1};
      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
    });

    test('a cycle document over its own caps is truncated, never asserted', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['cycle'] = <String, Object?>{
        'document': <String, Object?>{
          'mode': 'datesAndSymptoms',
          'contextFlags': [for (final f in CycleContextFlag.values) f.name],
          'cycleLengthDays': 900,
          'recentStarts': [for (var i = 1; i <= 40; i++) '2026-01-0$i'],
        },
        'periods': <Object?>[],
        'checkIns': <String, Object?>{},
      };

      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
      final cycle = AppRouter.cycleRepository.current;
      expect(cycle, isNotNull);
      expect(
        cycle!.contextFlags.length,
        lessThanOrEqualTo(CycleDocument.maxContextFlags),
      );
      expect(
        cycle.recentStarts.length,
        lessThanOrEqualTo(CycleDocument.maxRecentStarts),
      );
      expect(
        cycle.cycleLengthDays,
        isNull,
        reason: 'a length outside 21-45 is not a length she gave us',
      );
    });

    test('a measurement the store would refuse never reaches it', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['progress'] = <String, Object?>{
        'measurements': <String, Object?>{
          'not-a-date': <String, Object?>{
            'takenAt': '2026-09-01T00:00:00.000',
            'weightKg': 61,
          },
          _dayKey: <String, Object?>{
            'takenAt': '2026-09-01T00:00:00.000',
            'weightKg': -5,
            'waistCm': 70,
          },
        },
      };

      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
      final measurements = AppRouter.progressStore.measurements;
      expect(measurements.containsKey('not-a-date'), isFalse);
      expect(measurements[_dayKey]?.weightKg, isNull);
      expect(measurements[_dayKey]?.waistCm, 70);
    });

    test('setup answers outside what the screens offer fall back', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['intake'] = <String, Object?>{
        'goal': 'not_a_goal',
        'days': 99,
        'minutes': 7,
        'equipment': <Object?>[],
      };

      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
      final intake = AppRouter.intakeRepository.read();
      expect(Intake.allowedDays, contains(intake.days));
      expect(Intake.allowedMinutes, contains(intake.minutes));
      expect(
        intake.equipment,
        isNotEmpty,
        reason: 'Equipment.none is an answer; an empty set is not a state',
      );
    });

    test('a slot over the rules cap is trimmed rather than stored', () {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['meals'] = <String, Object?>{
        'days': <String, Object?>{
          _dayKey: <String, Object?>{
            'slots': <String, Object?>{
              'lunch': [
                for (var i = 0; i < kSlotItemCap + 10; i++)
                  <String, Object?>{
                    'itemId': 'item-$i',
                    'foodId': 'koshari_bowl',
                    'loggedAt': '2026-09-01T13:05:00.000',
                    'kcal': 540,
                    'proteinG': 18,
                  },
              ],
            },
          },
        },
      };

      expect(AppSnapshot.restore(jsonEncode(whole)), greaterThan(0));
      expect(
        AppRouter.mealRepository.store.days[_dayKey]
            ?.itemsIn(MealSlot.lunch)
            .length,
        kSlotItemCap,
      );
    });
  });
}
