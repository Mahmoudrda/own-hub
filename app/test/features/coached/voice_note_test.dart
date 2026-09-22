// P0-MSG-03 and P0-MSG-04 — record, preview, send; and the two things that
// never happen.
//
// "Nothing is sent on selection or on release" is a claim about a state
// machine, so it is tested as one: there is no transition from `recording` to
// `sending`, and asking for one throws rather than quietly succeeding.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/voice_note.dart';

void main() {
  group('P0-MSG-03 — record, preview, send', () {
    test('letting go produces a preview, not a send', () {
      var draft = VoiceNoteDraft.start('m12');
      expect(draft.state, VoiceNoteState.recording);

      draft = draft.ticked(const Duration(seconds: 12));
      draft = draft.stopRecording();

      expect(draft.state, VoiceNoteState.preview);
      expect(draft.duration, const Duration(seconds: 12));
      expect(draft.hasPreview, isTrue);
    });

    test('sending straight from recording is not a transition that exists', () {
      final recording = VoiceNoteDraft.start('m13');
      expect(() => recording.sending(), throwsA(isA<StateError>()));
    });

    test('cancel discards, and leaves nothing behind', () {
      var draft = VoiceNoteDraft.start('m14')
          .ticked(const Duration(seconds: 7))
          .stopRecording();

      draft = draft.cancel();

      expect(draft.state, VoiceNoteState.idle);
      expect(draft.duration, Duration.zero);
      expect(draft.id, isEmpty);
    });

    test('the full path reaches sent', () {
      final draft = VoiceNoteDraft.start('m15')
          .ticked(const Duration(seconds: 23))
          .stopRecording()
          .sending()
          .sent();
      expect(draft.state, VoiceNoteState.sent);
    });

    test('nothing is sent when she picks an attachment', () {
      // Picking is a choice of what to record or attach; it is not a send, and
      // there is no method on the draft that a picker could call to send one.
      expect(AttachmentPick.values, hasLength(3));
      final idle = VoiceNoteDraft.idle();
      expect(() => idle.sending(), throwsA(isA<StateError>()));
    });
  });

  group('P0-MSG-02 — a failed send retries under the same id', () {
    test('the id is minted once, at the start of recording', () {
      final draft = VoiceNoteDraft.start('m16')
          .ticked(const Duration(seconds: 9))
          .stopRecording()
          .sending()
          .failed();

      expect(draft.state, VoiceNoteState.failed);
      expect(draft.retryId, 'm16');
      expect(draft.canSend, isTrue, reason: 'retry is available inline');
      expect(draft.sending().id, 'm16', reason: 'one message, never two');
    });
  });

  group('P0-MSG-04 — blur is applied before anything leaves the handset', () {
    test('an unblurred attachment cannot be sent', () {
      // The draft records what the upload gateway did. A send with blur not
      // applied is refused here as well as at the door — coach media is not an
      // exception, and rule 6 does not care who the audience is.
      final unblurred = VoiceNoteDraft.attachment(
        id: 'm17',
        blurApplied: false,
        duration: const Duration(seconds: 6),
      );
      expect(unblurred.hasPreview, isTrue);
      expect(() => unblurred.sending(), throwsA(isA<StateError>()));
    });

    test('a blurred attachment sends normally', () {
      final blurred = VoiceNoteDraft.attachment(id: 'm18', blurApplied: true);
      expect(blurred.sending().state, VoiceNoteState.sending);
    });

    test(
      'blurApplied has no default — the caller must state what happened',
      () {
        final source = File('lib/features/coached/domain/voice_note.dart')
            .readAsStringSync();
        final factory = source.substring(
          source.indexOf('factory VoiceNoteDraft.attachment'),
          source.indexOf('final String id;'),
        );
        expect(factory, contains('required bool blurApplied'));
        expect(factory.contains('blurApplied = true'), isFalse);
      },
    );
  });

  group('a voice note is never transcribed for the coach', () {
    test('no type in this feature has a field that could hold words', () {
      final banned = RegExp(
        r'\b(transcript|transcription|transcribe|speechToText|asr)\b',
        caseSensitive: false,
      );
      final offenders = <String>[];

      for (final file
          in Directory('lib/features/coached')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          // Comments may say "never transcribed"; code may not say it at all.
          if (line.startsWith('//') || line.startsWith('///')) continue;
          if (banned.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A transcript is a copy of her voice in words, handed to someone '
            'she recorded a voice note for on purpose.',
      );
    });
  });
}
