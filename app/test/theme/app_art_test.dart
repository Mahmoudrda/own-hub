// Every illustration name must have a real file behind it, at every density.
//
// A missing asset is not a compile error in Flutter -- it is a grey box at
// runtime, on a screen nobody looked at. This is the check that would have
// caught a renamed or dropped file before a woman saw the hole.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/theme/app_art.dart';

void main() {
  test('every named illustration exists at 1x, 2x and 3x', () {
    final missing = <String>[];
    for (final name in AppArt.all) {
      for (final density in ['', '2.0x/', '3.0x/']) {
        final f = File('assets/art/$density$name.webp');
        if (!f.existsSync()) missing.add(f.path);
      }
    }
    expect(missing, isEmpty, reason: 'missing illustration files');
  });

  test('no illustration is shipped at a size that could pixelate', () {
    // 3x files back a 200pt illustration. Anything much under 600px on the
    // longest side would be upscaled on a modern phone.
    final small = <String>[];
    for (final name in AppArt.all) {
      final f = File('assets/art/3.0x/$name.webp');
      if (f.existsSync() && f.lengthSync() < 2000) small.add(name);
    }
    expect(small, isEmpty, reason: 'suspiciously small 3x assets');
  });

  test('the names are unique', () {
    expect(AppArt.all.toSet().length, AppArt.all.length);
  });

  test('every shipped file is claimed by a name', () {
    // Catches an orphan left behind by a rename -- dead weight in the bundle.
    final dir = Directory('assets/art');
    final shipped = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.webp', ''))
        .toSet();
    expect(shipped.difference(AppArt.all.toSet()), isEmpty);
  });
}
