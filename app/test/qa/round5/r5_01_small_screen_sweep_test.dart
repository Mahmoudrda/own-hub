// ignore_for_file: avoid_print
//
// R5-01. The small end of the range the owner claims to support.
//
// Every sweep in this repository has been measured at 390x844 — the iPhone 14
// shape. The stated range starts at an **iPhone 7: 375 x 667 logical points**,
// which is 177 points shorter. A screen that fits at 844 with room to spare can
// lose its primary action entirely at 667, and nothing here has ever looked.
//
// Three shapes, because the failure modes differ:
//
//   * **375 x 667 @2x** — iPhone 7 / 8 / SE (2nd and 3rd gen). The shortest
//     iPhone the range names, and the one most likely to hurt.
//   * **320 x 640 @2x** — the bottom of Android. Narrow as well as short, so
//     this is where a row of three chips stops fitting side by side.
//   * **390 x 844 @3x** — the control, so a failure here can be told apart
//     from a failure that was always there.
//
// What it measures that the existing sweeps do not:
//
//   1. **Overflow with no scroll view to rescue it.** An overflow inside a
//      `ListView` is a non-event: she scrolls. An overflow on a screen with no
//      scrollable at all is content she can never reach. R3-12 counted
//      overflows; it never asked whether the screen could scroll.
//   2. **Controls below the fold on a screen that does not scroll.** A
//      `Scaffold` with a `Column` draws its button at y=700 on a 667-point
//      phone without throwing anything at all, because nothing overflowed —
//      the button is simply painted outside the viewport. This is silent, and
//      it is the exact shape of "Continue is gone on an iPhone 7".
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;

/// A phone of an arbitrary shape, rather than the one 390x844 the round-one
/// harness fixes.
void device(
  WidgetTester t, {
  required double width,
  required double height,
  required double dpr,
  double textScale = 1.0,
}) {
  t.view.physicalSize = Size(width * dpr, height * dpr);
  t.view.devicePixelRatio = dpr;
  if (textScale != 1.0) {
    t.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  addTearDown(t.view.reset);
}

typedef Shape = ({String name, double w, double h, double dpr});

const List<Shape> shapes = <Shape>[
  (name: 'iPhone7 375x667', w: 375, h: 667, dpr: 2.0),
  (name: 'small-Android 320x640', w: 320, h: 640, dpr: 2.0),
  (name: 'control 390x844', w: 390, h: 844, dpr: 3.0),
];

/// True when anything on this screen can be scrolled, so content below the
/// fold is reachable rather than lost.
bool _canScroll(WidgetTester t) {
  for (final el in find.byType(Scrollable).evaluate()) {
    final state = (el as StatefulElement).state as ScrollableState;
    final pos = state.position;
    if (!pos.hasContentDimensions) continue;
    if (pos.maxScrollExtent > 0.5) return true;
  }
  return false;
}

/// Controls painted wholly or partly below the bottom of the screen.
///
/// Read off the semantics tree because that is what she can actually reach:
/// a node whose rect starts below the viewport is painted off the phone. On a
/// screen that scrolls this is expected and ignored by the caller; on one that
/// does not, it is a control that does not exist for her.
List<String> _offBottom(WidgetTester t, double viewportHeight) {
  final out = <String>[];
  for (final c in tappables(t)) {
    // `> viewport` rather than `>= `: a control flush with the bottom edge is
    // on screen. Half a point of rounding is not a defect.
    if (c.rect.top > viewportHeight - 0.5) {
      out.add('${c.label.trim()} @y=${c.rect.top.toStringAsFixed(0)}');
    }
  }
  return out;
}

/// Paragraphs that lost a line to `maxLines`. Same instrument as R1-55.
int _truncatedCount(WidgetTester t) {
  var n = 0;
  void visit(RenderObject o) {
    if (o is RenderParagraph && !o.debugNeedsLayout) {
      try {
        if (o.didExceedMaxLines) n++;
      } catch (_) {
        // A paragraph inside an offstage route has never been laid out.
      }
    }
    o.visitChildren(visit);
  }

  final root = t.binding.rootElement?.renderObject;
  if (root != null) visit(root);
  return n;
}

Future<void> _sweep(
  WidgetTester t,
  Shape shape,
  Locale locale,
  double scale,
) async {
  device(t, width: shape.w, height: shape.h, dpr: shape.dpr, textScale: scale);
  final sem = t.ensureSemantics();

  final unrescued = <String>[]; // overflow on a screen that cannot scroll
  final rescued = <String>[]; // overflow, but she can scroll to it
  final lostControls = <String>[]; // painted below a fixed screen's bottom
  final truncated = <String>[];
  final threw = <String>[];

  var sanity = '';
  for (final id in shippingScreens) {
    await boot(t, locale: locale);
    nav(t).pushNamed(appDestinations[id]!.name);
    await settle(t);
    if (sanity.isEmpty) {
      final mq = MediaQuery.of(t.element(find.byType(Navigator).first));
      sanity = 'MediaQuery=${mq.size.width.toStringAsFixed(0)}x'
          '${mq.size.height.toStringAsFixed(0)} '
          'textScale=${mq.textScaler.scale(10) / 10} '
          'paintedOn$id=${paintedText(t).length}';
    }

    final openErr = t.takeException();
    if (openErr != null) {
      final first = '$openErr'.split('\n').first;
      // A RenderFlex overflow is thrown on open; anything else is a real
      // failure to build and is worth telling apart.
      if (first.contains('overflowed')) {
        (_canScroll(t) ? rescued : unrescued).add('$id\t$first');
      } else {
        threw.add('$id\t$first');
      }
      continue;
    }

    if (!_canScroll(t)) {
      final lost = _offBottom(t, shape.h);
      if (lost.isNotEmpty) {
        lostControls.add('$id\t${lost.join(" | ")}');
      }
    }

    final n = _truncatedCount(t);
    if (n > 0) truncated.add('$id:$n');
  }

  final tag = '${shape.name} ${locale.languageCode} ${scale}x';
  print("=== R5-01 $tag ===");
  print("  sanity: $sanity");
  print('  BUILD FAILURES (${threw.length}):');
  for (final x in threw) {
    print('    $x');
  }
  print('  OVERFLOW, NO SCROLL VIEW TO RESCUE IT (${unrescued.length}):');
  for (final x in unrescued) {
    print('    $x');
  }
  print('  OVERFLOW, BUT SHE CAN SCROLL (${rescued.length}):');
  for (final x in rescued) {
    print('    $x');
  }
  print('  CONTROLS BELOW A FIXED SCREEN\'S BOTTOM EDGE '
      '(${lostControls.length}):');
  for (final x in lostControls) {
    print('    $x');
  }
  print('  PARAGRAPHS THAT LOST A LINE: ${truncated.join(" ")}');

  sem.dispose();

  // Asserted, not merely printed: a control painted off the bottom of a screen
  // that cannot scroll is unreachable, and an overflow with no scroll view is
  // content she can never see. Both are defects at any size.
  expect(
    threw,
    isEmpty,
    reason: '$tag: a shipping screen failed to build',
  );
  expect(
    unrescued,
    isEmpty,
    reason: '$tag: overflow on a screen with nothing to scroll',
  );
  expect(
    lostControls,
    isEmpty,
    reason: '$tag: a control is painted below the bottom of a fixed screen',
  );
}

void main() {
  useShippingApp();

  for (final shape in shapes) {
    for (final loc in <String>['en', 'ar']) {
      for (final scale in <double>[1.0, 1.6]) {
        testWidgets(
          '${shape.name} $loc ${scale}x',
          (t) => _sweep(t, shape, Locale(loc), scale),
        );
      }
    }
  }
}
