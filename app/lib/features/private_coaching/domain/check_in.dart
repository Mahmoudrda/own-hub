/// The weekly check-in: what she answers, and how it reaches the server.
/// Same shape as `app_state/coach_invite_state.dart`: an interface, a callable
/// implementation, an in-memory one for tests and a build with no back end.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';
import '../../../domain/week/week_key.dart';
import '../../train/domain/my_plan.dart' show kCoachPlanId;
import '../../train/domain/train_repository.dart';
import 'parse.dart';

const String kSubmitCheckInCallable = 'submit_check_in';
const String kCoachNeedsAttentionCallable = 'coach_needs_attention';
const String kListCheckInsCallable = 'list_check_ins';
const String kReplyCheckInCallable = 'reply_check_in';

/// What the server accepts for the two optional numbers (checkins.py).
const double kCheckInWeightMinKg = 30;
const double kCheckInWeightMaxKg = 300;
const int kCheckInReplyMax = 400;
const int kCheckInWorkoutsMax = 14;

enum TrainingAnswer { all, most, some, none }

class CheckInAnswers {
  const CheckInAnswers({
    required this.training,
    required this.energy,
    required this.food,
    required this.pain,
    this.note = '',
    this.weightKg,
    this.workoutsDone,
  });

  final TrainingAnswer training;
  final int energy;
  final int food;
  final bool pain;
  final String note;

  /// Health data: only there when she ticked "share with my coach".
  final double? weightKg;

  /// The coach-plan workouts she finished that week, sent only when she
  /// agreed to share them.
  final int? workoutsDone;

  Map<String, Object> toWire() => <String, Object>{
    'training': training.name,
    'energy': energy,
    'food': food,
    'pain': pain,
    'note': note.trim(),
    'weightKg': ?weightKg,
    // Her tick, sent with the weight: the server keeps it with the check-in.
    if (weightKg != null) 'weightConsent': true,
    'workoutsDone': ?workoutsDone,
  };
}

/// How many sessions of her coach's plan she finished in the ISO week
/// [weekKey] (`2026-W44`): completed, not given up, started from the coach's
/// plan (its `planVersion` begins with [kCoachPlanId]).
int coachWorkoutsInWeek(Iterable<TrainSession> history, String weekKey) {
  var done = 0;
  for (final s in history) {
    if (!s.completed ||
        s.endedReason == EndedReason.abandoned ||
        !(s.planVersion ?? '').startsWith('$kCoachPlanId@')) {
      continue;
    }
    final day = DateTime.tryParse(s.dateKey);
    if (day != null && WeekKey.of(day).id == weekKey) done++;
  }
  // The server takes 0 to 14.
  return done > kCheckInWorkoutsMax ? kCheckInWorkoutsMax : done;
}

/// What `reply_check_in` takes.
Map<String, Object> replyRequest({
  required String relId,
  required String weekKey,
  required String text,
}) => <String, Object>{'relId': relId, 'weekKey': weekKey, 'text': text.trim()};

/// One answered week as either person reads it.
class CheckInCard {
  const CheckInCard({
    required this.weekKey,
    required this.answers,
    this.reply = '',
    this.answeredAt,
  });

  final String weekKey;
  final CheckInAnswers answers;

  /// When she answered; the history is headed by this day, not by the week key.
  final DateTime? answeredAt;

  /// Her coach's reply; empty until she writes one.
  final String reply;

  static CheckInCard? fromWire(Object? raw) {
    final map = asMap(raw);
    final answers = asMap(map?['answers']);
    final training = TrainingAnswer.values.where(
      (t) => t.name == answers?['training'],
    );
    if (map == null || answers == null || training.isEmpty) return null;
    final weight = answers['weightKg'];
    final workouts = answers['workoutsDone'];
    return CheckInCard(
      weekKey: readString(map['weekKey']),
      answers: CheckInAnswers(
        training: training.first,
        energy: readInt(answers['energy']),
        food: readInt(answers['food']),
        pain: answers['pain'] == true,
        note: readString(answers['note']),
        weightKg: weight is num ? weight.toDouble() : null,
        workoutsDone: workouts is int ? workouts : null,
      ),
      reply: readString(map['reply']),
      answeredAt: readTime(map['answeredAt']),
    );
  }
}

enum CheckInResult { sent, alreadySent, containsContact, failed }

/// What became of a coach's reply. [containsContact]: the server refused a
/// phone number, link or handle in it.
enum CheckInReply { sent, containsContact, failed }

abstract class CheckInStore {
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  });

  Future<List<AttentionRow>> needsAttention();

  /// The last weeks she answered in this coaching, newest first. Empty when
  /// there are none or they could not be read.
  Future<List<CheckInCard>> history(String relId);

  /// Her coach's reply to an answered week.
  Future<CheckInReply> reply({
    required String relId,
    required String weekKey,
    required String text,
  });
}

/// One client on the coach's "Needs attention" list.
class AttentionRow {
  const AttentionRow({
    required this.subId,
    required this.relId,
    required this.clientName,
    required this.reasons,
    this.pain = false,
    this.note = '',
  });

  final String subId;
  final String relId;
  final String clientName;

  /// Wire names: noCheckIn, missedSessions, healthFlag, unread.
  final List<String> reasons;

  /// What she said in her latest check-in: any pain or injury, and her note.
  final bool pain;
  final String note;
}

class CheckIns {
  CheckIns._();

  static CheckInStore? override;
  static CheckInStore get store =>
      override ??
      (FirebaseBoot.isReady ? CallableCheckInStore() : InMemoryCheckInStore());

  /// Weeks answered in this session, so the card can say so.
  static final Set<String> answeredThisSession = <String>{};
}

class CallableCheckInStore implements CheckInStore {
  CallableCheckInStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
  );

  @override
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  }) async {
    try {
      await _callable(kSubmitCheckInCallable).call<Object?>(<String, Object>{
        'relId': relId,
        'weekKey': weekKey,
        'answers': answers.toWire(),
      });
      return CheckInResult.sent;
    } on FirebaseFunctionsException catch (error) {
      return switch (error.message) {
        'wrong_status' => CheckInResult.alreadySent,
        'contains_contact' => CheckInResult.containsContact,
        _ => CheckInResult.failed,
      };
    } catch (_) {
      return CheckInResult.failed;
    }
  }

  @override
  Future<List<AttentionRow>> needsAttention() async {
    try {
      final result = await _callable(kCoachNeedsAttentionCallable)
          .call<Object?>(<String, Object>{});
      final data = result.data;
      final list = data is Map ? data['clients'] : null;
      if (list is! List) return const <AttentionRow>[];
      return <AttentionRow>[
        for (final raw in list)
          if (raw is Map) attentionRowFromWire(raw),
      ];
    } catch (_) {
      return const <AttentionRow>[];
    }
  }

  @override
  Future<List<CheckInCard>> history(String relId) async {
    try {
      final result = await _callable(kListCheckInsCallable)
          .call<Object?>(<String, Object>{'relId': relId});
      final data = result.data;
      final list = data is Map ? data['checkIns'] : null;
      if (list is! List) return const <CheckInCard>[];
      return <CheckInCard>[for (final raw in list) ?CheckInCard.fromWire(raw)];
    } catch (_) {
      return const <CheckInCard>[];
    }
  }

  @override
  Future<CheckInReply> reply({
    required String relId,
    required String weekKey,
    required String text,
  }) async {
    try {
      await _callable(
        kReplyCheckInCallable,
      ).call<Object?>(replyRequest(relId: relId, weekKey: weekKey, text: text));
      return CheckInReply.sent;
    } on FirebaseFunctionsException catch (error) {
      return error.message == 'contains_contact'
          ? CheckInReply.containsContact
          : CheckInReply.failed;
    } catch (_) {
      return CheckInReply.failed;
    }
  }
}

AttentionRow attentionRowFromWire(Map<Object?, Object?> raw) {
  final checkIn = raw['checkIn'];
  final answers = checkIn is Map ? checkIn['answers'] : null;
  return AttentionRow(
    subId: '${raw['subId']}',
    relId: '${raw['relId']}',
    clientName: '${raw['clientName'] ?? ''}',
    reasons: <String>[
      for (final r
          in (raw['reasons'] is List ? raw['reasons'] as List : const []))
        '$r',
    ],
    pain: answers is Map && answers['pain'] == true,
    note: answers is Map ? '${answers['note'] ?? ''}'.trim() : '',
  );
}

class InMemoryCheckInStore implements CheckInStore {
  InMemoryCheckInStore({this.rows = const <AttentionRow>[]});

  final List<AttentionRow> rows;
  final List<CheckInAnswers> sent = <CheckInAnswers>[];
  CheckInResult result = CheckInResult.sent;

  /// What [history] returns, and what [reply] was asked to send.
  List<CheckInCard> cards = <CheckInCard>[];
  final List<({String weekKey, String text})> replies =
      <({String weekKey, String text})>[];
  CheckInReply replyOutcome = CheckInReply.sent;

  @override
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  }) async {
    if (result == CheckInResult.sent) sent.add(answers);
    return result;
  }

  @override
  Future<List<AttentionRow>> needsAttention() async => rows;

  @override
  Future<List<CheckInCard>> history(String relId) async => cards;

  @override
  Future<CheckInReply> reply({
    required String relId,
    required String weekKey,
    required String text,
  }) async {
    if (replyOutcome == CheckInReply.sent) {
      replies.add((weekKey: weekKey, text: text.trim()));
    }
    return replyOutcome;
  }
}
