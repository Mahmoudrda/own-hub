// A speech service that does what a test tells it to: it never touches a
// platform channel, and it records every call so a test can say what was and
// was not asked of the phone.

import 'dart:async';

import 'package:own_hub/features/eat/domain/meal_speech.dart';

class FakeMealSpeech implements MealSpeechEngine {
  FakeMealSpeech({
    this.allowed = false,
    this.prepareResult,
    this.localeIds = const ['ar_EG', 'en_US'],
  });

  /// Whether the phone already lets Own Hub listen.
  bool allowed;

  /// What `prepare` says; null is "ready", and also records that she answered
  /// the system prompts with yes.
  SpeechFailure? prepareResult;

  final List<String> localeIds;

  int isAllowedCalls = 0;
  int prepareCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  String? lastLocale;

  StreamController<SpeechEvent>? _session;

  @override
  Future<bool> isAllowed() async {
    isAllowedCalls++;
    return allowed;
  }

  @override
  Future<SpeechFailure?> prepare() async {
    prepareCalls++;
    if (prepareResult == null) allowed = true;
    return prepareResult;
  }

  @override
  Future<List<String>> locales() async => localeIds;

  @override
  Stream<SpeechEvent> listen({String? localeId}) {
    listenCalls++;
    lastLocale = localeId;
    _session = StreamController<SpeechEvent>();
    return _session!.stream;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async {
    cancelCalls++;
    final session = _session;
    _session = null;
    if (session != null && !session.isClosed) await session.close();
  }

  bool get isListening => _session != null && !_session!.isClosed;

  /// Words so far, while she is still speaking.
  void say(String words) => _session!.add(SpeechEvent.words(words));

  /// The phone's final words, which end the session.
  void finish(String words) {
    _session!.add(SpeechEvent.words(words, isFinal: true));
    unawaited(_session!.close());
  }

  /// The session ends without words.
  void fail(SpeechFailure failure) {
    _session!.add(SpeechEvent.failed(failure));
    unawaited(_session!.close());
  }
}
