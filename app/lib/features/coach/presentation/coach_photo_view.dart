/// `K01` — Add a photo of you.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K01`. One thing: her photo, taken
/// live with the front lens, and the blur that goes with it. Her name and city
/// are the next screen (`K08`).
///
/// # Blur is on when she arrives
///
/// The mockup used to write *"Face visible. Clients pick a person, not a
/// logo"* under her photo, which is an instruction. §2 rule 6 says blur
/// defaults on, and G12 §9 **Q1** resolved the collision: *"default blurred,
/// with an explicit 'show my face' action … Confirm the copy reflects a choice,
/// not an instruction."* So the switch is named, the line under it says what
/// each position means, and the preview shows her photo the way it will be
/// shown: blurred while the switch is on.
///
/// The photo is optional. A coach can carry on without one and add it from her
/// page; a step that refused to move until she photographed herself would be
/// the kind of wall this flow exists to take down.
library;

import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_toggle.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachPhotoView extends StatefulWidget {
  const CoachPhotoView({
    super.key,
    required this.model,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
    this.onTakePhoto,
  });

  final CoachSetupViewModel model;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// Opens the front camera and answers with the photo, or null when she
  /// closed it. Null draws no camera button.
  final Future<Uint8List?> Function()? onTakePhoto;

  @override
  State<CoachPhotoView> createState() => _CoachPhotoViewState();
}

class _CoachPhotoViewState extends State<CoachPhotoView> {
  bool _taking = false;

  Future<void> _take() async {
    final take = widget.onTakePhoto;
    if (take == null || _taking) return;
    setState(() => _taking = true);
    final bytes = await take();
    if (!mounted) return;
    setState(() {
      _taking = false;
      if (bytes != null) widget.model.photo = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.photo,
      title: l10n.addAPhotoOfYou,
      subtitle: l10n.womenChooseAPersonTheyCanSee,
      onBack: widget.onBack,
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: () => goToScreen(context, 'K08', widget.onContinue),
      children: [
        Center(
          child: _PhotoWell(
            photo: model.photo,
            blurred: model.photoBlurred,
            onTap: widget.onTakePhoto == null ? null : _take,
          ),
        ),
        if (widget.onTakePhoto != null)
          AppButton(
            model.photo == null ? l10n.takeAPhoto : l10n.takeItAgain,
            variant: AppButtonVariant.tonal,
            height: 48,
            fontSize: 15,
            icon: Icons.photo_camera,
            onPressed: _taking ? null : _take,
          ),
        // Rule 6, as a named action. On when she arrives; only this moves it.
        Row(
          children: [
            Expanded(
              child: Text(l10n.blurFacesInMyPhotos, style: AppText.titleS),
            ),
            const SizedBox(width: 12),
            AppToggle(
              value: model.photoBlurred,
              semanticLabel: l10n.blurFacesInMyPhotos,
              onChanged: (on) => setState(() => model.photoBlurred = on),
            ),
          ],
        ),
        // The consequence of the switch, stated in the position she is in.
        Text(
          model.photoBlurred
              ? l10n.facesBlurredBeforeItUploads
              : l10n.faceVisibleClientsPickAPersonNot,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Her photo as women will see it, or the place one will go.
class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.photo, required this.blurred, this.onTap});

  final Uint8List? photo;
  final bool blurred;
  final VoidCallback? onTap;

  static const double _size = 120;

  @override
  Widget build(BuildContext context) {
    final bytes = photo;
    final Widget face = bytes == null
        ? const Icon(
            Icons.photo_camera,
            size: 44,
            color: AppColors.onPrimaryContainer,
          )
        : ImageFiltered(
            enabled: blurred,
            imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Image.memory(
              bytes,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
    return Semantics(
      button: onTap != null,
      image: bytes != null,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: ClipOval(
          child: Container(
            width: _size,
            height: _size,
            alignment: Alignment.center,
            color: AppColors.primaryContainer,
            child: face,
          ),
        ),
      ),
    );
  }
}
