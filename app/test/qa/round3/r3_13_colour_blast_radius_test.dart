// ignore_for_file: avoid_print
//
// R3-13. Seven roles went "one shade deeper". Six of them did. The seventh
// moved thirty points of lightness, and this file is why it was put back.
//
//   role            old       new       ΔL*   vs surface
//   primary         #B4526E   #A24661    -6   4.71 -> 5.74
//   primaryDim      #A8455F   #9A3F57    -3   5.59 -> 6.39
//   tertiary        #4F7359   #4C6E55    -2   5.24 -> 5.61
//   tertiarySoft    #6E9478   #65896F    -4   3.34 -> 3.84
//   error           #A84A4A   #A34848    -1   5.50 -> 5.75
//   outline         #9C838A   #977C84    -2   3.41 -> 3.72
//   outlineVariant  #EBDCDF   #B47B87   -30   1.30 -> 3.36    REVERTED
//
// The hexes above are the rose palette of that round. The Linen, Petrol and
// Pale Pink palette of 16 October 2026 (D49) replaced them; the assertions below
// read the live tokens.
//
// `outlineVariant` was the hairline AND four things that are not hairlines: the
// border of every `AppCardVariant.outlined`, the 2px ring on an UNSELECTED
// intake answer, the unfilled half of two controls, and — the one that changes
// meaning — `WeekBarKind.missed` on the Progress chart. A number passing 3:1 is
// not the same fact as a screen looking right: at #B47B87 a week that did not
// count became the brightest, most saturated bar on a page of sage.
//
// THIS FILE NOW ASSERTS RATHER THAN ONLY PRINTING. The four boundaries above
// moved to `outline`, which is M3's role for a boundary that carries meaning
// and which `contrast.dart:335-357` argued for before any of this happened, and
// `outlineVariant` went back to #EBDCDF and draws nothing but row separators.
// The assertions below are the half of the finding a print cannot keep: every
// graphical object a woman has to see clears WCAG 1.4.11 against the surface it
// is drawn on. What `outlineVariant` measures is left as a print, because a
// divider is exempt and the number is only here to show how far it moved.
//
// The blast-radius walk is unchanged and still counts what is on the 55
// shipping screens.
@Tags(['qa'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;

double _lin(int c) {
  final v = c / 255;
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luma(Color c) =>
    0.2126 * _lin((c.r * 255).round()) +
    0.7152 * _lin((c.g * 255).round()) +
    0.0722 * _lin((c.b * 255).round());

double _contrast(Color a, Color b) {
  final la = _luma(a), lb = _luma(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, "0").substring(2).toUpperCase()}';

void main() {
  useShippingApp();

  test('the pairs a woman has to tell apart', () {
    final failures = <String>[];

    /// Printed always. Asserted when [floor] is given — 3.0 is WCAG 1.4.11 for
    /// a graphical object against what it is drawn on.
    void pair(String name, Color a, Color b, {double? floor}) {
      final ratio = _contrast(a, b);
      final verdict = floor == null
          ? ''
          : (ratio >= floor ? '  ok' : '  FAIL needs $floor');
      print(
        '  $name  ${_hex(a)} vs ${_hex(b)}  '
        '${ratio.toStringAsFixed(2)}:1$verdict',
      );
      if (floor != null && ratio < floor) {
        failures.add('$name ${ratio.toStringAsFixed(2)}:1 needs $floor:1');
      }
    }

    print('=== R3-13 the pairs ===');
    // The four boundaries that carry meaning, against what they are drawn on.
    pair(
      'outlined card border (outline) / its card (surfaceLowest)',
      AppColors.outline,
      AppColors.surfaceLowest,
      floor: 3,
    );
    pair(
      'unselected answer ring (outline) / page (surface)',
      AppColors.outline,
      AppColors.surface,
      floor: 3,
    );
    pair(
      'missed week (outline) / page (surface)',
      AppColors.outline,
      AppColors.surface,
      floor: 3,
    );
    pair(
      'repaired week (tertiarySoft) / page (surface)',
      AppColors.tertiarySoft,
      AppColors.surface,
      floor: 3,
    );
    pair(
      'counted week (tertiary) / page (surface)',
      AppColors.tertiary,
      AppColors.surface,
      floor: 3,
    );

    // The three bars against each other. NOT asserted, and that is a decision
    // rather than an omission: the bars are separated by 5px of page, so the
    // colour each one is adjacent to is the surface measured above. They are
    // told apart by height (34 / 28 / 16) and, on the repaired one, by the
    // hatch `WeekBarsChart` paints over it. Printed because the missed bar is
    // what round two's change was measured on.
    pair(
      'missed week (outline) / counted week (tertiary)',
      AppColors.outline,
      AppColors.tertiary,
    );
    pair(
      'missed week (outline) / repaired week (tertiarySoft)',
      AppColors.outline,
      AppColors.tertiarySoft,
    );

    // Decoration, exempt from 1.4.11, printed so the revert is visible.
    pair(
      'outlineVariant / surface (the hairline, decoration only)',
      AppColors.outlineVariant,
      AppColors.surface,
    );
    pair(
      'outline / outlineVariant (the two boundary roles)',
      AppColors.outline,
      AppColors.outlineVariant,
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  for (final loc in <String>['en']) {
    testWidgets('how many hairlines are on the 55 screens, $loc', (t) async {
      phone(t);
      var dividers = 0;
      var outlinedCards = 0;
      final screens = <String>[];

      for (final id in shippingScreens) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) continue;

        final d = find.byType(Divider).evaluate().length;
        final c = t
            .widgetList<AppCard>(find.byType(AppCard))
            .where((w) => w.variant == AppCardVariant.outlined)
            .length;
        dividers += d;
        outlinedCards += c;
        if (d + c > 0) screens.add('$id: $d dividers, $c outlined cards');
      }

      print(
        '=== R3-13 blast radius: $dividers dividers and $outlinedCards '
        'outlined-card borders across the shipping surface ===',
      );
      for (final s in screens) {
        print('  $s');
      }
    });
  }
}
