/// The woman reviewers she can name, the times they are free, and booking one.
///
/// `list_reviewers`, `list_review_slots` and `book_review_slot`. Times travel as UTC ISO strings and are
/// shown in her phone's time zone by the screen. A callable that is not
/// deployed yet, or a poor connection, surfaces as a [ReviewSchedulingFailure]
/// the screens turn into one honest line; nothing here pretends a time was
/// booked that the server did not confirm.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:meta/meta.dart';

import '../../../app_state/firebase_boot.dart';

const String kListReviewersCallable = 'list_reviewers';
const String kListReviewSlotsCallable = 'list_review_slots';
const String kBookReviewSlotCallable = 'book_review_slot';

/// A reviewer who chose to be listed. First name only.
@immutable
class ListedReviewer {
  const ListedReviewer({required this.reviewerId, required this.firstName});

  final String reviewerId;
  final String firstName;

  @override
  bool operator ==(Object other) =>
      other is ListedReviewer &&
      other.reviewerId == reviewerId &&
      other.firstName == firstName;

  @override
  int get hashCode => Object.hash(reviewerId, firstName);
}

/// One free time with one reviewer.
@immutable
class ReviewSlot {
  const ReviewSlot({required this.reviewerId, required this.start});

  final String reviewerId;
  final DateTime start;

  @override
  bool operator ==(Object other) =>
      other is ReviewSlot &&
      other.reviewerId == reviewerId &&
      other.start == start;

  @override
  int get hashCode => Object.hash(reviewerId, start);
}

/// The call did not complete, or the answer could not be read.
class ReviewSchedulingFailure implements Exception {
  const ReviewSchedulingFailure([this.code = 'unavailable']);

  final String code;

  @override
  String toString() => 'ReviewSchedulingFailure($code)';
}

abstract class ReviewSchedulingRepository {
  /// Reviewers who set themselves as listed.
  Future<List<ListedReviewer>> listReviewers();

  /// Free slots over the next [days] days, soonest first.
  Future<List<ReviewSlot>> listSlots({int days = 7});

  /// Books [slot]; booking again replaces the old time. Returns the time the
  /// server confirmed.
  Future<DateTime> book(ReviewSlot slot);
}

/// What a build with no back end holds: every call fails.
class UnavailableReviewScheduling implements ReviewSchedulingRepository {
  const UnavailableReviewScheduling();

  @override
  Future<List<ListedReviewer>> listReviewers() async =>
      throw const ReviewSchedulingFailure();

  @override
  Future<List<ReviewSlot>> listSlots({int days = 7}) async =>
      throw const ReviewSchedulingFailure();

  @override
  Future<DateTime> book(ReviewSlot slot) async =>
      throw const ReviewSchedulingFailure();
}

class CallableReviewScheduling implements ReviewSchedulingRepository {
  CallableReviewScheduling({FirebaseFunctions? functions})
    : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseBoot.functions;

  Future<Object?> _call(String name, Map<String, Object?> body) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final response = await callable.call<Object?>(body);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      throw ReviewSchedulingFailure(error.code);
    } catch (_) {
      throw const ReviewSchedulingFailure();
    }
  }

  static List<Object?> _rows(Object? data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    throw const ReviewSchedulingFailure('bad-answer');
  }

  @override
  Future<List<ListedReviewer>> listReviewers() async {
    final rows = _rows(await _call(kListReviewersCallable, const {}));
    return [
      for (final row in rows)
        if (row case {
          'reviewerId': final String id,
          'firstName': final String name,
        })
          ListedReviewer(reviewerId: id, firstName: name),
    ];
  }

  @override
  Future<List<ReviewSlot>> listSlots({int days = 7}) async {
    final rows = _rows(await _call(kListReviewSlotsCallable, {'days': days}));
    final slots = <ReviewSlot>[
      for (final row in rows)
        if (row case {
          'reviewerId': final String id,
          'start': final String start,
        })
          if (DateTime.tryParse(start) case final at?)
            ReviewSlot(reviewerId: id, start: at.toUtc()),
    ];
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  @override
  Future<DateTime> book(ReviewSlot slot) async {
    final data = await _call(kBookReviewSlotCallable, {
      'reviewerId': slot.reviewerId,
      'start': slot.start.toUtc().toIso8601String(),
    });
    final raw = data is Map ? data['scheduledFor'] : null;
    final at = raw is String ? DateTime.tryParse(raw) : null;
    if (at == null) throw const ReviewSchedulingFailure('bad-answer');
    return at.toUtc();
  }
}
