/// The one question before her first meal photo.
///
/// Asked once per account on this phone, as a sheet over the screen she is
/// on, before the camera opens. It says where the photo goes, that it is not
/// kept or used for training, that a fingerprint of it and the foods found
/// are kept for 30 days to answer the same photo again, and that she checks
/// everything before it is logged. "Agree" records it on the server (`record_meal_photo_consent`,
/// version [kMealPhotoConsentVersion]); only once the server has answered is
/// it remembered here. "Not now" closes it and nothing is sent.
///
/// This is a consent, not a confirmation of a log: no meal is anywhere near
/// being written when it shows, so rule 9 is untouched.
library;

import 'package:flutter/material.dart';

import '../../../app_state/meal_scan_state.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../../signup/domain/legal_acceptance.dart' show kAppVersion;
import '../domain/meal_scan.dart';

/// True when she has agreed, now or before. Shows the sheet only when she has
/// not.
Future<bool> ensureMealPhotoConsent(
  BuildContext context, {
  required MealScanState state,
  required String? uid,
}) async {
  if (await state.hasConsented(uid)) return true;
  if (!context.mounted) return false;
  final agreed = await showAppSheet<bool>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => MealPhotoConsentBody(
          state: state,
          uid: uid,
          onAgreed: () => Navigator.of(sheet).pop(true),
          onNotNow: () => Navigator.of(sheet).pop(false),
        ),
      ),
    ],
  );
  return agreed ?? false;
}

/// The words and the two answers. Drawn in the sheet, and inline on E12 when
/// the camera is opened without having been asked.
class MealPhotoConsentBody extends StatefulWidget {
  const MealPhotoConsentBody({
    super.key,
    required this.state,
    required this.uid,
    required this.onAgreed,
    required this.onNotNow,
  });

  final MealScanState state;
  final String? uid;

  /// Called once the server has recorded her agreement.
  final VoidCallback onAgreed;
  final VoidCallback onNotNow;

  @override
  State<MealPhotoConsentBody> createState() => _MealPhotoConsentBodyState();
}

class _MealPhotoConsentBodyState extends State<MealPhotoConsentBody> {
  bool _sending = false;
  bool _failed = false;

  Future<void> _agree() async {
    if (_sending) return;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await widget.state.client.recordConsent(
        locale: locale,
        appVersion: kAppVersion.isEmpty ? null : kAppVersion,
      );
      await widget.state.rememberConsent(widget.uid);
      if (!mounted) return;
      widget.onAgreed();
    } on MealScanException {
      if (mounted) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              size: 26,
              color: AppColors.primaryDim,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.beforeYourFirstPhoto, style: AppText.titleL),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.yourPhotoGoesToOurAiIn, style: AppText.body),
        const SizedBox(height: 10),
        Text(
          l10n.upTo5PhotosADayYou,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.weKeepAFingerprintOfThePhoto,
          key: const ValueKey('meal-consent-cache-line'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (_failed) ...[
          const SizedBox(height: 10),
          Text(
            l10n.weCouldntSaveYourAnswerCheckYour,
            key: const ValueKey('meal-consent-failed'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurface),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          l10n.agree,
          key: const ValueKey('meal-consent-agree'),
          onPressed: _sending ? null : _agree,
        ),
        const SizedBox(height: 6),
        AppButton(
          l10n.notNow,
          key: const ValueKey('meal-consent-not-now'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 16,
          onPressed: _sending ? null : widget.onNotNow,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
