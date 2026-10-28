// The sound system: the cue table against the files, the gates that keep it
// polite (her switch, the server, the foreground, her first touch, the rate
// limit), and her two Profile switches.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/feel_prefs.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/app_state/sound.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_sound.dart';

/// What a 16-bit mono PCM WAV says about itself, and its loudest sample.
({int channels, int rate, int bits, Duration length, double peakDb}) _wav(
  File file,
) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  final channels = data.getUint16(22, Endian.little);
  final rate = data.getUint32(24, Endian.little);
  final bits = data.getUint16(34, Endian.little);
  expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
  final size = data.getUint32(40, Endian.little);
  var peak = 0;
  for (var i = 0; i < size; i += 2) {
    final v = data.getInt16(44 + i, Endian.little).abs();
    if (v > peak) peak = v;
  }
  final frames = size ~/ (bits ~/ 8) ~/ channels;
  return (
    channels: channels,
    rate: rate,
    bits: bits,
    length: Duration(microseconds: frames * 1000000 ~/ rate),
    peakDb: peak == 0 ? -120 : 20 * math.log(peak / 32768) / math.ln10,
  );
}

void main() {
  late FakeSoundBackend backend;

  setUp(() => backend = setUpFakeSound());
  tearDown(tearDownFakeSound);

  group('the cue table', () {
    final soundsDir = Directory('assets/sounds');
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('every cue has files, a length cap and a level note', () {
      for (final cue in SoundCue.values) {
        final spec = kSoundCues[cue];
        expect(spec, isNotNull, reason: '${cue.name} has no row');
        expect(spec!.files, isNotEmpty);
        expect(spec.lengthCap, greaterThan(Duration.zero));
        expect(spec.lengthCap, lessThanOrEqualTo(const Duration(seconds: 2)));
        expect(spec.level, isNotEmpty);
      }
      expect(kSoundCues.keys.toSet(), SoundCue.values.toSet());
    });

    test('every file exists, is declared in pubspec.yaml and is used', () {
      final listed = <String>{
        for (final spec in kSoundCues.values) ...spec.files,
      };
      for (final file in listed) {
        expect(File(file).existsSync(), isTrue, reason: file);
        expect(pubspec, contains('    - $file\n'), reason: '$file undeclared');
      }
      final onDisk = {
        for (final f in soundsDir.listSync().whereType<File>())
          if (f.path.endsWith('.wav')) f.path,
      };
      expect(onDisk, listed, reason: 'an orphan file, or a missing one');
    });

    test('the folder itself is not bundled, so SOUNDS.md stays out', () {
      expect(pubspec, isNot(contains('    - assets/sounds/\n')));
      expect(File('assets/sounds/SOUNDS.md').existsSync(), isTrue);
      final notes = File('assets/sounds/SOUNDS.md').readAsStringSync();
      for (final file in kSoundCues.values.expand((s) => s.files)) {
        expect(notes, contains(file.split('/').last.replaceAll('.wav', '')));
      }
      expect(notes, contains('Synthesised'));
      expect(notes, contains('Licence'));
    });

    test('files are mono 16-bit, short, quiet and small in all', () {
      var total = 0;
      for (final entry in kSoundCues.entries) {
        for (final file in entry.value.files) {
          final wav = _wav(File(file));
          expect((wav.channels, wav.bits), (1, 16), reason: file);
          expect(wav.rate, 22050, reason: file);
          expect(
            wav.length,
            lessThanOrEqualTo(entry.value.lengthCap),
            reason: '$file is longer than its cap',
          );
          expect(wav.peakDb, lessThan(-11.0), reason: '$file is too loud');
          total += File(file).lengthSync();
        }
      }
      expect(total, lessThan(450 * 1024));
    });

    test('only the finish may run to two seconds', () {
      for (final cue in SoundCue.values) {
        if (cue == SoundCue.sessionDone || cue == SoundCue.personalBest) {
          continue;
        }
        expect(
          kSoundCues[cue]!.lengthCap,
          lessThanOrEqualTo(const Duration(milliseconds: 1500)),
          reason: cue.name,
        );
      }
    });

    test('a set has five pitches, one per set of the move', () {
      expect(kSoundCues[SoundCue.setDone]!.files, hasLength(5));
    });

    test('the audio plugin is a declared dependency', () {
      expect(pubspec, contains('\n  audioplayers: '));
    });
  });

  group('the gates', () {
    test('nothing plays before the files are loaded', () async {
      AppSound.debugUse(null);
      await AppSound.play(SoundCue.saved);
      expect(backend.played, isEmpty);
    });

    test('a cue plays, and a variant picks its file', () async {
      AppSound.clock = _steppingClock();
      await AppSound.play(SoundCue.setDone);
      await AppSound.play(SoundCue.setDone, variant: 3);
      expect(backend.names, ['set_done_1', 'set_done_4']);
    });

    test('an out of range variant is held to the files the cue has', () async {
      AppSound.clock = _steppingClock();
      await AppSound.play(SoundCue.setDone, variant: 99);
      await AppSound.play(SoundCue.setDone, variant: -4);
      expect(backend.names, ['set_done_5', 'set_done_1']);
    });

    test('her switch off means silent', () async {
      await FeelPrefs.instance.setSounds(false);
      await AppSound.play(SoundCue.sessionDone);
      expect(backend.played, isEmpty);
      await FeelPrefs.instance.setSounds(true);
      await AppSound.play(SoundCue.sessionDone);
      expect(backend.names, ['session_done']);
    });

    test('the server flag off means silent', () async {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      AppSound.debugReset();
      AppSound.debugUse(backend);
      AppRouter.featureFlags = FeatureFlags.allOff.with_({Feature.sounds: true});
      await AppSound.play(SoundCue.saved);
      expect(backend.names, ['saved']);

      AppSound.clock = _steppingClock();
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.sounds: false,
      });
      await AppSound.play(SoundCue.saved);
      expect(backend.names, ['saved'], reason: 'the flag is off');
      expect(Feature.sounds.serverMayTurnOff, isTrue);
      expect(Feature.sounds.parent, isNull);
    });

    testWidgets('nothing plays with the app out of the foreground', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await AppSound.play(SoundCue.verified);
      expect(backend.played, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await AppSound.play(SoundCue.verified);
      expect(backend.played, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await AppSound.play(SoundCue.verified);
      expect(backend.names, ['verified']);
    });

    testWidgets('silent until she has touched the app, then plays', (
      tester,
    ) async {
      AppSound.debugUse(null, touched: false);
      AppSound.enabled = () => true;
      await AppSound.start(backend: backend);
      expect(backend.loaded, isNotEmpty);

      await AppSound.play(SoundCue.verified);
      expect(backend.played, isEmpty, reason: 'a screen opening by itself');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('hello'))),
        ),
      );
      await tester.tap(find.text('hello'));
      await AppSound.play(SoundCue.verified);
      expect(backend.names, ['verified']);
    });

    testWidgets('a screen reader activation counts as a touch', (
      tester,
    ) async {
      AppSound.debugUse(null, touched: false);
      AppSound.enabled = () => true;
      await AppSound.start(backend: backend);
      await AppSound.play(SoundCue.verified);
      expect(backend.played, isEmpty);

      tester.binding.platformDispatcher.onSemanticsActionEvent?.call(
        const ui.SemanticsActionEvent(
          type: ui.SemanticsAction.tap,
          viewId: 0,
          nodeId: 0,
        ),
      );
      await AppSound.play(SoundCue.verified);
      expect(backend.names, ['verified']);
    });

    test('the same cue is held to once per 400 ms, others are not', () async {
      var now = DateTime(2026, 10, 28, 9);
      AppSound.clock = () => now;
      await AppSound.play(SoundCue.restTick);
      now = now.add(const Duration(milliseconds: 399));
      await AppSound.play(SoundCue.restTick);
      await AppSound.play(SoundCue.restEnd);
      expect(backend.names, ['rest_tick', 'rest_end']);
      now = now.add(const Duration(milliseconds: 1));
      await AppSound.play(SoundCue.restTick);
      expect(backend.names, ['rest_tick', 'rest_end', 'rest_tick']);
    });

    test('playOnce plays the first time for a key and never again', () async {
      AppSound.clock = _steppingClock();
      await AppSound.playOnce(SoundCue.sessionDone, 'r10:a');
      await AppSound.playOnce(SoundCue.sessionDone, 'r10:a');
      await AppSound.playOnce(SoundCue.sessionDone, 'r10:b');
      expect(backend.names, ['session_done', 'session_done']);
    });

    test('a switch that is off does not spend the once', () async {
      await FeelPrefs.instance.setSounds(false);
      await AppSound.playOnce(SoundCue.verified, 'c13');
      await FeelPrefs.instance.setSounds(true);
      await AppSound.playOnce(SoundCue.verified, 'c13');
      expect(backend.names, ['verified']);
    });

    test('a backend that cannot load leaves the app silent, not broken', () async {
      final broken = _BrokenBackend();
      AppSound.debugUse(null);
      await AppSound.start(backend: broken);
      await AppSound.play(SoundCue.saved);
      expect(broken.played, 0);
    });

    test('start loads every file of every cue once', () async {
      AppSound.debugUse(null);
      await AppSound.start(backend: backend);
      expect(backend.loaded.toSet(), {
        for (final spec in kSoundCues.values) ...spec.files,
      });
      await AppSound.start(backend: _BrokenBackend());
      await AppSound.play(SoundCue.saved);
      expect(backend.names, ['saved'], reason: 'a second start changes nothing');
    });
  });

  group('her two switches', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('both start on', () async {
      await FeelPrefs.instance.load();
      expect(FeelPrefs.instance.sounds, isTrue);
      expect(FeelPrefs.instance.haptics, isTrue);
    });

    test('each is kept on the phone and read back', () async {
      await FeelPrefs.instance.setSounds(false);
      await FeelPrefs.instance.setHaptics(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kSoundsOnKey), isFalse);
      expect(prefs.getBool(kHapticsOnKey), isFalse);

      FeelPrefs.instance.debugReset();
      await FeelPrefs.instance.load();
      expect(FeelPrefs.instance.sounds, isFalse);
      expect(FeelPrefs.instance.haptics, isFalse);
    });

    test('the two are independent', () async {
      await FeelPrefs.instance.setSounds(false);
      expect(FeelPrefs.instance.haptics, isTrue);
    });

    test('haptics off means nothing is felt', () async {
      final saved = AppRouter.featureFlags;
      final felt = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              felt.add(call.arguments as String?);
            }
            return null;
          });
      addTearDown(() {
        AppRouter.featureFlags = saved;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.haptics: true,
      });
      await AppHaptics.play(HapticMoment.actionDone);
      expect(felt, hasLength(1));
      await FeelPrefs.instance.setHaptics(false);
      await AppHaptics.play(HapticMoment.actionDone);
      expect(felt, hasLength(1), reason: 'her switch is off');
    });

    test('sound does not read Reduce Motion', () async {
      // The gates are her switch, the server, the foreground and her touch.
      // Nothing in the service reads the motion setting, so a woman who has
      // Reduce Motion on still hears her cues.
      await AppSound.play(SoundCue.restEnd);
      expect(backend.names, ['rest_end']);
    });
  });
}

DateTime Function() _steppingClock() {
  var now = DateTime(2026, 10, 28, 9);
  return () => now = now.add(const Duration(seconds: 1));
}

class _BrokenBackend implements SoundBackend {
  int played = 0;

  @override
  Future<void> load(Iterable<String> bundleKeys) async =>
      throw StateError('no audio here');

  @override
  Future<void> play(String bundleKey) async => played++;
}
