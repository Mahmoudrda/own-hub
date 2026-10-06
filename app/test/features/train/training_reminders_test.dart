// R1-P19: a reason to come back that she chose herself.
//
// Training reminders are offered once, on R10, after a session she finished.
// She picks her days (her week's count, spread, preselected) and a time;
// permission is asked only when she taps "Remind me", and her days are kept
// only once the phone agreed. A refusal is answered on the sheet with the way
// to Settings. "Not now" is an answer: the offer is not made again, and A01
// keeps the way in, where she can change them or turn them off. The text is
// the same every time and counts nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/reminder_scheduler.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/features/train/presentation/reminder_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

class _Fake implements ReminderScheduler {
  _Fake(this.permission);

  ReminderPermission permission;
  int asked = 0;
  final List<(TrainingReminders, ReminderText)> scheduled = [];
  int cancelled = 0;

  @override
  Future<ReminderPermission> requestPermission() async {
    asked++;
    return permission;
  }

  @override
  Future<void> schedule(TrainingReminders reminders, ReminderText text) async =>
      scheduled.add((reminders, text));

  @override
  Future<void> cancel() async => cancelled++;
}

Future<void> _open(
  WidgetTester tester,
  String id, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('$id-$locale'),
      locale: locale,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: appRoutes[id]!.name,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

final _offer = find.byKey(const ValueKey('r10-reminder-offer'));
final _choose = find.byKey(const ValueKey('r10-reminder-choose'));
final _notNow = find.byKey(const ValueKey('r10-reminder-not-now'));
final _save = find.byKey(const ValueKey('reminder-save'));
final _off = find.byKey(const ValueKey('reminder-off'));
final _a01Row = find.byKey(const ValueKey('a01-reminders'));

Finder _day(int weekday) => find.byKey(ValueKey('reminder-day-$weekday'));

void main() {
  final savedFlags = AppRouter.featureFlags;
  late _Fake fake;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    ReminderState.instance.reset();
    fake = _Fake(ReminderPermission.granted);
    AppRouter.reminderScheduler = fake;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    ReminderState.instance.reset();
    AppRouter.reminderScheduler = null;
  });

  group('the days and the time', () {
    test('her week count is offered, spread, Saturday first', () {
      expect(suggestedReminderDays(2), {DateTime.sunday, DateTime.wednesday});
      expect(suggestedReminderDays(3), {
        DateTime.sunday,
        DateTime.tuesday,
        DateTime.thursday,
      });
      expect(suggestedReminderDays(4), hasLength(4));
      for (final n in [2, 3, 4]) {
        expect(suggestedReminderDays(n), hasLength(n));
      }
      expect(
        TrainingReminders(
          weekdays: {DateTime.thursday, DateTime.saturday},
        ).orderedWeekdays,
        [DateTime.saturday, DateTime.thursday],
      );
    });

    test('the next reminder is later today, or that day next week', () {
      // Tuesday 6 October 2026, 17:00.
      final tuesday = DateTime(2026, 10, 6, 17);
      expect(
        nextReminderAt(tuesday, weekday: DateTime.tuesday, hour: 18, minute: 0),
        DateTime(2026, 10, 6, 18),
      );
      expect(
        nextReminderAt(tuesday, weekday: DateTime.tuesday, hour: 9, minute: 30),
        DateTime(2026, 10, 13, 9, 30),
      );
      expect(
        nextReminderAt(tuesday, weekday: DateTime.saturday, hour: 18, minute: 0),
        DateTime(2026, 10, 10, 18),
      );
    });

    test('a broken saved schedule is no schedule', () {
      final kept = TrainingReminders(
        weekdays: {DateTime.sunday},
        hour: 7,
        minute: 15,
      );
      expect(TrainingReminders.fromJson(kept.toJson()), kept);
      expect(TrainingReminders.fromJson({'weekdays': [], 'hour': 7, 'minute': 0}),
          isNull);
      expect(
        TrainingReminders.fromJson({'weekdays': [9], 'hour': 7, 'minute': 0}),
        isNull,
      );
      expect(
        TrainingReminders.fromJson({'weekdays': [1], 'hour': 25, 'minute': 0}),
        isNull,
      );
      expect(TrainingReminders.fromJson('nonsense'), isNull);
    });

    test('they survive a restart and go with her account', () {
      ReminderState.instance
        ..offered = true
        ..schedule = TrainingReminders(
          weekdays: {DateTime.monday, DateTime.friday},
          hour: 20,
        );
      final saved = jsonEncode(AppSnapshot.capture());
      ReminderState.instance.reset();
      AppSnapshot.restore(saved);
      expect(ReminderState.instance.offered, isTrue);
      expect(
        ReminderState.instance.schedule,
        TrainingReminders(weekdays: {DateTime.monday, DateTime.friday}, hour: 20),
      );
    });
  });

  group('R10', () {
    testWidgets('offers them once, and asks for nothing until she taps', (
      tester,
    ) async {
      await _open(tester, 'R10');
      expect(_offer, findsOneWidget);
      expect(fake.asked, 0);
      expect(find.text('A reminder on your training days?'), findsOneWidget);
    });

    testWidgets('"Not now" is an answer: the offer is not made again', (
      tester,
    ) async {
      await _open(tester, 'R10');
      await _tap(tester, _notNow);
      expect(_offer, findsNothing);
      expect(ReminderState.instance.offered, isTrue);
      expect(ReminderState.instance.schedule, isNull);
      expect(fake.asked, 0);

      await _open(tester, 'R10');
      expect(_offer, findsNothing);
    });

    testWidgets('her days, preselected from her week, are set once allowed', (
      tester,
    ) async {
      await _open(tester, 'R10');
      await _tap(tester, _choose);

      final target = AppRouter.todayRepository.day.week.sessionsTarget;
      final suggested = suggestedReminderDays(target);
      expect(find.text('Training reminders'), findsOneWidget);
      expect(
        find.text(
          'Sessions in your week: $target. Pick the days that suit you.',
        ),
        findsOneWidget,
      );
      for (final day in egyptianWeekOrder) {
        final chip = tester.widget<Semantics>(
          find
              .descendant(of: _day(day), matching: find.byType(Semantics))
              .first,
        );
        expect(chip.properties.selected, suggested.contains(day), reason: '$day');
      }

      // She moves one day.
      final dropped = suggested.first;
      final added = egyptianWeekOrder.firstWhere((d) => !suggested.contains(d));
      await _tap(tester, _day(dropped));
      await _tap(tester, _day(added));
      await _tap(tester, _save);

      expect(fake.asked, 1);
      expect(fake.scheduled, hasLength(1));
      final (reminders, text) = fake.scheduled.single;
      expect(reminders.weekdays, {...suggested}..remove(dropped)..add(added));
      expect(reminders.hour, TrainingReminders.defaultHour);
      expect(text.body, 'Your session is ready when you are.');
      expect(ReminderState.instance.schedule, reminders);
      expect(find.byType(ReminderSheet), findsNothing);
      expect(_offer, findsNothing);
      expect(find.text('Reminders are on.'), findsOneWidget);
    });

    testWidgets('no day, no reminder', (tester) async {
      await _open(tester, 'R10');
      await _tap(tester, _choose);
      for (final day in suggestedReminderDays(
        AppRouter.todayRepository.day.week.sessionsTarget,
      )) {
        await _tap(tester, _day(day));
      }
      expect(find.text('Pick at least one day.'), findsOneWidget);
      await _tap(tester, _save);
      expect(fake.asked, 0);
      expect(fake.scheduled, isEmpty);
    });

    testWidgets('refused, nothing is kept and Settings is offered', (
      tester,
    ) async {
      fake.permission = ReminderPermission.denied;
      await _open(tester, 'R10');
      await _tap(tester, _choose);
      await _tap(tester, _save);

      expect(fake.asked, 1);
      expect(fake.scheduled, isEmpty);
      expect(ReminderState.instance.schedule, isNull);
      expect(find.byType(ReminderSheet), findsOneWidget);
      expect(
        find.text(
          'Notifications are off for Own Hub on this phone. You can turn them '
          'on in Settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('a phone that cannot show them says so', (tester) async {
      fake.permission = ReminderPermission.unavailable;
      await _open(tester, 'R10');
      await _tap(tester, _choose);
      await _tap(tester, _save);
      expect(find.text('Reminders cannot be set on this phone.'), findsOneWidget);
      expect(ReminderState.instance.schedule, isNull);
    });

    testWidgets('the sheet reads in Arabic', (tester) async {
      await _open(tester, 'R10', locale: const Locale('ar'));
      expect(find.text('هل تريدين تذكيرًا في أيام تمرينكِ؟'), findsOneWidget);
      await _tap(tester, _choose);
      expect(find.text('تذكيرات التمرين'), findsOneWidget);
      expect(find.text('تفعيل التذكير'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A01', () {
    testWidgets('says whether they are on, and opens the same sheet', (
      tester,
    ) async {
      await _open(tester, 'A01');
      expect(_a01Row, findsOneWidget);
      expect(find.text('Reminders are off.'), findsOneWidget);
      await _tap(tester, _a01Row);
      expect(find.byType(ReminderSheet), findsOneWidget);
      // Off, so there is nothing to turn off.
      expect(_off, findsNothing);
    });

    testWidgets('she can change her days or turn them off', (tester) async {
      ReminderState.instance
        ..offered = true
        ..schedule = TrainingReminders(
          weekdays: {DateTime.saturday},
          hour: 7,
        );
      await _open(tester, 'A01');
      expect(find.text('Reminders are on.'), findsOneWidget);
      await _tap(tester, _a01Row);

      // Her own days, not the suggestion.
      final saturday = tester.widget<Semantics>(
        find
            .descendant(
              of: _day(DateTime.saturday),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(saturday.properties.selected, isTrue);

      await _tap(tester, _off);
      expect(fake.cancelled, 1);
      expect(ReminderState.instance.schedule, isNull);
      expect(find.text('Reminders are off.'), findsWidgets);
    });

    testWidgets('no Train, no reminders row', (tester) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_(<Feature, bool>{
        Feature.train: false,
      });
      await _open(tester, 'A01');
      expect(_a01Row, findsNothing);
    });
  });

  test('the words count nothing and name nothing', () {
    final en = lookupAppL10n(const Locale('en'));
    final ar = lookupAppL10n(const Locale('ar'));
    for (final l10n in [en, ar]) {
      final text = AppRouter.reminderText(l10n);
      expect(text.title, 'Own Hub');
      expect(text.body, isNot(matches(RegExp(r'[0-9٠-٩]'))));
      expect(text.body.toLowerCase(), isNot(contains('streak')));
      expect(text.body.toLowerCase(), isNot(contains('miss')));
    }
    expect(AppRouter.reminderText(ar).body, 'جلستكِ جاهزة متى شئتِ.');
  });

  test('re-set at launch only when she has them', () async {
    final en = lookupAppL10n(const Locale('en'));
    await AppRouter.reapplyTrainingReminders(en);
    expect(fake.scheduled, isEmpty);
    ReminderState.instance.schedule = TrainingReminders(
      weekdays: {DateTime.sunday},
    );
    await AppRouter.reapplyTrainingReminders(en);
    expect(fake.scheduled, hasLength(1));
    expect(fake.asked, 0);
  });

  test('ids are a fixed block, one a weekday', () {
    expect(
      {for (var d = 1; d <= 7; d++) reminderNotificationId(d)},
      hasLength(7),
    );
  });
}
