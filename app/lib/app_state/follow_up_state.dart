/// What she has answered on the follow-ups, and how she set them.
///
/// Phone only: kept in the snapshot, wiped with the rest of her data, and not
/// part of the cloud backup or analytics.
library;

import '../domain/format/day_key.dart';
import '../features/followup/domain/follow_up_plan.dart';
import 'app_changes.dart';

/// Most day-after answers kept.
const int kFeelsKept = 60;

/// Most week reviews kept.
const int kWeekReviewsKept = 26;

class FollowUpState {
  FollowUpState._();

  static final FollowUpState instance = FollowUpState._();

  /// Her master switch.
  bool enabled = true;

  /// Kinds she asked not to see again.
  final Set<FollowUpKind> muted = <FollowUpKind>{};

  /// Per kind, the first day it may show again.
  final Map<FollowUpKind, String> notBefore = <FollowUpKind, String>{};

  /// How she felt after a session, by the day of the session.
  final Map<String, Feel> feels = <String, Feel>{};

  /// Her week reviews, by the Saturday the week started on.
  final Map<String, WeekReviewAnswer> weekReviews =
      <String, WeekReviewAnswer>{};

  /// Whether anything has been answered or set, for the snapshot.
  bool get touched =>
      !enabled ||
      muted.isNotEmpty ||
      notBefore.isNotEmpty ||
      feels.isNotEmpty ||
      weekReviews.isNotEmpty;

  void answerFeel(String dateKey, Feel feel) {
    feels[dateKey] = feel;
    _keepNewest(feels, kFeelsKept);
    AppChanges.bump();
  }

  void answerWeek(String weekStartKey, WeekReviewAnswer answer) {
    weekReviews[weekStartKey] = answer;
    _keepNewest(weekReviews, kWeekReviewsKept);
    AppChanges.bump();
  }

  /// Hides [kind] until tomorrow.
  void notNow(FollowUpKind kind, String todayKey) {
    final today = DateTime.tryParse(todayKey);
    if (today == null) return;
    notBefore[kind] = dayKey(DateTime(today.year, today.month, today.day + 1));
    AppChanges.bump();
  }

  /// Stops [kind] for good.
  void mute(FollowUpKind kind) {
    muted.add(kind);
    AppChanges.bump();
  }

  /// Lets [kind] show again.
  void unmute(FollowUpKind kind) {
    if (muted.remove(kind)) AppChanges.bump();
  }

  void setEnabled(bool value) {
    enabled = value;
    AppChanges.bump();
  }

  /// Puts back what the snapshot held.
  void restore({
    required bool enabled,
    Set<FollowUpKind> muted = const <FollowUpKind>{},
    Map<FollowUpKind, String> notBefore = const <FollowUpKind, String>{},
    Map<String, Feel> feels = const <String, Feel>{},
    Map<String, WeekReviewAnswer> weekReviews =
        const <String, WeekReviewAnswer>{},
  }) {
    this.enabled = enabled;
    this.muted
      ..clear()
      ..addAll(muted);
    this.notBefore
      ..clear()
      ..addAll(notBefore);
    this.feels
      ..clear()
      ..addAll(feels);
    _keepNewest(this.feels, kFeelsKept);
    this.weekReviews
      ..clear()
      ..addAll(weekReviews);
    _keepNewest(this.weekReviews, kWeekReviewsKept);
  }

  /// Account deletion, and tests.
  void reset() {
    enabled = true;
    muted.clear();
    notBefore.clear();
    feels.clear();
    weekReviews.clear();
  }

  /// Drops the oldest keys (day ids sort in time order) down to [keep].
  static void _keepNewest(Map<String, Object?> map, int keep) {
    if (map.length <= keep) return;
    final oldest = (map.keys.toList()..sort()).take(map.length - keep);
    oldest.toList().forEach(map.remove);
  }
}
