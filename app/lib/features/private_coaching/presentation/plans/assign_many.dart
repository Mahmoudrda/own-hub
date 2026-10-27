/// Sends one plan to several clients, one call each, and keeps going when one
/// call fails. Nothing is retried here: the caller offers a retry for the
/// failures only.
library;

import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';

class AssignOutcome {
  const AssignOutcome({
    this.sent = const <String>[],
    this.failed = const <String, CoachingFailure>{},
  });

  final List<String> sent;

  /// Sub id to why it was not sent.
  final Map<String, CoachingFailure> failed;

  bool get allSent => failed.isEmpty;
}

Future<AssignOutcome> publishToMany({
  required List<String> subIds,
  required Future<void> Function(String subId) send,
}) async {
  final sent = <String>[];
  final failed = <String, CoachingFailure>{};
  for (final id in subIds) {
    try {
      await send(id);
      sent.add(id);
    } on CoachingFailure catch (failure) {
      failed[id] = failure;
    } catch (_) {
      failed[id] = const CoachingFailure(CoachingRefusal.unreachable);
    }
  }
  return AssignOutcome(sent: sent, failed: failed);
}

/// Whether sending again can work. A refusal that needs the coach to act first
/// (her client's health answers, a subscription that has ended) would only
/// fail the same way, so no Retry is offered for it.
bool canRetryAssign(CoachingFailure failure) =>
    failure.refusal == CoachingRefusal.unreachable ||
    failure.refusal == CoachingRefusal.unknown;

/// Who has the plan and who has not, across the first send and its retries.
/// A client who has it is never sent it again; a Retry goes only to the
/// failures a second try can fix, and the others stay listed with their reason.
class AssignProgress {
  final Set<String> sent = <String>{};
  Map<String, CoachingFailure> failed = <String, CoachingFailure>{};

  bool get allSent => failed.isEmpty;

  /// The failures [can] says a second try may fix.
  List<String> retryable(bool Function(CoachingFailure) can) => [
    for (final e in failed.entries)
      if (can(e.value)) e.key,
  ];

  /// First time: every client in [chosen] not yet sent. After a failure: the
  /// retryable ones only.
  List<String> toSend(
    List<String> chosen,
    bool Function(CoachingFailure) can,
  ) => failed.isEmpty
      ? [
          for (final id in chosen)
            if (!sent.contains(id)) id,
        ]
      : retryable(can);

  void record(AssignOutcome outcome, bool Function(CoachingFailure) can) {
    final stuck = {
      for (final e in failed.entries)
        if (!can(e.value)) e.key: e.value,
    };
    sent.addAll(outcome.sent);
    failed = {...stuck, ...outcome.failed};
  }
}
