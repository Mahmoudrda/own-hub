// The one place every local notification is decided.
//
// 2026-10-14 is a Wednesday.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';

final _wed10 = DateTime(2026, 10, 14, 10);

List<PlannedNotification> _plan({
  DateTime? now,
  bool permitted = true,
  TrainingReminders? reminders,
  // These tests are about "Trained today?" and the check-ins, so the friendly
  // nudges, which share their budget, are off unless a test asks for them
  // (casual_nudges_test.dart covers the shared budget).
  NotificationPrefs prefs = const NotificationPrefs(nudges: false),
  DateTime? lastActiveAt,
  DateTime? lastSessionAt,
}) => NotificationPlan.build(
  now: now ?? _wed10,
  permitted: permitted,
  reminders: reminders,
  prefs: prefs,
  lastActiveAt: lastActiveAt,
  lastSessionAt: lastSessionAt,
);

Iterable<PlannedNotification> _of(List<PlannedNotification> p, PlanKind k) =>
    p.where((n) => n.kind == k);

final _wedSun = TrainingReminders(
  weekdays: {DateTime.wednesday, DateTime.sunday},
);

void main() {
  group('nothing until the phone agreed', () {
    test('no permission, no plan, whatever else is set', () {
      expect(_plan(permitted: false, reminders: _wedSun), isEmpty);
      expect(
        NotificationPlan.rest(
          now: _wed10,
          deadline: _wed10.add(const Duration(seconds: 60)),
          permitted: false,
        ),
        isNull,
      );
    });
  });

  group('her days', () {
    test('weekly, one id a weekday, at her time', () {
      final weekly = _of(_plan(reminders: _wedSun), PlanKind.training).toList();
      expect(weekly, hasLength(2));
      expect(weekly.every((n) => n.weekly), isTrue);
      expect(
        {for (final n in weekly) n.id},
        {
          reminderNotificationId(DateTime.wednesday),
          reminderNotificationId(DateTime.sunday),
        },
      );
      expect(
        weekly.firstWhere((n) => n.id == 7103).at,
        DateTime(2026, 10, 14, 18),
      );
      expect(
        weekly.firstWhere((n) => n.id == 7107).at,
        DateTime(2026, 10, 18, 18),
      );
    });

    test('a time already gone today goes to next week', () {
      final evening = DateTime(2026, 10, 14, 19);
      final at = _of(
        _plan(now: evening, reminders: _wedSun),
        PlanKind.training,
      ).firstWhere((n) => n.id == 7103).at;
      expect(at, DateTime(2026, 10, 21, 18));
    });
  });

  group('quiet hours, 22:00 to 08:00', () {
    test('afterQuietHours moves only what falls inside', () {
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 21, 59)),
        DateTime(2026, 10, 14, 21, 59),
      );
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 22)),
        DateTime(2026, 10, 15, 8),
      );
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 23, 30)),
        DateTime(2026, 10, 15, 8),
      );
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 0, 5)),
        DateTime(2026, 10, 14, 8),
      );
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 7, 59)),
        DateTime(2026, 10, 14, 8),
      );
      expect(
        afterQuietHours(DateTime(2026, 10, 14, 8)),
        DateTime(2026, 10, 14, 8),
      );
    });

    test(
      'a weekly reminder at 22:30 moves to the next day, weekday and all',
      () {
        expect(quietWeeklySlot(DateTime.thursday, 22, 30), (
          weekday: DateTime.friday,
          hour: 8,
          minute: 0,
        ));
        expect(quietWeeklySlot(DateTime.sunday, 23, 0), (
          weekday: DateTime.monday,
          hour: 8,
          minute: 0,
        ));
        expect(quietWeeklySlot(DateTime.monday, 6, 30), (
          weekday: DateTime.monday,
          hour: 8,
          minute: 0,
        ));
        expect(quietWeeklySlot(DateTime.monday, 12, 0), (
          weekday: DateTime.monday,
          hour: 12,
          minute: 0,
        ));
      },
    );

    test('the plan never schedules inside them', () {
      final late = TrainingReminders(
        weekdays: {DateTime.thursday, DateTime.saturday},
        hour: 23,
      );
      final early = TrainingReminders(weekdays: {DateTime.monday}, hour: 6);
      for (final reminders in [late, early]) {
        for (final n in _plan(reminders: reminders)) {
          expect(
            n.at.hour >= 8 && n.at.hour < 22,
            isTrue,
            reason: '$n is in quiet hours',
          );
        }
      }
      final moved = _of(
        _plan(reminders: late),
        PlanKind.training,
      ).firstWhere((n) => n.id == reminderNotificationId(DateTime.thursday));
      // Asked for Thursday 23:00; it arrives Friday 08:00.
      expect(moved.at.weekday, DateTime.friday);
      expect(moved.at.hour, 8);
    });

    test('check-ins at her reminder time move out of them too', () {
      final plan = _plan(
        reminders: TrainingReminders(weekdays: {DateTime.sunday}, hour: 7),
      );
      for (final n in _of(plan, PlanKind.checkIn)) {
        expect(n.at.hour, 8);
      }
    });
  });

  group('"Trained today?"', () {
    test('21:00 on a reminder day', () {
      final n = _of(_plan(reminders: _wedSun), PlanKind.didYouTrain).single;
      expect(n.id, kDidYouTrainId);
      expect(n.at, DateTime(2026, 10, 14, 21));
      expect(n.weekly, isFalse);
    });

    test('not a reminder day: the next one', () {
      final thu = DateTime(2026, 10, 15, 10);
      final n = _of(
        _plan(now: thu, reminders: _wedSun),
        PlanKind.didYouTrain,
      ).single;
      expect(n.at, DateTime(2026, 10, 18, 21));
    });

    test('after 21:00 it is the next reminder day', () {
      final late = DateTime(2026, 10, 14, 21, 30);
      final n = _of(
        _plan(now: late, reminders: _wedSun),
        PlanKind.didYouTrain,
      ).single;
      expect(n.at, DateTime(2026, 10, 18, 21));
    });

    test('a session logged today cancels today and plans the next day', () {
      final n = _of(
        _plan(reminders: _wedSun, lastSessionAt: DateTime(2026, 10, 14, 9)),
        PlanKind.didYouTrain,
      ).single;
      expect(n.at, DateTime(2026, 10, 18, 21));
    });

    test('a session on another day changes nothing', () {
      final n = _of(
        _plan(reminders: _wedSun, lastSessionAt: DateTime(2026, 10, 13, 9)),
        PlanKind.didYouTrain,
      ).single;
      expect(n.at, DateTime(2026, 10, 14, 21));
    });

    test('exactly 60 minutes after the reminder is allowed', () {
      final n = _of(
        _plan(
          reminders: TrainingReminders(
            weekdays: {DateTime.wednesday},
            hour: 20,
          ),
        ),
        PlanKind.didYouTrain,
      ).single;
      expect(n.at, DateTime(2026, 10, 14, 21));
    });

    test('a reminder less than 60 minutes before it skips that day', () {
      final n = _of(
        _plan(
          reminders: TrainingReminders(
            weekdays: {DateTime.wednesday, DateTime.sunday},
            hour: 20,
            minute: 1,
          ),
        ),
        PlanKind.didYouTrain,
      );
      expect(n, isEmpty);
    });

    test('a late reminder never gets a 21:00 follow-up', () {
      final plan = _plan(
        reminders: TrainingReminders(weekdays: {DateTime.wednesday}, hour: 23),
      );
      expect(_of(plan, PlanKind.didYouTrain), isEmpty);
      for (final n in _of(plan, PlanKind.didYouTrain)) {
        expect(n.at.hour, lessThan(22));
      }
    });

    test('no days, none; its switch off, none', () {
      expect(_of(_plan(), PlanKind.didYouTrain), isEmpty);
      expect(
        _of(
          _plan(
            reminders: _wedSun,
            prefs: const NotificationPrefs(logNudge: false),
          ),
          PlanKind.didYouTrain,
        ),
        isEmpty,
      );
    });
  });

  group('gentle check-ins', () {
    test('four and ten days after she last opened the app, at 18:00', () {
      final plan = _plan(lastActiveAt: _wed10);
      final ins = _of(plan, PlanKind.checkIn).toList();
      expect(ins.map((n) => n.id), [kCheckInFirstId, kCheckInSecondId]);
      expect(ins[0].at, DateTime(2026, 10, 18, 18));
      expect(ins[1].at, DateTime(2026, 10, 24, 18));
    });

    test('at her reminder time when she has one', () {
      final plan = _plan(
        reminders: TrainingReminders(
          weekdays: {DateTime.tuesday},
          hour: 9,
          minute: 15,
        ),
        lastActiveAt: _wed10,
      );
      expect(
        _of(plan, PlanKind.checkIn).first.at,
        DateTime(2026, 10, 18, 9, 15),
      );
    });

    test('a check-in due on a reminder day moves on to the next day', () {
      final plan = _plan(
        reminders: TrainingReminders(
          weekdays: {DateTime.sunday},
          hour: 9,
          minute: 15,
        ),
        lastActiveAt: _wed10,
      );
      expect(_of(plan, PlanKind.checkIn).map((n) => n.at), [
        DateTime(2026, 10, 19, 9, 15),
        DateTime(2026, 10, 24, 9, 15),
      ]);
    });

    test('with nothing recorded, they count from now', () {
      final ins = _of(_plan(), PlanKind.checkIn).toList();
      expect(ins.first.at, DateTime(2026, 10, 18, 18));
    });

    test('every open or session pushes them out', () {
      final threeDaysAgo = _wed10.subtract(const Duration(days: 3));
      final before = _of(
        _plan(lastActiveAt: threeDaysAgo),
        PlanKind.checkIn,
      ).first.at;
      expect(before, DateTime(2026, 10, 15, 18));
      // She opens the app: the clock restarts.
      final afterOpen = _of(
        _plan(lastActiveAt: _wed10),
        PlanKind.checkIn,
      ).first.at;
      expect(afterOpen.isAfter(before), isTrue);
      // A session later than the last open counts the same way.
      final afterSession = _of(
        _plan(lastActiveAt: threeDaysAgo, lastSessionAt: _wed10),
        PlanKind.checkIn,
      ).first.at;
      expect(afterSession, afterOpen);
    });

    test('after the second, nothing more until she comes back', () {
      final fiveDays = _wed10.subtract(const Duration(days: 5));
      final onlySecond = _of(
        _plan(lastActiveAt: fiveDays),
        PlanKind.checkIn,
      ).toList();
      expect(onlySecond.map((n) => n.id), [kCheckInSecondId]);

      final elevenDays = _wed10.subtract(const Duration(days: 11));
      expect(_of(_plan(lastActiveAt: elevenDays), PlanKind.checkIn), isEmpty);
      // Weeks later, still nothing.
      final long = _wed10.subtract(const Duration(days: 90));
      expect(_of(_plan(lastActiveAt: long), PlanKind.checkIn), isEmpty);
    });

    test('the two carry different texts, both inside the set', () {
      for (var day = 0; day < 12; day++) {
        final seen = DateTime(2026, 10, 1 + day, 9);
        final ins = _of(
          _plan(now: seen, lastActiveAt: seen),
          PlanKind.checkIn,
        ).toList();
        expect(ins, hasLength(2));
        expect(ins[0].variant, isNot(ins[1].variant));
        for (final n in ins) {
          expect(n.variant, inInclusiveRange(0, kCheckInVariants - 1));
        }
      }
    });

    test('the text rotates from one absence to the next', () {
      final first = <int>{};
      for (var day = 0; day < kCheckInVariants; day++) {
        final seen = DateTime(2026, 10, 1 + day, 9);
        first.add(
          _of(
            _plan(now: seen, lastActiveAt: seen),
            PlanKind.checkIn,
          ).first.variant,
        );
      }
      expect(first, hasLength(kCheckInVariants));
    });

    test('the switch turns them off', () {
      expect(
        _of(
          _plan(prefs: const NotificationPrefs(checkIns: false)),
          PlanKind.checkIn,
        ),
        isEmpty,
      );
    });

    test('they need no reminders and read nothing about her training', () {
      final plan = _plan();
      expect(_of(plan, PlanKind.training), isEmpty);
      expect(_of(plan, PlanKind.checkIn), hasLength(2));
    });
  });

  group('the rest alert', () {
    final deadline = _wed10.add(const Duration(seconds: 45));

    test('one shot at the deadline', () {
      final n = NotificationPlan.rest(
        now: _wed10,
        deadline: deadline,
        permitted: true,
      )!;
      expect(n.id, kRestOverId);
      expect(n.kind, PlanKind.restOver);
      expect(n.at, deadline);
    });

    test('nothing for a rest already over, or with its switch off', () {
      expect(
        NotificationPlan.rest(
          now: deadline,
          deadline: deadline,
          permitted: true,
        ),
        isNull,
      );
      expect(
        NotificationPlan.rest(
          now: _wed10,
          deadline: deadline,
          permitted: true,
          prefs: const NotificationPrefs(restAlert: false),
        ),
        isNull,
      );
    });

    test('a timer in her hand is not a reminder: no quiet hours', () {
      final night = DateTime(2026, 10, 14, 23);
      final n = NotificationPlan.rest(
        now: night,
        deadline: night.add(const Duration(seconds: 60)),
        permitted: true,
      )!;
      expect(n.at, DateTime(2026, 10, 14, 23, 1));
    });
  });

  test('ids never overlap and the rest alert is not in the replaced set', () {
    final ids = <int>[...kPlannedIds, kRestOverId];
    expect(ids.toSet(), hasLength(ids.length));
    expect(kPlannedIds, isNot(contains(kRestOverId)));
    expect(kPlannedIds, containsAll([7101, 7107, 7121, 7131, 7132]));
  });
}
