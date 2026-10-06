// The widget payload: what the Home Screen and Lock Screen widgets are told.
//
// Built from an allow-list in `widget_projection.dart`. These tests hold the
// shape: the right sentence for each day, the closed state when she is not
// let in, a fresh week at zero, Western digits in Arabic, and no daily tally.

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/widget_projection.dart';
import 'package:own_hub/l10n/app_l10n.dart';

final AppL10n _en = lookupAppL10n(const Locale('en'));
final AppL10n _ar = lookupAppL10n(const Locale('ar'));

final DateTime _now = DateTime(2026, 10, 6, 9, 30);

TodayDay _day({
  DayState state = DayState.nothingDone,
  int done = 1,
  int target = 3,
  DateTime? date,
  DateTime? meal,
}) => TodayDay(
  date: date ?? _now,
  state: state,
  arc: const FirstWeekArc(hasAnyLog: true),
  week: WeekProgress(sessionsLogged: done, sessionsTarget: target),
  mealLoggedAt: meal,
);

Map<String, Object?> _build(
  TodayDay day, {
  bool open = true,
  AppL10n? l10n,
  String lang = 'en',
}) => WidgetProjection.build(
  day: day,
  open: open,
  l10n: l10n ?? _en,
  lang: lang,
  now: _now,
);

Map<String, Object?> _strings(Map<String, Object?> payload) =>
    (payload['s']! as Map).cast<String, Object?>();

void main() {
  test('each day state has its own status line', () {
    final expected = {
      DayState.dayOne: _en.yourFirstSessionIsReady,
      DayState.nothingDone: _en.todaysWorkoutIsReady,
      DayState.inProgress: _en.todayIsUnderWay,
      DayState.done: _en.sessionDone,
      DayState.recalled: _en.sessionLogged,
      DayState.restDay: _en.restDay,
    };
    expect(expected.keys.toSet(), DayState.values.toSet());
    for (final MapEntry(key: state, value: line) in expected.entries) {
      final payload = _build(_day(state: state));
      expect(payload['today'], state.name);
      expect(_strings(payload)['status'], line, reason: state.name);
    }
  });

  test('the open payload carries the week and today, nothing else', () {
    final payload = _build(_day(meal: DateTime(2026, 10, 6, 8, 10)));
    expect(payload['state'], 'open');
    expect(payload['dayKey'], '2026-10-06');
    expect(payload['weekId'], '2026-W41');
    expect(payload['done'], 1);
    expect(payload['target'], 3);
    expect(payload['meal'], isTrue);
    expect(_strings(payload)['week'], 'This week, 1 of 3');
    expect(_strings(payload)['inline'], '1 of 3 this week');
    expect(payload.keys.toSet().difference(kWidgetPayloadKeys), isEmpty);
    expect(_strings(payload).keys.toSet(), kWidgetStringKeys);
  });

  test('a meal from another day is not today\'s meal', () {
    final payload = _build(_day(meal: DateTime(2026, 10, 5, 20)));
    expect(payload['meal'], isFalse);
  });

  test('closed when she is not verified or signed out: no numbers at all', () {
    final payload = _build(_day(done: 2), open: false);
    expect(payload['state'], 'closed');
    expect(payload.keys.toSet(), {'v', 'state', 'lang', 's'});
    expect(_strings(payload), {'closed': _en.openOwnHubToStart});
    expect(jsonEncode(payload), isNot(matches(RegExp(r'\d+ of'))));
  });

  test('the fresh week reads zero of her target', () {
    final payload = _build(_day(done: 3, target: 4));
    expect(_strings(payload)['weekFresh'], 'This week, 0 of 4');
    expect(_strings(payload)['inlineFresh'], '0 of 4 this week');
    expect(_strings(payload)['a11yFresh'], 'Sessions this week: 0 of 4');
  });

  test('yesterday\'s data is not presented as today', () {
    final payload = _build(
      _day(state: DayState.done, date: DateTime(2026, 10, 5, 21)),
    );
    expect(payload['today'], 'stale');
    expect(payload['meal'], isFalse);
    expect(_strings(payload)['status'], _en.openOwnHubForToday);
  });

  test('Arabic uses Western digits only', () {
    final payload = _build(_day(done: 2, target: 4), l10n: _ar, lang: 'ar');
    final encoded = jsonEncode(payload);
    expect(payload['lang'], 'ar');
    expect(encoded, isNot(matches(RegExp('[٠-٩]'))));
    expect(_strings(payload)['week'], contains('2'));
    expect(_strings(payload)['week'], contains('4'));
  });

  test('no daily tally anywhere in the payload', () {
    for (final state in DayState.values) {
      for (final l10n in [_en, _ar]) {
        final payload = _build(_day(state: state), l10n: l10n);
        // Two numbers, both weekly. Nothing counts days.
        final numbers = payload.values.whereType<int>().toList();
        expect(numbers, [1, 1, 3]);
        expect(
          jsonEncode(payload),
          isNot(
            matches(
              RegExp(r'in a row|days|missed|streak', caseSensitive: false),
            ),
          ),
        );
      }
    }
  });
}
