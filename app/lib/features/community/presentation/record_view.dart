/// **M16 — Record.** Blur is a camera control.
///
/// Matches `screens-community.mjs` → `M16`. The design note: *"Recording puts
/// blur on the rail beside the timer and the light, so it reads as an ordinary
/// camera control rather than a privacy setting buried elsewhere. Mode switches
/// at the bottom, the way every camera she already uses works."*
///
/// ## Blur is on, and it is on again next time
///
/// Rule 6. [RecordScreenModel.blurOn] comes from `blurFacesDefault`, which is
/// true, and every composition builds a fresh model — so turning it off applies
/// to that image only and the next one starts blurred again (`P0-COM-09`). This
/// screen renders the switch position it is given and decides nothing.
///
/// ## What the rail offers is decided by flags, not by this file
///
/// The Reel chip is present only when `communityVideo` is on, because
/// [RecordScreenModel.modes] asked. The Voice control is present only when
/// `communityVoiceNotes` is on, because [RecordScreenModel.offersVoiceNote]
/// asked. Neither is deleted, so neither needs finding again when a flag flips.
///
/// There is no capture behind any of it — no frame sampling, no blur export,
/// no transcode. `PostPublishService.allows` is the single place that refuses a
/// reel, which is the honest state rather than a surface that pretends.
///
/// ## Publishing raises nothing
///
/// Rule 9. The confirm control hands off to `PostPublishService.enqueue`, whose
/// `undoWindow` state is five seconds of snackbar **before** the upload starts.
/// There is no dialog on this screen, and there is no dialog anywhere under
/// `lib/features/` — `product_rules_test.dart` enforces it.
///
/// ## Missing copy, left out rather than invented
///
///   * The elapsed readout — *"0:12 / 1:00"* — has no parameterised form, and
///     the minted variants bake the mockup's durations into a sentence about
///     her recording. Omitted.
///   * The timer control on the rail wants *"15s"*. Same defect, same decision:
///     the control is not drawn.
///
/// Both are reported with the build.
library;

import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import 'community_widgets.dart';
import 'create_view_model.dart';

/// The label the dictionary carries for a capture mode, or null when it has
/// none.
///
/// Null rather than a fallback: an invented chip would show English to an
/// Arabic reader and no test of the English UI would notice.
String? recordModeLabel(RecordMode mode, AppL10n l10n) => switch (mode) {
  RecordMode.reel => l10n.reel,
  RecordMode.story => l10n.story,
  RecordMode.post => l10n.post,
};

class RecordView extends StatelessWidget {
  const RecordView({
    super.key,
    required this.model,
    this.selectedMode,
    this.onClose,
    this.onSelectMode,
    this.onToggleBlur,
    this.onToggleLight,
    this.onToggleVoice,
    this.onOpenGallery,
    this.onCapture,
    this.onConfirm,
    this.lightOn = false,
    this.voiceOn = false,
  });

  final RecordScreenModel model;

  /// The mode she is on. Defaults to the first the model offers.
  final RecordMode? selectedMode;

  final VoidCallback? onClose;
  final ValueChanged<RecordMode>? onSelectMode;
  final ValueChanged<bool>? onToggleBlur;
  final VoidCallback? onToggleLight;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onCapture;

  /// Hands off to the publish pipeline, which opens a five-second undo window
  /// before anything uploads. No dialog, here or there.
  final VoidCallback? onConfirm;

  final bool lightOn;
  final bool voiceOn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Nothing may be composed at all — the whole feature is dark. The ordinary
    // panel, with no shutter and no camera behind it.
    if (!model.available || model.modes.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: l10n.create,
          onBack: onClose,
          leadingIcon: Icons.close,
        ),
        body: const AppScaffold(children: [NotAvailablePanel()]),
      );
    }

    final modes = model.modes;
    final current = selectedMode == null ? modes.first : selectedMode!;
    final labels = <String>[
      for (final mode in modes) recordModeLabel(mode, l10n) ?? '',
    ];
    final selectedIndex = modes.indexOf(current);

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: SafeArea(
        child: Stack(
          children: [
            // The viewfinder. There is no camera behind it in this build, and
            // the placeholder draws no play control — nothing here is video.
            const Positioned.fill(
              child: AppMedia(
                height: double.infinity,
                kind: AppMediaKind.photo,
                showPlayButton: false,
                borderRadius: 0,
              ),
            ),
            PositionedDirectional(
              start: 4,
              end: 4,
              top: 2,
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    tooltip: l10n.close,
                    color: AppColors.inverseOnSurface,
                    icon: const Icon(Icons.close),
                  ),
                  // The elapsed readout belongs here. Its only minted forms
                  // state the mockup's durations, so nothing is drawn.
                  const Spacer(),
                ],
              ),
            ),
            PositionedDirectional(
              end: 8,
              top: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The timer control wants "15s" and the dictionary has no
                  // parameterised form, so it is omitted rather than invented.
                  RecordRailButton(
                    icon: Icons.bolt,
                    label: l10n.light,
                    selected: lightOn,
                    onTap: onToggleLight,
                  ),
                  // Rule 6, on the rail and on, exactly where a camera control
                  // belongs.
                  RecordRailButton(
                    icon: Icons.blur_on,
                    label: l10n.blur,
                    selected: model.blurOn,
                    onTap: onToggleBlur == null
                        ? null
                        : () => onToggleBlur!(!model.blurOn),
                  ),
                  // Absent because the flag is off, not because it was cut.
                  if (model.offersVoiceNote)
                    RecordRailButton(
                      icon: Icons.mic_none,
                      label: l10n.voice,
                      selected: voiceOn,
                      onTap: onToggleVoice,
                    ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 96,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppChipRow(
                  items: labels,
                  selected: <int>{if (selectedIndex >= 0) selectedIndex},
                  onTap: (i) => onSelectMode?.call(modes[i]),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 18,
              child: _Controls(
                galleryLabel: l10n.gallery,
                publishLabel: l10n.publish,
                onOpenGallery: onOpenGallery,
                onCapture: onCapture,
                onConfirm: onConfirm,
              ),
            ),
            // Last, so it draws above the viewfinder rather than behind it.
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: ScreenArtStrip(size: 64),
            ),
          ],
        ),
      ),
    );
  }
}

/// One control on the camera rail.
///
/// Public so a test can read its [selected] state directly: "blur is on"
/// is a product rule, and a rule proved through a colour comparison is a rule
/// proved by accident.
class RecordRailButton extends StatelessWidget {
  const RecordRailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;

  /// Already resolved by the screen.
  final String label;

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // On is a filled disc as well as a brighter icon: two
                  // signals, so it does not rest on colour alone.
                  color: selected
                      ? AppColors.primary
                      : AppColors.inverseSurface.withValues(alpha: 0.42),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.inverseOnSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.label.copyWith(
                  color: AppColors.inverseOnSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shutter.
///
/// Public for the same reason [RecordRailButton] is: a control with no label —
/// every camera she already uses draws this one as a circle and nothing else —
/// still has to be findable by the tests that prove what it does.
class RecordShutterButton extends StatelessWidget {
  const RecordShutterButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.inverseOnSurface, width: 4),
          ),
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The gallery, the shutter and the confirm.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.galleryLabel,
    required this.publishLabel,
    this.onOpenGallery,
    this.onCapture,
    this.onConfirm,
  });

  final String galleryLabel;
  final String publishLabel;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onCapture;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onOpenGallery,
            tooltip: galleryLabel,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.photo_library_outlined, size: 28),
          ),
          RecordShutterButton(onTap: onCapture),
          IconButton(
            onPressed: onConfirm,
            tooltip: publishLabel,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.check_circle, size: 38),
          ),
        ],
      ),
    );
  }
}
