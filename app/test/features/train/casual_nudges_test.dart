// The friendly nudges and the one-casual-note-a-day rule.
//
// 2026-10-14 is a Wednesday.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/features/train/presentation/notification_explainer.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

const _casualKinds = {
  PlanKind.didYouTrain,
  PlanKind.checkIn,
  PlanKind.tip,
  PlanKind.nudge,
};

final _noPrefs = const NotificationPrefs();

List<PlannedNotification> _plan(
  DateTime now, {
  TrainingReminders? reminders,
  NotificationPrefs prefs = const NotificationPrefs(),
  DateTime? lastActiveAt,
  DateTime? lastSessionAt,
  List<PlannedNotification> tips = const <PlannedNotification>[],
}) => NotificationPlan.build(
  now: now,
  permitted: true,
  reminders: reminders,
  prefs: prefs,
  lastActiveAt: lastActiveAt,
  lastSessionAt: lastSessionAt,
  tips: tips,
);

Iterable<PlannedNotification> _nudges(List<PlannedNotification> plan) =>
    plan.where((n) => n.kind == PlanKind.nudge);

DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

/// The Saturday her week starts on.
DateTime _saturday(DateTime at) => DateTime(
  at.year,
  at.month,
  at.day - (at.weekday - DateTime.saturday) % DateTime.daysPerWeek,
);

List<PlannedNotification> _tipsEveryDay(DateTime from) => [
  for (var i = 0; i < 7; i++)
    PlannedNotification(
      id: tipNotificationId(i),
      kind: PlanKind.tip,
      at: DateTime(from.year, from.month, from.day + i, 12),
      variant: i,
    ),
];

final _scenarios = <TrainingReminders?>[
  null,
  TrainingReminders(weekdays: {DateTime.wednesday, DateTime.sunday}),
  TrainingReminders(weekdays: {DateTime.monday, DateTime.thursday}, hour: 7),
  TrainingReminders(
    weekdays: {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    },
  ),
];

void main() {
  group('quiet hours', () {
    test('the hard-coded hours equal the privacy settings defaults', () {
      expect(NotifySettings.initial.quietStart, kQuietFromHour * 60);
      expect(NotifySettings.initial.quietEnd, kQuietToHour * 60);
    });

    test('every nudge sits inside its window and outside quiet hours', () {
      for (var d = 0; d < 60; d++) {
        final now = DateTime(2026, 10, 1 + d, 6);
        for (final n in _nudges(_plan(now))) {
          final code = nudgeFromCode(n.variant);
          final minute = n.at.hour * 60 + n.at.minute;
          expect(minute, greaterThanOrEqualTo(code.context.fromMinute));
          expect(minute, lessThan(code.context.toMinute));
          expect(n.at.hour, greaterThanOrEqualTo(kQuietToHour));
          expect(n.at.hour, lessThan(kQuietFromHour));
        }
      }
    });
  });

  group('the rules hold in every combination', () {
    for (final reminders in _scenarios) {
      for (final withTips in [false, true]) {
        for (var d = 0; d < 21; d++) {
          for (final hour in [6, 12, 20]) {
            final now = DateTime(2026, 10, 12 + d, hour);
            final label =
                '${reminders?.weekdays.length ?? "none"} days, tips '
                '$withTips, $now';
            test('one casual a day, four a week, none on a training day, '
                'none after she was active: $label', () {
              final active = d.isEven ? now : null;
              final plan = _plan(
                now,
                reminders: reminders,
                lastActiveAt: active,
                lastSessionAt: d % 3 == 0
                    ? now.subtract(const Duration(days: 5))
                    : null,
                tips: withTips ? _tipsEveryDay(now) : const [],
              );
              final perDay = <DateTime, int>{};
              for (final n in plan.where(
                (n) => _casualKinds.contains(n.kind),
              )) {
                perDay[_day(n.at)] = (perDay[_day(n.at)] ?? 0) + 1;
              }
              expect(
                perDay.values.every((c) => c == 1),
                isTrue,
                reason: '$plan',
              );

              final perWeek = <DateTime, int>{};
              for (final n in _nudges(plan)) {
                perWeek[_saturday(n.at)] = (perWeek[_saturday(n.at)] ?? 0) + 1;
                expect(
                  reminders?.weekdays.contains(n.at.weekday) ?? false,
                  isFalse,
                  reason: 'nudge on a training day: $n',
                );
                if (active != null) {
                  expect(_day(n.at), isNot(_day(active)));
                }
              }
              expect(perWeek.values.every((c) => c <= kNudgesPerWeek), isTrue);
              expect(
                _nudges(plan).length,
                lessThanOrEqualTo(kNudgesUnanswered),
              );
              for (final n in plan) {
                expect(kPlannedIds, contains(n.id), reason: '$n');
              }
            });
          }
        }
      }
    }
  });

  group('one budget for every casual note', () {
    final reminderDays = TrainingReminders(
      weekdays: {DateTime.wednesday, DateTime.sunday},
    );

    List<PlannedNotification> casual(List<PlannedNotification> plan) =>
        plan.where((n) => _casualKinds.contains(n.kind)).toList();

    test('away for a fortnight: three casual notes in all, then none', () {
      final opened = DateTime(2026, 10, 1, 20);
      for (final reminders in _scenarios) {
        final delivered = <DateTime>{};
        for (var d = 0; d < 20; d++) {
          final now = DateTime(2026, 10, 2 + d, 7);
          // The tips are one series from the first day, the ones already due
          // gone from the list, as the tip plan hands them over.
          final series = _tipsEveryDay(DateTime(2026, 10, 2));
          final plan = NotificationPlan.build(
            now: now,
            permitted: true,
            reminders: reminders,
            lastActiveAt: opened,
            tips: [
              for (final tip in series)
                if (tip.at.isAfter(now)) tip,
            ],
            shownTips: [
              for (final tip in series)
                if (!tip.at.isAfter(now)) tip.at,
            ],
          );
          for (final n in casual(plan)) {
            if (n.at.isBefore(DateTime(2026, 10, 2 + d + 1))) {
              delivered.add(_day(n.at));
            }
          }
        }
        expect(
          delivered.length,
          lessThanOrEqualTo(kNudgesUnanswered),
          reason: '${reminders?.weekdays}: $delivered',
        );
      }
    });

    test('no week holds more than four casual notes', () {
      for (final reminders in _scenarios) {
        for (var d = 0; d < 21; d++) {
          final now = DateTime(2026, 10, 12 + d, 6);
          final plan = casual(
            _plan(
              now,
              reminders: reminders,
              lastActiveAt: now,
              tips: _tipsEveryDay(now),
            ),
          );
          final perWeek = <DateTime, int>{};
          for (final n in plan) {
            perWeek[_saturday(n.at)] = (perWeek[_saturday(n.at)] ?? 0) + 1;
          }
          expect(perWeek.values.every((c) => c <= kNudgesPerWeek), isTrue);
        }
      }
    });

    test('a casual note never shares a day with a training reminder', () {
      for (final reminders in [
        reminderDays,
        TrainingReminders(weekdays: {DateTime.thursday}, hour: 22, minute: 30),
      ]) {
        final days = <int>{
          for (final w in reminders.weekdays) ...{
            w,
            quietWeeklySlot(w, reminders.hour, reminders.minute).weekday,
          },
        };
        for (var d = 0; d < 14; d++) {
          final now = DateTime(2026, 10, 12 + d, 6);
          final plan = _plan(
            now,
            reminders: reminders,
            lastActiveAt: now.subtract(const Duration(days: 3)),
            tips: _tipsEveryDay(now),
          );
          for (final n in casual(plan)) {
            if (n.kind == PlanKind.didYouTrain) continue;
            expect(days, isNot(contains(n.at.weekday)), reason: '$n');
          }
        }
      }
    });
  });

  group('the order of priority', () {
    test('a check-in beats a tip on the same day, a tip beats a nudge', () {
      final now = DateTime(2026, 10, 14, 6);
      // Four days on from an open at 10:00 today is the first check-in.
      final opened = DateTime(2026, 10, 14, 5);
      final noNudges = _noPrefs.copyWith(nudges: false);
      final base = _plan(now, lastActiveAt: opened, prefs: noNudges);
      final checkIn = base.firstWhere((n) => n.kind == PlanKind.checkIn);
      final tip = PlannedNotification(
        id: tipNotificationId(0),
        kind: PlanKind.tip,
        at: DateTime(checkIn.at.year, checkIn.at.month, checkIn.at.day, 13),
      );
      final plan = _plan(
        now,
        lastActiveAt: opened,
        tips: [tip],
        prefs: noNudges,
      );
      expect(plan.where((n) => n.id == checkIn.id), hasLength(1));
      // The tip gives way by a day, it is not lost.
      final moved = plan.singleWhere((n) => n.id == tip.id);
      expect(_day(moved.at), DateTime(2026, 10, 19));
      expect(_day(moved.at), isNot(_day(checkIn.at)));
      expect(moved.at.hour, 13);

      final tipDay = _plan(
        now,
        lastActiveAt: opened,
        tips: [
          PlannedNotification(
            id: tipNotificationId(1),
            kind: PlanKind.tip,
            at: DateTime(2026, 10, 15, 13),
            variant: 1,
          ),
        ],
      );
      expect(
        tipDay
            .where((n) => _day(n.at) == DateTime(2026, 10, 15))
            .map((n) => n.kind),
        [PlanKind.tip],
      );
    });

    test('"Trained today?" keeps its day against a nudge or a check-in', () {
      final reminders = TrainingReminders(weekdays: {DateTime.wednesday});
      final plan = _plan(DateTime(2026, 10, 14, 6), reminders: reminders);
      final didYouTrain = plan.where((n) => n.kind == PlanKind.didYouTrain);
      expect(didYouTrain, hasLength(1));
      expect(
        plan.where(
          (n) =>
              n.kind != PlanKind.training &&
              _day(n.at) == _day(didYouTrain.first.at),
        ),
        hasLength(1),
      );
    });
  });

  group('the nudges themselves', () {
    test(
      'a fresh week on a plain day plans nudges, Friday is the week end',
      () {
        final plan = _plan(DateTime(2026, 10, 12, 6));
        final nudges = _nudges(plan).toList();
        expect(nudges, isNotEmpty);
        for (final n in nudges) {
          expect(n.id, nudgeNotificationId(n.at.weekday));
          expect(n.weekly, isFalse);
          final isFriday = n.at.weekday == DateTime.friday;
          expect(
            nudgeFromCode(n.variant).context == NudgeContext.weekEnd,
            isFriday,
          );
        }
      },
    );

    test('the same day gives the same nudge on every rebuild', () {
      final a = _plan(DateTime(2026, 10, 12, 6));
      final b = _plan(DateTime(2026, 10, 12, 7, 30));
      expect(_nudges(a).toList(), _nudges(b).toList());
    });

    test('a week keeps its days when the plan is rebuilt midweek', () {
      final early =
          _nudges(
                _plan(
                  DateTime(2026, 10, 12, 6),
                  lastActiveAt: DateTime(2026, 10, 11, 20),
                ),
              )
              .where((n) => n.at.isBefore(DateTime(2026, 10, 17)))
              .map((n) => _day(n.at))
              .toSet();
      final late =
          _nudges(
                _plan(
                  DateTime(2026, 10, 14, 6),
                  lastActiveAt: DateTime(2026, 10, 11, 20),
                ),
              )
              .where((n) => n.at.isBefore(DateTime(2026, 10, 17)))
              .map((n) => _day(n.at))
              .toSet();
      expect(early.containsAll(late), isTrue);
    });

    test('three unanswered and then none until she opens the app', () {
      // Wednesday 14 Oct; she last opened the app on Mon 5 Oct, a week and
      // more of nudge days ago.
      final now = DateTime(2026, 10, 14, 6);
      final away = _plan(now, lastActiveAt: DateTime(2026, 10, 5, 20));
      expect(_nudges(away), isEmpty);

      // An open five days back leaves room for at most three in all.
      final recent = _plan(now, lastActiveAt: DateTime(2026, 10, 9, 20));
      expect(_nudges(recent).length, lessThanOrEqualTo(3));

      // Opening the app starts the count again.
      final opened = _plan(now, lastActiveAt: now);
      expect(_nudges(opened), isNotEmpty);
    });

    test('the cap holds across rebuilds without an open', () {
      final opened = DateTime(2026, 10, 10, 20);
      final delivered = <DateTime>{};
      // Rebuilt every evening for three weeks, never opened: whatever was
      // planned and then came due counts, and no more than three ever come.
      for (var d = 0; d < 21; d++) {
        final now = DateTime(2026, 10, 11 + d, 7);
        final plan = _plan(now, lastActiveAt: opened);
        for (final n in _nudges(plan)) {
          if (n.at.isBefore(DateTime(2026, 10, 11 + d + 1))) {
            delivered.add(_day(n.at));
          }
        }
      }
      expect(delivered.length, lessThanOrEqualTo(kNudgesUnanswered));
    });

    test('the nudge days of a week do not change as the plan is rebuilt', () {
      // Saturday 10 Oct to Friday 16 Oct, planned fresh every morning.
      final union = <DateTime>{};
      for (var d = 0; d < 7; d++) {
        final now = DateTime(2026, 10, 10 + d, 6);
        for (final n in _nudges(_plan(now))) {
          if (n.at.isBefore(DateTime(2026, 10, 17))) union.add(_day(n.at));
        }
      }
      expect(union.length, lessThanOrEqualTo(kNudgesPerWeek));
      expect(union, contains(DateTime(2026, 10, 16)), reason: 'Friday');
    });

    test('a reminder that quiet hours moved to the next day frees no nudge '
        'there', () {
      // 22:30 on Thursday becomes 08:00 on Friday, so Friday is a training
      // day and carries no nudge, and neither does Thursday, her chosen day.
      final reminders = TrainingReminders(
        weekdays: {DateTime.thursday},
        hour: 22,
        minute: 30,
      );
      for (var d = 0; d < 14; d++) {
        final now = DateTime(2026, 10, 10 + d, 6);
        for (final n in _nudges(_plan(now, reminders: reminders))) {
          expect(n.at.weekday, isNot(DateTime.thursday));
          expect(n.at.weekday, isNot(DateTime.friday));
        }
      }
    });

    test('switching nudges off removes them, the rest stays', () {
      final reminders = TrainingReminders(weekdays: {DateTime.wednesday});
      final now = DateTime(2026, 10, 12, 6);
      final on = _plan(now, reminders: reminders);
      final off = _plan(
        now,
        reminders: reminders,
        prefs: _noPrefs.copyWith(nudges: false),
      );
      expect(_nudges(on), isNotEmpty);
      expect(_nudges(off), isEmpty);
      expect(
        off.where((n) => n.kind == PlanKind.training),
        on.where((n) => n.kind == PlanKind.training),
      );
    });

    test('nothing without permission', () {
      expect(
        NotificationPlan.build(
          now: DateTime(2026, 10, 12, 6),
          permitted: false,
        ),
        isEmpty,
      );
    });

    test('today is skipped once she opened the app or logged a session', () {
      final now = DateTime(2026, 10, 14, 6);
      final before = _nudges(_plan(now)).map((n) => _day(n.at));
      expect(before, contains(DateTime(2026, 10, 14)));
      for (final active in [
        _plan(now, lastActiveAt: now),
        _plan(now, lastSessionAt: now),
      ]) {
        expect(
          _nudges(active).map((n) => _day(n.at)),
          isNot(contains(DateTime(2026, 10, 14))),
        );
      }
    });

    test('a tap opens the screen the note is about', () {
      String screen(NudgeContext c, int v) =>
          nudgeScreen(nudgeVariantCode(c, v));
      for (var v = 0; v < kNudgeVariants; v++) {
        expect(screen(NudgeContext.midday, v), 'T01');
        expect(screen(NudgeContext.weekEnd, v), 'P01');
      }
      // Breakfast and dinner: an idea from the recipes, a meal to log, an
      // idea, a meal to log.
      for (final context in [NudgeContext.morning, NudgeContext.evening]) {
        expect(
          [for (var v = 0; v < kNudgeVariants; v++) screen(context, v)],
          ['E05', 'E01', 'E05', 'E01'],
        );
      }
    });

    test('the codes round-trip', () {
      for (final context in NudgeContext.values) {
        for (var v = 0; v < kNudgeVariants; v++) {
          final back = nudgeFromCode(nudgeVariantCode(context, v));
          expect(back.context, context);
          expect(back.variant, v);
        }
      }
    });
  });

  for (final code in ['en', 'ar']) {
    group('the nudge texts in $code', () {
      final text = AppRouter.reminderText(lookupAppL10n(Locale(code)));

      test('sixteen, each its own, with a channel', () {
        expect(
          text.nudgeBodies,
          hasLength(NudgeContext.values.length * kNudgeVariants),
        );
        expect(text.nudgeBodies.toSet(), hasLength(16));
        expect(text.nudgeChannelName, isNotEmpty);
        expect(text.nudgeChannelDescription, isNotEmpty);
      });

      test('short, warm and clean', () {
        final banned = code == 'en'
            ? [
                'streak',
                'miss',
                'lose',
                'lost',
                'fail',
                'behind',
                'lazy',
                'forgot',
                'guilt',
              ]
            : [
                'سلسلة',
                'فاتك',
                'فوّتي',
                'فوتي',
                'تأخرتي',
                'نسيتي',
                'كسلانة',
                'خسرتي',
                'فشل',
                'ذنب',
                'قصّرتي',
              ];
        for (final body in text.nudgeBodies) {
          expect(body.length, lessThanOrEqualTo(90), reason: body);
          expect(body, isNot(contains('—')), reason: body);
          expect(body, isNot(matches(RegExp(r'[0-9٠-٩۰-۹]'))), reason: body);
          final lower = body.toLowerCase();
          for (final word in banned) {
            final found = code == 'en'
                ? RegExp('\\b$word').hasMatch(lower)
                : lower.contains(word);
            expect(found, isFalse, reason: '"$body" has $word');
          }
        }
        expect(text.title.length, lessThanOrEqualTo(30));
        final bangs = text.nudgeBodies
            .map((b) => '!'.allMatches(b).length)
            .fold<int>(0, (a, b) => a + b);
        expect(bangs, lessThanOrEqualTo(1));
      });
    });
  }

  testWidgets('the explainer shows a sample notification before the prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NotificationExplainerBody(onChoose: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-sample')), findsOneWidget);
    expect(find.text('Own Hub'), findsOneWidget);
    expect(
      find.text(
        'Morning. Had breakfast yet? Log it in a tap whenever you are ready.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('explainer-yes')), findsOneWidget);
  });

  Future<void> pumpExplainer(
    WidgetTester tester, {
    String language = 'en',
    bool motionOff = false,
    double textScale = 1,
    bool tips = false,
  }) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: Locale(language),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: motionOff,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: NotificationExplainerBody(onChoose: (_) {}, tips: tips),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the explainer reads right to left in Arabic', (tester) async {
    await pumpExplainer(tester, language: 'ar');
    expect(tester.takeException(), isNull);
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('notification-explainer'))),
      ),
      TextDirection.rtl,
    );
    final ar = lookupAppL10n(const Locale('ar'));
    expect(find.text(ar.morningHadBreakfastYetLogItIn), findsOneWidget);
    expect(find.byKey(const ValueKey('explainer-yes')), findsOneWidget);
  });

  testWidgets('the explainer sits still and complete with motion off', (
    tester,
  ) async {
    await pumpExplainer(tester, motionOff: true);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('notification-sample')), findsOneWidget);
    expect(find.byKey(const ValueKey('explainer-not-now')), findsOneWidget);
  });

  for (final language in ['en', 'ar']) {
    for (final tips in [false, true]) {
      testWidgets('the explainer survives the largest text size: $language '
          'tips $tips', (tester) async {
        await pumpExplainer(
          tester,
          language: language,
          textScale: 2,
          tips: tips,
        );
        expect(tester.takeException(), isNull);
        final circle = tester.getRect(
          find.byKey(const ValueKey('notification-sample')),
        );
        final card = tester.getRect(
          find
              .descendant(
                of: find.byKey(const ValueKey('notification-sample')),
                matching: find.byType(Container),
              )
              .last,
        );
        expect(circle.contains(card.topLeft), isTrue);
        expect(circle.contains(card.bottomRight), isTrue);
      });
    }
  }
}
