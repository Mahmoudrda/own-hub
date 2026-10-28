/// E03 — "Say it". The voice capture state machine, G5 §3.3.
///
/// `idle → recording → transcribing → transcriptShown → …`, with
/// `transcribing → failed` on a timeout and `recording → refused` when there is
/// no on-device model and no signal.
///
/// ## The rule this file exists to make structural
///
/// **`transcriptShown` is mandatory and non-skippable** (`P0-LOG-08`). The
/// transcript is shown *before* anything is saved, so a misheard word is
/// obvious while it is still free to fix. That is enforced here by [canLog]
/// being false in every other state — there is no transition from `recording` or
/// `transcribing` to a log, so a screen cannot save something she has not seen.
///
/// ## Interface from the dictionary, speech in her own words
///
/// The whole point of the screen, and the two halves live in different places.
/// The interface language is `AppL10n`; the dialect is the recogniser's locale.
/// Nothing in this file renders text, so it cannot leak one into the other.
///
/// ## The phone's speech service, and no other
///
/// Words come from the phone (`MealSpeechEngine`): on-device where the phone can,
/// its own network service where it must, and nothing of Own Hub's. Cloud STT
/// of our own stays off (G5 §9 Q4), so [VoiceState.refused] and
/// [VoiceState.denied] are real states a woman will reach: each says why in a
/// calm line and offers the keyboard, never a spinner.
library;

import 'package:meta/meta.dart';

import '../domain/food_library.dart';
import '../domain/meal_sentence_parser.dart';
import '../domain/meal_speech.dart';

/// Where the capture is. §3.3.
enum VoiceState {
  idle,
  recording,
  transcribing,

  /// The transcript is on screen and she has not confirmed it yet. Nothing has
  /// been saved and nothing can be until she leaves this state deliberately.
  transcriptShown,

  /// The recogniser timed out or errored. "Say it again" is offered.
  failed,

  /// This phone has no speech service that can do it. Routed to E02.
  refused,

  /// The microphone or speech recognition is off for Own Hub. She is told how
  /// to turn it on and offered the keyboard.
  denied,
}

/// What E03 renders.
///
/// Named `SayItState` rather than `SayItView` because the *widget* is
/// `SayItView`. Two classes with one name across the two files a screen is
/// built from is a collision waiting for whoever imports both.
@immutable
class SayItState {
  const SayItState({
    required this.state,
    this.transcript,
    this.parse = MealSentenceParse.empty,
    this.partial,
    this.failure,
  });

  static const SayItState idle = SayItState(state: VoiceState.idle);

  final VoiceState state;

  /// What was heard, in her own words.
  ///
  /// **Null until the recogniser produces one.** There is no sample transcript
  /// baked into this layer: the prototype's Arabic line is a mockup value, not
  /// copy, and inventing one here would put words in her mouth on a screen whose
  /// entire purpose is showing her what was actually heard. Null renders the
  /// screen without a transcript card, which is the honest state.
  final String? transcript;

  /// The same parser E02 uses, so typing and speaking cannot drift.
  final MealSentenceParse parse;

  /// What has been heard so far while she is still speaking. Never a
  /// transcript: it cannot be logged and it is not the words she will confirm.
  final String? partial;

  /// Why a session ended with nothing to confirm, for [VoiceState.failed].
  final SpeechFailure? failure;

  bool get isRecording => state == VoiceState.recording;
  bool get isBusy =>
      state == VoiceState.recording || state == VoiceState.transcribing;

  /// The transcript is visible and there is something in it to log.
  ///
  /// Both halves matter: `P0-LOG-08` requires the transcript be shown *before*
  /// saving, and a transcript that resolved to nothing has nothing to save.
  bool get canLog =>
      state == VoiceState.transcriptShown && parse.items.isNotEmpty;

  /// True when she should be offered the keyboard instead.
  bool get shouldOfferTyping =>
      state == VoiceState.refused ||
      state == VoiceState.failed ||
      state == VoiceState.denied;
}

/// Drives the capture. Owns no recogniser — the platform supplies transcripts
/// and this decides what they mean.
class SayItViewModel {
  const SayItViewModel({required this.parser});

  final MealSentenceParser parser;

  SayItState start() => const SayItState(state: VoiceState.recording);

  /// Words so far, while she is still speaking.
  SayItState listening(String partial) =>
      SayItState(state: VoiceState.recording, partial: partial);

  SayItState stopped() => const SayItState(state: VoiceState.transcribing);

  /// A transcript arrived. It is **shown**, not logged.
  ///
  /// Note what this returns: [VoiceState.transcriptShown], never anything
  /// closer to a commit. The screen cannot skip ahead, because there is no
  /// method here that would take it there. Hesitation sounds on their own
  /// ("um") are not a transcript: they come back as [SpeechFailure.noSpeech].
  SayItState heard(String transcript) {
    final parse = parser.parse(transcript);
    if (transcript.trim().isEmpty || parse.isEmpty) {
      return failed(SpeechFailure.noSpeech);
    }
    return SayItState(
      state: VoiceState.transcriptShown,
      transcript: transcript,
      parse: parse,
    );
  }

  /// She fixed a word in the transcript: the sentence is read again, and she is
  /// still looking at what will be added.
  SayItState edited(SayItState state, String transcript) => SayItState(
    state: VoiceState.transcriptShown,
    transcript: transcript,
    parse: parser.parse(transcript),
  );

  /// The recogniser timed out or errored. "Say it again."
  SayItState failed([SpeechFailure reason = SpeechFailure.failed]) =>
      switch (reason) {
        SpeechFailure.denied => const SayItState(state: VoiceState.denied),
        SpeechFailure.unavailable => refuse(),
        _ => SayItState(state: VoiceState.failed, failure: reason),
      };

  /// No speech service on this phone, and tier 2 is off (§9 Q4).
  SayItState refuse() => const SayItState(state: VoiceState.refused);

  /// She adjusted a size on one of the parsed rows before confirming.
  SayItState resize(SayItState state, int index, FoodSize size) => SayItState(
    state: state.state,
    transcript: state.transcript,
    parse: state.parse.withSizeAt(index, size),
  );

  /// She removed a row the recogniser got wrong.
  SayItState remove(SayItState state, int index) => SayItState(
    state: state.state,
    transcript: state.transcript,
    parse: state.parse.withoutAt(index),
  );
}
