// The walk's clock is two stored times, so it survives a pocket and a kill.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/walk_session_state.dart';

void main() {
  final t0 = DateTime(2026, 10, 28, 9);
  final walk = WalkSessionState.instance;

  setUp(walk.reset);
  tearDown(walk.reset);

  test('elapsed is the time since the start', () {
    walk.start(t0);
    expect(walk.isWalking, isTrue);
    expect(walk.elapsed(t0.add(const Duration(minutes: 25))).inSeconds, 1500);
  });

  test('a pause is not walked time, now or after it ends', () {
    walk.start(t0);
    walk.pause(t0.add(const Duration(minutes: 10)));
    // Held for 5 minutes: the clock does not move.
    expect(walk.elapsed(t0.add(const Duration(minutes: 15))).inMinutes, 10);
    walk.resume(t0.add(const Duration(minutes: 15)));
    expect(walk.elapsed(t0.add(const Duration(minutes: 20))).inMinutes, 15);
  });

  test('finish keeps the seconds until the walk is logged or dropped', () {
    walk.start(t0);
    expect(walk.finish(t0.add(const Duration(minutes: 31))), 1860);
    expect(walk.isWalking, isFalse);
    expect(walk.finishedSeconds, 1860);
    expect(walk.touched, isTrue);
    // A new walk cannot start over one still waiting.
    walk.start(t0);
    expect(walk.isWalking, isFalse);
    walk.logged();
    expect(walk.touched, isFalse);
    expect(walk.finishedSeconds, isNull);
  });

  test('finishing a walk that is not there does nothing', () {
    expect(walk.finish(t0), isNull);
    expect(walk.touched, isFalse);
  });

  test('discard drops a walk under way and a finished one', () {
    walk.start(t0);
    walk.discard();
    expect(walk.touched, isFalse);
    walk.start(t0);
    walk.finish(t0.add(const Duration(minutes: 5)));
    walk.discard();
    expect(walk.touched, isFalse);
  });

  test('a walk survives the app being killed, mid-walk and paused', () {
    walk.start(t0);
    walk.pause(t0.add(const Duration(minutes: 10)));
    walk.resume(t0.add(const Duration(minutes: 12)));
    walk.pause(t0.add(const Duration(minutes: 20)));
    final raw = jsonEncode(AppSnapshot.capture());
    walk.reset();
    expect(walk.touched, isFalse);

    expect(AppSnapshot.restore(raw), greaterThan(0));
    expect(walk.isWalking, isTrue);
    expect(walk.isPaused, isTrue);
    // 20 minutes in, 2 of them paused, and still paused at minute 40.
    expect(walk.elapsed(t0.add(const Duration(minutes: 40))).inMinutes, 18);
  });

  test('a finished walk waiting to be logged survives too', () {
    walk.start(t0);
    walk.finish(t0.add(const Duration(minutes: 33)));
    final raw = jsonEncode(AppSnapshot.capture());
    walk.reset();
    AppSnapshot.restore(raw);
    expect(walk.finishedSeconds, 1980);
    expect(walk.isWalking, isFalse);
  });

  test('nothing is written to the snapshot when there is no walk', () {
    expect(AppSnapshot.capture().containsKey('walk'), isFalse);
  });
}
