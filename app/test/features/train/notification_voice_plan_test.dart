// The two nudges that carry words from the voice bank: a fresh start after a
// chosen day went by, and a new best. 2026-10-14 is a Wednesday.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';

final _wednesday = DateTime(2026, 10, 14, 6);

List<PlannedNotification> _plan(
  DateTime now, {
  Set<int> days = const {DateTime.tuesday},
  DateTime? lastActiveAt,
  DateTime? lastSessionAt,
  bool freshStart = true,
  DateTime? lastBestAt,
  bool severeToday = false,
  NotificationPrefs prefs = const NotificationPrefs(),
}) => NotificationPlan.build(
  prefs: prefs,
  now: now,
  permitted: true,
  reminders: TrainingReminders(weekdays: days),
  lastActiveAt: lastActiveAt ?? DateTime(2026, 10, 12, 9),
  lastSessionAt: lastSessionAt,
  freshStart: freshStart,
  lastBestAt: lastBestAt,
  severeToday: severeToday,
);

List<PlannedNotification> _of(
  List<PlannedNotification> plan,
  NudgeContext context,
) => [
  for (final n in plan)
    if (n.kind == PlanKind.nudge && nudgeFromCode(n.variant).context == context)
      n,
];

DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

void main() {
  group('fresh start', () {
    test('comes the day after a chosen day with nothing logged', () {
      final got = _of(_plan(_wednesday), NudgeContext.freshStart);
      expect(got, hasLength(1));
      expect(_day(got.single.at), DateTime(2026, 10, 14));
      final minute = got.single.at.hour * 60 + got.single.at.minute;
      expect(minute, greaterThanOrEqualTo(NudgeContext.freshStart.fromMinute));
      expect(minute, lessThan(NudgeContext.freshStart.toMinute));
      expect(got.single.id, nudgeNotificationId(DateTime.wednesday));
    });

    test('not after a chosen day she trained on', () {
      final plan = _plan(_wednesday, lastSessionAt: DateTime(2026, 10, 13, 19));
      expect(_of(plan, NudgeContext.freshStart), isEmpty);
    });

    test('logging a session later removes it on the next plan', () {
      // Tuesday, a chosen day, no session yet: tomorrow carries one.
      final evening = _plan(DateTime(2026, 10, 13, 20));
      expect(_of(evening, NudgeContext.freshStart), hasLength(1));
      final logged = _plan(
        DateTime(2026, 10, 13, 22, 30),
        lastSessionAt: DateTime(2026, 10, 13, 22, 20),
      );
      expect(_of(logged, NudgeContext.freshStart), isEmpty);
    });

    test('not on a chosen day itself', () {
      // "Trained today?" would take the week's last place on Wednesday.
      final plan = _plan(
        _wednesday,
        days: {DateTime.tuesday, DateTime.wednesday},
        prefs: const NotificationPrefs(logNudge: false),
      );
      final days = _of(plan, NudgeContext.freshStart).map((n) => _day(n.at));
      expect(days, isNot(contains(DateTime(2026, 10, 14))));
      // Wednesday is a chosen day with no session yet: Thursday is the one.
      expect(days, [DateTime(2026, 10, 15)]);
    });

    test('is off unless the caller asks for it', () {
      expect(
        _of(_plan(_wednesday, freshStart: false), NudgeContext.freshStart),
        isEmpty,
      );
    });

    test('not on the day she opened the app', () {
      final plan = _plan(_wednesday, lastActiveAt: DateTime(2026, 10, 14, 5));
      expect(_of(plan, NudgeContext.freshStart), isEmpty);
    });

    test('not on a severe day, and nothing else midday either', () {
      final plan = _plan(_wednesday, severeToday: true);
      final today = DateTime(2026, 10, 14);
      expect(
        [
          for (final n in plan)
            if (n.kind == PlanKind.nudge && _day(n.at) == today) n,
        ],
        isEmpty,
        reason: '$plan',
      );
      // Tomorrow is not touched by today's check-in.
      final tomorrow = _plan(DateTime(2026, 10, 13, 20), severeToday: true);
      expect(_of(tomorrow, NudgeContext.freshStart), hasLength(1));
    });

    test('keeps quiet hours, one casual a day and four nudges a week', () {
      for (var d = 0; d < 28; d++) {
        for (final hour in [6, 12, 20]) {
          final now = DateTime(2026, 10, 1 + d, hour);
          final days = {DateTime.monday, DateTime.thursday};
          final plan = _plan(
            now,
            days: days,
            lastSessionAt: d.isEven ? null : DateTime(2026, 9, 30),
            lastBestAt: DateTime(2026, 10, d + 1),
          );
          final nudges = plan.where((n) => n.kind == PlanKind.nudge).toList();
          final perDay = <DateTime, int>{};
          final perWeek = <DateTime, int>{};
          for (final n in nudges) {
            expect(n.at.hour, greaterThanOrEqualTo(kQuietToHour));
            expect(n.at.hour, lessThan(kQuietFromHour));
            expect(days.contains(n.at.weekday), isFalse, reason: '$n');
            perDay[_day(n.at)] = (perDay[_day(n.at)] ?? 0) + 1;
            final saturday = DateTime(
              n.at.year,
              n.at.month,
              n.at.day -
                  (n.at.weekday - DateTime.saturday) % DateTime.daysPerWeek,
            );
            perWeek[saturday] = (perWeek[saturday] ?? 0) + 1;
          }
          expect(perDay.values.every((c) => c == 1), isTrue, reason: '$now');
          expect(
            perWeek.values.every((c) => c <= kNudgesPerWeek),
            isTrue,
            reason: '$now',
          );
        }
      }
    });
  });

  group('new best', () {
    test('comes the morning after a session with a best', () {
      final plan = _plan(
        _wednesday,
        days: {DateTime.monday},
        lastBestAt: DateTime(2026, 10, 13),
      );
      final got = _of(plan, NudgeContext.newBest);
      expect(got, hasLength(1));
      expect(_day(got.single.at), DateTime(2026, 10, 14));
      final minute = got.single.at.hour * 60 + got.single.at.minute;
      expect(minute, greaterThanOrEqualTo(NudgeContext.newBest.fromMinute));
      expect(minute, lessThan(NudgeContext.newBest.toMinute));
    });

    test('not for an old best, or none, or on a chosen day', () {
      expect(
        _of(
          _plan(_wednesday, lastBestAt: DateTime(2026, 10, 1)),
          NudgeContext.newBest,
        ),
        isEmpty,
      );
      expect(_of(_plan(_wednesday), NudgeContext.newBest), isEmpty);
      expect(
        _of(
          _plan(
            _wednesday,
            days: {DateTime.wednesday},
            lastBestAt: DateTime(2026, 10, 13),
          ),
          NudgeContext.newBest,
        ),
        isEmpty,
      );
    });
  });

  group('the codes', () {
    test('the old contexts keep their numbers and the new ones round-trip', () {
      expect(nudgeVariantCode(NudgeContext.morning, 1), 1);
      expect(nudgeVariantCode(NudgeContext.weekEnd, 3), 15);
      for (final context in NudgeContext.values) {
        final back = nudgeFromCode(nudgeVariantCode(context, 2));
        expect(back.context, context);
        expect(back.variant, 2);
      }
    });

    test('a tap on either opens Today', () {
      expect(nudgeScreen(nudgeVariantCode(NudgeContext.freshStart, 0)), 'T01');
      expect(nudgeScreen(nudgeVariantCode(NudgeContext.newBest, 0)), 'T01');
    });
  });
}
