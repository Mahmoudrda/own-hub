/// `K02` — Certificates.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K02`.
///
/// # She picks from a list; she does not type one
///
/// The owner's rule: a coach cannot claim a certificate she does not hold. So
/// this screen has **no text field**. It offers the credentials in the
/// [CredentialCatalogue] it is given, and nothing else is reachable from here.
///
/// The catalogue that ships holds **one** entry, because the verified credential
/// list has never been authored — it is absent from `6-v2/content`, from the
/// spine and from G12 — and the dictionary carries a standalone name for exactly
/// one credential. With [CredentialCatalogue.unauthored] this screen offers
/// nothing at all, which is the honest rendering of a list nobody has written.
///
/// # A queued certificate is never shown as uploaded
///
/// `P0-CVER-05`. A certificate chosen with no signal renders "Waiting for
/// signal" and carries no checking pill, because it has not left the device.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_split_row.dart';
import '../domain/coach_credentials.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

/// The dictionary name for a credential id.
///
/// A switch rather than a map lookup, so a credential added to the catalogue
/// without a minted string returns null here and draws **no name** — rather
/// than a blank row, or an English id, on an Arabic screen.
String? credentialLabel(AppL10n l10n, String credentialId) =>
    switch (credentialId) {
      'nasm_cpt' => l10n.nasmCpt,
      _ => null,
    };

class CoachCertificatesView extends StatelessWidget {
  const CoachCertificatesView({
    super.key,
    required this.model,
    this.now,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
    this.onAddCertificate,
  });

  final CoachSetupViewModel model;

  /// Injectable, so lazy expiry can be exercised without waiting years.
  final DateTime? now;

  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// Given the credential id she picked. The router opens the camera for a
  /// photo of it and sends it for a woman reviewer (`addCertificatePhoto`).
  /// Null leaves the row inert, which no shipped build does.
  final ValueChanged<String>? onAddCertificate;

  /// The credentials she has not already claimed, and whose name we can draw.
  List<Credential> _addable(AppL10n l10n) => model.catalogue.entries
      .where((c) => credentialLabel(l10n, c.id) != null)
      .where((c) => !model.certificates.any((h) => h.credentialId == c.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = now ?? DateTime.now();
    final addable = _addable(l10n);

    return CoachSetupScaffold(
      step: CoachSetupStep.certificates,
      title: l10n.showUsYourCertificates,
      subtitle: l10n.aWomanOnOurTeamChecksThem,
      onBack: () => goToScreen(context, 'K01', onBack),
      onSaveAndClose: onSaveAndClose,
      onPrimary: () => goToScreen(context, 'K03', onContinue),
      children: [
        for (final certificate in model.certificates)
          _CertificateRow(certificate: certificate, now: at),

        // Nothing to offer means the list nobody wrote, said out loud. An "Add"
        // row that opened an empty picker would be worse than this.
        if (addable.isEmpty && model.certificates.isEmpty)
          AppEmptyState(
            icon: Icons.workspace_premium,
            title: l10n.certificates,
            body: l10n.photosOfTheCertificateAreEnoughWe,
          ),

        for (final credential in addable)
          AppListItem(
            variant: AppCardVariant.filled,
            leading: const Icon(
              Icons.add,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: credentialLabel(l10n, credential.id)!,
            subtitle: l10n.addAnotherCertificate,
            onTap: onAddCertificate == null
                ? null
                : () => onAddCertificate!(credential.id),
          ),

        AppSageNote(l10n.photosOfTheCertificateAreEnoughWe),
      ],
    );
  }
}

/// One certificate, with a label that never overstates where it has got to.
class _CertificateRow extends StatelessWidget {
  const _CertificateRow({required this.certificate, required this.now});

  final Certificate certificate;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = certificate.stateAt(now);
    final label = credentialLabel(l10n, certificate.credentialId);
    final waiting =
        state == CertificateState.uploaded ||
        state == CertificateState.checking;

    return AppCard(
      variant: state.counts ? AppCardVariant.sage : AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // A Wrap, not a Row, and for the reason `AppSplitRow` exists: "Waiting
        // for signal" beside a credential name is wider than a phone at the
        // largest text size, and a Row throws a RenderFlex overflow — which
        // hides content rather than merely looking wrong. This put the pill on
        // its own line instead, and a widget test caught it.
        AppSplitRow(
          start: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.counts ? Icons.verified : Icons.badge_outlined,
                size: 24,
                color: state.counts
                    ? AppColors.tertiary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A credential with no minted name draws no name.
                    // Inventing one here is exactly the free text this screen
                    // forbids.
                    if (label != null) Text(label, style: AppText.titleM),
                    if (waiting) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.uploadedChecking,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          end: _trailing(l10n, state),
        ),
      ],
    );
  }

  /// The pill, when there is an honest one to draw.
  ///
  /// `verified`, `rejected` and `expired` have **no minted label**, so those
  /// rows carry an icon and no words rather than a word this product has not
  /// written. Reported as missing rather than invented.
  Widget _trailing(AppL10n l10n, CertificateState state) => switch (state) {
    CertificateState.localPending => AppPill(
      l10n.waitingForSignal,
      background: AppColors.surfaceContainer,
      foreground: AppColors.onSurfaceVariant,
    ),
    CertificateState.uploaded || CertificateState.checking => AppPill(
      l10n.checking,
      background: AppColors.amberContainer,
      foreground: AppColors.amber,
    ),
    CertificateState.verified => const Icon(
      Icons.check_circle,
      size: 22,
      color: AppColors.tertiary,
    ),
    CertificateState.rejected || CertificateState.expired => const Icon(
      Icons.error_outline,
      size: 22,
      color: AppColors.amber,
    ),
  };
}
