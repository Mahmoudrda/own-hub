/// The legal update sheet (M1): she has not accepted the Terms and Privacy
/// Policy in force.
///
/// Shown at launch to a signed-in woman whose server record does not cover
/// `kTermsVersion` and `kPrivacyVersion`, and before the check (C09b) if the
/// acceptance she made at C06 never reached the server. It blocks: it cannot
/// be swiped away, because continuing to use the app is never acceptance of
/// a material change. She can agree, or delete her account instead. Both
/// documents are one tap away.
///
/// The recording itself is not here: the router hands in [onAgree], which
/// sends the acceptance to `record_legal_acceptance`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

/// What changed in this version, at most three lines.
List<String> legalUpdateChanges(AppL10n l10n) => <String>[
  l10n.yourAgreementIsNowRecordedWhenYou,
  l10n.crashReportsAreSentOnlyIfYou,
  l10n.youCanAskForACopyOf,
];

/// Shows the sheet. True once the server has her agreement; false when she
/// chose to delete her account instead.
Future<bool> showLegalUpdateSheet(
  BuildContext context, {
  required Future<bool> Function() onAgree,
  VoidCallback? onOpenTerms,
  VoidCallback? onOpenPrivacy,
}) async {
  final result = await showAppSheet<bool>(
    context: context,
    dismissible: false,
    children: [
      LegalUpdateSheet(
        onAgree: onAgree,
        onOpenTerms: onOpenTerms,
        onOpenPrivacy: onOpenPrivacy,
      ),
    ],
  );
  return result ?? false;
}

class LegalUpdateSheet extends StatefulWidget {
  const LegalUpdateSheet({
    super.key,
    required this.onAgree,
    this.onOpenTerms,
    this.onOpenPrivacy,
  });

  /// Records her agreement. True when the server confirmed it.
  final Future<bool> Function() onAgree;

  /// Open each document. Null while it has no address, and then not drawn.
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  State<LegalUpdateSheet> createState() => _LegalUpdateSheetState();
}

class _LegalUpdateSheetState extends State<LegalUpdateSheet> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _agree() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await widget.onAgree();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

    return PopScope(
      canPop: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.weHaveUpdatedOurTermsAndPrivacy, style: AppText.titleL),
          const SizedBox(height: 10),
          Text(l10n.pleaseReadWhatChangedToKeepUsing, style: quiet),
          const SizedBox(height: 10),
          for (final line in legalUpdateChanges(l10n))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: 3, end: 8),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.primaryDim,
                    ),
                  ),
                  Expanded(child: Text(line, style: AppText.bodyM)),
                ],
              ),
            ),
          if (widget.onOpenTerms != null)
            AppButton(
              l10n.termsOfUse,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: widget.onOpenTerms,
            ),
          if (widget.onOpenPrivacy != null)
            AppButton(
              l10n.privacyPolicy,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: widget.onOpenPrivacy,
            ),
          if (_failed) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.weCouldNotSaveYourAgreementCheck,
                key: const ValueKey('legal-update-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(l10n.agreeAndContinue, onPressed: _busy ? null : _agree),
          const SizedBox(height: 8),
          AppButton(
            l10n.deleteMyAccountInstead,
            variant: AppButtonVariant.outlined,
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
