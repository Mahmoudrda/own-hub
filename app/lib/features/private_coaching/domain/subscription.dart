/// A client's subscription to a coach, the intake she sends with the request,
/// and the live sessions inside it.
///
/// Only the server writes the status. The helpers here read what the server
/// wrote and say what she may do next; the server checks it again.
library;

import 'chat_message.dart' show MessageType;
import 'coach_profile.dart' show PackageSnapshot;
import 'coaching_contract.dart';
import 'parse.dart';
import 'payments.dart';
import 'pricing.dart' as pricing;

/// What she tells the coach, and the seven health questions.
class Intake {
  const Intake({
    this.goal = '',
    this.level = '',
    this.daysPerWeek = 0,
    this.place = '',
    this.allergies = const <String>[],
    this.lifeStage,
    this.health = const <String, bool>{},
    this.doctorAck = false,
    this.note = '',
  });

  final String goal;
  final String level;
  final int daysPerWeek;
  final String place;
  final List<String> allergies;
  final String? lifeStage;

  /// Question id to her yes or no. All seven are sent.
  final Map<String, bool> health;
  final bool doctorAck;
  final String note;

  static const int allergiesMax = 16;
  static const int allergyMax = 30;

  bool get answeredAllHealth =>
      CoachingEnums.healthQuestions.every(health.containsKey);

  bool get anyHealthYes => health.values.any((yes) => yes);

  /// A yes means she ticks "I will check with my doctor"; the coach then
  /// accepts by hand.
  bool get needsDoctorAck => anyHealthYes;

  Intake copyWith({
    String? goal,
    String? level,
    int? daysPerWeek,
    String? place,
    List<String>? allergies,
    String? lifeStage,
    bool clearLifeStage = false,
    Map<String, bool>? health,
    bool? doctorAck,
    String? note,
  }) => Intake(
    goal: goal ?? this.goal,
    level: level ?? this.level,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    place: place ?? this.place,
    allergies: allergies ?? this.allergies,
    lifeStage: clearLifeStage ? null : (lifeStage ?? this.lifeStage),
    health: health ?? this.health,
    doctorAck: doctorAck ?? this.doctorAck,
    note: note ?? this.note,
  );

  /// Reads a stored intake. The health answers may be a map by question or a
  /// list of seven in the contract's order.
  factory Intake.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    final rawHealth = map['health'];
    final health = <String, bool>{};
    if (rawHealth is Map) {
      for (final id in CoachingEnums.healthQuestions) {
        final answer = rawHealth[id];
        if (answer is bool) health[id] = answer;
      }
    } else if (rawHealth is List) {
      for (var i = 0; i < CoachingEnums.healthQuestions.length; i++) {
        if (i < rawHealth.length && rawHealth[i] is bool) {
          health[CoachingEnums.healthQuestions[i]] = rawHealth[i] as bool;
        }
      }
    }
    return Intake(
      goal: readString(map['goal']),
      level: readString(map['level']),
      daysPerWeek: readInt(map['daysPerWeek']),
      place: readString(map['place']),
      allergies: readStrings(map['allergies']),
      lifeStage: readStringOrNull(map['lifeStage']),
      health: health,
      doctorAck: readBool(map['doctorAck']),
      note: readString(map['note']),
    );
  }

  /// The fields the server would refuse, by key.
  List<String> problems() {
    final out = <String>[];
    if (!CoachingEnums.goals.contains(goal)) out.add('goal');
    if (!CoachingEnums.levels.contains(level)) out.add('level');
    if (daysPerWeek < 1 || daysPerWeek > 7) out.add('daysPerWeek');
    if (!CoachingEnums.places.contains(place)) out.add('place');
    if (allergies.length > allergiesMax ||
        allergies.any(
          (a) => a.trim().isEmpty || a.trim().length > allergyMax,
        )) {
      out.add('allergies');
    }
    final stage = lifeStage;
    if (stage != null && (stage.trim().isEmpty || stage.length > 30)) {
      out.add('lifeStage');
    }
    if (!answeredAllHealth) out.add('health');
    if (needsDoctorAck && !doctorAck) out.add('doctorAck');
    if (note.trim().length > CoachingLimits.noteMax) out.add('note');
    return out;
  }

  bool get isValid => problems().isEmpty;

  Json toRequest() => <String, Object?>{
    'goal': goal,
    'level': level,
    'daysPerWeek': daysPerWeek,
    'place': place,
    'allergies': <String>[for (final a in allergies) a.trim()],
    'lifeStage': ?lifeStage,
    'health': <String, bool>{
      for (final id in CoachingEnums.healthQuestions) id: health[id] ?? false,
    },
    'doctorAck': doctorAck,
    'note': note.trim(),
  };
}

class PaymentState {
  const PaymentState({
    this.stage,
    this.attempts = 0,
    this.lastReason,
    this.proofId,
  });

  /// Null for a stage this build does not know.
  final PaymentStage? stage;
  final int attempts;

  /// Why staff rejected the last proof.
  final ProofRejectReason? lastReason;
  final String? proofId;

  factory PaymentState.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return PaymentState(
      stage: PaymentStage.fromWire(map['state']),
      attempts: readInt(map['attempts']),
      lastReason: ProofRejectReason.fromWire(map['lastReason']),
      proofId: readStringOrNull(map['proofId']),
    );
  }
}

class CancellationInfo {
  const CancellationInfo({
    required this.state,
    this.requestedAt,
    this.refundEgp,
  });

  final CancellationState state;
  final DateTime? requestedAt;
  final int? refundEgp;

  static CancellationInfo? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final state = CancellationState.fromWire(map['state']);
    if (state == null) return null;
    return CancellationInfo(
      state: state,
      requestedAt: readTime(map['requestedAt']),
      refundEgp: readIntOrNull(map['refundEgp']),
    );
  }
}

class Subscription {
  const Subscription({
    required this.id,
    required this.coachUid,
    required this.clientUid,
    required this.status,
    this.relId = '',
    this.packageId = '',
    this.package = const PackageSnapshot(),
    this.priceFinalEgp = 0,
    this.intake,
    this.payTo,
    this.paymentCode,
    this.payBy,
    this.payment = const PaymentState(),
    this.sessionsIncluded = 0,
    this.sessionsUsed = 0,
    this.startsAt,
    this.endsAt,
    this.cancellation,
    this.refund,
    this.endReason,
    this.createdAt,
    this.statusAt,
    this.acceptedAt,
    this.clientName = '',
    this.nextSessionAt,
  });

  final String id;
  final String coachUid;
  final String clientUid;
  final SubscriptionStatus status;
  final String relId;
  final String packageId;
  final PackageSnapshot package;
  final int priceFinalEgp;
  final Intake? intake;
  final ReceivingAccounts? payTo;
  final String? paymentCode;
  final DateTime? payBy;
  final PaymentState payment;
  final int sessionsIncluded;
  final int sessionsUsed;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final CancellationInfo? cancellation;
  final RefundInfo? refund;
  final String? endReason;
  final DateTime? createdAt;
  final DateTime? statusAt;
  final DateTime? acceptedAt;

  /// The name the client gave Own Hub, for the coach's lists. Empty when the
  /// server wrote none.
  final String clientName;

  /// When her next live session starts, if one is booked.
  final DateTime? nextSessionAt;

  /// Null when the document is missing the parties or a known status.
  static Subscription? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final status = SubscriptionStatus.fromWire(map['status']);
    final coachUid = readString(map['coachUid']);
    final clientUid = readString(map['clientUid']);
    if (status == null || coachUid.isEmpty || clientUid.isEmpty) return null;
    return Subscription(
      id: id,
      coachUid: coachUid,
      clientUid: clientUid,
      status: status,
      relId: readString(
        map['relId'],
        CoachingIds.relationshipId(coachUid, clientUid),
      ),
      packageId: readString(map['packageId']),
      package: PackageSnapshot.fromMap(map['package']),
      priceFinalEgp: readInt(map['priceFinalEgp']),
      intake: map['intake'] == null ? null : Intake.fromMap(map['intake']),
      payTo: map['payTo'] == null
          ? null
          : ReceivingAccounts.fromMap(map['payTo']),
      paymentCode: readStringOrNull(map['paymentCode']),
      payBy: readTime(map['payBy']),
      payment: PaymentState.fromMap(map['payment']),
      sessionsIncluded: readInt(map['sessionsIncluded']),
      sessionsUsed: readInt(map['sessionsUsed']),
      startsAt: readTime(map['startsAt']),
      endsAt: readTime(map['endsAt']),
      cancellation: CancellationInfo.fromMap(map['cancellation']),
      refund: RefundInfo.fromMap(map['refund']),
      endReason: readStringOrNull(map['endReason']),
      createdAt: readTime(map['createdAt']),
      statusAt: readTime(map['statusAt']),
      acceptedAt: readTime(map['acceptedAt']),
      clientName: readString(map['clientName']).trim(),
      nextSessionAt: readTime(map['nextSessionAt']),
    );
  }

  /// Requested, awaiting payment, in payment review, or active.
  bool get isOpen => CoachingEnums.subscriptionOpen.contains(status.wire);

  bool get isActive => status == SubscriptionStatus.active;

  /// She may withdraw it until staff are checking the payment.
  bool get canCancelRequest =>
      status == SubscriptionStatus.requested ||
      status == SubscriptionStatus.awaitingPayment;

  bool payByPassed(DateTime now) {
    final by = payBy;
    return by != null && now.isAfter(by);
  }

  /// She may send a proof: payment is awaited, the deadline has not passed and
  /// she has attempts left.
  bool canSendProof(DateTime now) =>
      status == SubscriptionStatus.awaitingPayment &&
      payBy != null &&
      !payByPassed(now) &&
      payment.attempts < CoachingLimits.proofAttempts;

  int get proofAttemptsLeft => (CoachingLimits.proofAttempts - payment.attempts)
      .clamp(0, CoachingLimits.proofAttempts);

  /// The last moment she can cancel with a refund.
  DateTime? get cancelWindowEnds =>
      startsAt?.add(const Duration(days: CoachingLimits.cancelWindowDays));

  bool inCancelWindow(DateTime now) {
    final end = cancelWindowEnds;
    return isActive && end != null && !now.isAfter(end);
  }

  /// She may ask to cancel: active, in the window, none asked yet.
  bool canRequestCancellation(DateTime now) =>
      inCancelWindow(now) && cancellation == null;

  /// Whole days left, counting a part day as a day. Null unless it is active.
  int? daysLeft(DateTime now) {
    final end = endsAt;
    if (!isActive || end == null) return null;
    final left = end.difference(now);
    if (left.isNegative) return 0;
    return (left.inMinutes + 1439) ~/ 1440;
  }

  bool endsSoon(DateTime now) {
    final days = daysLeft(now);
    return days != null && days <= CoachingLimits.endsSoonDays;
  }

  int get sessionsLeft =>
      (sessionsIncluded - sessionsUsed).clamp(0, sessionsIncluded);

  /// What she would get back if she cancelled now.
  int refundIfCancelled() =>
      pricing.refundAmount(priceFinalEgp, sessionsUsed, sessionsIncluded);
}

class LiveSession {
  const LiveSession({
    required this.id,
    required this.status,
    this.startsAt,
    this.minutes = 0,
    this.link = '',
    this.proposedBy = '',
    this.doneBy = const <String>[],
    this.createdAt,
    this.statusAt,
  });

  final String id;
  final SessionStatus status;
  final DateTime? startsAt;
  final int minutes;
  final String link;
  final String proposedBy;
  final List<String> doneBy;
  final DateTime? createdAt;
  final DateTime? statusAt;

  static LiveSession? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final status = SessionStatus.fromWire(map['status']);
    if (status == null) return null;
    final done = map['doneBy'];
    return LiveSession(
      id: id,
      status: status,
      startsAt: readTime(map['startsAt']),
      minutes: readInt(map['minutes']),
      link: readString(map['link']),
      proposedBy: readString(map['proposedBy']),
      doneBy: done is String ? <String>[done] : readStrings(done),
      createdAt: readTime(map['createdAt']),
      statusAt: readTime(map['statusAt']),
    );
  }

  /// Whether [uid] has already marked it done.
  bool doneByMe(String uid) => doneBy.contains(uid);

  /// [uid] has marked it done and the other party has not yet. It counts as
  /// used only when both have.
  bool waitingForOther(String uid) =>
      doneBy.contains(uid) && status != SessionStatus.done;

  /// She may mark it done once a confirmed session has started.
  bool canMarkDone(DateTime now) {
    final at = startsAt;
    return status == SessionStatus.confirmed && at != null && !now.isBefore(at);
  }

  bool get isUpcoming =>
      status == SessionStatus.proposed || status == SessionStatus.confirmed;
}

/// `relationships/{coachUid}__{clientUid}`.
class Relationship {
  const Relationship({
    required this.id,
    required this.coachUid,
    required this.clientUid,
    required this.status,
    this.chatOpen = false,
    this.activeSubId,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadFor = const <String, int>{},
  });

  final String id;
  final String coachUid;
  final String clientUid;
  final RelationshipStatus status;
  final bool chatOpen;
  final String? activeSubId;
  final DateTime? lastMessageAt;

  /// The newest line, as the server copied it for the chat list.
  final LastMessage? lastMessage;

  /// How many lines each party has not read yet, by uid.
  final Map<String, int> unreadFor;

  /// How many lines [uid] has not read.
  int unreadOf(String uid) => unreadFor[uid] ?? 0;

  /// The other party, seen from [myUid].
  String otherParty(String myUid) => myUid == coachUid ? clientUid : coachUid;

  static Relationship? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final status = RelationshipStatus.fromWire(map['status']);
    final coachUid = readString(map['coachUid']);
    final clientUid = readString(map['clientUid']);
    if (status == null || coachUid.isEmpty || clientUid.isEmpty) return null;
    return Relationship(
      id: id,
      coachUid: coachUid,
      clientUid: clientUid,
      status: status,
      chatOpen: readBool(map['chatOpen']),
      activeSubId: readStringOrNull(map['activeSubId']),
      lastMessageAt: readTime(map['lastMessageAt']),
      lastMessage: LastMessage.fromMap(map['lastMessage']),
      unreadFor: _readCounts(map['unreadFor']),
    );
  }

  static Map<String, int> _readCounts(Object? raw) {
    final map = asMap(raw);
    if (map == null) return const <String, int>{};
    return <String, int>{
      for (final entry in map.entries)
        if (readInt(entry.value) > 0) entry.key: readInt(entry.value),
    };
  }
}

/// The newest line of a chat: `relationships/{id}.lastMessage`.
class LastMessage {
  const LastMessage({
    this.text = '',
    this.type = MessageType.text,
    this.senderUid = '',
    this.at,
  });

  /// At most 80 characters, cut by the server.
  final String text;
  final MessageType type;
  final String senderUid;
  final DateTime? at;

  static LastMessage? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    return LastMessage(
      text: readString(map['text']),
      type: MessageType.fromWire(map['type']) ?? MessageType.text,
      senderUid: readString(map['senderUid']),
      at: readTime(map['at']),
    );
  }
}
