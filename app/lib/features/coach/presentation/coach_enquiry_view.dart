/// `K09` — a new enquiry.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K09`.
///
/// # Everything on this screen is denormalised onto the enquiry
///
/// Her situation and her own words are fields of [Enquiry], projected by G11.
/// That is not a performance choice: a coach session **may not read
/// `users/{clientUid}`** — the rules deny it — so without the denormalisation
/// this screen would be unbuildable rather than merely slower (G12 §7.3).
///
/// # Declining is a neutral choice
///
/// `P0-ENQ-02`. The action is "Not a fit for me", the authorisation is voided
/// and capacity does not move. Nothing here calls it a rejection, and forced
/// matches make both sides miserable.
///
/// # Accepting is refused rather than queued
///
/// `P0-ENQ-04`. Offline, unverified, full, or with no payment rail, the accept
/// button is **disabled** — it is never tapped into a queue. G12 §4: *"Queuing
/// it would let two coaches accept the last spot, or take money for a spot that
/// no longer exists."* The domain refuses all four cases
/// ([CoachEnquiryService.accept]); this screen refuses to offer them.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_verification.dart';
import '../domain/enquiry.dart';
import 'coach_setup_scaffold.dart';

class CoachEnquiryView extends StatelessWidget {
  const CoachEnquiryView({
    super.key,
    required this.enquiry,
    required this.verification,
    this.hasRoom = true,
    this.network = NetworkStatus.online,
    this.onAccept,
    this.onDecline,
    this.onBack,
  });

  final Enquiry enquiry;
  final CoachVerificationState verification;

  /// Whether a spot is free. From [CoachCapacity.hasRoom], never counted here.
  final bool hasRoom;

  final NetworkStatus network;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onBack;

  /// Whether Accept may be offered at all.
  ///
  /// Four conditions, and each is the domain's. This restates none of them —
  /// it reads the answers.
  bool get canAccept =>
      enquiry.status.awaitsCoach &&
      verification.mayAcceptClients &&
      hasRoom &&
      network.isOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.newEnquiry,
        onBack: () => goToScreen(context, 'K07', onBack),
      ),
      footer: [
        AppButton(
          l10n.acceptAndSendAWelcome,
          height: 56,
          onPressed: canAccept ? onAccept : null,
        ),
        AppButton(
          l10n.notAFitForMe,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: enquiry.status.awaitsCoach && network.isOnline
              ? onDecline
              : null,
        ),
      ],
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: enquiry.initial.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 28,
                      color: AppColors.onPrimaryContainer,
                    )
                  : Text(
                      enquiry.initial,
                      style: AppText.titleL.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Her name, underlined once in a steady pen: the person this
            // page is about, marked the way a coach marks a new name.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                heightFactor: 1,
                child: HandUnderline(
                  level: HandLevel.crafted,
                  child: Text(enquiry.displayName, style: AppText.titleL),
                ),
              ),
            ),
          ],
        ),
        const HandRule(seed: 9, height: 10),

        // Her situation, as G11 projected it. Never read from her documents.
        // Set open on the page; only her own words below sit on a tint.
        if (enquiry.situation.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.whatSheIsAskingFor, style: AppText.titleM),
              const SizedBox(height: 4),
              Text(
                enquiry.situation,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),

        // Her own words. The reason this screen exists rather than a list row.
        if (enquiry.herWords.isNotEmpty)
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mic, size: 22, color: AppColors.primaryDim),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      enquiry.herWords,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),

        // Why the button above is not available, when it is not. Stated as the
        // rule rather than as an error, because nothing has gone wrong.
        if (!verification.mayAcceptClients)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                l10n.photosOfTheCertificateAreEnoughWe,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),

        AppSageNote(l10n.shePaysOnlyOnceYouAccept),
      ],
    );
  }
}
