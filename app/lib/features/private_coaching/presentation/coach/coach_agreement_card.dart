/// "Your signed agreement" in the coach space: accept Coach Agreement v2 in
/// the app, print it and sign it by hand, upload a photo of the signed page,
/// and see where Own Hub's check stands. Until it is verified the server
/// refuses a new client; clients she already has are not touched.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/profile_photo_state.dart'
    show ProfilePhotoPermissionDenied;
import '../../../../config/legal_links.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_sheet.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_agreement.dart';
import '../../domain/coaching_failure.dart';
import '../apply/apply_widgets.dart';
import '../coach_agreement_points.dart';
import 'coach_photo.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';

class CoachAgreementCard extends StatefulWidget {
  const CoachAgreementCard({
    super.key,
    required this.repository,
    required this.agreement,
    required this.imageChooser,
    this.onOpenLink,
    this.urgent = true,
  });

  /// Its action is the one filled button on the screen. False while something
  /// more urgent (an account on hold) holds that place.
  final bool urgent;

  final CoachingRepository repository;
  final CoachAgreement? agreement;
  final CoachImageChooser imageChooser;

  /// Opens an address outside the app. Without it the links are not offered.
  final ValueChanged<String>? onOpenLink;

  @override
  State<CoachAgreementCard> createState() => _CoachAgreementCardState();
}

class _CoachAgreementCardState extends State<CoachAgreementCard> {
  bool _busy = false;
  String _error = '';

  String _link(String url) =>
      LegalLinks.localised(url, Localizations.localeOf(context).languageCode);

  void _open(String url) => widget.onOpenLink?.call(_link(url));

  Future<void> _run(Future<void> Function() work) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await work();
    } on ProfilePhotoPermissionDenied {
      if (mounted) setState(() => _error = l10n.theCameraIsTurnedOffForOwn);
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.somethingWentWrongPleaseTryAgain);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final accepted = await showAppSheet<bool>(
      context: context,
      children: [
        _GateSheet(
          onOpenAgreement: widget.onOpenLink == null
              ? null
              : () => _open(LegalLinks.coachAgreement),
        ),
      ],
    );
    if (accepted != true || !mounted) return;
    final language = Localizations.localeOf(context).languageCode;
    await _run(
      () => widget.repository.acceptCoachTerms(
        locale: language == 'ar' ? 'ar' : 'en',
      ),
    );
  }

  Future<void> _upload() => _run(() async {
    final l10n = AppL10n.of(context);
    final image = await widget.imageChooser(context);
    if (image == null) return;
    final path = await widget.repository.uploadCoachDoc(
      CoachDocFolder.agreement,
      image.bytes,
      image.contentType,
    );
    await widget.repository.submitCoachAgreement(path);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.yourSignedCopyWasSentOwnHub)));
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final step = agreementStep(widget.agreement);
    final reason = widget.agreement?.reason ?? '';
    final body = switch (step) {
      AgreementStep.accept => l10n.readTheNewCoachAgreementAndAccept,
      AgreementStep.upload => l10n.printTheAgreementAndSignItBy,
      AgreementStep.waiting => l10n.ownHubIsCheckingYourSignedCopy,
      AgreementStep.uploadAgain =>
        reason.isEmpty
            ? l10n.printTheAgreementAndSignItBy
            : l10n.ownHubNeedsANewSignedCopy(reason),
      AgreementStep.verified => l10n.yourSignedAgreementIsVerifiedYouCan,
    };
    final done = step == AgreementStep.verified;
    if (done) {
      // Settled: one line, not a card.
      return Row(
        key: const ValueKey('coach-agreement-card'),
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.yourSignedAgreementIsVerifiedYouCan,
              style: AppText.bodyM,
            ),
          ),
        ],
      );
    }
    final variant = widget.urgent
        ? AppButtonVariant.filled
        : AppButtonVariant.tonal;
    return AppCard(
      key: const ValueKey('coach-agreement-card'),
      variant: done ? AppCardVariant.filled : AppCardVariant.tonal,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.yourSignedAgreement, style: AppText.titleL),
        ),
        if (done)
          AppPill(
            l10n.yourSignedAgreementIsVerifiedYouCan,
            background: AppColors.tertiaryContainer,
            foreground: AppColors.onTertiaryContainer,
          )
        else
          Text(body, style: AppText.bodyM),
        if (_error.isNotEmpty) CoachFieldError(_error),
        if (step == AgreementStep.accept)
          AppButton(
            l10n.acceptTheAgreement,
            key: const ValueKey('agreement-accept'),
            variant: variant,
            onPressed: _busy ? null : _accept,
          ),
        if (step == AgreementStep.upload || step == AgreementStep.uploadAgain)
          AppButton(
            step == AgreementStep.upload
                ? l10n.uploadSignedCopy
                : l10n.uploadANewCopy,
            key: const ValueKey('agreement-upload'),
            variant: variant,
            onPressed: _busy ? null : _upload,
          ),
        if (!done && widget.onOpenLink != null) ...[
          AppButton(
            l10n.readTheAgreement,
            key: const ValueKey('agreement-read'),
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: () => _open(LegalLinks.coachAgreement),
          ),
          if (step != AgreementStep.accept && step != AgreementStep.waiting)
            AppButton(
              l10n.downloadThePdf,
              key: const ValueKey('agreement-pdf'),
              variant: AppButtonVariant.text,
              height: 48,
              fontSize: 15,
              onPressed: () => _open(LegalLinks.coachAgreementPdf),
            ),
        ],
      ],
    );
  }
}

/// The agreement in plain points and one tick, before she accepts.
class _GateSheet extends StatefulWidget {
  const _GateSheet({this.onOpenAgreement});

  final VoidCallback? onOpenAgreement;

  @override
  State<_GateSheet> createState() => _GateSheetState();
}

class _GateSheetState extends State<_GateSheet> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.coachAgreement,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        for (final point in coachAgreementPoints(l10n))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 2, end: 10),
                child: Icon(Icons.check, size: 18, color: AppColors.primary),
              ),
              Expanded(child: Text(point, style: AppText.bodyM)),
            ],
          ),
        if (widget.onOpenAgreement != null)
          AppButton(
            l10n.readTheFullCoachAgreement,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: widget.onOpenAgreement,
          ),
        ApplyTick(
          text: l10n.iHaveReadTheCoachAgreementAnd_egtgj,
          value: _ticked,
          onChanged: (on) => setState(() => _ticked = on),
        ),
        AppButton(
          l10n.acceptTheAgreement,
          key: const ValueKey('agreement-sheet-accept'),
          onPressed: _ticked ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
