/// G15 — a voice note: **record, preview, send.**
///
/// Three properties, all of them absences:
///
///  1. **Nothing is sent on selection or on release.** The states run
///     `idle → recording → preview → sending → sent`, and there is no
///     transition from `recording` straight to `sending`. Letting go of the
///     button produces a preview, which is a thing she can cancel.
///  2. **A voice note is never transcribed for the coach.** This file has no
///     transcript field, no `transcribe` method and nothing that could hold
///     words. Neither does [MessageAttachment]. `coached_product_rules_test`
///     bans the vocabulary across the whole feature, so adding one is a red
///     build rather than a code review someone might skim.
///  3. **A failed send retries without duplicating.** The draft mints its id
///     once, at [VoiceNoteDraft.start], and [retryId] hands back the same one.
///     One message, never two.
///
/// Blur belongs to the upload gateway, not here: a clip of her squatting is
/// coach media and rule 6 does not care who the audience is. This file records
/// **whether** blur ran, so a send can refuse when it did not.
library;

import 'package:meta/meta.dart';

/// Where a draft is.
enum VoiceNoteState {
  idle,

  /// The microphone is live. Nothing exists to send yet.
  recording,

  /// She has something she can listen to, cancel, or send.
  preview,

  sending,
  sent,

  /// The send was rejected. The row shows it with an inline retry.
  failed,
}

/// What may travel with a message besides a voice note.
enum AttachmentPick { photo, formClip, todaysWorkout }

/// One voice note being made.
@immutable
class VoiceNoteDraft {
  const VoiceNoteDraft._({
    required this.id,
    required this.state,
    required this.duration,
    this.blurApplied = true,
  });

  /// Nothing recorded yet.
  factory VoiceNoteDraft.idle() => const VoiceNoteDraft._(
    id: '',
    state: VoiceNoteState.idle,
    duration: Duration.zero,
  );

  /// Begins recording, minting the id **once**.
  ///
  /// The id is minted here rather than at send so that a retry after a
  /// rejection reuses it. That is what makes "a failed send retries without
  /// duplicating the message" structural rather than a promise.
  factory VoiceNoteDraft.start(String id) => VoiceNoteDraft._(
    id: id,
    state: VoiceNoteState.recording,
    duration: Duration.zero,
  );

  /// A photo or a form clip she picked, waiting in preview.
  ///
  /// [blurApplied] is **required and has no default**. The upload gateway is
  /// what actually blurs, and this is where it reports back — a default of true
  /// would be this type claiming something it cannot know, and a default of
  /// false would let a caller forget. `sending()` refuses when it is false, so
  /// an unblurred clip cannot leave the handset even if every other check is
  /// somehow passed.
  factory VoiceNoteDraft.attachment({
    required String id,
    required bool blurApplied,
    Duration duration = Duration.zero,
  }) => VoiceNoteDraft._(
    id: id,
    state: VoiceNoteState.preview,
    duration: duration,
    blurApplied: blurApplied,
  );

  final String id;
  final VoiceNoteState state;
  final Duration duration;

  /// Whether on-device blur ran, for a clip or a photo. A voice note carries no
  /// face, so it is trivially true; the field exists so the same draft type can
  /// refuse an unblurred clip at [send].
  final bool blurApplied;

  bool get isRecording => state == VoiceNoteState.recording;
  bool get hasPreview => state == VoiceNoteState.preview;
  bool get canSend =>
      state == VoiceNoteState.preview || state == VoiceNoteState.failed;

  /// One tick of the recorder.
  VoiceNoteDraft ticked(Duration elapsed) {
    if (!isRecording) return this;
    return VoiceNoteDraft._(
      id: id,
      state: state,
      duration: elapsed,
      blurApplied: blurApplied,
    );
  }

  /// She let go. This produces a **preview**, never a send.
  VoiceNoteDraft stopRecording() {
    if (!isRecording) {
      throw StateError('Nothing is recording, so there is nothing to preview.');
    }
    return VoiceNoteDraft._(
      id: id,
      state: VoiceNoteState.preview,
      duration: duration,
      blurApplied: blurApplied,
    );
  }

  /// Discards. Available throughout, and it leaves nothing behind.
  VoiceNoteDraft cancel() => VoiceNoteDraft.idle();

  /// Marks the send in flight.
  ///
  /// Throws when there is no preview to send, which is the state machine
  /// refusing "sent on release" rather than a comment asking it not to happen.
  VoiceNoteDraft sending() {
    if (!canSend) {
      throw StateError(
        'A voice note is sent from its preview. Nothing sends on selection or '
        'on release.',
      );
    }
    if (!blurApplied) {
      throw StateError(
        'Blur has not been applied. Coach media follows the same rule as a '
        'community post.',
      );
    }
    return VoiceNoteDraft._(
      id: id,
      state: VoiceNoteState.sending,
      duration: duration,
      blurApplied: blurApplied,
    );
  }

  VoiceNoteDraft sent() => VoiceNoteDraft._(
    id: id,
    state: VoiceNoteState.sent,
    duration: duration,
    blurApplied: blurApplied,
  );

  VoiceNoteDraft failed() => VoiceNoteDraft._(
    id: id,
    state: VoiceNoteState.failed,
    duration: duration,
    blurApplied: blurApplied,
  );

  /// The id to retry under — the same one, always.
  String get retryId => id;

  @override
  String toString() =>
      'VoiceNoteDraft($id ${state.name} ${duration.inSeconds}s)';
}
