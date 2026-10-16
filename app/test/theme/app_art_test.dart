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
import 'package:own_hub/theme/hand_tokens.dart';
import 'package:own_hub/ui/hand/art_marks.dart';
import 'package:own_hub/ui/hand/art_palette.dart';
import 'package:own_hub/ui/hand/food_marks.dart';

/// Paints [markKey] into an image and returns the pixels, so two marks can be
/// compared as drawings rather than as names.
Future<ByteData> _pixels(
  String markKey, {
  bool rtl = false,
  double side = 96,
  HandMarkPen pen = ArtMarkPainter.artPen,
  HandLevel level = HandLevel.expressive,
}) async {
  final size = Size(side, side);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  ArtMarkPainter(
    markKey: markKey,
    ink: const Color(0xFF000000),
    rtl: rtl,
    pen: pen,
    level: level,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    side.toInt(),
    side.toInt(),
  );
  final data = await image.toByteData();
  image.dispose();
  return data!;
}

/// The same, for a shape drawn by the other painter, so a borrowed mark can be
/// compared against the thing it borrows.
Future<ByteData> _foodPixels(
  String markKey, {
  bool rtl = false,
  double side = 96,
  HandMarkPen pen = HandMarkPen.recipeCard,
  HandLevel level = HandLevel.expressive,
  ArtTone? tone,
  ArtTone? accent,
}) async {
  final size = Size(side, side);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  FoodMarkPainter(
    markKey: markKey,
    ink: const Color(0xFF000000),
    rtl: rtl,
    pen: pen,
    level: level,
    tone: tone,
    accent: accent,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    side.toInt(),
    side.toInt(),
  );
  final data = await image.toByteData();
  image.dispose();
  return data!;
}

/// The lowest row of the image that has real ink in it, as a fraction of the
/// box. Alpha above 40 rather than above 0, so the 13% wash inside a closed
/// shape and the antialiasing at the edge of a stroke do not count as the
/// bottom of the drawing.
double _lowestInk(ByteData d, int side) {
  for (var y = side - 1; y >= 0; y--) {
    for (var x = 0; x < side; x++) {
      if (d.getUint8((y * side + x) * 4 + 3) > 40) return y / side;
    }
  }
  return -1;
}

/// Pixels with any ink at all, which is one way to measure how fat a pen is:
/// the same path drawn with a wider nib covers more of the box.
int _inkedPixels(ByteData d) {
  var n = 0;
  for (var i = 3; i < d.lengthInBytes; i += 4) {
    if (d.getUint8(i) > 40) n++;
  }
  return n;
}

void main() {
  test('the names are unique', () {
    expect(AppArt.all.toSet().length, AppArt.all.length);
  });

  test('every name has its file at 1x, 2x and 3x, and nothing else ships', () {
    // A missing asset is not a compile error in Flutter: it is an empty box at
    // runtime, on a screen nobody looked at. And a file no name points at is
    // weight in every download for nothing.
    for (final name in AppArt.all) {
      for (final dir in ['assets/art', 'assets/art/2.0x', 'assets/art/3.0x']) {
        expect(
          File('$dir/$name.webp').existsSync(),
          isTrue,
          reason: '$dir/$name.webp is missing',
        );
      }
    }
    final shipped = Directory('assets/art')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n != 'LICENCE.md')
        .map((n) => n.replaceAll('.webp', ''))
        .toSet();
    expect(shipped, AppArt.all.toSet());
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

  testWidgets('every name is its own drawing, and the marks that face '
      'something really do turn round in Arabic', (tester) async {
    // Several questions asked of one set of renders, because rendering 32
    // marks twice is the expensive part and `Picture.toImage` only resolves on
    // the real event loop -- so it all has to happen inside ONE `runAsync`.
    // Split across three tests it was three times the work and, the first time
    // it was written, an await that never completed and a run that never
    // ended.
    await tester.runAsync(() async {
      // A name with no `case` falls through to the default drawing. That is
      // the right behaviour at runtime -- a blank corner reads as a failed
      // image load -- and the wrong thing to ship, so it is caught here.
      final fallback = _digest(
        await _pixels('a name that is deliberately not a mark'),
      );
      final silent = <String>[];
      final clashes = <String>[];
      final noOpFlip = <String>[];
      final flippedAnyway = <String>[];
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
        final flips = _digest(await _pixels(name, rtl: true)) != key;
        // Which names belong in `facing` is a judgement about pictures, and it
        // was made by looking at all 32 marks at 92 pt in both directions on
        // 28 September 2026: every figure with a profile, the trainer, the
        // bike, the glove, the plate with its fork and the steak with its fat
        // cap turn round; the dumbbell, the bowls, the fruit, the headphones,
        // the mat, the bag and the head-on figures do not. This test does not
        // re-ask that question -- "the painter flips what is in `facing`" is
        // the painter's own definition, and asserting it proves nothing.
        //
        // It asks the two things eyes cannot check by looking at one drawing:
        if (ArtMarkPainter.facing.contains(name)) {
          // That the flip is not a no-op. A mark that happens to be
          // left-right symmetric would sit in `facing` looking correct and
          // mirror to exactly the same picture, and nobody would ever see the
          // difference the entry claims to make.
          if (!flips) noOpFlip.add(name);
        } else {
          // And that nothing flips behind this set's back. The six borrowed
          // marks are drawn by `FoodMarkPainter`, which has a `facing` set of
          // its own, so a name can be absent here and still turn round -- or
          // be flipped twice and turn round not at all.
          if (flips) flippedAnyway.add(name);
        }
      }

      expect(silent, isEmpty, reason: 'these names draw the fallback');
      // The old pack could not express this: `running`, `run_side`, `jogger`
      // and `dumbbell_run` were four names for one picture, and nothing could
      // tell. One name, one drawing is the rule now, and this holds it.
      expect(clashes, isEmpty);
      expect(
        noOpFlip,
        isEmpty,
        reason:
            'these are in `facing` but mirror to the same picture, so the '
            'entry buys nothing',
      );
      expect(
        flippedAnyway,
        isEmpty,
        reason: 'these are not in `facing` and turned round anyway',
      );
    });
  });

  test('every mark has colours, and they are a real name', () {
    // A name with no entry in `toneFor` still draws -- it falls back to one
    // flat ink -- so the failure is a mark that is quietly the wrong medium
    // next to a painted one in the same header strip, which is exactly the
    // defect the pen parameter exists to stop in the other direction.
    final uncoloured = AppArt.all
        .where((n) => !ArtMarkPainter.toneFor.containsKey(n))
        .toList();
    expect(uncoloured, isEmpty, reason: 'these marks have no tone');

    // And nothing is coloured that is not drawn.
    expect(
      ArtMarkPainter.toneFor.keys.toSet().difference(AppArt.all.toSet()),
      isEmpty,
    );
    expect(
      ArtMarkPainter.accentFor.keys.toSet().difference(AppArt.all.toSet()),
      isEmpty,
    );
    expect(ArtMarkPainter.figures.difference(AppArt.all.toSet()), isEmpty);
  });

  test('every figure is rose, and nothing else is', () {
    // The one decision in this set that is not about taste. Twelve marks are a
    // woman's body and every one of them is a single flat colour, head
    // included: no skin tone, no hair, no face, no garment. Whether a woman in
    // Egypt covers her hair is hers to decide, and an empty-state drawing has
    // no business answering it -- which is also why Microsoft Fluent Emoji was
    // turned down despite being MIT. See `assets/art/LICENCE.md`.
    //
    // "Rose" is the tone's name and is kept; since the Linen, Petrol and Pale
    // Pink palette it is a Pale Pink fill with a petrol line (`ArtTones.rose`).
    // The bundled WebP illustrations were recoloured to the same inks on
    // 16 October 2026, but their pixels are not asserted here.
    //
    // Asserting the colour rather than the absence is what makes this
    // checkable: a second tone appearing on a figure is how a face or a
    // covering would arrive, because it takes a second colour to draw one.
    for (final name in ArtMarkPainter.figures) {
      expect(
        ArtMarkPainter.toneFor[name],
        ArtTones.rose,
        reason: '$name is a figure drawn in something other than one rose',
      );
      expect(
        ArtMarkPainter.accentFor.containsKey(name),
        isFalse,
        reason: '$name is a figure with a second colour on it',
      );
    }
  });

  test('every mark this painter faces is a real name', () {
    expect(
      ArtMarkPainter.facing.difference(AppArt.all.toSet()),
      isEmpty,
      reason: 'a name in `facing` that no longer exists flips nothing',
    );
  });

  test('a borrowed shape faces the same way in both painters', () {
    // `borrow` un-sets `rtl` for the names this painter has already mirrored,
    // so a shape in both sets flips once rather than twice. The failure it
    // guards is silent in the other direction too: a food shape put into
    // `FoodMarkPainter.facing` and not into this one turns round on a recipe
    // card and not in a header strip, which is the same drawing pointing two
    // ways in one app.
    final disagree = <String>[];
    ArtMarkPainter.borrowed.forEach((artName, foodName) {
      if (ArtMarkPainter.facing.contains(artName) !=
          FoodMarkPainter.facing.contains(foodName)) {
        disagree.add('$artName/$foodName');
      }
    });
    expect(disagree, isEmpty);
  });

  test('every borrowed name is a real name on both sides', () {
    expect(
      ArtMarkPainter.borrowed.keys.toSet().difference(AppArt.all.toSet()),
      isEmpty,
    );
    expect(
      ArtMarkPainter.borrowed.values.toSet().difference(FoodMarks.all.toSet()),
      isEmpty,
    );
  });

  testWidgets('a borrowed mark is drawn with the same pen as a native one', (
    tester,
  ) async {
    // E05 draws `pasta` (borrowed from `pot`) beside `buddha_bowl` (native).
    // The borrowed one used to arrive with the recipe card's pen on it: a 23%
    // wider nib and 1.64x the wobble, two hands in one header strip.
    await tester.runAsync(() async {
      const fat = HandMarkPen(
        strokeFactor: 0.06,
        minStroke: 3,
        wobbleReference: 20,
      );

      // Hand a pen that cannot be mistaken for either default to a native mark
      // and to a borrowed one. If either painter reached past its `pen` field
      // for a constant, one of these would come back unchanged.
      expect(
        _digest(await _pixels('buddha_bowl', pen: fat)),
        isNot(_digest(await _pixels('buddha_bowl'))),
        reason: 'a native mark ignored the pen it was given',
      );
      // The colours are handed down with the pen now, so the comparison has to
      // hand them down too -- otherwise this would only be re-measuring that a
      // painted pot and an unpainted one are different pictures, which is the
      // point of `art_palette.dart` rather than a bug.
      final tone = ArtMarkPainter.toneFor['pasta'];
      final accent = ArtMarkPainter.accentFor['pasta'];
      expect(tone, isNotNull, reason: 'pasta lost its colours');

      expect(
        _digest(await _pixels('pasta', pen: fat)),
        _digest(
          await _foodPixels(
            FoodMarks.pot,
            pen: fat,
            tone: tone,
            accent: accent,
          ),
        ),
        reason: 'the borrowed shape was not drawn with the pen handed down',
      );

      // And with nothing passed, the borrowed shape is this file's pen rather
      // than the card's.
      expect(
        _digest(await _pixels('pasta')),
        _digest(
          await _foodPixels(
            FoodMarks.pot,
            pen: ArtMarkPainter.artPen,
            tone: tone,
            accent: accent,
          ),
        ),
      );
      final borrowed = await _pixels('pasta');
      final onACard = await _foodPixels(FoodMarks.pot);
      expect(
        _digest(borrowed),
        isNot(_digest(onACard)),
        reason:
            'the recipe card pen and the art pen cannot be the same, or '
            'this whole fix is a no-op',
      );
      // Measured rather than asserted from the constants: the art pen is
      // 0.026 against the card's 0.032, so the same path must cover visibly
      // less of the box. The bounds are wide because a stroke that crosses
      // itself does not count twice.
      //
      // Both sides are PAINTED for this one. Measured against the card's own
      // one-ink render the ratio would be about 3, because a solid fill covers
      // far more of the box than a 13% wash -- which measures the palette, not
      // the pen. Same shape, same colours, one difference: the nib.
      final sameShapeCardPen = await _foodPixels(
        FoodMarks.pot,
        tone: tone,
        accent: accent,
      );
      final ratio = _inkedPixels(borrowed) / _inkedPixels(sameShapeCardPen);
      expect(ratio, lessThan(0.99), reason: 'borrowed pen is not thinner');
      expect(ratio, greaterThan(0.6), reason: 'borrowed pen is far too thin');
    });
  });

  testWidgets('every mark stands on the shared baseline', (tester) async {
    // R01 puts `dumbbells` next to `running` and E05 puts a borrowed `pot`
    // next to `buddha_bowl`. The figures always ended at 0.88; the objects
    // ended wherever their shape did -- the dumbbell at 0.70 -- so the two
    // marks in a strip floated at different heights.
    //
    // Measured at `structural`, which is wobble 0: at `expressive` the hand
    // drifts three points of the box at this size, and a bound wide enough to
    // allow for that is wide enough to let a mark sit off the rule and pass.
    //
    // The window is the rule itself at the top and the rule plus five points
    // at the bottom, because a mark is measured as it is DRAWN, not as it is
    // specified: half the nib sits below the path, and a closed shape's base
    // is a curve through its points, which bows a little past them. The marks
    // that draw a straight foot land at 0.891 and the tubs at 0.926.
    const rule = handMarkBaseline;
    await tester.runAsync(() async {
      const side = 256.0;
      final off = <String>[];
      for (final name in AppArt.all) {
        final y = _lowestInk(
          await _pixels(name, side: side, level: HandLevel.structural),
          side.toInt(),
        );
        if (y < rule || y > rule + 0.05) {
          off.add('$name(${y.toStringAsFixed(3)})');
        }
      }
      for (final name in FoodMarks.all) {
        final y = _lowestInk(
          await _foodPixels(name, side: side, level: HandLevel.structural),
          side.toInt(),
        );
        if (y < rule || y > rule + 0.05) {
          off.add('$name(${y.toStringAsFixed(3)})');
        }
      }
      expect(
        off,
        isEmpty,
        reason:
            'lowest ink should sit on handMarkBaseline ($rule); each entry '
            'names the mark and where its lowest ink actually landed',
      );
    });
  });

  testWidgets('every mark paints at the sizes it is really used at', (
    tester,
  ) async {
    // The redrawn marks carry more strokes than the ones they replaced -- a
    // cuff and lacing, a bone, a zip -- and a coordinate that is fine at 92 pt
    // can still divide by a rounding error at 16. The sizes are the smallest
    // and largest the product asks for: 30 pt beside a list row, 160 pt on
    // `whats_inside_view`, and the extremes either side of them.
    await tester.runAsync(() async {
      for (final side in [16.0, 28.0, 92.0, 256.0]) {
        for (final name in AppArt.all) {
          expect(
            (await _pixels(name, side: side)).lengthInBytes,
            side.toInt() * side.toInt() * 4,
            reason: '$name at $side',
          );
        }
      }
    });
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
