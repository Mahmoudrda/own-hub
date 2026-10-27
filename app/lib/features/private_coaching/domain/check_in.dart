/// The weekly check-in: what she answers, and how it reaches the server.
/// Same shape as `app_state/coach_invite_state.dart`: an interface, a callable
/// implementation, an in-memory one for tests and a build with no back end.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';

const String kSubmitCheckInCallable = 'submit_check_in';
const String kCoachNeedsAttentionCallable = 'coach_needs_attention';

enum TrainingAnswer { all, most, some, none }

class CheckInAnswers {
  const CheckInAnswers({
    required this.training,
    required this.energy,
    required this.food,
    required this.pain,
    this.note = '',
  });

  final TrainingAnswer training;
  final int energy;
  final int food;
  final bool pain;
  final String note;

  Map<String, Object> toWire() => <String, Object>{
    'training': training.name,
    'energy': energy,
    'food': food,
    'pain': pain,
    'note': note.trim(),
  };
}

enum CheckInResult { sent, alreadySent, failed }

abstract class CheckInStore {
  Future<CheckInResult> submit({
    required String relId,
    required String weekKey,
    required CheckInAnswers answers,
  });

  Future<List<AttentionRow>> needsAttention();
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
      return error.message == 'wrong_status'
          ? CheckInResult.alreadySent
          : CheckInResult.failed;
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
}
