/// Words for the codes the console's callables answer with.
///
/// The server speaks in codes on purpose (an outcome, a reviewer action, a
/// deletion state) and the console says them in the owner's language. A code
/// this build does not know is shown as the code itself rather than hidden: an
/// unknown outcome is something to notice, not to tidy away.
library;

import '../../../l10n/app_l10n.dart';
import '../../events/domain/cairo_time.dart';
import '../domain/console_report.dart';

String outcomeLabel(AppL10n l10n, String code) => switch (code) {
  'APPROVED' => l10n.approved,
  'PENDING_REVIEW' => l10n.sentToAReviewer,
  'REJECTED_NOT_ELIGIBLE' => l10n.notEligible,
  'REJECTED_FAILED' => l10n.checkDidNotPass,
  'REJECTED_DUPLICATE' => l10n.cardAlreadyInUse,
  'RETRY_CAPTURE' => l10n.askedToRetake,
  'RETRY_REQUIRED' => l10n.askedToTryAgain,
  _ => code,
};

String logKindLabel(AppL10n l10n, ConsoleLogKind kind) => switch (kind) {
  ConsoleLogKind.decisions => l10n.decisions,
  ConsoleLogKind.reviews => l10n.reviews,
  ConsoleLogKind.deletions => l10n.deletions,
  ConsoleLogKind.waitlist => l10n.waitlist,
  ConsoleLogKind.errors => l10n.errors,
  ConsoleLogKind.access => l10n.consoleReads,
};

String reviewActionLabel(AppL10n l10n, String? action) => switch (action) {
  'list' => l10n.lookedAtTheReviewQueue,
  'contact' => l10n.lookedUpAContact,
  'schedule' => l10n.bookedAReview,
  'decide' => l10n.recordedADecision,
  'reviewerBypass' => l10n.storeReviewAccount,
  _ => action ?? '',
};

String deletionStateLabel(AppL10n l10n, String? state) => switch (state) {
  'done' => l10n.finished,
  'failedRetryable' => l10n.willRetry,
  _ => l10n.stillRunning,
};

String accessActionLabel(AppL10n l10n, String? action) {
  if (action == 'dashboard') return l10n.openedTheDashboard;
  if (action != null && action.startsWith('logs.')) {
    final kind = ConsoleLogKind.values
        .where((k) => 'logs.${k.wire}' == action)
        .firstOrNull;
    return kind == null
        ? l10n.openedALog
        : '${l10n.openedALog} · ${logKindLabel(l10n, kind)}';
  }
  return action ?? '';
}

/// `2026-10-07 14:05`, Cairo time, or nothing.
String consoleTime(DateTime? at) => at == null ? '' : formatCairo(at);
