/// `B12` — What it is doing.
///
/// The screen exists because the row on `B01` leads here, and a row that opens
/// nothing is worse than a screen that says what it knows. What it knows today
/// is nothing: `portfolio_insights.dart` records that there is no ratified
/// storage for `coaches/{coachUid}/insights/*` and no view or enquiry beacon
/// anywhere, so `kPortfolioInsightsEnabled` is false.
///
/// So this draws the sentence and no figures. **A screen of zeros is not a
/// neutral placeholder** — "0 views · 0 opened · 0 enquiries" under "Last 30
/// days" tells a coach her page is being seen by nobody, which is a statement
/// about her work; it is not true, and what is true is a statement about our
/// telemetry. `progress_view.dart` takes the same posture with the tier ladder,
/// and for the same reason.
///
/// When storage lands and the beacons fire, [PortfolioInsights.hasFigures]
/// becomes true and the figures belong on this screen. Nothing here ranks her
/// against another coach and nothing here counts consecutive days: the model
/// has no comparator and no field either could live on.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/portfolio_insights.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({
    super.key,
    this.insights = PortfolioInsights.deferred,
    this.isPublished = false,
    this.onBack,
  });

  /// What the summary document says. [PortfolioInsights.deferred] is the only
  /// state this build can be in.
  final PortfolioInsights insights;

  /// Whether a client could find her page at all. Read from her own documents,
  /// so the screen never suggests a published page is being ignored when there
  /// is no published page.
  final bool isPublished;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.whatItIsDoing,
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      children: [
        AppEmptyState(
          icon: Icons.insights_outlined,
          title: l10n.whatItIsDoing,
          body: l10n.viewsAndEnquiriesAreNotMeasuredIn,
        ),
        // The one thing about her page that is true and knowable today:
        // whether anybody could be reading it at all. Read from her own live
        // document, not counted — and said only when the answer is no, because
        // "it is live" without a figure beside it invites the figure back.
        if (!isPublished) AppSageNote(l10n.onlyYouCanSeeWhatYouSaved),
      ],
    );
  }
}
