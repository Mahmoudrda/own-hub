// What the app tells her about the profile photo is true: it is kept on the
// phone and never uploaded by Own Hub, but a backup of the whole phone made
// earlier can hold a copy, so no text says it is outside every backup.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the camera text keeps the ID promise and says the photo is not uploaded', () {
    for (final path in [
      'ios/Runner/Info.plist',
      'ios/Runner/en.lproj/InfoPlist.strings',
    ]) {
      final text = read(path);
      expect(
        text,
        contains('ID card, selfie and meal photographs are read in memory'),
        reason: path,
      );
      expect(text, contains('never stored'), reason: path);
      expect(
        text,
        contains(
          'A profile photo you take stays on this phone. Photos you add as a '
          'coach (your photo, certificates, feedback and results) are uploaded '
          'for Own Hub to check',
        ),
        reason: path,
      );
      expect(text, isNot(contains('Your profile photo stays on this phone')));
      expect(text, isNot(contains('is never uploaded')), reason: path);
    }
    final arabic = read('ios/Runner/ar.lproj/InfoPlist.strings');
    expect(arabic, contains('ومش بتتخزّن أبدًا'));
    expect(arabic, contains('بتفضل على موبايلك'));
    expect(arabic, contains('بتترفع، وOwn Hub بتراجعها'));
    for (final path in [
      'ios/Runner/Info.plist',
      'ios/Runner/en.lproj/InfoPlist.strings',
      'ios/Runner/ar.lproj/InfoPlist.strings',
    ]) {
      expect(read(path), contains('NSMicrophoneUsageDescription'), reason: path);
    }
  });

  test('the profile screen says kept, not that no copy exists anywhere', () {
    final view = read('lib/features/account/presentation/profile_view.dart');
    expect(view, contains('l10n.yourPhotoIsKeptOnThisPhone'));
    expect(view, isNot(contains('yourPhotoStaysOnThisPhoneOnly')));
    final en = read('lib/l10n/app_en.arb');
    expect(
      en,
      contains(
        '"yourPhotoIsKeptOnThisPhone": "Your photo is kept on this phone and '
        'never uploaded by Own Hub. Only you see it."',
      ),
    );
  });

  test('the code does not claim the photo is outside every backup', () {
    expect(
      read('lib/app_state/profile_photo_state.dart'),
      isNot(contains('not part of any backup')),
    );
  });

  test('the picker is not asked to resize, so it keeps no resized copy', () {
    // With a size limit the Android picker copies the whole picture into the
    // cache and hands back a scaled copy, leaving the original (with its
    // location) behind. The picture is drawn smaller in Dart instead.
    final source = read('lib/app_state/profile_photo_state.dart');
    final start = source.indexOf('.pickImage(');
    expect(start, isNonNegative, reason: 'the picker call moved');
    final call = source.substring(start, source.indexOf(');', start));
    for (final option in ['maxWidth', 'maxHeight', 'imageQuality']) {
      expect(call, isNot(contains(option)), reason: option);
    }
  });
}
