// Which follow-up shows, and what the week review would change.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';

// 2026-10-23 is a Friday; her week started on Saturday 2026-10-17.
final DateTime _friday = DateTime(2026, 10, 23, 9);
final DateTime _wednesday = DateTime(2026, 10, 21, 9);
const String _week = '2026-10-17';

SessionRecap _session(String day) =>
    SessionRecap(dateKey: day, moves: 5, sets: 15);

const WeekReviewAnswer _answer = WeekReviewAnswer(
  felt: WeekFelt.good,
  fit: PlanFit.aboutRight,
  focus: WeekFocus.strength,
);

final List<({int protein, int target})> _lowFood = [
  for (var i = 0; i < 5; i++) (protein: i < 3 ? 60 : 110, target: 100),
];

FollowUpFacts _facts({
  DateTime? now,
  bool enabled = true,
  Set<FollowUpKind> muted = const {},
  Map<FollowUpKind, String> notBefore = const {},
  SessionRecap? lastSession,
  Map<String, Feel> feels = const {},
  Map<String, WeekReviewAnswer> weekReviews = const {},
  List<({int protein, int target})> lastLoggedDays = const [],
  ({String name, int proteinG})? proteinPick,
  bool protectedStage = false,
  bool severeToday = false,
  bool gentleToday = false,
}) => FollowUpFacts(
  now: now ?? _wednesday,
  enabled: enabled,
  muted: muted,
  notBefore: notBefore,
  lastSession: lastSession,
  feels: feels,
  weekStartKey: _week,
  sessionsThisWeek: 2,
  weekTarget: 3,
  setsThisWeek: 30,
  bestsThisWeek: 1,
  avgProteinThisWeek: 80,
  weekReviews: weekReviews,
  lastLoggedDays: lastLoggedDays,
  proteinPick: proteinPick,
  protectedStage: protectedStage,
  severeToday: severeToday,
  gentleToday: gentleToday,
);

const ({String name, int proteinG}) _pick = (name: 'Lentils', proteinG: 18);

final DateTime _today = DateTime(2026, 10, 18, 9);

void main() {
  group('week start', () {
    test('Saturday to Friday', () {
      expect(FollowUpPlan.weekStartKeyOf(DateTime(2026, 10, 17)), _week);
      expect(FollowUpPlan.weekStartKeyOf(DateTime(2026, 10, 23)), _week);
      expect(FollowUpPlan.weekStartKeyOf(DateTime(2026, 10, 24)), '2026-10-24');
    });
  });

  group('next', () {
    test('nothing to say gives null', () {
      expect(FollowUpPlan.next(_facts()), isNull);
    });

    test('the week review shows on Friday, with the week in numbers', () {
      final found = FollowUpPlan.next(_facts(now: _friday))!;
      expect(found.kind, FollowUpKind.weekReview);
      expect(found.weekStartKey, _week);
      expect(found.sessions, 2);
      expect(found.sets, 30);
      expect(found.bests, 1);
      expect(found.avgProtein, 80);
    });

    test('the week review never shows on another day', () {
      for (var day = 17; day <= 22; day++) {
        expect(FollowUpPlan.next(_facts(now: DateTime(2026, 10, day))), isNull);
      }
    });

    test('an answered week is not asked again', () {
      expect(
        FollowUpPlan.next(_facts(now: _friday, weekReviews: {_week: _answer})),
        isNull,
      );
    });

    test('after a session: one or two days later, unanswered', () {
      expect(
        FollowUpPlan.next(_facts(lastSession: _session('2026-10-21'))),
        isNull,
        reason: 'same day',
      );
      for (final day in ['2026-10-20', '2026-10-19']) {
        final found = FollowUpPlan.next(_facts(lastSession: _session(day)))!;
        expect(found.kind, FollowUpKind.afterSession);
        expect(found.session?.dateKey, day);
      }
      expect(
        FollowUpPlan.next(_facts(lastSession: _session('2026-10-18'))),
        isNull,
        reason: 'three days is too late to ask how it felt',
      );
    });

    test('an answered session is not asked about again', () {
      expect(
        FollowUpPlan.next(
          _facts(
            lastSession: _session('2026-10-20'),
            feels: {'2026-10-20': Feel.fresh},
          ),
        ),
        isNull,
      );
    });

    test('after a session carries the gentle flag from a hard day', () {
      final found = FollowUpPlan.next(
        _facts(lastSession: _session('2026-10-20'), gentleToday: true),
      )!;
      expect(found.gentle, isTrue);
      expect(
        FollowUpPlan.next(_facts(lastSession: _session('2026-10-20')))!.gentle,
        isFalse,
      );
    });

    test('come back after seven days away, with the count', () {
      expect(
        FollowUpPlan.next(_facts(lastSession: _session('2026-10-15'))),
        isNull,
        reason: 'six days',
      );
      final found = FollowUpPlan.next(
        _facts(lastSession: _session('2026-10-14')),
      )!;
      expect(found.kind, FollowUpKind.comeBack);
      expect(found.daysAway, 7);
    });

    test('come back needs a session to come back from', () {
      expect(FollowUpPlan.next(_facts()), isNull);
    });

    test('food: five logged days, three low, and a pick', () {
      final found = FollowUpPlan.next(
        _facts(lastLoggedDays: _lowFood, proteinPick: _pick),
      )!;
      expect(found.kind, FollowUpKind.food);
      expect(found.lowDays, 3);
      expect(found.pick?.name, 'Lentils');
    });

    test('food needs five days, three low and a pick', () {
      expect(
        FollowUpPlan.next(
          _facts(lastLoggedDays: _lowFood.take(4).toList(), proteinPick: _pick),
        ),
        isNull,
      );
      expect(
        FollowUpPlan.next(
          _facts(
            lastLoggedDays: [
              for (var i = 0; i < 5; i++)
                (protein: i < 2 ? 60 : 110, target: 100),
            ],
            proteinPick: _pick,
          ),
        ),
        isNull,
      );
      expect(FollowUpPlan.next(_facts(lastLoggedDays: _lowFood)), isNull);
    });

    test('the first kind in order wins', () {
      final all = _facts(
        now: _friday,
        lastSession: _session('2026-10-22'),
        lastLoggedDays: _lowFood,
        proteinPick: _pick,
      );
      expect(FollowUpPlan.next(all)!.kind, FollowUpKind.weekReview);
      expect(
        FollowUpPlan.next(
          _facts(
            now: _friday,
            muted: {FollowUpKind.weekReview},
            lastSession: _session('2026-10-22'),
            lastLoggedDays: _lowFood,
            proteinPick: _pick,
          ),
        )!.kind,
        FollowUpKind.afterSession,
      );
      expect(
        FollowUpPlan.next(
          _facts(
            now: _friday,
            muted: {FollowUpKind.weekReview, FollowUpKind.afterSession},
            lastSession: _session('2026-10-22'),
            lastLoggedDays: _lowFood,
            proteinPick: _pick,
          ),
        )!.kind,
        FollowUpKind.food,
      );
    });

    test('a muted kind never shows, and the next one still can', () {
      final found = FollowUpPlan.next(
        _facts(
          now: _friday,
          muted: {FollowUpKind.weekReview},
          lastSession: _session('2026-10-10'),
        ),
      )!;
      expect(found.kind, FollowUpKind.comeBack);
    });

    test('not before: hidden until that day, shown on it', () {
      final facts = _facts(
        now: _friday,
        notBefore: {FollowUpKind.weekReview: '2026-10-24'},
      );
      expect(FollowUpPlan.next(facts), isNull);
      expect(
        FollowUpPlan.next(
          _facts(
            now: _friday,
            notBefore: {FollowUpKind.weekReview: '2026-10-23'},
          ),
        )!.kind,
        FollowUpKind.weekReview,
      );
    });

    test('the master switch and a severe day show nothing', () {
      expect(FollowUpPlan.next(_facts(now: _friday, enabled: false)), isNull);
      expect(
        FollowUpPlan.next(_facts(now: _friday, severeToday: true)),
        isNull,
      );
    });

    test('a protected stage puts safety first on every kind', () {
      final facts = {
        FollowUpKind.weekReview: _facts(now: _friday, protectedStage: true),
        FollowUpKind.afterSession: _facts(
          lastSession: _session('2026-10-20'),
          protectedStage: true,
        ),
        FollowUpKind.comeBack: _facts(
          lastSession: _session('2026-10-10'),
          protectedStage: true,
        ),
        FollowUpKind.food: _facts(
          lastLoggedDays: _lowFood,
          proteinPick: _pick,
          protectedStage: true,
        ),
      };
      for (final entry in facts.entries) {
        final found = FollowUpPlan.next(entry.value)!;
        expect(found.kind, entry.key);
        expect(found.safetyFirst, isTrue, reason: entry.key.name);
      }
      expect(FollowUpPlan.next(_facts(now: _friday))!.safetyFirst, isFalse);
    });
  });

  group('suggest', () {
    WeekSuggestion suggest(
      PlanFit fit, {
      int days = 3,
      int minutes = 45,
      WeekFocus focus = WeekFocus.strength,
      TrainingGoal goal = TrainingGoal.stronger,
    }) => FollowUpPlan.suggest(
      WeekReviewAnswer(felt: WeekFelt.okay, fit: fit, focus: focus),
      days: days,
      minutes: minutes,
      goal: goal,
    );

    test('too much takes a day off', () {
      expect(suggest(PlanFit.tooMuch).days, 2);
      expect(suggest(PlanFit.tooMuch).minutes, isNull);
    });

    test('too much on one day shortens the session, to a floor of ten', () {
      expect(suggest(PlanFit.tooMuch, days: 1).days, isNull);
      expect(suggest(PlanFit.tooMuch, days: 1).minutes, 35);
      expect(suggest(PlanFit.tooMuch, days: 1, minutes: 15).minutes, 10);
      expect(suggest(PlanFit.tooMuch, days: 1, minutes: 10).isEmpty, isTrue);
    });

    test('too little adds a day', () {
      expect(suggest(PlanFit.tooLittle).days, 4);
    });

    test('too little on seven days lengthens the session, to a cap', () {
      expect(suggest(PlanFit.tooLittle, days: 7).days, isNull);
      expect(suggest(PlanFit.tooLittle, days: 7).minutes, 55);
      expect(suggest(PlanFit.tooLittle, days: 7, minutes: 175).minutes, 180);
      expect(suggest(PlanFit.tooLittle, days: 7, minutes: 180).isEmpty, isTrue);
    });

    test('about right changes no days or minutes', () {
      final found = suggest(PlanFit.aboutRight);
      expect(found.days, isNull);
      expect(found.minutes, isNull);
      expect(found.isEmpty, isTrue);
    });

    test('building muscle already is getting stronger', () {
      expect(
        suggest(PlanFit.aboutRight, goal: TrainingGoal.buildMuscle).goal,
        isNull,
      );
      expect(
        suggest(
          PlanFit.aboutRight,
          goal: TrainingGoal.buildMuscle,
          focus: WeekFocus.feelGood,
        ).goal,
        TrainingGoal.feelBetter,
      );
      expect(
        suggest(PlanFit.aboutRight, focus: WeekFocus.strength).goal,
        isNull,
      );
    });

    test('the goal only comes back when it differs from hers', () {
      expect(suggest(PlanFit.aboutRight).goal, isNull);
      expect(
        suggest(PlanFit.aboutRight, focus: WeekFocus.feelGood).goal,
        TrainingGoal.feelBetter,
      );
      expect(
        suggest(PlanFit.aboutRight, focus: WeekFocus.steadyLoss).goal,
        TrainingGoal.loseSteadily,
      );
      expect(
        suggest(
          PlanFit.aboutRight,
          focus: WeekFocus.feelGood,
          goal: TrainingGoal.feelBetter,
        ).goal,
        isNull,
      );
      expect(
        suggest(PlanFit.aboutRight, focus: WeekFocus.feelGood).isEmpty,
        isFalse,
      );
    });
  });

  group('holdsLoad', () {
    test('two very sore days running hold it', () {
      expect(
        FollowUpPlan.holdsLoad({
          '2026-10-10': Feel.verySore,
          '2026-10-13': Feel.verySore,
        }, now: _today),
        isTrue,
      );
    });

    test('one, or a fresh answer in between, does not', () {
      expect(
        FollowUpPlan.holdsLoad({'2026-10-10': Feel.verySore}, now: _today),
        isFalse,
      );
      expect(
        FollowUpPlan.holdsLoad({
          '2026-10-06': Feel.verySore,
          '2026-10-10': Feel.verySore,
          '2026-10-13': Feel.aBitSore,
        }, now: _today),
        isFalse,
      );
      expect(FollowUpPlan.holdsLoad(const {}, now: _today), isFalse);
    });

    test('only the two latest by day count, whatever the map order', () {
      expect(
        FollowUpPlan.holdsLoad({
          '2026-10-13': Feel.verySore,
          '2026-10-02': Feel.fresh,
          '2026-10-10': Feel.verySore,
        }, now: _today),
        isTrue,
      );
    });

    test('two very sore answers from three weeks ago do not hold it', () {
      expect(
        FollowUpPlan.holdsLoad({
          '2026-09-28': Feel.verySore,
          '2026-09-30': Feel.verySore,
        }, now: _today),
        isFalse,
      );
    });

    test('two very sore answers inside the last 14 days hold it', () {
      expect(
        FollowUpPlan.holdsLoad({
          '2026-10-07': Feel.verySore,
          '2026-10-14': Feel.verySore,
        }, now: _today),
        isTrue,
      );
    });

    test('an old answer does not pair with a fresh one', () {
      expect(
        FollowUpPlan.holdsLoad({
          '2026-09-28': Feel.verySore,
          '2026-10-14': Feel.verySore,
        }, now: _today),
        isFalse,
      );
    });
  });
}
