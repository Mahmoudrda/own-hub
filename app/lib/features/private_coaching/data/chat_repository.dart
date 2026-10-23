/// What a chat thread needs beyond [CoachingRepository]: the other party's
/// read marker, the cheap "mark read" callable and reporting one line.
/// `FirestoreCoachingRepository` implements both.
library;

import '../domain/chat_message.dart';
import 'coaching_repository.dart';

abstract interface class ChatThreadRepository implements CoachingRepository {
  /// When the other party last read this chat (one small document).
  Stream<DateTime?> watchOtherReadAt(String relId, String otherUid);

  /// Marks the thread read and zeroes her unread count in one server write.
  /// Called when a thread opens and, debounced, when lines arrive while it is
  /// open.
  Future<void> markThreadRead(String relId);

  /// Reports one chat line: one write to `reports/{id}` with
  /// `subjectKind: coachMessage`. [reason] is one of
  /// `CoachingEnums.reportReasons`.
  Future<void> reportMessage({
    required String relId,
    required ChatMessage message,
    required String reason,
    String note,
    required String locale,
  });
}
