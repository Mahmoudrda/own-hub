// A different woman signing in on the same phone must not see the last one's
// week.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/install_id.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/app_state/snapshot_owner.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/signup/domain/legal_acceptance.dart';
import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements SnapshotStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String snapshot) async => value = snapshot;
  @override
  Future<void> erase() async => value = null;
}

Future<void> _fillHer() async {
  await AppRouter.trainRepository.logRecalled(
    dateKey: '2026-09-01',
    method: RecallMethod.plan,
  );
  AppRouter.mealRepository.store.apply(
    MealWrite.transform(
      dayId: '2026-09-01',
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
  AppRouter.todayRepository.recordSession('session-1');
  await AppRouter.cycleRepository.completeSetup(
    mode: CycleMode.datesAndSymptoms,
    contextFlags: const {CycleContextFlag.irregular},
  );
  AppRouter.progressStore.rewards = const Rewards(
    points: 90,
    level: 2,
    sessionsLogged: 7,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStorage ownerStore;
  late _MemoryStorage snapshotStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
    ownerStore = _MemoryStorage();
    snapshotStore = _MemoryStorage();
    SnapshotOwner.instance.resetForTest();
    SnapshotOwner.instance.storage = ownerStore;
    LocalPersistence.instance.reset();
    LocalPersistence.instance.storage = snapshotStore;
    await AppRouter.localePreference.write(AppLanguage.english);
  });

  tearDown(() async {
    await const ThisPhoneWipe().clearPersistence();
    SnapshotOwner.instance.resetForTest();
    LocalPersistence.instance.reset();
    await AppRouter.localePreference.write(AppLanguage.english);
  });

  test('a different uid erases meals, training, cycle and rewards', () async {
    ownerStore.value = 'uid-a';
    await SnapshotOwner.instance.load();
    await _fillHer();
    expect(nothingOfHersRemains, isFalse);

    final erased = await SnapshotOwner.instance.claim('uid-b');

    expect(erased, isTrue);
    expect(AppRouter.trainRepository.sessions, isEmpty);
    expect(AppRouter.mealRepository.store.days, isEmpty);
    expect(AppRouter.progressStore.rewards.points, 0);
    expect(AppRouter.cycleRepository.current, isNull);
    expect(nothingOfHersRemains, isTrue);
    expect(ownerStore.value, 'uid-b');
    expect(SnapshotOwner.instance.owner, 'uid-b');
  });

  test('the erase is done before claim returns control to a waiter', () {
    ownerStore.value = 'uid-a';
    return SnapshotOwner.instance.load().then((_) async {
      await _fillHer();
      // Not awaited: the stores are already empty on the same turn.
      final pending = SnapshotOwner.instance.claim('uid-b');
      expect(nothingOfHersRemains, isTrue);
      await pending;
    });
  });

  test('the same uid keeps everything', () async {
    ownerStore.value = 'uid-a';
    await SnapshotOwner.instance.load();
    await _fillHer();

    final erased = await SnapshotOwner.instance.claim('uid-a');

    expect(erased, isFalse);
    expect(AppRouter.trainRepository.sessions, isNotEmpty);
    expect(AppRouter.mealRepository.store.days, isNotEmpty);
    expect(ownerStore.value, 'uid-a');
  });

  test('no stored owner adopts the uid without a wipe', () async {
    await SnapshotOwner.instance.load();
    await _fillHer();

    final erased = await SnapshotOwner.instance.claim('uid-a');

    expect(erased, isFalse);
    expect(AppRouter.trainRepository.sessions, isNotEmpty);
    expect(ownerStore.value, 'uid-a');
  });

  test('the language survives a change of owner, on the phone too', () async {
    ownerStore.value = 'uid-a';
    await SnapshotOwner.instance.load();
    await AppRouter.localePreference.write(AppLanguage.arabic);
    await _fillHer();

    await SnapshotOwner.instance.claim('uid-b');

    expect(AppRouter.localePreference.read(), AppLanguage.arabic);
    expect(snapshotStore.value, contains('"code":"ar"'));
    expect(snapshotStore.value, isNot(contains('koshari_bowl')));
  });

  test('the wipe runs before the restore exposes data', () async {
    ownerStore.value = 'uid-a';
    snapshotStore.value = null;
    await _fillHer();
    LocalPersistence.instance.storage = snapshotStore;
    LocalPersistence.instance.start();
    await LocalPersistence.instance.flush();
    final document = snapshotStore.value!;
    LocalPersistence.instance.stop();
    await const ThisPhoneWipe().clearPersistence();
    ownerStore.value = 'uid-a';
    snapshotStore.value = document;

    // Launch order: restore, load the owner, claim the signed-in uid, then
    // the first frame would draw.
    await LocalPersistence.instance.load();
    expect(AppRouter.mealRepository.store.days, isNotEmpty);
    await SnapshotOwner.instance.load();
    await SnapshotOwner.instance.claim('uid-b');

    expect(nothingOfHersRemains, isTrue);
    expect(snapshotStore.value, isNot(contains('koshari_bowl')));
  });

  group('what the woman signing in did on the way stays', () {
    /// The short "Your week" before she has an account: four days, twenty
    /// minutes, postpartum, then "Save my week and join".
    Future<void> buildWeekBeforeSignup() async {
      OnboardingState.instance.beforeSignup = true;
      await AppRouter.intakeRepository.merge(
        days: 4,
        minutes: 20,
        lifeStage: LifeStage.postpartum,
      );
      OnboardingState.instance.finish();
      OnboardingState.instance.beforeSignup = false;
    }

    tearDown(() {
      OnboardingState.instance
        ..beforeSignup = false
        ..weekBuiltSignedOut = false;
    });

    test(
      'her terms, her week and the install id stay; the last woman goes',
      () async {
        ownerStore.value = 'uid-a';
        await SnapshotOwner.instance.load();
        await _fillHer();
        await buildWeekBeforeSignup();
        // C06: written before the code is sent.
        await PendingLegalAcceptance.write(LegalAcceptance.now('ar'));
        final installId = await InstallId.read();

        final erased = await SnapshotOwner.instance.claim('uid-b');
        await Future<void>.delayed(Duration.zero);

        expect(erased, isTrue);
        // The previous woman's week is gone.
        expect(AppRouter.trainRepository.sessions, isEmpty);
        expect(AppRouter.mealRepository.store.days, isEmpty);
        expect(AppRouter.cycleRepository.current, isNull);
        expect(AppRouter.progressStore.rewards.points, 0);
        expect(AppRouter.progressStore.rewards.sessionsLogged, 0);
        // Hers stays, with the target her days set.
        final intake = AppRouter.intakeRepository.read();
        expect(intake.days, 4);
        expect(intake.minutes, 20);
        expect(intake.lifeStage, LifeStage.postpartum);
        expect(AppRouter.intakeRepository.setupDone, isTrue);
        expect(AppRouter.progressStore.goal.sessionsTarget, 4);
        expect(await PendingLegalAcceptance.read(), isNotNull);
        expect(await InstallId.read(), installId);
        expect(AppRouter.localePreference.read(), AppLanguage.english);
        // Claimed: the next change of account does not read it as hers.
        expect(OnboardingState.instance.weekBuiltSignedOut, isFalse);
        // And it is what the phone keeps.
        expect(snapshotStore.value, contains('postpartum'));
      },
    );

    test(
      'C07 records her acceptance, so she is not asked to agree again',
      () async {
        ownerStore.value = 'uid-a';
        await SnapshotOwner.instance.load();
        await PendingLegalAcceptance.write(LegalAcceptance.now('en'));

        // The sign-in event and C07's reconcile, in the order that lost it.
        unawaited(SnapshotOwner.instance.claim('uid-b'));
        final server = InMemoryLegalAcceptanceStore()..uid = 'uid-b';
        final status = await reconcileLegalAcceptance(
          store: server,
          uid: 'uid-b',
        );

        expect(status, LegalStatus.accepted);
        expect(server.recorded['uid-b'], isNotNull);
        expect(await server.hasCurrent('uid-b'), isTrue);
      },
    );

    test('answers left by the previous woman are not handed on', () async {
      ownerStore.value = 'uid-a';
      await SnapshotOwner.instance.load();
      // Hers, from her own setup after she had an account.
      await AppRouter.intakeRepository.merge(
        days: 2,
        lifeStage: LifeStage.pregnant,
      );
      OnboardingState.instance.finish();
      expect(OnboardingState.instance.weekBuiltSignedOut, isFalse);

      await SnapshotOwner.instance.claim('uid-b');

      expect(AppRouter.intakeRepository.read().lifeStage, LifeStage.none);
      expect(AppRouter.intakeRepository.setupDone, isFalse);
      expect(snapshotStore.value, isNot(contains('pregnant')));
    });
  });

  test('deleting the account forgets the owner too', () async {
    ownerStore.value = 'uid-a';
    await SnapshotOwner.instance.load();
    await const ThisPhoneWipe().clearPersistence();
    await Future<void>.delayed(Duration.zero);
    expect(SnapshotOwner.instance.owner, isNull);
    expect(ownerStore.value, isNull);
  });
}
