import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';

import 'support/fake_coaching_repository.dart';
import 'support/fixtures.dart';

Relationship rel(String coach, {DateTime? last, int unread = 0}) =>
    Relationship(
      id: '${coach}__me',
      coachUid: coach,
      clientUid: 'me',
      status: RelationshipStatus.active,
      chatOpen: true,
      lastMessageAt: last,
      unreadFor: unread > 0 ? <String, int>{'me': unread} : const {},
    );

void main() {
  late FakeCoachingRepository repo;
  late PrivateCoachingState state;
  var bumps = 0;
  void onBump() => bumps++;

  setUp(() {
    repo = FakeCoachingRepository();
    state = PrivateCoachingState.forTest();
    bumps = 0;
    AppChanges.instance.addListener(onBump);
  });

  tearDown(() {
    AppChanges.instance.removeListener(onBump);
    state.stop();
  });

  test(
    'nothing is loaded before start, and a signed-out start stays empty',
    () {
      expect(state.isStarted, isFalse);
      expect(state.activeAsClient, isNull);
      repo.uid = null;
      state.start(repo);
      expect(state.loading, isFalse);
      expect(state.clientSubscriptions, isEmpty);
    },
  );

  test('loading lasts until every stream has answered, and bumps', () async {
    state.start(repo, now: () => kNow);
    expect(state.loading, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(state.loading, isFalse);
    expect(bumps, greaterThan(0));
  });

  test('a stream that has not spoken keeps loading true', () {
    final slow = StreamController<List<Subscription>>();
    final custom = _SlowRepo(slow.stream);
    state.start(custom);
    expect(state.loading, isTrue);
    slow.add(const <Subscription>[]);
    return Future<void>.delayed(Duration.zero).then((_) {
      expect(state.loading, isFalse);
      slow.close();
    });
  });

  test('her active subscription is the one that is active', () async {
    repo.clientSubs.value = [
      sub('old', SubscriptionStatus.ended),
      sub('now', SubscriptionStatus.active),
      sub('next', SubscriptionStatus.requested),
    ];
    state.start(repo, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.activeAsClient!.id, 'now');
    expect(state.currentAsClient!.id, 'now');
    repo.clientSubs.value = [
      sub('a', SubscriptionStatus.requested, coachUid: 'x'),
      sub('b', SubscriptionStatus.awaitingPayment),
      sub('c', SubscriptionStatus.paymentReview),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(state.activeAsClient, isNull);
    expect(state.currentAsClient!.id, 'c');
    repo.clientSubs.value = [sub('a', SubscriptionStatus.declined)];
    await Future<void>.delayed(Duration.zero);
    expect(state.currentAsClient, isNull);
  });

  test(
    'the coach desk lists sort into requests, review, active, ending',
    () async {
      repo.coachSubs.value = [
        sub(
          'r2',
          SubscriptionStatus.requested,
          createdAt: kNow.subtract(const Duration(hours: 1)),
        ),
        sub(
          'r1',
          SubscriptionStatus.requested,
          createdAt: kNow.subtract(const Duration(hours: 5)),
        ),
        sub('p', SubscriptionStatus.paymentReview),
        sub(
          'a1',
          SubscriptionStatus.active,
          endsAt: kNow.add(const Duration(days: 20)),
        ),
        sub(
          'a2',
          SubscriptionStatus.active,
          endsAt: kNow.add(const Duration(days: 2)),
        ),
        sub('done', SubscriptionStatus.ended),
      ];
      state.start(repo, isCoach: true, now: () => kNow);
      await Future<void>.delayed(Duration.zero);
      expect(state.requests.map((s) => s.id), ['r1', 'r2']);
      expect(state.paymentReview.map((s) => s.id), ['p']);
      expect(state.activeClients.map((s) => s.id), ['a2', 'a1']);
      expect(state.endingSoon.map((s) => s.id), ['a2']);
    },
  );

  test('coach streams run only for a coach, and can be switched', () async {
    repo.coachSubs.value = [sub('r', SubscriptionStatus.requested)];
    state.start(repo, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.requests, isEmpty);
    state.setCoach(true);
    await Future<void>.delayed(Duration.zero);
    expect(state.requests, hasLength(1));
    state.setCoach(false);
    expect(state.requests, isEmpty);
  });

  test(
    'unread follows the server counter, with no read stream per chat',
    () async {
      repo.relationships.value = [
        rel('a', last: DateTime.utc(2026, 10, 24, 10), unread: 2),
        rel('b', last: DateTime.utc(2026, 10, 24, 10)),
        rel('c'),
      ];
      state.start(repo, now: () => kNow);
      await Future<void>.delayed(Duration.zero);
      expect(state.hasUnread('a__me'), isTrue);
      expect(state.hasUnread('b__me'), isFalse);
      expect(state.hasUnread('c__me'), isFalse);
      expect(state.hasUnread('nobody'), isFalse);
      expect(state.unreadChats, 1);
      expect(repo.readAt, isEmpty);

      repo.relationships.value = [
        rel('b', last: DateTime.utc(2026, 10, 24, 12), unread: 1),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(state.hasUnread('b__me'), isTrue);
      expect(state.hasUnread('a__me'), isFalse);
    },
  );

  test('marking a chat read tells the repository; the counter comes back on the stream', () async {
    repo.relationships.value = [
      rel('a', last: DateTime.utc(2026, 10, 24, 10), unread: 1),
    ];
    state.start(repo, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.unreadChats, 1);
    await state.markRead('a__me');
    expect(repo.callNames, contains('markRead'));
    repo.relationships.value = [rel('a', last: DateTime.utc(2026, 10, 24, 10))];
    await Future<void>.delayed(Duration.zero);
    expect(state.unreadChats, 0);
  });

  test('a failing mark-read is kept as the failure, not thrown', () async {
    repo.failWith['markRead'] = const CoachingFailure(
      CoachingRefusal.unreachable,
    );
    state.start(repo, now: () => kNow);
    await state.markRead('a__me');
    expect(state.failure?.refusal, CoachingRefusal.unreachable);
  });

  test('a mark-read failure is cleared by the next one that works', () async {
    repo.failWith['markRead'] = const CoachingFailure(
      CoachingRefusal.unreachable,
    );
    state.start(repo, now: () => kNow);
    await state.markRead('a__me');
    expect(state.failure, isNotNull);
    repo.failWith.remove('markRead');
    await state.markRead('a__me');
    expect(state.failure, isNull);
  });

  test(
    'a stream error becomes the failure and clears on the next value',
    () async {
      state.start(repo, now: () => kNow);
      await Future<void>.delayed(Duration.zero);
      repo.clientSubs.fail(const CoachingFailure(CoachingRefusal.unreachable));
      await Future<void>.delayed(Duration.zero);
      expect(state.failure?.refusal, CoachingRefusal.unreachable);
      repo.clientSubs.value = const <Subscription>[];
      await Future<void>.delayed(Duration.zero);
      expect(state.failure, isNull);
    },
  );

  test('plans her coaches shared are listed by kind', () async {
    repo.plans.value = [
      const CoachPlan(id: 'm', kind: PlanKind.meal, meal: MealPlanBody()),
    ];
    state.start(repo, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.coachPlansOf(PlanKind.meal), hasLength(1));
    expect(state.coachPlansOf(PlanKind.workout), isEmpty);
  });

  test('stop forgets everything and stops listening', () async {
    repo.clientSubs.value = [sub('now', SubscriptionStatus.active)];
    state.start(repo, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.activeAsClient, isNotNull);
    state.stop();
    expect(state.activeAsClient, isNull);
    expect(state.isStarted, isFalse);
    final before = bumps;
    repo.clientSubs.value = [sub('x', SubscriptionStatus.active)];
    await Future<void>.delayed(Duration.zero);
    expect(bumps, before);
  });

  test('restarting replaces the old streams', () async {
    state.start(repo, now: () => kNow);
    final other = FakeCoachingRepository()
      ..clientSubs.value = [sub('z', SubscriptionStatus.active)];
    state.start(other, now: () => kNow);
    await Future<void>.delayed(Duration.zero);
    expect(state.activeAsClient!.id, 'z');
    repo.clientSubs.value = [sub('old', SubscriptionStatus.active)];
    await Future<void>.delayed(Duration.zero);
    expect(state.activeAsClient!.id, 'z');
  });
}

class _SlowRepo extends FakeCoachingRepository {
  _SlowRepo(this._subs);
  final Stream<List<Subscription>> _subs;

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsClient() => _subs;
}
