/// C15 — Checked by a woman, no photo kept.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C15`.
///
/// **The niqab path is first class.** It is designed, not improvised: a live
/// check with a woman reviewer, or an in-person check at a ladies-only gym, with
/// the ID card doing exactly the same work it does on the automatic path. A
/// woman reaches this screen straight from `C09` and leaves it for `C14` — and
/// **no route through `C09`→`C15`→`C14` opens a camera or asks for a selfie**.
/// Nothing in this file imports the capture layer, which is what makes that
/// structural rather than a promise.
///
/// Both options submit [VerificationMethod.niqabFriendly], so the decision is
/// recorded as a no-selfie path whichever she picks.
///
/// Two gaps carried from G1, neither of which this screen can close:
///
///  * The domain has one `niqabFriendly` method and no representation of G1's
///    `reviewerPath` (`video` | `gym`), so which of the two she chose is
///    reported through [onBooked] rather than stored in the domain type.
///  * "Book the video check" has no booking backend and no named vendor, and
///    "nothing is recorded" must be enforced by configuration and proven by a
///    test — it is a promise in copy today.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/verification.dart';

/// Which no-selfie check she chose. G1's `reviewerPath`; it has no home in the
/// domain layer yet, so it is reported to the caller instead of invented there.
enum ReviewerPath { video, gym }

class WomanReviewerView extends StatefulWidget {
  const WomanReviewerView({
    super.key,
    required this.repository,
    this.onBooked,
    this.onBack,
  });

  final VerificationRepository repository;

  /// Fired after the check has been submitted — on to `C14`.
  final ValueChanged<ReviewerPath>? onBooked;

  final VoidCallback? onBack;

  @override
  State<WomanReviewerView> createState() => _WomanReviewerViewState();
}

class _WomanReviewerViewState extends State<WomanReviewerView> {
  /// The video check is preselected because it needs nothing but her phone.
  ReviewerPath _path = ReviewerPath.video;
  bool _booking = false;

  Future<void> _book() async {
    if (_booking) return;
    setState(() => _booking = true);
    try {
      // niqabFriendly for both options: neither ever captures a selfie.
      await widget.repository.submit(method: VerificationMethod.niqabFriendly);
      if (!mounted) return;
      widget.onBooked?.call(_path);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onBack),
      footer: [AppButton(l10n.bookTheVideoCheck, onPressed: _book)],
      children: [
        Text(l10n.checkedByAWomanNoPhotoKept, style: AppText.headline),
        Text(
          l10n.ifYouDoNotShowYourFace,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _PathCard(
          icon: Icons.videocam,
          title: l10n.aShortVideoCheck,
          body: l10n.twoMinutesWithAWomanReviewerNothing,
          selected: _path == ReviewerPath.video,
          onTap: () => setState(() => _path = ReviewerPath.video),
        ),
        _PathCard(
          icon: Icons.fitness_center,
          title: l10n.inPersonAtALadiesOnlyGym,
          body: l10n.n12PartnerGymsInCairoGizaAnd,
          selected: _path == ReviewerPath.gym,
          onTap: () => setState(() => _path = ReviewerPath.gym),
        ),
        // `sageNote()`: only women review these checks.
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Text(
              l10n.onlyWomenReviewTheseChecksNoMan,
              style: AppText.body.copyWith(
                color: AppColors.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.primaryDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.check_circle,
                size: 24,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
