// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_harness.dart';

Future<double> _h(
  WidgetTester t,
  String s,
  String f,
  TextDirection d, {
  double size = 16,
}) async {
  final k = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: d,
      child: Center(
        child: SizedBox(
          width: 2000,
          child: Text(
            s,
            key: k,
            maxLines: 1,
            style: TextStyle(fontFamily: f, fontSize: size),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return t.getSize(find.byKey(k)).height;
}

Future<double> _w(
  WidgetTester t,
  String s,
  String f,
  TextDirection d, {
  double size = 16,
}) async {
  final k = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: d,
      child: Center(
        child: Text(
          s,
          key: k,
          maxLines: 1,
          style: TextStyle(fontFamily: f, fontSize: size),
        ),
      ),
    ),
  );
  await t.pump();
  return t.getSize(find.byKey(k)).width;
}

const ar = 'سجّلي دورتك الشهرية';
const en = 'Log your cycle today';
void main() {
  testWidgets('A no fonts', (t) async {
    print(
      'NOFONT single-line height 16px: Rubik/en=${await _h(t, en, "Rubik", TextDirection.ltr)} ArefRuqaa/ar=${await _h(t, ar, "ArefRuqaa", TextDirection.rtl)} Rubik/ar=${await _h(t, ar, "Rubik", TextDirection.rtl)} LaBelle/en=${await _h(t, en, "LaBelleAurore", TextDirection.ltr)}',
    );
    print(
      'NOFONT single-line width  16px: Rubik/en=${await _w(t, en, "Rubik", TextDirection.ltr)} ArefRuqaa/ar=${await _w(t, ar, "ArefRuqaa", TextDirection.rtl)} Rubik/ar=${await _w(t, ar, "Rubik", TextDirection.rtl)}',
    );
  });
  testWidgets('B with fonts', (t) async {
    await loadAppFonts();
    print(
      'REAL   single-line height 16px: Rubik/en=${await _h(t, en, "Rubik", TextDirection.ltr)} ArefRuqaa/ar=${await _h(t, ar, "ArefRuqaa", TextDirection.rtl)} Rubik/ar=${await _h(t, ar, "Rubik", TextDirection.rtl)} LaBelle/en=${await _h(t, en, "LaBelleAurore", TextDirection.ltr)}',
    );
    print(
      'REAL   single-line width  16px: Rubik/en=${await _w(t, en, "Rubik", TextDirection.ltr)} ArefRuqaa/ar=${await _w(t, ar, "ArefRuqaa", TextDirection.rtl)} Rubik/ar=${await _w(t, ar, "Rubik", TextDirection.rtl)}',
    );
  });
}
