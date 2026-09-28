// Every illustration name must have a real drawing behind it.
//
// This used to check that every name had a WebP file at 1x, 2x and 3x, because
// a missing asset is not a compile error in Flutter -- it is a grey box at
// runtime, on a screen nobody looked at. The pack is gone (see
// assets/art/LICENCE.md) and the illustrations are painted, so the same hole
// now looks different: a name with no `case` in ArtMarkPainter falls through to
// the default and draws a yoga mat on a screen about food. That is quieter than
// a grey box and therefore worse, so it is what these tests hunt for.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/theme/app_art.dart';
import 'package:own_hub/ui/hand/art_marks.dart';

/// Paints [markKey] into an image and returns the pixels, so two marks can be
/// compared as drawings rather than as names.
Future<ByteData> _pixels(String markKey, {bool rtl = false}) async {
  const size = Size(96, 96);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  ArtMarkPainter(
    markKey: markKey,
    ink: const Color(0xFF000000),
    rtl: rtl,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(96, 96);
  final data = await image.toByteData();
  image.dispose();
  return data!;
}

void main() {
  test('the names are unique', () {
    expect(AppArt.all.toSet().length, AppArt.all.length);
  });

  test('no illustration file is shipped at all', () {
    // The whole point of the change: assets/art holds the licence record and
    // nothing else. A `.webp`, `.png` or `.svg` reappearing here means someone
    // has put a third-party asset back in the binary, which is exactly what
    // LICENCE.md exists to stop.
    final dir = Directory('assets/art');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n != 'LICENCE.md')
        .toList();
    expect(files, isEmpty, reason: 'assets/art should hold only LICENCE.md');
  });

  test('the pack has a licence record, and it covers every name', () {
    // `find . -iname "*licen*"` once returned two ONNX licences and two font
    // licences and nothing for the illustrations, while `cupcake.webp` was
    // byte-identical to an element of a Canva-produced book whose licence
    // forbids exactly this use. The pack is gone; this record is what stops it
    // coming back, so the build fails if the record does.
    final record = File('assets/art/LICENCE.md');
    expect(record.existsSync(), isTrue);
    final text = record.readAsStringSync();
    for (final name in AppArt.all) {
      expect(
        text.contains(name),
        isTrue,
        reason: '$name is drawn and is not in the licence record',
      );
    }
    // The finding is kept as history on purpose: whoever proposes adding a
    // stock illustration should have to read why these went.
    expect(text.contains('Canva'), isTrue);
    expect(text.contains('cupcake.webp'), isTrue);
  });

  testWidgets('every name is its own drawing, and only the ones that face '
      'something turn round in Arabic', (tester) async {
    // Three questions asked of one set of renders, because rendering 32 marks
    // twice is the expensive part and `Picture.toImage` only resolves on the
    // real event loop -- so it all has to happen inside ONE `runAsync`. Split
    // across three tests it was three times the work and, the first time it
    // was written, an await that never completed and a run that never ended.
    await tester.runAsync(() async {
      // A name with no `case` falls through to the default drawing. That is
      // the right behaviour at runtime -- a blank corner reads as a failed
      // image load -- and the wrong thing to ship, so it is caught here.
      final fallback = _digest(
        await _pixels('a name that is deliberately not a mark'),
      );
      final silent = <String>[];
      final clashes = <String>[];
      final wrongWayRound = <String>[];
      final seen = <String, String>{};

      for (final name in AppArt.all) {
        final ltr = await _pixels(name);
        final key = _digest(ltr);
        if (key == fallback) silent.add(name);
        if (seen.containsKey(key)) {
          clashes.add('$name == ${seen[key]}');
        } else {
          seen[key] = name;
        }
        // Decorative, but not arbitrary: a runner heading into the left margin
        // of a right-to-left page is running backwards. Marks with no front --
        // a dumbbell, a bowl -- must NOT flip, or their hand-drawn wobble
        // would lean a different way in each language for no reason.
        final flips = _digest(await _pixels(name, rtl: true)) != key;
        if (flips != ArtMarkPainter.facing.contains(name)) {
          wrongWayRound.add(name);
        }
      }

      expect(silent, isEmpty, reason: 'these names draw the fallback');
      // The old pack could not express this: `running`, `run_side`, `jogger`
      // and `dumbbell_run` were four names for one picture, and nothing could
      // tell. One name, one drawing is the rule now, and this holds it.
      expect(clashes, isEmpty);
      expect(wrongWayRound, isEmpty, reason: 'mirrored against `facing`');
    });
  });

  test('every mark this painter faces is a real name', () {
    expect(
      ArtMarkPainter.facing.difference(AppArt.all.toSet()),
      isEmpty,
      reason: 'a name in `facing` that no longer exists flips nothing',
    );
  });
}

String _digest(ByteData d) {
  // Every tenth byte, which is the alpha channel of every other pixel: enough
  // to tell two drawings apart without holding 64 full bitmaps at once, and
  // enough that a mark differing from another by one stroke still differs
  // here, because a stroke covers far more than one pixel at 96 square.
  final b = StringBuffer();
  for (var i = 3; i < d.lengthInBytes; i += 10) {
    b.write(d.getUint8(i).toRadixString(16));
  }
  return b.toString();
}
