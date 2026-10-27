/// What the signed-in member knows about private coaching, kept live from the
/// repository's streams: her subscription as a client, the coach's desk lists,
/// the plans her coach shared and which chats have something she has not read.
///
/// No UI lives here. Screens read the getters and listen to [AppChanges];
/// every change bumps it. Nothing here writes a status or a payment: those
/// only come from the server.
library;

import 'dart:async';

import '../features/private_coaching/data/coaching_repository.dart';
import '../features/private_coaching/domain/coach_plan.dart';
import '../features/private_coaching/domain/coaching_contract.dart';
import '../features/private_coaching/domain/coaching_failure.dart';
import '../features/private_coaching/domain/subscription.dart';
import 'app_changes.dart';

class PrivateCoachingState {
  PrivateCoachingState._();

  static final PrivateCoachingState instance = PrivateCoachingState._();

  /// A state of its own for a test.
  factory PrivateCoachingState.forTest() => PrivateCoachingState._();

  CoachingRepository? _repository;
  DateTime Function() _now = DateTime.now;
  bool _isCoach = false;
  final Map<String, StreamSubscription<Object?>> _streams =
      <String, StreamSubscription<Object?>>{};
  final Set<String> _waiting = <String>{};
  final Map<String, CoachingFailure> _failures = <String, CoachingFailure>{};

  List<Subscription> _clientSubs = const <Subscription>[];
  List<Subscription> _coachSubs = const <Subscription>[];
  List<Relationship> _relationships = const <Relationship>[];
  List<CoachPlan> _plans = const <CoachPlan>[];

  /// The repository in use, or null before [start].
  CoachingRepository? get repository => _repository;

  bool get isStarted => _repository != null;

  bool get isCoach => _isCoach;

  /// True until every stream started has answered once.
  bool get loading => _waiting.isNotEmpty;

  /// The first stream failure still standing, or null.
  CoachingFailure? get failure =>
      _failures.isEmpty ? null : _failures.values.first;

  /// Starts (or restarts) the streams for the signed-in member. [isCoach] adds
  /// the coach's own streams; [now] is for tests.
  void start(
    CoachingRepository repository, {
    bool isCoach = false,
    DateTime Function()? now,
  }) {
    _cancelAll();
    _repository = repository;
    _isCoach = isCoach;
    _now = now ?? DateTime.now;
    if (repository.uid == null) {
      _clear();
      AppChanges.bump();
      return;
    }
    _listen<List<Subscription>>(
      'clientSubs',
      repository.watchMySubscriptionsAsClient(),
      (value) => _clientSubs = value,
    );
    _listen<List<Relationship>>(
      'relationships',
      repository.watchMyRelationships(),
      (value) => _relationships = value,
    );
    _listen<List<CoachPlan>>(
      'plans',
      repository.watchMyCoachPlans(),
      (value) => _plans = value,
    );
    if (isCoach) _startCoachStreams();
    AppChanges.bump();
  }

  /// Turns the coach's streams on or off, for example after her claim
  /// changes.
  void setCoach(bool isCoach) {
    if (_repository == null || isCoach == _isCoach) return;
    _isCoach = isCoach;
    if (isCoach) {
      _startCoachStreams();
    } else {
      _cancel('coachSubs');
      _coachSubs = const <Subscription>[];
    }
    AppChanges.bump();
  }

  /// Stops every stream and forgets what they held (sign-out).
  void stop() {
    _cancelAll();
    _repository = null;
    _isCoach = false;
    _clear();
    AppChanges.bump();
  }

  void _startCoachStreams() {
    final repository = _repository;
    if (repository == null) return;
    _listen<List<Subscription>>(
      'coachSubs',
      repository.watchMySubscriptionsAsCoach(),
      (value) => _coachSubs = value,
    );
  }

  void _listen<T>(String key, Stream<T> stream, void Function(T) assign) {
    _cancel(key);
    _waiting.add(key);
    _streams[key] = stream.listen(
      (value) {
        assign(value);
        _waiting.remove(key);
        _failures.remove(key);
        AppChanges.bump();
      },
      onError: (Object error) {
        _waiting.remove(key);
        _failures[key] = error is CoachingFailure
            ? error
            : const CoachingFailure(CoachingRefusal.unknown);
        AppChanges.bump();
      },
    );
  }

  void _cancel(String key) {
    unawaited(_streams.remove(key)?.cancel());
    _waiting.remove(key);
    _failures.remove(key);
  }

  void _cancelAll() {
    for (final sub in _streams.values) {
      unawaited(sub.cancel());
    }
    _streams.clear();
    _waiting.clear();
    _failures.clear();
  }

  void _clear() {
    _clientSubs = const <Subscription>[];
    _coachSubs = const <Subscription>[];
    _relationships = const <Relationship>[];
    _plans = const <CoachPlan>[];
  }

  // ------------------------------------------------------------ as a client

  /// Everything she bought or asked for, newest first.
  List<Subscription> get clientSubscriptions => _clientSubs;

  /// Her answers to her coach on eating mean Home shows her no calorie target.
  /// The answer stays with the subscription, so it holds after the coaching
  /// ends.
  bool get hidesCalorieTargets =>
      _clientSubs.any((s) => s.intake?.eatingHistoryFlag ?? false);

  /// Her subscription that is running now, if any.
  Subscription? get activeAsClient =>
      _firstWhere(_clientSubs, (s) => s.status == SubscriptionStatus.active);

  /// Her subscription that is still open, the furthest along first: active,
  /// then payment review, then awaiting payment, then requested. Newest first
  /// within a status.
  Subscription? get currentAsClient {
    for (final status in const <SubscriptionStatus>[
      SubscriptionStatus.active,
      SubscriptionStatus.paymentReview,
      SubscriptionStatus.awaitingPayment,
      SubscriptionStatus.requested,
    ]) {
      final found = _firstWhere(_clientSubs, (s) => s.status == status);
      if (found != null) return found;
    }
    return null;
  }

  /// The plans her coaches shared.
  List<CoachPlan> get coachPlans => _plans;

  /// Every relationship she is part of, as a client or a coach.
  List<Relationship> get relationships => _relationships;

  /// The relationship with [relId], or null.
  Relationship? relationshipOf(String relId) {
    for (final r in _relationships) {
      if (r.id == relId) return r;
    }
    return null;
  }

  List<CoachPlan> coachPlansOf(PlanKind kind) => <CoachPlan>[
    for (final p in _plans)
      if (p.kind == kind) p,
  ];

  // --------------------------------------------------------- as a coach

  List<Subscription> get coachSubscriptions => _coachSubs;

  /// New requests, the oldest first.
  List<Subscription> get requests => _sorted(
    _coachSubs.where((s) => s.status == SubscriptionStatus.requested),
    (a, b) => _compareTime(a.createdAt, b.createdAt),
  );

  /// Clients who sent a payment proof that staff are checking.
  List<Subscription> get paymentReview => _sorted(
    _coachSubs.where((s) => s.status == SubscriptionStatus.paymentReview),
    (a, b) => _compareTime(a.statusAt, b.statusAt),
  );

  /// Clients being coached now, the ones ending first on top.
  List<Subscription> get activeClients => _sorted(
    _coachSubs.where((s) => s.status == SubscriptionStatus.active),
    (a, b) => _compareTime(a.endsAt, b.endsAt),
  );

  /// The chats where she is the coach.
  List<Relationship> get coachRelationships {
    final uid = _repository?.uid;
    if (uid == null) return const <Relationship>[];
    return <Relationship>[
      for (final r in _relationships)
        if (r.coachUid == uid) r,
    ];
  }

  /// Active clients with [CoachingLimits.endsSoonDays] days or fewer left.
  List<Subscription> get endingSoon => <Subscription>[
    for (final s in activeClients)
      if (s.endsSoon(_now())) s,
  ];

  // ------------------------------------------------------------------ chat

  /// Whether the chat has a line she has not read, by the server's counter on
  /// the relationship (no stream of its own per chat).
  bool hasUnread(String relId) {
    final uid = _repository?.uid;
    if (uid == null) return false;
    for (final r in _relationships) {
      if (r.id == relId) return r.unreadOf(uid) > 0;
    }
    return false;
  }

  /// How many chats have something unread.
  int get unreadChats => <Relationship>[
    for (final r in _relationships)
      if (hasUnread(r.id)) r,
  ].length;

  /// Marks the chat read: the server zeroes her counter and the relationship
  /// stream carries it back.
  Future<void> markRead(String relId) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.markRead(relId);
      if (_failures.remove('markRead') != null) AppChanges.bump();
    } on CoachingFailure catch (error) {
      _failures['markRead'] = error;
      AppChanges.bump();
    }
  }

  // --------------------------------------------------------------- helpers

  static Subscription? _firstWhere(
    List<Subscription> list,
    bool Function(Subscription) test,
  ) {
    for (final s in list) {
      if (test(s)) return s;
    }
    return null;
  }

  static List<Subscription> _sorted(
    Iterable<Subscription> items,
    int Function(Subscription, Subscription) compare,
  ) => (items.toList()..sort(compare));

  static int _compareTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
