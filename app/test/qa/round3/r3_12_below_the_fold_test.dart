// ignore_for_file: avoid_print
//
// R3-12. Below the fold, and back out again.
//
// Round one wrote down its own boundary: "zero overflow" means zero **above**
// the fold, because a lazy scroll view never builds what she has not scrolled
// to. So this scrolls every one of the 55 shipping screens to the bottom, in
// both languages, at 1.0x and at 1.6x, and measures overflow and lost lines
// there — which is where the long Arabic sentences are, because the long
// Arabic sentences are the explanatory ones and explanations sit at the foot of
// a screen.
//
// Then: back navigation out of a deep flow, and the same tap twice quickly.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;

/// Every paragraph on screen that lost a line to `maxLines`.
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

/// Drives every scrollable on screen to its end.
///
/// `jumpTo`, not `drag`: a lazy list's `maxScrollExtent` grows as it builds, so
/// this jumps, pumps, and jumps again until the extent stops moving. Dragging
/// would also warn on every screen that does not scroll, which is most of them.
Future<double> _toTheBottom(WidgetTester t) async {
  var moved = 0.0;
  for (final el in find.byType(Scrollable).evaluate().toList()) {
    final state = el as StatefulElement;
    final scrollable = state.state as ScrollableState;
    for (var i = 0; i < 20; i++) {
      final pos = scrollable.position;
      if (!pos.hasContentDimensions) break;
      final end = pos.maxScrollExtent;
      if (end <= pos.pixels + 0.5) break;
      pos.jumpTo(end);
      moved += end - pos.pixels;
      await t.pump(const Duration(milliseconds: 40));
    }
  }
  await settle(t);
  return moved;
}

Future<void> _sweep(WidgetTester t, Locale locale, double scale) async {
  phone(t, textScale: scale);
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

  print('=== R3-12 ${locale.languageCode} ${scale}x, SCROLLED TO THE END ===');
  print('OVERFLOWED ONLY BELOW THE FOLD (${overflowed.length}):');
  for (final o in overflowed) {
    print('  $o');
  }
  print('LINES LOST ONLY BELOW THE FOLD (${lost.length}):');
  for (final l in lost) {
    print('  $l');
  }
  expect(overflowed, isEmpty, reason: 'overflow below the fold');
}

void main() {
  useShippingApp();

  testWidgets(
    'en 1.0x below the fold',
    (t) => _sweep(t, const Locale('en'), 1.0),
  );
  testWidgets(
    'ar 1.0x below the fold',
    (t) => _sweep(t, const Locale('ar'), 1.0),
  );
  testWidgets(
    'en 1.6x below the fold',
    (t) => _sweep(t, const Locale('en'), 1.6),
  );
  testWidgets(
    'ar 1.6x below the fold',
    (t) => _sweep(t, const Locale('ar'), 1.6),
  );

  // Back out of a deep flow, one screen at a time.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('back out of a five-deep flow, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      const chain = <String>['T01', 'R01', 'R02', 'R03', 'R05', 'R07'];
      await boot(t, locale: Locale(loc));
      final landed = <String?>[topScreen(t)];
      for (final id in chain) {
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        t.takeException();
        landed.add(topScreen(t));
      }
      print('=== R3-12 $loc pushed: ${landed.join(" -> ")} ===');

      final back = <String?>[];
      for (var i = 0; i < chain.length; i++) {
        nav(t).pop();
        await settle(t);
        final err = t.takeException();
        back.add(
          err == null ? topScreen(t) : 'THREW ${'$err'.split('\n').first}',
        );
      }
      print('  popped back: ${back.join(" -> ")}');
      expect(
        back.where((e) => e != null && e.startsWith('THREW')),
        isEmpty,
        reason: 'backing out of a deep flow threw',
      );
      s.dispose();
    });
  }

  // The same tap twice, quickly, on every screen that has a primary action.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('the same control tapped twice quickly, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      final trouble = <String>[];

      for (final id in shippingScreens) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) continue;
        final controls = tappables(t);
        if (controls.isEmpty) continue;

        // The first control that is not a tab and not a back button.
        final target = controls.firstWhere(
          (c) =>
              c.label.trim().isNotEmpty &&
              !<String>[
                'Home',
                'Train',
                'Eat',
                'Back',
                'Close',
                'الرئيسية',
                'التمرين',
                'الأكل',
                'ارجعي',
                'اقفلي',
              ].contains(c.label.trim()),
          orElse: () => controls.first,
        );

        // Twice with no settle between: two pointer-ups inside one frame gap.
        await tapControl(t, target.label);
        final firstErr = t.takeException();
        await tapControl(t, target.label);
        final secondErr = t.takeException();
        if (firstErr != null || secondErr != null) {
          trouble.add(
            '$id  "${target.label}"  '
            'first=${firstErr == null ? "ok" : '$firstErr'.split('\n').first}  '
            'second=${secondErr == null ? "ok" : '$secondErr'.split('\n').first}',
          );
        }
      }

      print(
        '=== R3-12 $loc, double-tapped every screen: '
        '${trouble.length} threw ===',
      );
      for (final x in trouble) {
        print('  $x');
      }
      expect(trouble, isEmpty, reason: 'a second tap threw');
      s.dispose();
    });
  }
}
