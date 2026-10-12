// R1-00. Prove the fonts are in effect before measuring anything with them.
//
// Order matters inside this file and is the whole design: a FontLoader cannot
// be undone inside an isolate, so the "without" measurement has to be taken
// first. Test 1 measures a long Arabic string and a long English string in a
// narrow box against whatever `flutter test` gives by default (Ahem). Test 2
// loads the real faces and measures the identical boxes again. If the two sets
// of numbers are the same, the harness is not working and every layout case in
// round one is BLOCKED.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_harness.dart';

/// A long Arabic sentence from the product's own dictionary, and a long English
/// one, each laid out in a 200-logical-pixel-wide box.
const String _ar =
    'سجّلي دورتك الشهرية لتعرفي متى يكون جسمك أقوى، وما الذي يناسبك في كل أسبوع';
const String _en =
    'Log your cycle so you know when your body is strongest, and what suits you each week';

const double _boxWidth = 200;

Future<Size> _measure(WidgetTester tester, String text, String family) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: text == _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: _boxWidth,
          child: Text(
            text,
            key: key,
            style: TextStyle(fontFamily: family, fontSize: 16),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byKey(key));
}

late Size arWithout;
late Size enWithout;
late Size arHandWithout;

void main() {
  testWidgets('1 — measured with no fonts loaded (Ahem)', (tester) async {
    arWithout = await _measure(tester, _ar, 'ArefRuqaa');
    enWithout = await _measure(tester, _en, 'Rubik');
    arHandWithout = await _measure(tester, _ar, 'LaBelleAurore');
    // ignore: avoid_print
    print(
      'R1-00 WITHOUT FONTS: ar/ArefRuqaa=$arWithout '
      'en/Rubik=$enWithout ar/LaBelleAurore=$arHandWithout',
    );
  });

  testWidgets('2 — the same boxes with the real fonts loaded', (tester) async {
    await loadAppFonts();
    final arWith = await _measure(tester, _ar, 'ArefRuqaa');
    final enWith = await _measure(tester, _en, 'Rubik');
    final arHandWith = await _measure(tester, _ar, 'LaBelleAurore');
    // ignore: avoid_print
    print(
      'R1-00 WITH FONTS:    ar/ArefRuqaa=$arWith '
      'en/Rubik=$enWith ar/LaBelleAurore=$arHandWith',
    );

    // Ahem's every glyph is a 1em box, so a 16px Ahem line is exactly 16 tall
    // and wraps at exactly 12 characters in a 200px box. A real face does not.
    expect(
      arWith,
      isNot(equals(arWithout)),
      reason:
          'Aref Ruqaa did not reach the tester: the Arabic string laid out '
          'identically with and without it. Every Arabic layout figure in this '
          'repository is an Ahem figure.',
    );
    expect(
      enWith,
      isNot(equals(enWithout)),
      reason: 'Rubik did not reach the tester.',
    );
    expect(
      arHandWith,
      isNot(equals(arHandWithout)),
      reason: 'LaBelleAurore did not reach the tester.',
    );
  });

  testWidgets('3 — all seven declared faces load without throwing', (
    tester,
  ) async {
    await loadAppFonts();
    var files = 0;
    appFontFiles.forEach((_, v) => files += v.length);
    expect(files, 7);
  });
}
