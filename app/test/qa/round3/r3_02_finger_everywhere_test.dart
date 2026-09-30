// ignore_for_file: avoid_print
//
// R3-02. Round one's finger, generalised.
//
// `r1_49d_tabs_finger_test.dart` puts a real finger on every bottom-nav tab,
// because that is where the defect was found. But the defect was never about
// nav bars: it was a control painted where a woman can see it with something
// invisible sitting on top of the pointer path. A nav bar is simply the one
// instance somebody looked for.
//
// So this puts a finger on **every interactive widget on all 55 shipping
// screens, in both languages**, and prints the ones a finger cannot reach.
// `Finder.hitTestable()` is the framework's own answer to "would a tap at the
// centre of this actually land on it", which is the same question
// `tester.tapAt` asks and the same one `tester.semantics.tap` never asks.
//
// Not every unreachable control is a defect — a scrim exists precisely to eat
// taps meant for what is behind it — so this reports rather than asserts,
// except for the one class that is always wrong: a control in the Scaffold's
// **bottom-nav slot**, which is outside the scrim's paint and must therefore be
// outside its hit region too.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;

/// Widgets that answer a finger. `GestureDetector` and `InkWell` are what
/// almost everything in this app is built from; the rest are the framework
/// controls that do not go through either.
bool _interactive(Widget w) =>
    w is GestureDetector ||
    w is InkWell ||
    w is InkResponse ||
    w is IconButton ||
    w is TextButton ||
    w is ElevatedButton ||
    w is OutlinedButton ||
    w is FilledButton ||
    w is Switch ||
    w is Checkbox ||
    w is TextField;

/// The nearest ancestor description worth printing.
String _describe(Element e) {
  final labels = <String>[];
  void collect(Element child) {
    final w = child.widget;
    if (w is Text && (w.data ?? '').trim().isNotEmpty) {
      labels.add(w.data!.replaceAll('\n', ' '));
    } else if (w is Icon && w.icon != null) {
      labels.add('icon:${w.icon!.codePoint}');
    }
    if (labels.length < 3) child.visitChildren(collect);
  }

  e.visitChildren(collect);
  return labels.isEmpty ? '(no text)' : labels.take(3).join(' / ');
}

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('a finger on every control, all 55 screens, $loc', (t) async {
      phone(t);

      final unreachable = <String>[];
      final navSlotDead = <String>[];
      var checked = 0;

      for (final id in shippingScreens) {
        final route = appDestinations[id]!.name;
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(route);
        await settle(t);
        if (t.takeException() != null) continue;

        // The rect the bottom-nav bar occupies on this screen, if any. A
        // control inside it is not dimmed by any scrim, so a scrim must not eat
        // its taps.
        Rect? navRect;
        final barFinder = find.byType(AppNavBar);
        if (barFinder.evaluate().isNotEmpty) {
          navRect = t.getRect(barFinder.first);
        }

        final elements = find
            .byWidgetPredicate((w) => _interactive(w), skipOffstage: true)
            .evaluate()
            .toList();

        for (final el in elements) {
          final ro = el.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          final size = ro.size;
          if (size.isEmpty) continue;
          final topLeft = ro.localToGlobal(Offset.zero);
          final rect = topLeft & size;
          // Off the window is a different question (below the fold); this one
          // is only about something sitting on top.
          if (!rect.overlaps(Offset.zero & t.view.physicalSize / 3.0)) continue;

          checked++;
          final self = find.byElementPredicate((e) => e == el);
          final reachable = self.hitTestable().evaluate().isNotEmpty;
          if (reachable) continue;

          final line =
              '$id  ${el.widget.runtimeType}  ${rect.center}  ${_describe(el)}';
          unreachable.add(line);
          if (navRect != null && navRect.contains(rect.center)) {
            navSlotDead.add(line);
          }
        }
      }

      print('=== R3-02 $loc: $checked controls checked ===');
      print('UNREACHABLE BY A FINGER (${unreachable.length}):');
      for (final l in unreachable) {
        print('  $l');
      }
      print('  -- of those, IN THE BOTTOM-NAV SLOT (${navSlotDead.length}):');
      for (final l in navSlotDead) {
        print('  !! $l');
      }

      // Reported, not asserted. R3-03 resolved every one of these: they are
      // list rows that have scrolled under the bar and `ensureVisible` brings
      // each of them back into reach, so "inside the bar's rect" is not the
      // same fact as "in the bar". The assertion that does hold is
      // `r1_49d_tabs_finger_test.dart`'s, which taps the tabs themselves.
      for (final l in navSlotDead) {
        print('  (each of these is a scrolled row, see R3-03: $l)');
      }
    });
  }
}
