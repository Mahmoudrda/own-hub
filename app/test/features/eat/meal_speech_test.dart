// The two pure halves of F2 that do not need a phone: which recogniser language
// is asked for, and what each platform error string means to the screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/platform_meal_speech.dart';
import 'package:own_hub/features/eat/domain/meal_speech.dart';

void main() {
  group('the recogniser language', () {
    test('Arabic prefers Egypt, however the phone writes it', () {
      expect(
        pickSpeechLocale(['ar_SA', 'ar_EG', 'en_US'], arabic: true),
        'ar_EG',
      );
      expect(pickSpeechLocale(['ar-SA', 'ar-EG'], arabic: true), 'ar-EG');
      expect(pickSpeechLocale(['AR_eg'], arabic: true), 'AR_eg');
    });

    test('Arabic falls back to any Arabic, then to the phone\'s choice', () {
      expect(pickSpeechLocale(['en_US', 'ar_SA'], arabic: true), 'ar_SA');
      expect(pickSpeechLocale(['ar'], arabic: true), 'ar');
      expect(pickSpeechLocale(['en_US', 'fr_FR'], arabic: true), isNull);
      expect(pickSpeechLocale(const [], arabic: true), isNull);
    });

    test('English prefers the US, then Britain, then any English', () {
      expect(pickSpeechLocale(['en_GB', 'en_US'], arabic: false), 'en_US');
      expect(pickSpeechLocale(['en-AU', 'en-GB'], arabic: false), 'en-GB');
      expect(pickSpeechLocale(['ar_EG', 'en_AU'], arabic: false), 'en_AU');
      expect(pickSpeechLocale(['ar_EG'], arabic: false), isNull);
    });

    test('a language that only looks like Arabic or English is not one', () {
      expect(pickSpeechLocale(['ara_XX', 'enm_US'], arabic: true), isNull);
      expect(pickSpeechLocale(['ara_XX', 'enm_US'], arabic: false), isNull);
    });
  });

  group('what a platform error means', () {
    const noSpeech = ['error_no_match', 'error_speech_timeout'];
    const offline = [
      'error_network',
      'error_network_timeout',
      'error_server',
      'error_server_disconnected',
      'error_too_many_requests',
      'error_retry',
      'error_speech_recognizer_connection_invalidated',
      'error_speech_recognizer_connection_interrupted',
    ];
    const denied = [
      'error_permission',
      'error_speech_recognizer_request_not_authorized',
      'error_speech_recognizer_disabled',
    ];
    const unavailable = [
      'error_language_not_supported',
      'error_language_unavailable',
      'error_assets_not_installed',
    ];
    const failed = [
      'error_busy',
      'error_audio_error',
      'error_client',
      'error_speech_recognizer_already_active',
      'error_request_cancelled',
      'error_unknown (7)',
      'something we have never seen',
    ];

    for (final (reason, errors) in [
      (SpeechFailure.noSpeech, noSpeech),
      (SpeechFailure.offline, offline),
      (SpeechFailure.denied, denied),
      (SpeechFailure.unavailable, unavailable),
      (SpeechFailure.failed, failed),
    ]) {
      test('${reason.name}: ${errors.length} strings', () {
        for (final error in errors) {
          expect(speechFailureFor(error), reason, reason: error);
        }
      });
    }
  });

  test('a phone with no speech service refuses and never listens', () async {
    const engine = UnavailableSpeechEngine();
    expect(await engine.isAllowed(), isFalse);
    expect(await engine.prepare(), SpeechFailure.unavailable);
    final event = await engine.listen().first;
    expect(event.failure, SpeechFailure.unavailable);
    expect(event.isFinal, isTrue);
  });
}
