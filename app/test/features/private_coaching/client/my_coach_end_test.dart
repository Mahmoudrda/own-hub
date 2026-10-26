// My coach: ending a coaching, the waiting and closed states, and the
// streams being opened once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/requests.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';

import '../plans/plans_support.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 3600);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

final _now = DateTime.utc(2026, 10, 24, 12);

Future<RecordingRepo> _open(
  WidgetTester t,
  SubscriptionStatus status, {
  RecordingRepo? repo,
  VoidCallback? onFind,
}) async {
  _phone(t);
  final r = repo ?? RecordingRepo();
  await t.pumpWidget(
    host(
      MyCoachView(
        repository: r,
        subscription: sub(status: status),
        now: () => _now,
        onMessage: () {},
        onFind: onFind,
      ),
    ),
  );
  await t.pumpAndSettle();
  return r;
}

/// End coaching lives behind the "..." in the top bar.
Future<void> _endFromMenu(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('overflow-menu')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('overflow-row-End coaching')));
  await t.pumpAndSettle();
}

void main() {
  test('the end request carries the subscription and a trimmed reason', () {
    expect(CoachingRequests.endMine('s', ' tired '), {
      'subId': 's',
      'reason': 'tired',
    });
    expect(CoachingRequests.endMine('s', null), {'subId': 's'});
    expect(CoachingCallables.all, contains('end_my_coaching'));
  });

  group('End coaching', () {
    testWidgets('asks first, says what happens, then calls the server', (
      t,
    ) async {
      final repo = await _open(t, SubscriptionStatus.active);
      await _endFromMenu(t);
      expect(find.text('End this coaching?'), findsOneWidget);
      expect(
        find.text(
          'The chat becomes read only. Your plans stay with you. '
          'Coach Sara will no longer see your answers.',
        ),
        findsOneWidget,
      );
      expect(repo.calls.where((c) => c.$1 == 'endMyCoaching'), isEmpty);
      await t.tap(find.byKey(const ValueKey('end-coaching-no')));
      await t.pumpAndSettle();
      expect(repo.calls.where((c) => c.$1 == 'endMyCoaching'), isEmpty);

      await _endFromMenu(t);
      await t.tap(find.byKey(const ValueKey('end-coaching-yes')));
      await t.pumpAndSettle();
      expect(repo.calls.last.$1, 'endMyCoaching');
      expect(repo.calls.last.$2['subId'], 'sub1');
      expect(find.byKey(const ValueKey('coach-error')), findsNothing);
    });

    testWidgets('a refusal is shown, not thrown', (t) async {
      final repo = RecordingRepo()
        ..failEnd = const CoachingFailure(CoachingRefusal.unreachable);
      await _open(t, SubscriptionStatus.active, repo: repo);
      await _endFromMenu(t);
      await t.tap(find.byKey(const ValueKey('end-coaching-yes')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('coach-error')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('not offered once it has ended', (t) async {
      await _open(t, SubscriptionStatus.endedEarly);
      await t.tap(find.byKey(const ValueKey('overflow-menu')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('overflow-row-End coaching')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('overflow-row-Report')), findsOneWidget);
    });
  });

  group('a request still open', () {
    testWidgets('waits for the answer, hides Message, can be cancelled', (
      t,
    ) async {
      final repo = await _open(t, SubscriptionStatus.requested);
      expect(find.text("Waiting for Coach Sara's answer"), findsOneWidget);
      expect(find.byKey(const ValueKey('coach-message')), findsNothing);
      expect(find.byKey(const ValueKey('end-coaching')), findsNothing);
      await t.tap(find.byKey(const ValueKey('cancel-request')));
      await t.pumpAndSettle();
      expect(repo.calls.last.$1, 'cancelCoachingRequest');
      expect(repo.calls.last.$2['subId'], 'sub1');
    });

    testWidgets('Message waits until the coaching is active', (t) async {
      await _open(t, SubscriptionStatus.awaitingPayment);
      expect(find.byKey(const ValueKey('coach-message')), findsNothing);
      await _open(t, SubscriptionStatus.active);
      expect(find.byKey(const ValueKey('coach-message')), findsOneWidget);
    });
  });

  group('a request that did not go through', () {
    testWidgets('declined: one line and a way to find another coach', (
      t,
    ) async {
      var found = 0;
      await _open(t, SubscriptionStatus.declined, onFind: () => found++);
      expect(
        find.text('Coach Sara could not take you this time'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('coach-message')), findsNothing);
      await t.tap(find.byKey(const ValueKey('find-another-coach')));
      expect(found, 1);
    });

    testWidgets('expired: no answer in time', (t) async {
      await _open(t, SubscriptionStatus.expired, onFind: () {});
      expect(find.text('No answer in time'), findsOneWidget);
      expect(find.text('Find another coach'), findsOneWidget);
    });

    test('requestClosed names the two', () {
      expect(requestClosed(sub(status: SubscriptionStatus.declined)), isTrue);
      expect(requestClosed(sub(status: SubscriptionStatus.expired)), isTrue);
      expect(requestClosed(sub(status: SubscriptionStatus.cancelled)), isFalse);
    });
  });

  testWidgets('the streams are opened once, not on every rebuild', (t) async {
    _phone(t);
    final repo = RecordingRepo();
    Widget view() => host(
      MyCoachView(
        repository: repo,
        subscription: sub(),
        now: () => _now,
        onMessage: () {},
      ),
    );
    await t.pumpWidget(view());
    await t.pumpAndSettle();
    await t.pumpWidget(view());
    await t.pumpAndSettle();
    expect(repo.watchCoachCalls, 1);
    expect(repo.watchSessionCalls, 1);
  });
}
