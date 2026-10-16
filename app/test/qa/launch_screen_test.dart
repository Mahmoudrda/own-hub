// WP3: the window a phone shows before Flutter draws is the brand's, not a
// white flash, on both platforms.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/theme/app_tokens.dart';

void main() {
  const res = 'android/app/src/main/res';

  test('both Android launch drawables carry the brand colour and the tile', () {
    for (final path in [
      '$res/drawable/launch_background.xml',
      '$res/drawable-v21/launch_background.xml',
    ]) {
      final xml = File(path).readAsStringSync();
      expect(xml, contains('@color/launch_background'), reason: path);
      expect(xml, contains('@drawable/launch_logo'), reason: path);
      expect(xml, isNot(contains('@android:color/white')), reason: path);
    }
    for (final density in ['mdpi', 'xhdpi', 'xxhdpi']) {
      expect(
        File('$res/drawable-$density/launch_logo.png').existsSync(),
        isTrue,
      );
    }
  });

  test('the launch colour is the surface the app paints first', () {
    final colors = File('$res/values/colors.xml').readAsStringSync();
    final hex = AppColors.surface
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();
    expect(colors, contains('name="launch_background">#$hex<'));
  });

  test('the iOS launch screen has the brand background and a real image', () {
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();
    expect(storyboard, isNot(contains('red="1" green="1" blue="1"')));
    expect(storyboard, contains('name="LaunchImage" width="88" height="88"'));
    for (final name in ['LaunchImage', 'LaunchImage@2x', 'LaunchImage@3x']) {
      final file = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/$name.png',
      );
      expect(file.lengthSync(), greaterThan(500), reason: name);
    }
  });
}
