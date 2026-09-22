/// B12, and the reason it renders nothing.
///
/// ## Deferred, by owner decision
///
/// There is **no ratified storage** for `coaches/{coachUid}/insights/*` — G13
/// §10 Q2 asks the spine owner to ratify or relocate it and has no answer — and
/// there are **no view or enquiry beacons**, because those fire on H02, H03 and
/// H06, which are G11's screens (Q11). Built as specified today, B12 would read
/// a document that does not exist and draw `0 views · 0 opened · 0 enquiries`
/// under the heading "Last 30 days".
///
/// A screen of zeros is not a neutral placeholder. It tells a coach her page is
/// being seen by nobody, which is a statement about her work, and it is not
/// true — it is a statement about our telemetry. So B12 ships behind
/// [kPortfolioInsightsEnabled], which is `false`, and the screen states plainly
/// that the figures are not being counted yet.
///
/// This is the same posture `progress_view.dart` takes for the tier ladder:
/// *"A tier bar drawn against an invented threshold would tell a woman she is
/// 70% of the way to something nobody has defined."*
///
/// ## Nothing is ranked, and there is no streak
///
/// Two absences, both load-bearing and both tested:
///
///   * **No consecutive-day field exists.** Not `streak`, not `daysInARow`, not
///     `currentRun`. "Live 14 days in a row" is unstorable, so the screen
///     cannot grow one later by accident. `kForbiddenStreakKeys` is the list
///     G8's `noStreak()` rule uses, and a source-scanning test asserts none of
///     them appears anywhere in this feature.
///   * **No comparator.** [PortfolioInsights] does not implement `Comparable`,
///     has no `compareTo`, no `rank` and no method that sorts by views,
///     enquiries or followers. The storage half is the `fieldOverrides` in
///     G13 §1.9, which strip the automatic indexes on `views`, `enquiries` and
///     `totals` — because Firestore indexes every field by default, and without
///     the exemption `orderBy('views')` works no matter what this file says.
library;

import 'package:meta/meta.dart';

/// B12 is off. See the library comment: there is no storage and no beacon.
///
/// Flipping this to `true` is not sufficient on its own — it requires the spine
/// to ratify `insights/*` (Q2) and G11 to emit the beacons (Q11). It is a flag
/// so the screen can be switched on the day both land, without a code change.
const bool kPortfolioInsightsEnabled = false;

/// Field names that must never exist in this feature.
///
/// Mirrors `noStreak()` in G13 §6 exactly, so the client and the security rule
/// forbid the same list.
const Set<String> kForbiddenStreakKeys = <String>{
  'streak',
  'streakDays',
  'dayStreak',
  'daysStreak',
  'dailyStreak',
  'currentStreak',
  'consecutiveDays',
  'daysInARow',
  'missedDays',
};

/// Why B12 is not showing numbers.
enum InsightsAvailability {
  /// The flag is off: no ratified storage, no beacons. The honest state today.
  notMeasuredYet,

  /// Measured, and there is a summary to draw.
  available,

  /// Measured, but this coach's page has never been published, so there is
  /// nothing to have been seen.
  notPublished,
}

/// One dated bucket. Days, because a date range is a date range — this is not
/// a run, and nothing here counts consecutive anything.
@immutable
class InsightDay {
  const InsightDay({
    required this.dayId,
    this.views = 0,
    this.opens = 0,
    this.enquiries = 0,
  });

  /// `yyyy-MM-dd`.
  final String dayId;

  final int views;
  final int opens;
  final int enquiries;
}

/// `insights/summary`, as B12 would read it.
///
/// Fixed-length `last30`, one document, one read — G6's `recent8` correction
/// applied before it could become a bug, since a 30-document range read is 30
/// reads rather than one.
@immutable
class PortfolioInsights {
  const PortfolioInsights({
    required this.availability,
    this.last30 = const <InsightDay>[],
    this.sectionAttention = const <String, double>{},
    this.updatedAt,
  });

  /// The state B12 ships in.
  static const PortfolioInsights deferred = PortfolioInsights(
    availability: InsightsAvailability.notMeasuredYet,
  );

  final InsightsAvailability availability;

  /// Up to 30 dated buckets, oldest first.
  final List<InsightDay> last30;

  /// `blockId → percentage`, ≤40 keys. A share of attention within *her own*
  /// page — never a comparison with another coach's.
  final Map<String, double> sectionAttention;

  final DateTime? updatedAt;

  /// True only when there is something real to draw.
  bool get hasFigures =>
      availability == InsightsAvailability.available && last30.isNotEmpty;

  /// The enquiry rate, as a share rather than a rank: "7 in 100 who see you
  /// ask". Null when there is nothing measured, because a rate over zero views
  /// is not zero, it is unknown.
  double? get enquiryRate {
    if (!hasFigures) return null;
    var views = 0;
    var enquiries = 0;
    for (final day in last30) {
      views += day.views;
      enquiries += day.enquiries;
    }
    if (views == 0) return null;
    return enquiries / views;
  }
}
