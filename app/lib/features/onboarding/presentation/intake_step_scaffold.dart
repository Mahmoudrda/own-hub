/// The shape of a setup step — the prototype's `step()` helper.
///
/// `6-v2/src/screens-onboarding.mjs` builds O01 through O04 from one local
/// `step(n, title, sub, inner, next, back)`, so the four screens are the same
/// page with different questions in it. Reproduced here as one widget for that
/// reason: four copies of this frame is four chances for the step counter, the
/// close button or the Skip link to drift.
///
/// Three parts are fixed and are what make the flow safe to abandon:
///
///  * **The counter tells her how much is left.** Four questions, and she can
///    see it is four.
///  * **`Skip` is always there, at every step.** Skipping is a designed path,
///    not a failure — every question preselects a valid answer, so a woman who
///    skips all four still gets a real programme (G2 §3.2 `DEFAULTED`).
///  * **The close button leaves.** She is never trapped in setup. Closing keeps
///    whatever she has already answered, because each step writes as she goes.
///
/// The body is [AppScaffold]'s, which means its 10px stack gap rather than the
/// prototype's 12 and `SafeArea` rather than a drawn status bar. Both are the
/// house translation and are explained in `lib/ui/app_scaffold.dart`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_step_progress.dart';

class IntakeStepScaffold extends StatelessWidget {
  const IntakeStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
  });

  /// Which of the four questions this is.
  final int step;

  final String title;
  final String subtitle;

  /// The answers themselves.
  final List<Widget> children;

  final VoidCallback? onContinue;

  /// Leaves the question unanswered and moves on. The preselected default
  /// stands, and nothing is written.
  final VoidCallback? onSkip;

  final VoidCallback? onBack;

  /// Leaves setup entirely — `X` in the design, which goes to Home.
  final VoidCallback? onClose;

  static const int totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: stepOfLabel(l10n, step: step, total: totalSteps),
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onClose,
            iconSize: 24,
            color: AppColors.onSurface,
            icon: const Icon(Icons.close),
            tooltip: l10n.skipSetup,
          ),
        ],
      ),
      footer: [
        AppButton(l10n.continueLabel, onPressed: onContinue),
        AppButton(
          l10n.skip,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onSkip,
        ),
      ],
      children: [
        Text(
          title,
          style: AppText.display.copyWith(color: AppColors.onPrimaryContainer),
        ),
        Text(
          subtitle,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // The prototype's 2px shim between the question and the answers.
        const SizedBox(height: 2),
        ...children,
      ],
    );
  }
}
