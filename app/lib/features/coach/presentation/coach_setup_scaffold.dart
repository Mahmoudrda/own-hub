/// The chrome `K01`–`K06` share, and the one place this feature navigates from.
///
/// Matches `step()` in `6-v2/src/screens-coach.mjs`: an "N of 6" bar with a
/// close action, a headline and a muted line, and a footer carrying the primary
/// action over a quiet "Save and close" that returns her to Today.
///
/// Six screens drawing their own bar is six chances for one of them to say
/// "Step 4 of 5", and a coach counting steps that do not add up stops trusting
/// the count. It is built once here instead.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coach_view_models.dart';

/// Navigates by screen id, or calls the override a test supplied.
///
/// The coach feature's own copy of the idiom the Today flow uses. It is a
/// four-line function rather than an import across feature folders, and it
/// keeps every literal screen id visible at its call site — which is what
/// `nav_reachability_test` reads the navigation graph from.
void goToScreen(
  BuildContext context,
  String screenId, [
  VoidCallback? override,
]) {
  if (override != null) {
    override();
    return;
  }
  AppRouter.goTo(context, screenId);
}

/// The step counter in the bar, counted from the enum rather than written out.
///
/// It used to be six fixed dictionary strings — `step1Of6` … `step6Of6` —
/// which is six chances to say "Step 4 of 5", the exact drift the library
/// comment above warns about, and six more of the frozen figures
/// `baked_in_samples_test` exists to drain. `countOfTotal` is the
/// parameterised `{count} of {total}` the dictionary already carries and
/// translates, so both numbers are derived: add a seventh step and the bar
/// counts to seven by itself.
String stepTitle(AppL10n l10n, CoachSetupStep step) =>
    l10n.countOfTotal('${step.number}', '${CoachSetupStep.values.length}');

/// One step of the coach application.
class CoachSetupScaffold extends StatelessWidget {
  const CoachSetupScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    this.subtitle = '',
    this.primaryLabel,
    this.onPrimary,
    this.onBack,
    this.onSaveAndClose,
    this.showSaveAndClose = true,
  });

  final CoachSetupStep step;

  /// The headline. "Tell clients who you are".
  final String title;

  /// The muted line under it. Empty renders nothing rather than a gap.
  final String subtitle;

  final List<Widget> children;

  /// Defaults to "Continue".
  final String? primaryLabel;

  /// Null disables the button — which is how a step that is not answered yet
  /// refuses to advance, rather than advancing and failing later.
  final VoidCallback? onPrimary;

  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// `K06` has nothing to save and nothing to close.
  final bool showSaveAndClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final headline = Text(
      title,
      style: AppText.headline.copyWith(color: AppColors.onPrimaryContainer),
    );

    return AppScaffold(
      appBar: AppTopBar(
        title: stepTitle(l10n, step),
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.close,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.close),
            onPressed: () => goToScreen(context, 'K07', onSaveAndClose),
          ),
        ],
      ),
      footer: [
        AppButton(
          primaryLabel ?? l10n.continueLabel,
          height: 56,
          onPressed: onPrimary,
        ),
        if (showSaveAndClose)
          AppButton(
            l10n.saveAndClose,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: () => goToScreen(context, 'K07', onSaveAndClose),
          ),
      ],
      children: [
        // The step's number, set by hand beside the question — the bar above
        // already prints the count, so this is only the diary numbering its
        // pages. The payout step goes without: a page about her money stays
        // wholly in print.
        if (step == CoachSetupStep.payout)
          headline
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HandFigure('${step.number}', size: 32),
              const SizedBox(width: 12),
              Expanded(child: headline),
            ],
          ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ...children,
      ],
    );
  }
}

/// A muted section label — the prototype's `m()` above a chip row.
class CoachFieldLabel extends StatelessWidget {
  const CoachFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
  );
}
