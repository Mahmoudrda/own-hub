/// What `admin_dashboard` and `admin_logs` answer, as values a screen can draw.
///
/// The server builds both answers from an allowlist and never puts a person in
/// them (see `functions/console/`). These types keep the same discipline on
/// this side: they hold counts, codes, times and eight-character references,
/// and a field the server did not promise is not read at all.
///
/// Parsing is forgiving in one direction only: a missing count reads as zero
/// and an unknown code is dropped, so a newer server never breaks an older
/// console. Nothing is invented to fill a gap.
library;

import 'package:meta/meta.dart';

/// Verification outcome codes, in the order the dashboard lists them.
const List<String> kOutcomeCodes = [
  'APPROVED',
  'PENDING_REVIEW',
  'RETRY_CAPTURE',
  'RETRY_REQUIRED',
  'REJECTED_FAILED',
  'REJECTED_NOT_ELIGIBLE',
  'REJECTED_DUPLICATE',
];

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

Map<String, Object?> _map(Object? v) =>
    v is Map ? v.cast<String, Object?>() : const <String, Object?>{};

DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

String? _ref(Object? v) =>
    v is String && RegExp(r'^[0-9a-f]{8}$').hasMatch(v) ? v : null;

@immutable
class ConsoleDashboard {
  const ConsoleDashboard({
    required this.generatedAt,
    this.accounts = 0,
    this.verified = 0,
    this.reviewsPending = 0,
    this.reviewsOverSla = 0,
    this.oldestReviewHours,
    this.slaHours = 72,
    this.outcomes7 = const {},
    this.outcomes30 = const {},
    this.waitlist = 0,
    this.deletionsRunning = 0,
    this.deletionsDone = 0,
    this.eventsUpcoming = 0,
    this.eventDrafts = 0,
    this.content = const {},
  });

  factory ConsoleDashboard.fromJson(Map<String, Object?> json) {
    final members = _map(json['members']);
    final reviews = _map(json['reviews']);
    final outcomes = _map(json['outcomes']);
    final deletions = _map(json['deletions']);
    final events = _map(json['events']);
    Map<String, int> codes(Object? raw) {
      final m = _map(raw);
      return {
        for (final code in kOutcomeCodes)
          if (m.containsKey(code)) code: _int(m[code]),
      };
    }

    final oldest = reviews['oldestHours'];
    return ConsoleDashboard(
      generatedAt: _time(json['generatedAt']) ?? DateTime.utc(1970),
      accounts: _int(members['total']),
      verified: _int(members['verified']),
      reviewsPending: _int(reviews['pending']),
      reviewsOverSla: _int(reviews['overSla']),
      oldestReviewHours: oldest is int ? oldest : null,
      slaHours: reviews['slaHours'] is int ? reviews['slaHours']! as int : 72,
      outcomes7: codes(outcomes['7']),
      outcomes30: codes(outcomes['30']),
      waitlist: _int(_map(json['waitlist'])['total']),
      deletionsRunning: _int(deletions['pending']),
      deletionsDone: _int(deletions['done']),
      eventsUpcoming: _int(events['upcoming']),
      eventDrafts: _int(events['drafts']),
      content: {
        for (final e in _map(json['content']).entries) e.key: _int(e.value),
      },
    );
  }

  final DateTime generatedAt;
  final int accounts;
  final int verified;
  final int reviewsPending;
  final int reviewsOverSla;

  /// Null when no review is waiting.
  final int? oldestReviewHours;
  final int slaHours;
  final Map<String, int> outcomes7;
  final Map<String, int> outcomes30;
  final int waitlist;
  final int deletionsRunning;
  final int deletionsDone;
  final int eventsUpcoming;
  final int eventDrafts;

  /// By Firestore collection name: exercises, foods, recipes, programs.
  final Map<String, int> content;

  /// The oldest waiting review is past the promise made to her.
  bool get oldestIsLate =>
      oldestReviewHours != null && oldestReviewHours! >= slaHours;
}

/// The six logs, in the order the console offers them.
enum ConsoleLogKind {
  decisions,
  reviews,
  deletions,
  waitlist,
  errors,
  access;

  String get wire => name;
}

/// One line of a log. Which fields are set depends on [kind]; none of them
/// is a person.
@immutable
class ConsoleLogRow {
  const ConsoleLogRow({
    required this.kind,
    this.at,
    this.day,
    this.outcome,
    this.reasons = const [],
    this.caseRef,
    this.reviewerRef,
    this.adminRef,
    this.action,
    this.state,
    this.swept = false,
    this.count,
    this.counts = const {},
  });

  factory ConsoleLogRow.fromJson(ConsoleLogKind kind, Map<String, Object?> j) =>
      ConsoleLogRow(
        kind: kind,
        at: _time(j['at']),
        day: j['day'] is String ? j['day']! as String : null,
        outcome: kOutcomeCodes.contains(j['outcome'])
            ? j['outcome']! as String
            : null,
        reasons: [
          for (final r
              in (j['reasons'] is List ? j['reasons']! as List : const []))
            if (r is String && RegExp(r'^[A-Za-z_]{1,64}$').hasMatch(r)) r,
        ],
        caseRef: _ref(j['case']),
        reviewerRef: _ref(j['reviewer']),
        adminRef: _ref(j['admin']),
        action: j['action'] is String ? j['action']! as String : null,
        state: j['state'] is String ? j['state']! as String : null,
        swept: j['swept'] == true,
        count: j['joined'] is int ? j['joined']! as int : null,
        counts: {
          for (final e in _map(j['counts']).entries)
            if (e.value is int) e.key: e.value! as int,
        },
      );

  final ConsoleLogKind kind;
  final DateTime? at;

  /// `yyyy-mm-dd`, for the per-day logs (waitlist, errors).
  final String? day;
  final String? outcome;
  final List<String> reasons;
  final String? caseRef;
  final String? reviewerRef;
  final String? adminRef;
  final String? action;
  final String? state;
  final bool swept;

  /// Waitlist joins on [day].
  final int? count;

  /// Function errors on [day], by event code.
  final Map<String, int> counts;
}

@immutable
class ConsoleLogPage {
  const ConsoleLogPage({required this.kind, this.rows = const [], this.next});

  factory ConsoleLogPage.fromJson(
    ConsoleLogKind kind,
    Map<String, Object?> json,
  ) => ConsoleLogPage(
    kind: kind,
    rows: [
      for (final r in (json['rows'] is List ? json['rows']! as List : const []))
        if (r is Map) ConsoleLogRow.fromJson(kind, r.cast<String, Object?>()),
    ],
    next: json['next'] is String ? json['next']! as String : null,
  );

  final ConsoleLogKind kind;
  final List<ConsoleLogRow> rows;

  /// The cursor for the page after this one, or null at the end.
  final String? next;
}
