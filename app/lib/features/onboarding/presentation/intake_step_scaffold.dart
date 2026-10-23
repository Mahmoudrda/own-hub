/// The shape of a setup step — the prototype's `step()` helper.
///
/// `6-v2/src/screens-onboarding.mjs` builds every setup question from one local
/// `step(n, title, sub, inner, next, back)`, so the screens are the same page
/// with a different question in it. Reproduced here as one widget for that
/// reason: six copies of this frame is six chances for the step counter, the
/// bar or the close button to drift.
///
/// Three parts are fixed and are what make the flow safe to abandon:
///
///  * **The counter tells her how much is left.** One question a screen, the
///    count in the bar title ("2 of 6") and a line under it that fills as she
///    goes, so she sees how short it is before she starts.
///  * **Every answer is already chosen.** Skipping is a designed path, not a
///    failure: every question preselects a valid answer, so a woman who just
///    taps Continue through all of them still gets a real programme (G2 §3.2
///    `DEFAULTED`).
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
import '../../../ui/app_step_bar.dart';
import '../../../ui/screen_art_strip.dart';

class IntakeStepScaffold extends StatelessWidget {
  const IntakeStepScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.children,
    this.lead,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
    this.titleOverride,
    this.continueLabel,
  });

  /// Which question of the walk this is, counted from 1, and how many the
  /// walk has (`setupProgress` in `onboarding_state.dart`).
  final int step;
  final int total;

  /// The bar title instead of "2 of 6": the short "Your week" before sign-up
  /// says "1 of 3 · Your week", which counts the parts of joining. An empty
  /// string shows no count in the title; the line under it still fills.
  final String? titleOverride;

  /// The primary button's words, when "Continue" undersells what it does.
  final String? continueLabel;

  final String title;
  final String subtitle;

  /// A line above the question, on the one step that needs it.
  ///
  /// The walk was designed as the tail of sign-up, where a woman arrived
  /// already knowing she was being set up. It now opens the app on a fresh
  /// install, so the first screen has to say what is about to happen and how
  /// long it takes before it asks her anything. "1 of 6" in the bar is the
  /// length; this is the rest of it, and only `O01` passes one. Same small
  /// grey treatment `O05` opens with, so the flow reads as one piece.
  final String? lead;

  /// The answers themselves.
  final List<Widget> children;

  final VoidCallback? onContinue;

  /// The Skip in the top bar: leaves setup with the preselected answers
  /// standing. Null draws no Skip, and the X (if [onClose] is given) shows
  /// instead.
  final VoidCallback? onSkip;

  final VoidCallback? onBack;

  /// Leaves setup entirely — `X` in the design, which goes to Home. Null draws
  /// no `X`: before she has an account there is no Home to leave to.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      // A setup question has no illustration strip and a tight stack, so the
      // answers fit the screen at the normal text size. Larger text still
      // wraps and scrolls.
      showArt: false,
      gap: 6,
      appBar: AppTopBar(
        title: titleOverride ?? l10n.countOfTotal('$step', '$total'),
        onBack: onBack,
        actions: [
          // Skip leaves with the answers already chosen. It replaces the X:
          // both leave setup, and two ways out of one bar is one too many.
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                l10n.skip,
                style: AppText.label.copyWith(fontWeight: FontWeight.w600),
              ),
            )
          else if (onClose != null)
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
        AppButton(continueLabel ?? l10n.continueLabel, onPressed: onContinue),
      ],
      children: [
        AppStepBar(step: step, total: total),
        if (lead != null)
          Text(
            lead!,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        // The question, with one small drawing beside it. The drawing is
        // small on purpose: the answers have to fit the screen.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppText.headline.copyWith(
                  fontSize: 22,
                  height: 1.25,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const ScreenArtInline(size: 44),
          ],
        ),
        Text(
          subtitle,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        ...children,
      ],
    );
  }
}
