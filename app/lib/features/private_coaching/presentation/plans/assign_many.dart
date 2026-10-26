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
