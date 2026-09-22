/// G15 — a voice note: **record, preview, send.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G15`. Its design note: *"Nothing
/// sends on selection: record, preview, then send, with cancel available
/// throughout — and a failed send retries without duplicating the message."*
///
/// The screen has three controls under the waveform and their order is the
/// design: **Cancel · Preview · Send**. Send is last and is reachable only from
/// the preview state, which `VoiceNoteDraft` enforces — asking it to send while
/// recording throws rather than quietly succeeding.
///
/// The three attachment chips below pick *what* to attach. Picking is not
/// sending, which the line underneath states and the state machine guarantees.
///
/// Her voice is never transcribed for the coach. There is no field for words on
/// any type this screen touches, and a source test bans the vocabulary across
/// the whole feature.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/voice_note.dart';
import 'coached_widgets.dart';

class VoiceNoteView extends StatelessWidget {
  const VoiceNoteView({
    super.key,
    this.onBack,
    this.onCancel,
    this.onPreview,
    this.onSend,
    this.onPickPhoto,
    this.onPickClip,
    this.onPickWorkout,
    this.draft,
    this.duration,
    this.coachName,
    this.lastMessage,
  });

  final VoidCallback? onBack;

  /// Discards. Available throughout.
  final VoidCallback? onCancel;

  final VoidCallback? onPreview;

  /// Sends. Reachable only from the preview state.
  final VoidCallback? onSend;

  final VoidCallback? onPickPhoto;
  final VoidCallback? onPickClip;
  final VoidCallback? onPickWorkout;

  /// The draft being made. Null renders the mockup's recording state.
  final VoiceNoteDraft? draft;

  /// "0:12". A value, not copy.
  final String? duration;

  final String? coachName;
  final String? lastMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = draft?.state ?? VoiceNoteState.recording;
    final canSend = draft?.canSend ?? false;

    return AppScaffold(
      appBar: AppTopBar(title: coachName ?? l10n.saraHany, onBack: onBack),
      footer: [
        CoachedComposer(
          hint: state == VoiceNoteState.recording
              ? l10n.recording
              : l10n.messageSara,
          attachTooltip: l10n.photo,
          voiceTooltip: l10n.voiceNote,
        ),
      ],
      children: [
        ChatBubble(text: lastMessage ?? l10n.yesIHaveUpdatedThursdayTheNew),
        AppCard(
          gap: 10,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.voiceNote, style: AppText.titleM)),
                AppPill(
                  duration ?? '0:12',
                  background: AppColors.errorContainer,
                  foreground: AppColors.error,
                ),
              ],
            ),
            const _RecordingWaveform(),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    l10n.cancel,
                    variant: AppButtonVariant.text,
                    height: 44,
                    fontSize: 14,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    l10n.preview,
                    variant: AppButtonVariant.outlined,
                    height: 44,
                    fontSize: 14,
                    onPressed: onPreview,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    l10n.send,
                    height: 44,
                    fontSize: 14,
                    icon: Icons.send,
                    // Only from the preview. The draft is the authority; a null
                    // draft is the mockup's recording state, where send is off.
                    onPressed: canSend ? onSend : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppChip(
                l10n.photo,
                icon: Icons.image_outlined,
                onTap: onPickPhoto,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppChip(
                l10n.formClip,
                icon: Icons.videocam_outlined,
                onTap: onPickClip,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppChip(
                l10n.todaysWorkout,
                icon: Icons.fitness_center,
                onTap: onPickWorkout,
              ),
            ),
          ],
        ),
        // Picking is not sending, and the state machine agrees.
        Text(
          l10n.nothingIsSentWhenYouPickIt,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The bars while she records. Decoration: a real waveform of her voice would
/// be a second copy of it.
class _RecordingWaveform extends StatelessWidget {
  const _RecordingWaveform();

  static const List<double> _heights = [
    14,
    26,
    38,
    20,
    34,
    44,
    22,
    30,
    16,
    24,
    36,
    18,
    28,
    12,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (final (i, h) in _heights.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  color: i < 9 ? AppColors.primary : AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
