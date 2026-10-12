/// A04 — blocking and reporting, which are deliberately **not** the same shape.
///
/// G7 §3.2: "Blocking is a separate, two-state, offline-capable relationship and
/// is deliberately *not* part of this machine: blocking is the protection she
/// gets instantly, reporting is the slower one. A04 must say so in those terms."
///
/// | | offline | takes effect | who acts |
/// |---|---|---|---|
/// | **Block** | yes | at once, locally | her |
/// | **Report** | **queued, not sent** | when a moderator reads it | someone else |
///
/// # The most misleading thing this group could ship
///
/// G7 §4 names it: a queued report that renders as "a moderator is reading it".
/// The SLA clock starts at `createdAt`, which is **server-stamped** and
/// unforgeable (`serverStamped('createdAt')` in the rules). Offline there is no
/// stamp, so the hour has not started.
///
/// That is enforced here by the type, not by copy discipline: [Report.createdAt]
/// is **null while [ReportState.queuedLocal]**, and [ReportProjection] derives
/// [ReporterView.hourStarted] from it. A screen cannot claim the hour has
/// started, because there is no timestamp for it to have started from — the same
/// technique `DayTotals` uses against a calorie countdown.
///
/// A04's queued copy must therefore say it has not been sent. The exact sentence
/// G7 §4 specifies — "Not sent yet. It will send when you have signal, and the
/// hour starts then." — is **absent from the dictionary**, which is reported
/// rather than worked around: nothing here fabricates it in English.
// `prefer_initializing_formals` asks for `this._online`, which Dart forbids: a
// named parameter cannot begin with an underscore. The field stays private
// deliberately — goOnline() is what stamps a queued report with the server's
// clock, so flipping the flag directly would produce a "sent" report that was
// never sent. See the same note on `lib/domain/identity/user_roles.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:meta/meta.dart';

// ------------------------------------------------------------------ blocks --

/// Where she blocked from. Matches the rules' enum exactly.
enum BlockSource {
  post('post'),
  profile('profile'),
  message('message'),
  safetyCentre('safety_centre');

  const BlockSource(this.wireName);

  final String wireName;
}

/// `users/{uid}/blocks/{blockedUid}`.
@immutable
class Block {
  const Block({
    required this.blockedUid,
    required this.createdAt,
    required this.source,
  });

  /// **Also the document id.** Spine C1: a deterministic id makes a replayed
  /// offline write idempotent, so blocking the same woman twice from two
  /// devices converges on one document rather than two.
  final String blockedUid;

  final DateTime createdAt;
  final BlockSource source;

  @override
  bool operator ==(Object other) =>
      other is Block && other.blockedUid == blockedUid;

  @override
  int get hashCode => blockedUid.hashCode;

  @override
  String toString() => 'Block($blockedUid from ${source.wireName})';
}

/// Blocking. Two states, offline-capable, instant.
abstract class BlockService {
  /// Newest first, capped at 50 (G7 §1.4). Typical real documents: 0–3.
  List<Block> blocks();

  bool isBlocked(String uid);

  /// Takes effect locally at once; the server mirror follows on sync.
  Future<void> block(String uid, BlockSource source);

  Future<void> unblock(String uid);
}

/// The cap A04 pages to, matching the rules.
const int kBlockPageSize = 50;

/// In-memory, strict about the two invariants the rules enforce: she cannot
/// block herself, and the id is the blocked uid.
class InMemoryBlockService implements BlockService {
  InMemoryBlockService({
    required this.selfUid,
    List<Block>? seed,
    DateTime? now,
  }) : _now = now ?? DateTime(2026, 9, 19, 10),
       _blocks = {for (final b in seed ?? const <Block>[]) b.blockedUid: b};

  final String selfUid;
  final DateTime _now;

  /// Keyed by blocked uid, which is the document id. A Map is the point: a
  /// List would let a replay create a duplicate.
  final Map<String, Block> _blocks;

  /// Every write, as `block:uid` / `unblock:uid`.
  final List<String> writes = <String>[];

  @override
  List<Block> blocks() {
    final all = _blocks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(kBlockPageSize).toList();
  }

  @override
  bool isBlocked(String uid) => _blocks.containsKey(uid);

  @override
  Future<void> block(String uid, BlockSource source) async {
    if (uid == selfUid) {
      throw StateError(
        'She cannot block herself. The security rules refuse '
        'blockedUid == uid, so a client that allowed it would write something '
        'the server rejects.',
      );
    }
    writes.add('block:$uid');
    // Idempotent: the same id replaces rather than appends.
    _blocks[uid] = Block(blockedUid: uid, createdAt: _now, source: source);
  }

  @override
  Future<void> unblock(String uid) async {
    writes.add('unblock:$uid');
    _blocks.remove(uid);
  }
}

// ----------------------------------------------------------------- reports --

/// Matches the `reason in [...]` list in the security rules exactly. A reason
/// the rules would reject is not constructible here.
enum ReportReason {
  harassment('harassment'),
  manAccount('man_account'),
  nudity('nudity'),
  spam('spam'),
  impersonation('impersonation'),
  selfHarm('self_harm'),
  other('other');

  const ReportReason(this.wireName);

  final String wireName;
}

/// G7 §3.2's lifecycle.
///
/// `slaBreached` is deliberately **not** a state — it is a flag on the document.
/// Making it a state would double every row below.
enum ReportState {
  /// Written on her phone with no signal. **The one state that must never look
  /// successful.**
  queuedLocal,

  /// Created on the server. The SLA clock starts here, server-stamped.
  submitted,

  triaged,
  actioned,
  dismissed,
  escalated,
  closed,
}

/// `reports/{reportId}`, as the reporter sees it through her `myReports` mirror.
@immutable
class Report {
  const Report({
    required this.id,
    required this.subjectUid,
    required this.reason,
    required this.state,
    this.createdAt,
    this.firstResponseMins,
    this.closedAt,
    this.slaBreached = false,
  }) : assert(
         state != ReportState.queuedLocal || createdAt == null,
         'a queued report has no server stamp, so it has no createdAt — the '
         'hour cannot have started',
       ),
       assert(
         state == ReportState.queuedLocal || createdAt != null,
         'a report that reached the server is stamped by the server',
       );

  final String id;
  final String subjectUid;
  final ReportReason reason;
  final ReportState state;

  /// **Server-stamped, and null while queued.** See the file note — this is the
  /// field that makes the one-hour claim unforgeable in both directions.
  final DateTime? createdAt;

  final int? firstResponseMins;
  final DateTime? closedAt;
  final bool slaBreached;

  /// True once the report exists on the server and the clock is running.
  bool get hourStarted => createdAt != null;

  @override
  bool operator ==(Object other) =>
      other is Report && other.id == id && other.state == state;

  @override
  int get hashCode => Object.hash(id, state);

  @override
  String toString() => 'Report($id, ${state.name}, sent: $hourStarted)';
}

/// What A04 may say about one report.
///
/// Every field is derived. There is no constructor a screen could use to assert
/// that a queued report is being read by a moderator.
@immutable
class ReporterView {
  const ReporterView._({
    required this.state,
    required this.hourStarted,
    required this.mayClaimModeratorReading,
    required this.resolvedInMinutes,
  });

  final ReportState state;

  /// False for a queued report, always.
  final bool hourStarted;

  /// False unless the report actually reached the server. This is the flag A04's
  /// copy branches on, and the queued branch has nothing reassuring to say.
  final bool mayClaimModeratorReading;

  /// Non-null only once it is closed — A04's "resolved in 40 minutes" line is a
  /// *measured* figure or it is absent. The prototype's 40 is a sample, and a
  /// sample stated as her fact is the defect `PHASE1-FIXES.md` §13 records four
  /// times over.
  final int? resolvedInMinutes;
}

class ReportProjection {
  const ReportProjection();

  static ReporterView forReporter(Report report) {
    final started = report.hourStarted;
    return ReporterView._(
      state: report.state,
      hourStarted: started,
      // Queued is the only state that has not reached a human. Everything from
      // `submitted` onward has.
      mayClaimModeratorReading:
          started && report.state != ReportState.queuedLocal,
      resolvedInMinutes: report.state == ReportState.closed
          ? report.firstResponseMins
          : null,
    );
  }
}

/// Filing a report. **Not offline-capable in the sense that matters**: it can be
/// queued, but it cannot be sent, and the difference is visible in the result.
abstract class ReportService {
  List<Report> reports();

  /// Files a report. Returns it in [ReportState.queuedLocal] when there is no
  /// signal, and [ReportState.submitted] when it reached the server.
  Future<Report> file({
    required String subjectUid,
    required ReportReason reason,
    String note = '',
  });
}

/// The note cap the security rules enforce.
const int kReportNoteMaxLength = 1000;

/// The cap A04 pages her own reports to.
const int kReportPageSize = 20;

class InMemoryReportService implements ReportService {
  InMemoryReportService({
    required this.reporterUid,
    List<Report>? seed,
    bool online = true,
    DateTime? serverNow,
  }) : _online = online,
       _serverNow = serverNow ?? DateTime(2026, 9, 19, 10, 30),
       _reports = [...?seed];

  final String reporterUid;

  /// "The server's clock." A queued report never reads this, which is the whole
  /// point: there is no local clock standing in for a server stamp.
  final DateTime _serverNow;

  final List<Report> _reports;
  bool _online;
  var _seq = 0;

  bool get online => _online;

  void goOffline() => _online = false;

  /// Reconnects and sends what was queued. A queued report becomes `submitted`
  /// and **gains its server stamp at that moment** — not the moment she wrote it.
  Future<void> goOnline() async {
    _online = true;
    for (var i = 0; i < _reports.length; i++) {
      if (_reports[i].state != ReportState.queuedLocal) continue;
      _reports[i] = Report(
        id: _reports[i].id,
        subjectUid: _reports[i].subjectUid,
        reason: _reports[i].reason,
        state: ReportState.submitted,
        createdAt: _serverNow,
      );
    }
  }

  @override
  List<Report> reports() {
    final all = [..._reports]
      ..sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        // Queued first: it is the one that still needs something from her.
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return bt.compareTo(at);
      });
    return all.take(kReportPageSize).toList();
  }

  @override
  Future<Report> file({
    required String subjectUid,
    required ReportReason reason,
    String note = '',
  }) async {
    if (subjectUid == reporterUid) {
      throw StateError(
        'subjectUid must differ from reporterUid — the security rules refuse a '
        'self-report.',
      );
    }
    if (note.length > kReportNoteMaxLength) {
      throw StateError(
        'A report note is capped at $kReportNoteMaxLength characters by the '
        'security rules; this one is ${note.length}.',
      );
    }

    final report = Report(
      id: 'report-${++_seq}',
      subjectUid: subjectUid,
      reason: reason,
      state: _online ? ReportState.submitted : ReportState.queuedLocal,
      // Null offline. There is no branch here that substitutes a local clock.
      createdAt: _online ? _serverNow : null,
    );
    _reports.add(report);
    return report;
  }

  /// Drops every report she filed. Account deletion calls it.
  ///
  /// On a server, manifest row 30 **pseudonymises** the report rather than
  /// deleting it: the safety record has to survive her leaving. There is no
  /// server here and no other woman's copy to keep, so the only honest local
  /// answer is to remove what is on this phone.
  void reset() {
    _reports.clear();
    _seq = 0;
    _online = true;
  }
}
