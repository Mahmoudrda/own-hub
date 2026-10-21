// What she answered on the follow-ups survives a restart and goes with a wipe.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/features/account/domain/health_backup.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

const WeekReviewAnswer _answer = WeekReviewAnswer(
  felt: WeekFelt.hard,
  fit: PlanFit.tooMuch,
  focus: WeekFocus.feelGood,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final state = FollowUpState.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
  });

  tearDown(() async {
    await const ThisPhoneWipe().clearPersistence();
  });

  test('a fresh phone has it on and has nothing to save', () {
    expect(state.enabled, isTrue);
    expect(state.touched, isFalse);
    expect(AppSnapshot.capture().containsKey('followUps'), isFalse);
  });

  test('every answer and setting makes the round trip', () async {
    state
      ..answerFeel('2026-10-10', Feel.verySore)
      ..answerFeel('2026-10-13', Feel.fresh)
      ..answerWeek('2026-10-10', _answer)
      ..notNow(FollowUpKind.food, '2026-10-20')
      ..mute(FollowUpKind.comeBack)
      ..setEnabled(false);
    expect(state.notBefore[FollowUpKind.food], '2026-10-21');

    final document = jsonEncode(AppSnapshot.capture());
    await const ThisPhoneWipe().clearPersistence();
    expect(state.touched, isFalse, reason: 'the wipe emptied it');
    expect(nothingOfHersRemains, isTrue);

    AppSnapshot.restore(document);

    expect(state.enabled, isFalse);
    expect(state.muted, {FollowUpKind.comeBack});
    expect(state.notBefore, {FollowUpKind.food: '2026-10-21'});
    expect(state.feels, {
      '2026-10-10': Feel.verySore,
      '2026-10-13': Feel.fresh,
    });
    expect(state.weekReviews, {'2026-10-10': _answer});
  });

  test('the wipe puts it back to on and empty', () async {
    state
      ..answerFeel('2026-10-10', Feel.aBitSore)
      ..setEnabled(false);
    expect(nothingOfHersRemains, isFalse);

    await const ThisPhoneWipe().clearPersistence();

    expect(state.enabled, isTrue);
    expect(state.feels, isEmpty);
    expect(nothingOfHersRemains, isTrue);
  });

  test('it is in the snapshot and in no cloud document', () async {
    state.answerFeel('2026-10-10', Feel.fresh);
    state.answerFeel('2026-10-11', Feel.verySore);
    state.answerWeek('2026-10-10', _answer);
    expect(AppSnapshot.capture().containsKey('followUps'), isTrue);

    const names = {'followUps', 'feels', 'weekReviews', 'reviews', 'notBefore'};
    // The answers the state holds right now: fresh and verySore, and the week
    // review's tooMuch and feelGood.
    const values = {'fresh', 'verySore', 'tooMuch', 'feelGood'};
    void scan(Object? node, String where) {
      if (node is Map) {
        for (final entry in node.entries) {
          expect(
            names.contains(entry.key),
            isFalse,
            reason: '$where has key ${entry.key}',
          );
          scan(entry.value, where);
        }
      } else if (node is Iterable) {
        for (final item in node) {
          scan(item, where);
        }
      } else if (node is String) {
        expect(
          values.any(node.contains),
          isFalse,
          reason: '$where has value $node',
        );
      }
    }

    final preference = HealthBackupPreference.instance;
    try {
      for (final backup in [false, true]) {
        await preference.set(backup);
        final docs = CloudDocuments.capture();
        expect(docs, isNotEmpty, reason: 'backup $backup');
        for (final doc in docs) {
          scan(doc.data, 'backup $backup ${doc.collection}/${doc.id}');
        }
      }
    } finally {
      await preference.set(false);
      preference.resetForTest();
    }
  });

  test('unknown names and bad days are skipped, not fatal', () async {
    final document = jsonEncode(<String, Object?>{
      ...AppSnapshot.capture(),
      'followUps': <String, Object?>{
        'on': true,
        'muted': ['comeBack', 'nonsense', 7],
        'notBefore': {
          'food': '2026-10-21',
          'nonsense': '2026-10-21',
          'weekReview': 'soon',
        },
        'feels': {
          '2026-10-10': 'verySore',
          '2026-10-11': 'furious',
          'tomorrow': 'fresh',
        },
        'reviews': {
          '2026-10-10': {
            'felt': 'good',
            'fit': 'aboutRight',
            'focus': 'strength',
          },
          '2026-10-17': {
            'felt': 'good',
            'fit': 'nonsense',
            'focus': 'strength',
          },
        },
      },
    });

    AppSnapshot.restore(document);

    expect(state.muted, {FollowUpKind.comeBack});
    expect(state.notBefore, {FollowUpKind.food: '2026-10-21'});
    expect(state.feels, {'2026-10-10': Feel.verySore});
    expect(state.weekReviews.keys, ['2026-10-10']);
  });

  test('only the newest 60 feels and 26 reviews are kept', () {
    String day(int i) =>
        DateTime(2026, 1, 1 + i).toIso8601String().substring(0, 10);
    for (var i = 0; i < 70; i++) {
      state.answerFeel(day(i), Feel.fresh);
    }
    for (var i = 0; i < 30; i++) {
      state.answerWeek(day(i * 7), _answer);
    }
    expect(state.feels.length, kFeelsKept);
    expect(state.feels.containsKey(day(0)), isFalse);
    expect(state.feels.containsKey(day(69)), isTrue);
    expect(state.weekReviews.length, kWeekReviewsKept);
    expect(state.weekReviews.containsKey(day(0)), isFalse);
    expect(state.weekReviews.containsKey(day(29 * 7)), isTrue);
  });
}
