/// The phone's own speech service, behind [MealSpeechEngine].
///
/// Apple Speech on iOS and `SpeechRecognizer` on Android, through the
/// `speech_to_text` plugin. Own Hub never opens the microphone itself here and
/// keeps no audio: the plugin hands back text.
///
///  * The plugin is created on first use and `initialize()` is called only from
///    [prepare], because `initialize()` is what raises the system's microphone
///    and speech prompts. Nothing in this file runs at launch.
///  * Recognition is first asked to stay on the phone (`onDevice`). Where the
///    phone has no model for the language it falls back to its network service,
///    and where it has no connection either the session ends as
///    [SpeechFailure.offline], which the screen says calmly.
///  * Every platform error string is mapped by [speechFailureFor] from the
///    plugin's own Swift and Kotlin sources, so the screen deals in five
///    reasons rather than twenty codes.
library;

import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/meal_speech.dart';

/// The reason a plugin error string means, and whether another try without the
/// on-device model could help.
SpeechFailure speechFailureFor(String error) => switch (error) {
  'error_no_match' || 'error_speech_timeout' => SpeechFailure.noSpeech,
  'error_network' ||
  'error_network_timeout' ||
  'error_server' ||
  'error_server_disconnected' ||
  'error_too_many_requests' ||
  'error_retry' ||
  'error_speech_recognizer_connection_invalidated' ||
  'error_speech_recognizer_connection_interrupted' => SpeechFailure.offline,
  'error_permission' ||
  'error_speech_recognizer_request_not_authorized' ||
  'error_speech_recognizer_disabled' => SpeechFailure.denied,
  'error_language_not_supported' ||
  'error_language_unavailable' ||
  'error_assets_not_installed' => SpeechFailure.unavailable,
  _ => SpeechFailure.failed,
};

/// Errors that mean "not on the phone for this language", so a second try
/// without the on-device model is worth making before giving up.
bool _onDeviceUnavailable(String error) =>
    error == 'error_language_not_supported' ||
    error == 'error_language_unavailable' ||
    error == 'error_assets_not_installed';

class PlatformMealSpeechEngine implements MealSpeechEngine {
  PlatformMealSpeechEngine({SpeechToText? plugin})
    : _plugin = plugin ?? SpeechToText();

  final SpeechToText _plugin;

  /// Stops a session that is too quiet or too long: a pause of this length ends
  /// it, which is how "I'm done" is heard without a second tap.
  static const Duration pauseEndsIt = Duration(seconds: 3);
  static const Duration longestSession = Duration(seconds: 45);

  StreamController<SpeechEvent>? _session;
  String? _locale;
  String _heard = '';
  bool _triedOffDevice = false;

  @override
  Future<bool> isAllowed() async {
    try {
      return await _plugin.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SpeechFailure?> prepare() async {
    try {
      final ready = await _plugin.initialize(
        onError: _onError,
        onStatus: _onStatus,
        // No Bluetooth permission is asked for or declared.
        options: [SpeechToText.androidNoBluetooth],
      );
      return ready ? null : SpeechFailure.denied;
    } on PlatformException {
      return SpeechFailure.unavailable;
    } catch (_) {
      return SpeechFailure.failed;
    }
  }

  @override
  Future<List<String>> locales() async {
    try {
      return [for (final l in await _plugin.locales()) l.localeId];
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Stream<SpeechEvent> listen({String? localeId}) {
    unawaited(_session?.close());
    final session = StreamController<SpeechEvent>();
    _session = session;
    _locale = localeId;
    _heard = '';
    _triedOffDevice = false;
    unawaited(_begin(session, onDevice: true));
    return session.stream;
  }

  Future<void> _begin(
    StreamController<SpeechEvent> session, {
    required bool onDevice,
  }) async {
    try {
      await _plugin.listen(
        onResult: (result) => _onResult(session, result),
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          onDevice: onDevice,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          pauseFor: pauseEndsIt,
          listenFor: longestSession,
        ),
      );
    } on PlatformException {
      // iOS refuses an on-device request for a language it has no model for.
      if (onDevice && !_triedOffDevice) {
        _triedOffDevice = true;
        return _begin(session, onDevice: false);
      }
      _finish(session, const SpeechEvent.failed(SpeechFailure.unavailable));
    } catch (_) {
      _finish(session, const SpeechEvent.failed(SpeechFailure.failed));
    }
  }

  void _onResult(
    StreamController<SpeechEvent> session,
    SpeechRecognitionResult r,
  ) {
    if (!identical(session, _session) || session.isClosed) return;
    _heard = r.recognizedWords;
    if (!r.finalResult) {
      session.add(SpeechEvent.words(_heard));
    } else if (_heard.trim().isEmpty) {
      _finish(session, const SpeechEvent.failed(SpeechFailure.noSpeech));
    } else {
      _finish(session, SpeechEvent.words(_heard, isFinal: true));
    }
  }

  void _onError(SpeechRecognitionError error) {
    final session = _session;
    if (session == null || session.isClosed) return;
    if (_heard.isEmpty &&
        !_triedOffDevice &&
        _onDeviceUnavailable(error.errorMsg)) {
      _triedOffDevice = true;
      unawaited(_begin(session, onDevice: false));
      return;
    }
    // Words that arrived before the error are hers; she sees and fixes them.
    if (_heard.trim().isNotEmpty) {
      _finish(session, SpeechEvent.words(_heard, isFinal: true));
      return;
    }
    _finish(session, SpeechEvent.failed(speechFailureFor(error.errorMsg)));
  }

  void _onStatus(String status) {
    final session = _session;
    if (session == null || session.isClosed) return;
    // The plugin reports "done" only once it has sent the final result, or
    // after a session that heard nothing.
    if (status != SpeechToText.doneStatus && status != 'doneNoResult') return;
    _finish(
      session,
      _heard.trim().isEmpty
          ? const SpeechEvent.failed(SpeechFailure.noSpeech)
          : SpeechEvent.words(_heard, isFinal: true),
    );
  }

  void _finish(StreamController<SpeechEvent> session, SpeechEvent event) {
    if (session.isClosed) return;
    session.add(event);
    unawaited(session.close());
    if (identical(session, _session)) _session = null;
  }

  @override
  Future<void> stop() async {
    try {
      await _plugin.stop();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    final session = _session;
    _session = null;
    if (session != null && !session.isClosed) unawaited(session.close());
    try {
      await _plugin.cancel();
    } catch (_) {}
  }
}
