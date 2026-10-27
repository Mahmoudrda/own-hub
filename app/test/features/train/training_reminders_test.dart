// R1-P19: a reason to come back that she chose herself.
//
// Training reminders are offered once, on Home (T01) as one line, after a session she finished.
// She picks her days (her week's count, spread, preselected) and a time;
// permission is asked only when she taps "Remind me", and her days are kept
// only once the phone agreed. A refusal is answered on the sheet with the way
// to Settings. "Not now" is an answer: the offer is not made again, and A01
// keeps the way in, where she can change them or turn them off. The text is
// the same every time and counts nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_toggle.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/notification_sync.dart';
import 'package:own_hub/app_state/reminder_scheduler.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/notification_voice.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/features/train/presentation/reminder_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

class _Fake implements ReminderScheduler {
  _Fake(this.permission);

  ReminderPermission permission;
  int asked = 0;
  final List<(List<PlannedNotification>, ReminderText)> applied = [];
  final List<PlannedNotification> rests = [];
  int restCancelled = 0;
  int cancelled = 0;

  @override
  Future<ReminderPermission> requestPermission() async {
    asked++;
    return permission;
  }

  @override
  Future<void> apply(List<PlannedNotification> plan, ReminderText text) async =>
      applied.add((plan, text));

  @override
  Future<void> scheduleRest(
    PlannedNotification rest,
    ReminderText text,
  ) async => rests.add(rest);

  @override
  Future<void> cancelRest() async => restCancelled++;

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

final _offer = find.byKey(const ValueKey('today-reminder-offer'));
final _choose = _offer;
final _notNow = find.byKey(const ValueKey('today-reminder-not-now'));
final _save = find.byKey(const ValueKey('reminder-save'));
final _off = find.byKey(const ValueKey('reminder-off'));
final _a01Row = find.byKey(const ValueKey('a01-reminders'));
final _explainerYes = find.byKey(const ValueKey('explainer-yes'));
final _a01Toggle = find.descendant(
  of: _a01Row,
  matching: find.byType(AppToggle),
);

/// R10's "Choose my days": the soft explainer first, then the days sheet.
Future<void> _chooseDays(WidgetTester tester) async {
  await _tap(tester, _choose);
  await _tap(tester, _explainerYes);
}

Iterable<PlannedNotification> _weekly(List<PlannedNotification> plan) =>
    plan.where((p) => p.kind == PlanKind.training);

Finder _day(int weekday) => find.byKey(ValueKey('reminder-day-$weekday'));

void main() {
  final savedFlags = AppRouter.featureFlags;
  late _Fake fake;

  setUp(() {
    // The real bank loads on the first schedule and sets the plan again
    // with the real clock; these tests count the first plan only.
    NotificationSync.bank = NotificationVoice.empty;
    AppRouter.featureFlags = FeatureFlags.everything;
    ReminderState.instance.reset();
    // Home offers reminders after a session she finished: one is logged.
    AppRouter.todayRepository.reset(day: InMemoryTodayRepository.defaultDay());
    fake = _Fake(ReminderPermission.granted);
    AppRouter.reminderScheduler = fake;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.todayRepository.reset();
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
        TrainingReminders(weekdays: {DateTime.thursday, DateTime.saturday})
            .orderedWeekdays,
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
        nextReminderAt(
          tuesday,
          weekday: DateTime.saturday,
          hour: 18,
          minute: 0,
        ),
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
      expect(
        TrainingReminders.fromJson({'weekdays': [], 'hour': 7, 'minute': 0}),
        isNull,
      );
      expect(
        TrainingReminders.fromJson({
          'weekdays': [9],
          'hour': 7,
          'minute': 0,
        }),
        isNull,
      );
      expect(
        TrainingReminders.fromJson({
          'weekdays': [1],
          'hour': 25,
          'minute': 0,
        }),
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
        TrainingReminders(
          weekdays: {DateTime.monday, DateTime.friday},
          hour: 20,
        ),
      );
    });
  });

  group('Home reminder offer', () {
    testWidgets('offers them once, and asks for nothing until she taps', (
      tester,
    ) async {
      await _open(tester, 'T01');
      expect(_offer, findsOneWidget);
      expect(fake.asked, 0);
      expect(find.text('A reminder on your training days?'), findsOneWidget);
    });

    testWidgets('"Not now" is an answer: the offer is not made again', (
      tester,
    ) async {
      await _open(tester, 'T01');
      await _tap(tester, _notNow);
      expect(_offer, findsNothing);
      expect(ReminderState.instance.offered, isTrue);
      expect(ReminderState.instance.schedule, isNull);
      expect(fake.asked, 0);

      await _open(tester, 'T01');
      expect(_offer, findsNothing);
    });

    testWidgets('her days, preselected from her week, are set once allowed', (
      tester,
    ) async {
      await _open(tester, 'T01');
      await _chooseDays(tester);

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
        expect(
          chip.properties.selected,
          suggested.contains(day),
          reason: '$day',
        );
      }

      // She moves one day.
      final dropped = suggested.first;
      final added = egyptianWeekOrder.firstWhere((d) => !suggested.contains(d));
      await _tap(tester, _day(dropped));
      await _tap(tester, _day(added));
      await _tap(tester, _save);

      expect(fake.asked, 1);
      expect(fake.applied, hasLength(1));
      final (plan, text) = fake.applied.single;
      final reminders = ReminderState.instance.schedule!;
      expect(
        reminders.weekdays,
        {...suggested}
          ..remove(dropped)
          ..add(added),
      );
      expect(reminders.hour, TrainingReminders.defaultHour);
      expect({for (final p in _weekly(plan)) p.at.weekday}, reminders.weekdays);
      expect(text.body, 'Your session is ready when you are.');
      expect(ReminderState.instance.permissionGranted, isTrue);
      expect(find.byType(ReminderSheet), findsNothing);
      expect(_offer, findsNothing);
      expect(find.text('Reminders are on.'), findsOneWidget);
    });

    testWidgets('no day, no reminder', (tester) async {
      await _open(tester, 'T01');
      await _chooseDays(tester);
      for (final day in suggestedReminderDays(
        AppRouter.todayRepository.day.week.sessionsTarget,
      )) {
        await _tap(tester, _day(day));
      }
      expect(find.text('Pick at least one day.'), findsOneWidget);
      await _tap(tester, _save);
      expect(fake.asked, 0);
      expect(fake.applied, isEmpty);
    });

    testWidgets('refused, nothing is kept and Settings is offered', (
      tester,
    ) async {
      fake.permission = ReminderPermission.denied;
      await _open(tester, 'T01');
      await _chooseDays(tester);
      await _tap(tester, _save);

      expect(fake.asked, 1);
      expect(fake.applied, isEmpty);
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
      await _open(tester, 'T01');
      await _chooseDays(tester);
      await _tap(tester, _save);
      expect(
        find.text('Reminders can\'t be set on this phone.'),
        findsOneWidget,
      );
      expect(ReminderState.instance.schedule, isNull);
    });

    testWidgets('the sheet reads in Arabic', (tester) async {
      await _open(tester, 'T01', locale: const Locale('ar'));
      expect(find.text('عايزة تذكير في أيام تمرينك؟'), findsOneWidget);
      await _chooseDays(tester);
      expect(find.text('تذكيرات التمرين'), findsOneWidget);
      expect(find.text('فكّرني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A01', () {
    testWidgets('says whether they are on, and opens the same sheet', (
      tester,
    ) async {
      await _open(tester, 'A01');
      expect(_a01Row, findsOneWidget);
      expect(tester.widget<AppToggle>(_a01Toggle).value, isFalse);
      await _tap(tester, _a01Row);
      expect(
        find.byKey(const ValueKey('notification-explainer')),
        findsOneWidget,
      );
      await _tap(tester, _explainerYes);
      expect(find.byType(ReminderSheet), findsOneWidget);
      // Off, so there is nothing to turn off.
      expect(_off, findsNothing);
    });

    testWidgets('she can change her days or turn them off', (tester) async {
      ReminderState.instance
        ..offered = true
        ..schedule = TrainingReminders(weekdays: {DateTime.saturday}, hour: 7);
      await _open(tester, 'A01');
      expect(tester.widget<AppToggle>(_a01Toggle).value, isTrue);
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
      // Her days and "Trained today?" are gone; nothing else is touched.
      expect(_weekly(fake.applied.last.$1), isEmpty);
      expect(
        fake.applied.last.$1.where((p) => p.kind == PlanKind.didYouTrain),
        isEmpty,
      );
      expect(ReminderState.instance.schedule, isNull);
      expect(tester.widget<AppToggle>(_a01Toggle).value, isFalse);
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
    expect(AppRouter.reminderText(ar).body, 'تمرينك جاهز وقت ما تحبي.');
  });

  test('re-set at launch only when she has them', () async {
    final en = lookupAppL10n(const Locale('en'));
    await AppRouter.reapplyTrainingReminders(en);
    expect(fake.applied, isEmpty);
    ReminderState.instance.schedule = TrainingReminders(
      weekdays: {DateTime.sunday},
    );
    await AppRouter.reapplyTrainingReminders(en);
    expect(fake.applied, hasLength(1));
    expect(fake.asked, 0);
  });

  test('ids are a fixed block, one a weekday', () {
    expect({
      for (var d = 1; d <= 7; d++) reminderNotificationId(d),
    }, hasLength(7));
  });
}
