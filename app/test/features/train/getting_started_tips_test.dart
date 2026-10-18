// Getting started: seven tips over her first fortnight, only while she is
// not opening the app.
//
// 2026-10-14 is a Wednesday. She lands at 10:00 that day, so day one is the
// 15th.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/getting_started_tips.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';

final _landed = DateTime(2026, 10, 14, 10);
final _series = TipSeries(anchorAt: _landed);

({List<PlannedNotification> plan, TipSeries series}) _next({
  DateTime? now,
  TipSeries? series,
  TipFacts facts = const TipFacts(),
  DateTime? lastActiveAt,
  int hour = TrainingReminders.defaultHour,
  int minute = 0,
}) {
  final at = now ?? _landed;
  return TipPlan.next(
    now: at,
    series: series ?? _series,
    facts: facts,
    lastActiveAt: lastActiveAt ?? at,
    hour: hour,
    minute: minute,
  );
}

DateTime _day(int n, int hour, [int minute = 0]) =>
    DateTime(_landed.year, _landed.month, _landed.day + n, hour, minute);

Map<GettingStartedTip, DateTime> _times(List<PlannedNotification> plan) => {
  for (final item in plan) GettingStartedTip.of(item)!: item.at,
};

void main() {
  group('the schedule', () {
    test('seven tips, on days one, two, three, five, seven, ten and '
        'fourteen, at six in the evening', () {
      final result = _next();
      expect(result.plan, hasLength(kTipCount));
      expect(_times(result.plan), {
        GettingStartedTip.firstWorkout: _day(1, 18),
        GettingStartedTip.videos: _day(2, 18),
        GettingStartedTip.mealScan: _day(3, 18),
        GettingStartedTip.recipes: _day(5, 18),
        GettingStartedTip.firstGym: _day(7, 18),
        GettingStartedTip.muscles: _day(10, 18),
        GettingStartedTip.program: _day(14, 18),
      });
      expect(result.plan.every((n) => n.kind == PlanKind.tip), isTrue);
      expect(result.plan.every((n) => !n.weekly), isTrue);
    });

    test('at her reminder time when she has one', () {
      final result = _next(hour: 19, minute: 30);
      expect(result.plan.first.at, _day(1, 19, 30));
      expect(result.plan.last.at, _day(14, 19, 30));
    });

    test('never in quiet hours', () {
      // Late at night: the next morning at eight, so the day moves with it.
      final late = _next(hour: 23);
      expect(late.plan.first.at, _day(2, 8));
      // Early morning: eight that day.
      final early = _next(
        hour: 6,
        minute: 30,
        lastActiveAt: _landed.subtract(const Duration(hours: 12)),
      );
      expect(early.plan.first.at, _day(1, 8));
      for (final item in [...late.plan, ...early.plan]) {
        expect(
          item.at.hour,
          inInclusiveRange(kQuietToHour, kQuietFromHour - 1),
        );
      }
    });

    test('ids 7151 to 7157, all of them in what a plan replaces', () {
      expect(
        [for (final tip in GettingStartedTip.values) tip.id],
        [7151, 7152, 7153, 7154, 7155, 7156, 7157],
      );
      for (final tip in GettingStartedTip.values) {
        expect(kPlannedIds, contains(tip.id));
        expect([7121, 7131, 7132, 7141], isNot(contains(tip.id)));
        expect(tip.id, isNot(inInclusiveRange(7101, 7107)));
      }
    });

    test('in order, each at least a day after the one before', () {
      final plan = _next(now: _day(1, 17)).plan;
      for (var i = 1; i < plan.length; i++) {
        expect(
          plan[i].at.difference(plan[i - 1].at),
          greaterThanOrEqualTo(const Duration(hours: 23)),
        );
        expect(plan[i].variant, greaterThan(plan[i - 1].variant));
      }
    });

    test('no anchor, no series', () {
      final result = _next(series: const TipSeries());
      expect(result.plan, isEmpty);
      expect(result.series, const TipSeries());
    });
  });

  group('only when she is away', () {
    test('a tip due within a day of an open moves to a day after it, and the '
        'ones after keep their order', () {
      final open = _day(1, 17);
      final result = _next(now: open, lastActiveAt: open);
      final times = _times(result.plan);
      expect(times[GettingStartedTip.firstWorkout], _day(2, 17));
      expect(times[GettingStartedTip.videos], _day(3, 17));
      expect(times[GettingStartedTip.mealScan], _day(4, 17));
      // Far enough away already: untouched.
      expect(times[GettingStartedTip.recipes], _day(5, 18));
      expect(result.series.due, times);
    });

    test('nothing ever comes within a day of an open', () {
      final open = _day(3, 21, 45);
      final result = _next(now: open, lastActiveAt: open);
      for (final item in result.plan) {
        expect(
          item.at.difference(open),
          greaterThanOrEqualTo(kTipQuietAfterOpen),
        );
      }
    });

    test('a woman who opens the app every day is never sent one', () {
      // A little earlier each morning, so no open is a whole day after the
      // one before.
      DateTime openOn(int day) => _day(day, 9).subtract(Duration(minutes: day));
      var series = _series;
      for (var day = 0; day <= kTipSeriesDays + 1; day++) {
        final open = openOn(day);
        final result = _next(now: open, series: series, lastActiveAt: open);
        for (final item in result.plan) {
          expect(item.at.isAfter(openOn(day + 1)), isTrue, reason: '$item');
        }
        series = result.series;
      }
      expect(series.ended, isTrue);
    });

    test('and after the fortnight the series is over', () {
      final open = _day(kTipSeriesDays + 1, 9);
      final result = _next(now: open, lastActiveAt: open);
      expect(result.series.ended, isTrue);
      expect(result.series.due, isEmpty);
    });

    test('a tip whose time came while she was away is done, never sent '
        'again or late', () {
      final first = _next();
      // She opens on day one at eight in the evening: the first tip has
      // been shown.
      final open = _day(1, 20);
      final again = _next(now: open, series: first.series, lastActiveAt: open);
      expect(again.series.done, {GettingStartedTip.firstWorkout});
      expect(
        again.plan.map(GettingStartedTip.of),
        isNot(contains(GettingStartedTip.firstWorkout)),
      );
      expect(_times(again.plan)[GettingStartedTip.videos], _day(2, 20));
    });

    test(
      'a slot that passed before anything could be set is not sent late',
      () {
        // Allowed on day four: the first three are behind her.
        final open = _day(4, 12);
        final result = _next(now: open, lastActiveAt: open);
        expect(result.series.done, {
          GettingStartedTip.firstWorkout,
          GettingStartedTip.videos,
          GettingStartedTip.mealScan,
        });
        expect(result.plan.first.variant, GettingStartedTip.recipes.index);
      },
    );

    test('a tip moved past its own day still comes at the time it was '
        'moved to', () {
      final open = _day(1, 17);
      final moved = _next(now: open, lastActiveAt: open);
      // Reapplied a few hours later without a new open (a changed switch):
      // the first tip's day-one slot is behind, its moved time is not.
      final later = _day(1, 21);
      final again = _next(now: later, series: moved.series, lastActiveAt: open);
      expect(_times(again.plan)[GettingStartedTip.firstWorkout], _day(2, 17));
    });

    test('nothing is ever planned at or before now', () {
      var series = _series;
      for (final open in [_day(1, 17), _day(2, 23), _day(6, 7), _day(9, 22)]) {
        final result = _next(now: open, series: series, lastActiveAt: open);
        for (final item in result.plan) {
          expect(item.at.isAfter(open), isTrue, reason: '$item');
        }
        series = result.series;
      }
    });
  });

  group('skipped when she already did its thing', () {
    final cases = <GettingStartedTip, TipFacts>{
      GettingStartedTip.firstWorkout: const TipFacts(loggedASession: true),
      GettingStartedTip.videos: const TipFacts(openedVideos: true),
      GettingStartedTip.mealScan: const TipFacts(loggedAPhotoMeal: true),
      GettingStartedTip.recipes: const TipFacts(openedRecipes: true),
      GettingStartedTip.firstGym: const TipFacts(sawGymGuide: true),
      GettingStartedTip.muscles: const TipFacts(openedMuscles: true),
      GettingStartedTip.program: const TipFacts(openedProgram: true),
    };
    for (final MapEntry(key: tip, value: facts) in cases.entries) {
      test(tip.name, () {
        final result = _next(facts: facts);
        expect(result.plan.map(GettingStartedTip.of), isNot(contains(tip)));
        expect(result.plan, hasLength(kTipCount - 1));
        expect(result.series.done, {tip});
      });
    }

    test('the first-gym tip is not for a woman who trains at home only', () {
      final result = _next(facts: const TipFacts(trainsAtHomeOnly: true));
      expect(
        result.plan.map(GettingStartedTip.of),
        isNot(contains(GettingStartedTip.firstGym)),
      );
    });

    test('a skipped tip stays skipped', () {
      final skipped = _next(facts: const TipFacts(openedRecipes: true));
      final again = _next(now: _day(1, 9), series: skipped.series);
      expect(
        again.plan.map(GettingStartedTip.of),
        isNot(contains(GettingStartedTip.recipes)),
      );
    });

    test('everything done ends the series', () {
      final result = _next(
        facts: const TipFacts(
          loggedASession: true,
          openedVideos: true,
          loggedAPhotoMeal: true,
          openedRecipes: true,
          trainsAtHomeOnly: true,
          openedMuscles: true,
          openedProgram: true,
        ),
      );
      expect(result.plan, isEmpty);
      expect(result.series.ended, isTrue);
    });
  });

  group('over for good', () {
    test('after day fourteen nothing is planned and the series has ended', () {
      final result = _next(now: _day(kTipSeriesDays + 1, 9));
      expect(result.plan, isEmpty);
      expect(result.series.ended, isTrue);
    });

    test('a tip pushed past day fourteen is dropped, not sent late', () {
      final open = _day(14, 10);
      final result = _next(now: open, lastActiveAt: open);
      expect(result.plan, isEmpty);
      expect(result.series.ended, isTrue);
    });

    test('an ended series plans nothing, whatever else is true', () {
      final ended = TipSeries(anchorAt: _landed, ended: true);
      final result = _next(series: ended);
      expect(result.plan, isEmpty);
      expect(result.series, ended);
    });

    test('landing again does not move the anchor', () {
      expect(_series.anchoredAt(_day(3, 9)).anchorAt, _landed);
      expect(const TipSeries().anchoredAt(_landed).anchorAt, _landed);
    });
  });

  group('with the rest of the plan', () {
    test('the switch off drops every tip', () {
      final tips = _next().plan;
      final plan = NotificationPlan.build(
        now: _landed,
        permitted: true,
        prefs: const NotificationPrefs(tips: false),
        tips: tips,
      );
      expect(plan.where((n) => n.kind == PlanKind.tip), isEmpty);
    });

    test('no permission, no tips', () {
      expect(
        NotificationPlan.build(
          now: _landed,
          permitted: false,
          tips: _next().plan,
        ),
        isEmpty,
      );
    });

    test('a check-in on a tip day gives way: one note that day', () {
      // Away since she landed: the second check-in is day ten at 18:00, the
      // same moment as the muscles tip.
      final plan = NotificationPlan.build(
        now: _landed,
        permitted: true,
        lastActiveAt: _landed,
        tips: _next().plan,
      );
      final checkIns = plan.where((n) => n.kind == PlanKind.checkIn).toList();
      expect(checkIns.single.at, _day(4, 18));
      expect(plan.where((n) => n.kind == PlanKind.tip), hasLength(kTipCount));
    });
  });

  group('what a tap opens', () {
    test('each tip names the screen it talks about', () {
      expect(
        {for (final tip in GettingStartedTip.values) tip: tip.screen},
        {
          GettingStartedTip.firstWorkout: 'R03',
          GettingStartedTip.videos: 'R01',
          GettingStartedTip.mealScan: 'E12',
          GettingStartedTip.recipes: 'E05',
          GettingStartedTip.firstGym: kFirstGymTipPayload,
          GettingStartedTip.muscles: 'P06',
          GettingStartedTip.program: 'R02',
        },
      );
    });

    test('a planned tip says which tip it is; nothing else does', () {
      for (final item in _next().plan) {
        expect(GettingStartedTip.of(item)!.id, item.id);
      }
      expect(
        GettingStartedTip.of(
          PlannedNotification(
            id: kCheckInFirstId,
            kind: PlanKind.checkIn,
            at: _landed,
          ),
        ),
        isNull,
      );
    });
  });

  test('the series survives a restart', () {
    final open = _day(1, 20);
    final series = _next(now: open, series: _next().series).series;
    final restored = TipSeries.fromJson(
      jsonDecode(jsonEncode(series.toJson())),
    );
    expect(restored, series);
    expect(TipSeries.fromJson(null), const TipSeries());
    expect(TipSeries.fromJson({'due': 'nonsense'}), const TipSeries());
  });
}
