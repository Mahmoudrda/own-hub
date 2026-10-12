// ignore_for_file: avoid_print
//
// R5-02. R3-12, redone at the small end.
//
// R3-12 scrolled all 55 shipping screens to the bottom at 390x844 and found
// nothing. That is the result the launch notes quote. It is also the result
// for a phone 177 points taller than the shortest one the owner names, and
// scrolling is exactly where the difference bites: a lazy list builds only what
// the viewport asks for, so on a shorter phone a DIFFERENT set of rows is built
// at a DIFFERENT width, and the row that overflows at 320 points wide was never
// constructed at 390.
//
// Same instrument as R3-12 — jump every scrollable to its end, then measure —
// at 375x667 and 320x640.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;
import 'r5_01_small_screen_sweep_test.dart' show Shape, device, shapes;

/// Drives every scrollable on screen to its end.
///
/// `jumpTo` rather than `drag`, for R3-12's reason: a lazy list's
/// `maxScrollExtent` grows as it builds, so this jumps, pumps, and jumps again
/// until the extent stops moving.
Future<void> _toTheBottom(WidgetTester t) async {
  for (final el in find.byType(Scrollable).evaluate().toList()) {
    final scrollable = (el as StatefulElement).state as ScrollableState;
    for (var i = 0; i < 20; i++) {
      final pos = scrollable.position;
      if (!pos.hasContentDimensions) break;
      final end = pos.maxScrollExtent;
      if (end <= pos.pixels + 0.5) break;
      pos.jumpTo(end);
      await t.pump(const Duration(milliseconds: 40));
    }
  }
  await settle(t);
}

/// Paragraphs that lost a line to `maxLines`, with their text.
List<String> _truncated(WidgetTester t) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && !o.debugNeedsLayout) {
      bool lost;
      try {
        lost = o.didExceedMaxLines;
      } catch (_) {
        lost = false;
      }
      if (lost) {
        final s = o.text.toPlainText().replaceAll('\n', ' ');
        out.add(s.length > 60 ? '${s.substring(0, 60)}…' : s);
      }
    }
    o.visitChildren(visit);
  }

  final root = t.binding.rootElement?.renderObject;
  if (root != null) visit(root);
  return out;
}

Future<void> _sweep(
  WidgetTester t,
  Shape shape,
  Locale locale,
  double scale,
) async {
  device(t, width: shape.w, height: shape.h, dpr: shape.dpr, textScale: scale);

  final overflowed = <String>[];
  final lost = <String>[];

  for (final id in shippingScreens) {
    await boot(t, locale: locale);
    nav(t).pushNamed(appDestinations[id]!.name);
    await settle(t);
    if (t.takeException() != null) continue;

    final before = _truncated(t).length;
    await _toTheBottom(t);
    final err = t.takeException();
    if (err != null) {
      overflowed.add('$id BELOW THE FOLD: ${'$err'.split('\n').first}');
      continue;
    }
    final after = _truncated(t);
    if (after.length > before) {
      for (final s in after) {
        lost.add('$id\t$s');
      }
    }
  }

  final tag = '${shape.name} ${locale.languageCode} ${scale}x';
  print('=== R5-02 $tag, SCROLLED TO THE END ===');
  print('  OVERFLOWED BELOW THE FOLD (${overflowed.length}):');
  for (final o in overflowed) {
    print('    $o');
  }
  print('  LINES LOST BELOW THE FOLD (${lost.length}):');
  for (final l in lost) {
    print('    $l');
  }

  expect(overflowed, isEmpty, reason: '$tag: overflow below the fold');
}

void main() {
  useShippingApp();

  // The two small shapes only. The control is R3-12's own territory and is
  // already covered there; repeating it here would double a four-minute sweep
  // for an answer that is written down.
  for (final shape in shapes.where((s) => s.h < 844)) {
    for (final loc in <String>['en', 'ar']) {
      for (final scale in <double>[1.0, 1.6]) {
        testWidgets(
          '${shape.name} $loc ${scale}x scrolled',
          (t) => _sweep(t, shape, Locale(loc), scale),
        );
      }
    }
  }
}
