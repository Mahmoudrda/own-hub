// The sixteen recipe-card drawings: that they are sixteen different pictures,
// that they turn round in Arabic when they point somewhere, and that the pen
// the cards were drawn with has not moved under them.
//
// `app_art_test.dart` covers the same ground for the 32 art marks and owns the
// two checks that span both sets: the shared baseline and the pen a borrowed
// shape is drawn with.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/food_marks.dart';

Future<ByteData> _pixels(
  String markKey, {
  bool rtl = false,
  double side = 96,
  HandMarkPen pen = HandMarkPen.recipeCard,
}) async {
  final size = Size(side, side);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  FoodMarkPainter(
    markKey: markKey,
    ink: const Color(0xFF000000),
    rtl: rtl,
    pen: pen,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    side.toInt(),
    side.toInt(),
  );
  final data = await image.toByteData();
  image.dispose();
  return data!;
}

/// Every pixel the drawing covers, wash included, so two marks can be compared
/// as shapes rather than as outlines.
List<bool> _silhouette(ByteData d) => [
  for (var i = 3; i < d.lengthInBytes; i += 4) d.getUint8(i) > 10,
];

/// How much of the two shapes is the same shape: shared pixels over pixels
/// either one covers. Two drawings of the same disc score near 1.
double _overlap(List<bool> a, List<bool> b) {
  var both = 0, either = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] && b[i]) both++;
    if (a[i] || b[i]) either++;
  }
  return either == 0 ? 1 : both / either;
}

/// The box the ink actually fills, as fractions of the side.
({double w, double h}) _inkedBox(ByteData d, int side) {
  var minX = side, maxX = -1, minY = side, maxY = -1;
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      if (d.getUint8((y * side + x) * 4 + 3) > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return (w: (maxX - minX) / side, h: (maxY - minY) / side);
}

String _digest(ByteData d) {
  final b = StringBuffer();
  for (var i = 3; i < d.lengthInBytes; i += 10) {
    b.write(d.getUint8(i).toRadixString(16));
  }
  return b.toString();
}

void main() {
  test('the names are unique and the facing set is made of them', () {
    expect(FoodMarks.all.toSet().length, FoodMarks.all.length);
    expect(
      FoodMarkPainter.facing.difference(FoodMarks.all.toSet()),
      isEmpty,
      reason: 'a name in `facing` that no longer exists turns nothing round',
    );
  });

  test('the recipe card keeps the pen its drawings were made with', () {
    // Fifteen of the sixteen placements are a card in the book, drawn and
    // looked at with this nib. The art strip's finer pen now reaches these
    // shapes through `ArtMarkPainter`, which is the point of `HandMarkPen` --
    // and the risk it introduces is someone "unifying" the two by moving this
    // one, which would redraw every card in the book without anyone asking.
    expect(HandMarkPen.recipeCard.strokeFactor, 0.032);
    expect(HandMarkPen.recipeCard.minStroke, 1.2);
    expect(HandMarkPen.recipeCard.wobbleReference, 56);
    expect(
      FoodMarkPainter(
        markKey: FoodMarks.jar,
        ink: const Color(0xFF000000),
      ).pen,
      HandMarkPen.recipeCard,
      reason: 'a card gets the card pen unless it is told otherwise',
    );
  });

  testWidgets('a card in Arabic turns the marks that point somewhere', (
    tester,
  ) async {
    // The widget end of it: `ArtMark` has read `Directionality` since the art
    // set was drawn and `FoodMark` did not, so the recipe book stayed
    // left-handed in Arabic -- the pan's handle running off the side of the
    // page the reader starts from.
    FoodMarkPainter painterOnScreen() {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(FoodMark),
          matching: find.byType(CustomPaint),
        ),
      );
      return paint.painter! as FoodMarkPainter;
    }

    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const FoodMark(markKey: FoodMarks.pan, ink: Color(0xFF000000)),
        ),
      );
      expect(
        painterOnScreen().rtl,
        direction == TextDirection.rtl,
        reason: '$direction',
      );
    }
  });

  testWidgets('a mark turns round if and only if it has a front', (
    tester,
  ) async {
    // The set was chosen by looking at all sixteen at 64 pt in both
    // directions on 28 September 2026: the pan's handle, the drumstick's
    // bone, the steak's fat cap, the cheese wedge's taper and the cake
    // slice's tip all point across the page and belong in `facing`; the
    // bowls, jar, pot, pancakes, egg, fries, potato and the cookie's bite do
    // not point anywhere.
    //
    // What is asserted here is what looking cannot tell: that an entry in the
    // set is not a no-op, which happens when a shape is symmetric enough that
    // mirroring it returns the same picture, and that nothing outside the set
    // moves.
    await tester.runAsync(() async {
      final noOpFlip = <String>[];
      final flippedAnyway = <String>[];
      for (final name in FoodMarks.all) {
        final flips =
            _digest(await _pixels(name, rtl: true)) !=
            _digest(await _pixels(name));
        if (FoodMarkPainter.facing.contains(name)) {
          if (!flips) noOpFlip.add(name);
        } else {
          if (flips) flippedAnyway.add(name);
        }
      }
      expect(
        noOpFlip,
        isEmpty,
        reason: 'in `facing` and mirrors to the same picture',
      );
      expect(flippedAnyway, isEmpty, reason: 'not in `facing` and moved');
    });
  });

  testWidgets('the cookie and the flatbread are two pictures', (tester) async {
    // They were a circle with three dots and a circle with three dots: the
    // same drawing twice, in the one vocabulary that is allowed to label a
    // specific dish, so a woman opening `Cheesy Bread` saw the mark from her
    // cookie recipe.
    //
    // Measured as shapes, not as names, and at both ends of the size range
    // they are drawn at: 28 pt beside a row and 64 pt on a card.
    await tester.runAsync(() async {
      for (final side in [28.0, 64.0]) {
        final cookie = await _pixels(FoodMarks.cookie, side: side);
        final bread = await _pixels(FoodMarks.flatbread, side: side);
        // The two discs this replaced scored 0.87 at 28 pt and 0.84 at 64;
        // the disc and the oval score 0.77 and 0.76. The bound is between the
        // two, so putting either of them back fails here.
        expect(
          _overlap(_silhouette(cookie), _silhouette(bread)),
          lessThan(0.80),
          reason: 'the two silhouettes are all but the same at $side pt',
        );
        // The rims are the difference a woman actually sees: the bread is
        // wide and flat, the biscuit is round.
        final breadBox = _inkedBox(bread, side.toInt());
        final cookieBox = _inkedBox(cookie, side.toInt());
        expect(
          breadBox.w / breadBox.h,
          greaterThan(1.2),
          reason: 'the flatbread is not noticeably wider than it is tall',
        );
        expect(
          cookieBox.w / cookieBox.h,
          lessThan(1.15),
          reason: 'the cookie has stopped being a disc',
        );
      }
    });
  });

  testWidgets('every mark paints at the sizes a card asks for', (tester) async {
    // 30 pt on the section row in `eat_view`, 48 pt on the divider in
    // `recipes_view`, 56 by default, and the extremes either side. The
    // redrawn marks carry more strokes than the ones they replaced.
    await tester.runAsync(() async {
      for (final side in [16.0, 28.0, 48.0, 64.0, 256.0]) {
        for (final name in FoodMarks.all) {
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
