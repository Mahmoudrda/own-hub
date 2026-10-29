import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';

import 'desk_support.dart';

class _Feed<T> {
  _Feed(this.value);

  T value;
  final StreamController<T> _changes = StreamController<T>.broadcast(
    sync: true,
  );

  void set(T next) {
    value = next;
    _changes.add(next);
  }

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(value);
    final sub = _changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
}

/// Only what the desk reads and does. Anything else fails loudly.
class DeskRepo implements CoachingRepository {
  @override
  String? uid = 'me';

  final _subs = _Feed<List<Subscription>>(const <Subscription>[]);
  final _rels = _Feed<List<Relationship>>(const <Relationship>[]);
  final _messages = _Feed<List<ChatMessage>>(const <ChatMessage>[]);
  final _sessions = _Feed<List<LiveSession>>(const <LiveSession>[]);

  /// Every respond call: sub id, accept, reason.
  final _plans = _Feed<List<CoachPlan>>(const <CoachPlan>[]);
  final _private = _Feed<CoachPrivateSummary?>(null);

  /// Her private record, as the agreement gate reads it.
  void setCoachPrivate(CoachPrivateSummary? value) => _private.set(value);

  @override
  Stream<CoachPrivateSummary?> watchCoachPrivate() => _private.watch();
  final List<String> ended = <String>[];
  CoachingFailure? failEnd;

  void setPlans(List<CoachPlan> value) => _plans.set(value);

  @override
  Stream<List<CoachPlan>> watchCoachPlansForClient(String clientUid) =>
      _plans.watch();

  @override
  Future<SubscriptionStatus> endMyCoaching(
    String subId, {
    String? reason,
  }) async {
    final failure = failEnd;
    if (failure != null) throw failure;
    ended.add(subId);
    return SubscriptionStatus.endedEarly;
  }

  final List<(String, bool, CoachDeclineReason?)> responses =
      <(String, bool, CoachDeclineReason?)>[];
  CoachingFailure? failResponse;

  void setSubscriptions(List<Subscription> value) => _subs.set(value);
  void setRelationships(List<Relationship> value) => _rels.set(value);
  void setMessages(List<ChatMessage> value) => _messages.set(value);
  void setSessions(List<LiveSession> value) => _sessions.set(value);

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsClient() =>
      Stream<List<Subscription>>.value(const <Subscription>[]);

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsCoach() => _subs.watch();

  @override
  Stream<List<Relationship>> watchMyRelationships() => _rels.watch();

  @override
  Stream<List<CoachPlan>> watchMyCoachPlans() =>
      Stream<List<CoachPlan>>.value(const <CoachPlan>[]);

  @override
  Stream<DateTime?> watchReadAt(String relId) => Stream<DateTime?>.value(null);

  @override
  Stream<List<ChatMessage>> watchMessages(String relId) => _messages.watch();

  @override
  Stream<List<LiveSession>> watchSessions(String subId) => _sessions.watch();

  @override
  Future<SubscriptionStatus> respondCoachingRequest({
    required String subId,
    required bool accept,
    CoachDeclineReason? declineReason,
  }) async {
    responses.add((subId, accept, declineReason));
    final failure = failResponse;
    if (failure != null) throw failure;
    return accept ? SubscriptionStatus.active : SubscriptionStatus.declined;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A started state over [repo], with the streams answered.
Future<PrivateCoachingState> startedState(
  WidgetTester tester,
  DeskRepo repo,
) async {
  final state = PrivateCoachingState.forTest();
  state.start(repo, isCoach: true, now: () => kDeskNow);
  addTearDown(state.stop);
  await tester.pump();
  return state;
}
