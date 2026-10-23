/// A coaching call or write that did not go through, as a typed refusal.
library;

import 'chat_screen.dart';
import 'coaching_contract.dart';

class CoachingFailure implements Exception {
  const CoachingFailure(this.refusal, {this.screen});

  /// A chat text the screen refused before it was sent.
  CoachingFailure.screened(ChatScreenReason reason)
    : this(CoachingRefusal.messageBlocked, screen: reason);

  final CoachingRefusal refusal;

  /// Set when [refusal] is [CoachingRefusal.messageBlocked].
  final ChatScreenReason? screen;

  /// The server answers `HttpsError(code, reason)`: the reason is the
  /// message. A callable status that means "could not reach it" is
  /// [CoachingRefusal.unreachable]; anything else we cannot read is
  /// [CoachingRefusal.unknown].
  factory CoachingFailure.fromCallable(String code, String? message) {
    final byReason = CoachingRefusal.fromCode(message);
    if (byReason != CoachingRefusal.unknown) return CoachingFailure(byReason);
    return CoachingFailure(switch (code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'cancelled' => CoachingRefusal.unreachable,
      'unauthenticated' => CoachingRefusal.signedOut,
      _ => CoachingRefusal.unknown,
    });
  }

  /// A storage or Firestore error code: `unavailable`, `permission-denied`...
  factory CoachingFailure.fromStore(String code) =>
      CoachingFailure(switch (code) {
        'unavailable' ||
        'deadline-exceeded' ||
        'retry-limit-exceeded' ||
        'network-request-failed' => CoachingRefusal.unreachable,
        'unauthenticated' || 'not-authenticated' => CoachingRefusal.signedOut,
        _ => CoachingRefusal.unknown,
      });

  @override
  String toString() => 'CoachingFailure(${refusal.code})';
}
