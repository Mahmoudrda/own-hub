// What O03 and O04 write and what survives a restart: the 60 minute, six day
// week, custom lengths from 10 to 180, the weekdays she chose, her level, and
// the "About you" numbers that never leave the phone.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/rewards/weekly_goal_service.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/features/onboarding/presentation/schedule_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

bool _selected(WidgetTester tester, String label) => tester
    .widget<AppChip>(
      find.ancestor(of: find.text(label), matching: find.byType(AppChip)),
    )
    .selected;

Future<void> _roundTrip() async {
  final document = jsonEncode(AppSnapshot.capture());
  await const ThisPhoneWipe().clearPersistence();
  AppRouter.intakeRepository.reset();
  BodyDataStore.instance.reset();
  AppSnapshot.restore(document);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
    AppRouter.intakeRepository.reset();
    BodyDataStore.instance.reset();
  });

  group('spec edge case 1, the onboarding half: 60 minutes and 6 days', () {
    testWidgets('she taps them on O03 and both are written', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = InMemoryIntakeRepository();
      await tester.pumpWidget(_host(ScheduleView(repository: repository)));
      await tester.pumpAndSettle();

      // Six days is a custom schedule now; the chips are the three splits.
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 min'));
      await tester.pumpAndSettle();
      // Five days and an hour a session do not raise the level: a woman who
      // has not picked one stays on Beginner.
      expect(_selected(tester, 'Beginner'), isTrue);
      expect(_selected(tester, 'Advanced'), isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final intake = repository.read();
      expect(intake.days, 5);
      expect(intake.minutes, 60);
      expect(intake.minutesCustom, isFalse);
      expect(intake.level, TrainingLevel.beginner);
      // So the plan is the beginner tier of the five-day split.
      expect(
        rankStartingPrograms(
          intake,
          null,
          tier: ViewedTier.of(intake),
        ).first.programId,
        'split_5day',
      );
    });

    test(
      'they survive a restart, reach the weekly goal and the cloud',
      () async {
        await AppRouter.intakeRepository.merge(days: 6, minutes: 60);
        AppRouter.intakeRepository.markSetupDone();

        await _roundTrip();
        final intake = AppRouter.intakeRepository.read();
        expect(intake.days, 6);
        expect(intake.minutes, 60);

        OnboardingState.instance.finish();
        expect(AppRouter.progressStore.goal.sessionsTarget, 6);

        final root = CloudDocuments.capture().firstWhere((d) => d.isRoot);
        final profile = root.data['profile']! as Map<String, Object?>;
        expect(profile['days'], 6);
        expect(profile['minutes'], 60);
      },
    );
  });

  group('custom minutes run from 10 to 180', () {
    test('10 and 180 are accepted, 9 and 181 are not', () {
      expect(const Intake(minutes: 10).minutes, 10);
      expect(const Intake(minutes: 180).minutes, 180);
      expect(Intake.minutesOk(10), isTrue);
      expect(Intake.minutesOk(180), isTrue);
      expect(Intake.minutesOk(9), isFalse);
      expect(Intake.minutesOk(181), isFalse);
      expect(() => Intake(minutes: int.parse('9')), throwsAssertionError);
      expect(() => Intake(minutes: int.parse('181')), throwsAssertionError);
    });

    test('the weekly goal runs from 1 to 7', () {
      expect(const Intake(days: 1).days, 1);
      expect(const Intake(days: 7).days, 7);
      expect(() => Intake(days: int.parse('0')), throwsAssertionError);
      expect(() => Intake(days: int.parse('8')), throwsAssertionError);
      expect(kMinSessionsTarget, 1);
      expect(kMaxSessionsTarget, 7);
    });

    test('a document outside the range falls back to the defaults', () async {
      final whole =
          jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
      whole['intake'] = <String, Object?>{'days': 8, 'minutes': 181};
      AppSnapshot.restore(jsonEncode(whole));
      expect(AppRouter.intakeRepository.read().days, Intake.defaults.days);
      expect(
        AppRouter.intakeRepository.read().minutes,
        Intake.defaults.minutes,
      );
    });

    testWidgets('the stepper stops at both ends and the length is written', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = InMemoryIntakeRepository(const Intake(minutes: 10));
      await tester.pumpWidget(_host(ScheduleView(repository: repository)));
      await tester.pumpAndSettle();

      // 10 is not a preset, so she opens on Custom.
      expect(_selected(tester, 'Custom'), isTrue);
      expect(find.text('10 min'), findsOneWidget);
      final less = find.byKey(const ValueKey('o03-minutes-less'));
      final more = find.byKey(const ValueKey('o03-minutes-more'));
      expect(tester.widget<IconButton>(less).onPressed, isNull);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('o03-minutes-value')), findsOneWidget);
      expect(find.text('15 min'), findsWidgets);

      final slider = find.byKey(const ValueKey('o03-minutes-slider'));
      tester.widget<Slider>(slider).onChanged!(180);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(more).onPressed, isNull);
      tester.widget<Slider>(slider).onChanged!(9);
      await tester.pumpAndSettle();
      expect(find.text('10 min'), findsWidgets);

      tester.widget<Slider>(slider).onChanged!(180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(repository.read().minutes, 180);
      expect(repository.read().minutesCustom, isTrue);
    });
  });

  group('the weekdays she chooses', () {
    testWidgets('the custom schedule writes the days and the goal follows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = InMemoryIntakeRepository();
      await tester.pumpWidget(_host(ScheduleView(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom schedule'));
      await tester.pumpAndSettle();
      // Three days preselected, spread through the week, Saturday first.
      expect(find.text('3 training · 4 recovery'), findsOneWidget);
      for (final d in Intake.spreadWeekdays(3)) {
        final pill = find.byKey(ValueKey('o03-weekday-$d'));
        expect(tester.widget<AppChip>(pill).selected, isTrue);
      }
      // Saturday is the first pill.
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('o03-weekday-6')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('o03-weekday-7')),
      );
      expect(first.dx, lessThan(second.dx));

      for (final d in [6, 7, 1, 2, 3, 4, 5]) {
        final pill = find.byKey(ValueKey('o03-weekday-$d'));
        if (tester.widget<AppChip>(pill).selected) await tester.tap(pill);
        await tester.pumpAndSettle();
      }
      // The last training day cannot be switched off: a goal of none is not one.
      expect(find.text('1 training · 6 recovery'), findsOneWidget);

      for (final d in [1, 4]) {
        final pill = find.byKey(ValueKey('o03-weekday-$d'));
        if (!tester.widget<AppChip>(pill).selected) await tester.tap(pill);
        await tester.pumpAndSettle();
      }
      for (final d in [6, 7, 2, 3, 5]) {
        final pill = find.byKey(ValueKey('o03-weekday-$d'));
        if (tester.widget<AppChip>(pill).selected) await tester.tap(pill);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.read().weekdays.length, repository.read().days);
      expect(repository.read().days, 2);
    });

    test('weekdays, level and custom length round-trip the snapshot', () async {
      await AppRouter.intakeRepository.merge(
        days: 3,
        minutes: 95,
        minutesCustom: true,
        level: TrainingLevel.intermediate,
        weekdays: const {6, 1, 3},
      );
      await _roundTrip();
      final intake = AppRouter.intakeRepository.read();
      expect(intake.weekdays, {6, 1, 3});
      expect(intake.level, TrainingLevel.intermediate);
      expect(intake.minutes, 95);
      expect(intake.minutesCustom, isTrue);
    });

    test('and the cloud profile, which old profiles still read', () async {
      await AppRouter.intakeRepository.merge(
        days: 3,
        level: TrainingLevel.advanced,
        weekdays: const {6, 1, 3},
      );
      AppRouter.intakeRepository.markSetupDone();
      final root = CloudDocuments.capture().firstWhere((d) => d.isRoot);
      final profile = root.data['profile']! as Map<String, Object?>;
      expect(profile['weekdays'], [1, 3, 6]);
      expect(profile['level'], 'advanced');
      expect(profile['minutesCustom'], false);

      AppRouter.intakeRepository.reset();
      CloudDocuments.mergeIn([
        CloudDoc(
          collection: '',
          id: '',
          data: <String, Object?>{'profile': profile},
        ),
      ]);
      expect(AppRouter.intakeRepository.read().weekdays, {1, 3, 6});
      expect(AppRouter.intakeRepository.read().level, TrainingLevel.advanced);

      // A profile written before any of this existed.
      AppRouter.intakeRepository.reset();
      CloudDocuments.mergeIn([
        const CloudDoc(
          collection: '',
          id: '',
          data: <String, Object?>{
            'profile': <String, Object?>{
              'days': 5,
              'minutes': 30,
              'setupDone': true,
            },
          },
        ),
      ]);
      final old = AppRouter.intakeRepository.read();
      expect(old.weekdays, isEmpty);
      expect(
        old.level,
        TrainingLevel.beginner,
        reason: 'days and minutes never raise the level',
      );
      expect(old.minutesCustom, isFalse);
    });

    test('days and minutes never raise the level, only her pick does', () {
      expect(TrainingLevel.defaultLevel, TrainingLevel.beginner);
      for (final days in [2, 4, 5, 7]) {
        for (final minutes in [20, 45, 60, 90]) {
          expect(
            Intake(days: days, minutes: minutes).level,
            TrainingLevel.beginner,
            reason: '$days days, $minutes minutes',
          );
        }
      }
    });
  });

  group('About you stays on the phone', () {
    testWidgets('O04 saves the three numbers and Skip clears them', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = BodyDataStore();
      await tester.pumpWidget(
        _host(
          LifeStageView(
            repository: InMemoryIntakeRepository(),
            bodyData: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('about-you-weight')),
        '62.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('about-you-height')),
        '165',
      );
      await tester.enterText(find.byKey(const ValueKey('about-you-age')), '29');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(store.read().weightKg, 62.5);
      expect(store.read().heightCm, 165);
      expect(store.read().ageYears, 29);

      await tester.tap(find.text('Skip this'));
      await tester.pumpAndSettle();
      expect(store.read().isEmpty, isTrue);
    });

    testWidgets('a number out of range keeps her on the screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = BodyDataStore();
      var continued = 0;
      await tester.pumpWidget(
        _host(
          LifeStageView(
            repository: InMemoryIntakeRepository(),
            bodyData: store,
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('about-you-weight')),
        '12',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, 0);
      expect(find.text('Between 30 and 250 kg'), findsOneWidget);
      expect(store.read().isEmpty, isTrue);
    });

    test('it is in the snapshot and in no cloud document', () async {
      BodyDataStore.instance.write(
        const BodyData(weightKg: 61.5, heightCm: 168, ageYears: 31),
      );
      await _roundTrip();
      final body = BodyDataStore.instance.read();
      expect(body.weightKg, 61.5);
      expect(body.heightCm, 168);
      expect(body.ageYears, 31);

      final wire = [for (final d in CloudDocuments.capture()) d.data]
          .toString();
      for (final key in ['weightKg', 'heightCm', 'ageYears', 'dateOfBirth']) {
        expect(wire, isNot(contains(key)), reason: key);
      }
      expect(wire, isNot(contains('61.5')));
    });

    test('values outside what a body can be read as absent', () {
      const mad = BodyData(weightKg: 5, heightCm: 400, ageYears: 3);
      expect(mad.sanitised().isEmpty, isTrue);
      expect(
        const BodyData(weightKg: 60, heightCm: 160, ageYears: 30).isComplete,
        isTrue,
      );
    });
  });
}
