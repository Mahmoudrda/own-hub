/// What a community surface is allowed to say about a report — and the sentence
/// it is not allowed to say.
///
/// `G10-community.md` §4 and `P0-COM-14`:
///
/// > **Report** — queued, and explicitly not sent (G7 §4) … *"Not sent yet. It
/// > will send when you have signal, and the hour starts then."* **Never** "a
/// > moderator is reading it".
///
/// # This file adds a gate, not a second rule
///
/// `lib/features/account/domain/safety.dart` already makes the claim unforgeable
/// by type: `Report.createdAt` is **null** while `ReportState.queuedLocal`, and
/// `ReportProjection.forReporter` derives `mayClaimModeratorReading` from it. A
/// screen cannot say the hour has started because there is no timestamp for it
/// to have started from.
///
/// G7 owns that. What this file adds is the community-side *presentation* gate,
/// so M08's sheet asks one object "what may I say" instead of reasoning about a
/// report's state itself — and so the answer is tested once rather than on every
/// surface that files a report.
///
/// # The copy does not exist, and is not invented here
///
/// The exact sentence `P0-COM-14` requires is **absent from the dictionary**.
/// `safety.dart` recorded the same finding for A04 and refused to work around
/// it; this file refuses in the same way. [ReportCopyState.queuedNotSent] names
/// the state that needs the sentence, and the view renders **nothing** for it
/// rather than fabricating English — which would bypass the dictionary and show
/// English to an Arabic reader.
///
/// The missing key is reported with the build. That is the honest failure: a
/// line that is absent is visibly absent, while a line invented in a widget is
/// a defect nobody sees until an Arabic screenshot.
library;

import '../../account/domain/safety.dart';

/// What may be said about a report, as a state a view switches on.
enum ReportCopyState {
  /// Written with no signal. **The one state that must never look successful.**
  ///
  /// Needs the sentence "Not sent yet. It will send when you have signal, and
  /// the hour starts then." — which the dictionary does not carry. The view
  /// draws nothing here until it does.
  queuedNotSent,

  /// It reached the server and the clock is running. The existing key
  /// `aWomanModeratorReadsItUsuallyWithin` is true of this state and only this
  /// state.
  sentHourStarted,

  /// Closed. A04 states a measured figure or says nothing.
  closed,
}

/// The community-side gate.
class CommunityReportCopy {
  const CommunityReportCopy();

  /// Maps a report to what a surface may claim about it.
  ///
  /// Derived from `ReportProjection`, never from the state enum directly, so
  /// there is one definition of "has this actually been sent".
  static ReportCopyState stateFor(Report report) {
    final view = ReportProjection.forReporter(report);
    if (!view.mayClaimModeratorReading) return ReportCopyState.queuedNotSent;
    if (report.state == ReportState.closed) return ReportCopyState.closed;
    return ReportCopyState.sentHourStarted;
  }

  /// Whether a surface may render "a woman moderator reads it within an hour".
  ///
  /// False for a queued report, always. This is the predicate M08 branches on,
  /// and the queued branch has nothing reassuring to say.
  static bool mayPromiseAnHour(Report report) =>
      ReportProjection.forReporter(report).mayClaimModeratorReading;

  /// The dictionary key this feature still needs, named so the build can report
  /// it and a test can assert it is still missing rather than quietly invented.
  ///
  /// When it is minted, `queuedNotSent` gains its line and this constant goes.
  static const String missingQueuedCopyKey =
      'Not sent yet. It will send when you have signal, and the hour starts '
      'then.';
}
