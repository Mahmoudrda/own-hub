/// Saying a meal: what the screen needs from a phone's speech service, and
/// nothing about which one it is.
///
/// E03 talks to a [MealSpeechEngine]. The shipped one wraps Apple Speech and
/// Android's SpeechRecognizer (`data/platform_meal_speech.dart`); a test gives
/// it a fake. Words come back as text and nothing else: Own Hub holds no
/// microphone stream and keeps no audio.
///
/// ## Two rules this interface exists to make hard to break
///
///  * **Nothing prompts by itself.** [isAllowed] only reads. [prepare] is the
///    one call that can raise the system's microphone and speech prompts, and
///    the screen calls it only from a tap of hers.
///  * **A word is not a result until she sees it.** Partial words stream out
///    while she speaks, but only one event with [SpeechEvent.isFinal] ends a
///    session, and the screen shows that as a transcript she can fix. Nothing
///    here can log.
library;

import 'package:meta/meta.dart';

/// Why a session ended without words, or why speech cannot start.
enum SpeechFailure {
  /// The microphone or speech recognition is off for Own Hub.
  denied,

  /// This phone has no speech service that can do it.
  unavailable,

  /// She said nothing the phone could hear.
  noSpeech,

  /// The phone needed the internet to turn her words into text and had none.
  offline,

  /// Anything else; trying again may work.
  failed,
}

/// One thing the speech service said.
@immutable
class SpeechEvent {
  const SpeechEvent.words(this.words, {this.isFinal = false}) : failure = null;

  const SpeechEvent.failed(this.failure) : words = '', isFinal = true;

  /// What has been heard so far. Empty for a failure.
  final String words;

  /// True on the one event that ends a session, with her words or a failure.
  final bool isFinal;

  final SpeechFailure? failure;
}

abstract class MealSpeechEngine {
  /// True when the phone already lets Own Hub listen. Reads only; never raises
  /// a system prompt.
  Future<bool> isAllowed();

  /// Gets the phone ready, raising the system prompts the first time. Null
  /// means she can speak now; otherwise why not. Call it only from a tap.
  Future<SpeechFailure?> prepare();

  /// The recogniser languages the phone offers, as the phone writes them
  /// ("ar_EG", "en-US"). Empty when it cannot say.
  Future<List<String>> locales();

  /// Starts listening in [localeId] (null: the phone's own language) and
  /// reports until one final event, which also closes the stream.
  Stream<SpeechEvent> listen({String? localeId});

  /// She is done speaking: a final event follows with what was heard.
  Future<void> stop();

  /// Drop the session. No event follows, and nothing is kept.
  Future<void> cancel();
}

/// The engine the app uses. Replaced in a test, so a screen that is opened by
/// route never reaches a platform channel.
abstract final class MealSpeech {
  static MealSpeechEngine? _engine;
  static MealSpeechEngine Function() create = _unset;

  static MealSpeechEngine get engine => _engine ??= create();

  /// Swaps the engine; pass null to go back to [create].
  static set engine(MealSpeechEngine? next) => _engine = next;

  static MealSpeechEngine _unset() => const UnavailableSpeechEngine();
}

/// The engine of a phone with no speech service, and the default until the app
/// installs the real one.
class UnavailableSpeechEngine implements MealSpeechEngine {
  const UnavailableSpeechEngine();

  @override
  Future<bool> isAllowed() async => false;

  @override
  Future<SpeechFailure?> prepare() async => SpeechFailure.unavailable;

  @override
  Future<List<String>> locales() async => const <String>[];

  @override
  Stream<SpeechEvent> listen({String? localeId}) =>
      Stream.value(const SpeechEvent.failed(SpeechFailure.unavailable));

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

/// The recogniser language to ask for, from what the phone offers.
///
/// Arabic prefers Egypt (`ar-EG`), then any Arabic; English prefers the US,
/// then Britain, then any English. The two platforms write ids differently
/// ("ar_EG" and "ar-EG"), so they are compared with the separator and case
/// ignored, and the id returned is the phone's own spelling. Null when the
/// phone offers none, which leaves the choice to the phone.
String? pickSpeechLocale(Iterable<String> offered, {required bool arabic}) {
  String fold(String id) => id.toLowerCase().replaceAll('_', '-');
  final language = arabic ? 'ar' : 'en';
  final wanted = arabic ? const ['ar-eg'] : const ['en-us', 'en-gb'];
  final all = offered.toList();
  for (final want in wanted) {
    for (final id in all) {
      if (fold(id) == want) return id;
    }
  }
  for (final id in all) {
    final folded = fold(id);
    if (folded == language || folded.startsWith('$language-')) return id;
  }
  return null;
}
