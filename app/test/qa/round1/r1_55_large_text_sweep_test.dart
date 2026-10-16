// R1-00b / R1-55 / R1-56. The 1.6x sweep, at the shipping flag set, with the
// real fonts loaded, in both languages — and with truncation counted, which is
// the thing the existing sweep cannot see.
//
// `test/qa/large_text_sweep_test.dart` fails only on a thrown RenderFlex
// overflow. Text that is ellipsised away, or clipped by a fixed-height box,
// throws nothing at all: `maxLines` plus `TextOverflow.ellipsis` is a silent,
// designed-for loss of a line. At 1.6x in Arabic that is where the product
// loses sentences, and nobody has ever counted it. `didExceedMaxLines` on
// `RenderParagraph` is the exact question "did this paragraph lose a line".
@Tags(['qa'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

/// The 55 screens the shipping flag set actually resolves to, as measured by
/// r1_53_shipping_surface_test.dart.
const List<String> shippingScreens = [
  'C02',
  'O01',
  'O02',
  'O03',
  'O04',
  'O05',
  'T01',
  'T02',
  'T03',
  'T04',
  'T05',
  'T07',
  'R01',
  'R02',
  'R03',
  'R04',
  'R05',
  'R06',
  'R07',
  'R08',
  'R09',
  'R10',
  'R11',
  'R12',
  'R13',
  'E01',
  'E02',
  'E03',
  'E04',
  'E05',
  'E06',
  'E07',
  'E08',
  'E10',
  'E11',
  'P01',
  'P02',
  'P03',
  'P04',
  'Y01',
  'Y02',
  'Y03',
  'Y04',
  'Y05',
  'Y06',
  'Y07',
  'Y08',
  'Y09',
  'Y10',
  'Y12',
  'Y13',
  'A01',
  'A02',
  'A03',
  'A04',
];

/// Every paragraph on screen that lost a line to `maxLines`.
List<String> _truncated(WidgetTester t) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && !o.debugNeedsLayout) {
      // `didExceedMaxLines` asserts on a paragraph that has never been laid
      // out, which happens inside an offstage route.
      bool lost;
      try {
        lost = o.didExceedMaxLines;
      } catch (_) {
        lost = false;
      }
      if (lost) {
        final s = o.text.toPlainText().replaceAll('\n', ' ');
        out.add(s.length > 70 ? '${s.substring(0, 70)}…' : s);
      }
    }
    o.visitChildren(visit);
  }

  final root = t.binding.rootElement?.renderObject;
  if (root != null) visit(root);
  return out;
}

Future<void> _sweep(
  WidgetTester tester,
  Locale locale,
  double scale,
  String tag,
) async {
  phone(tester, textScale: scale);
  final overflowed = <String>[];
  final truncations = <String, List<String>>{};

  for (final id in shippingScreens) {
    final route = appDestinations[id]!.name;
    await boot(tester, locale: locale);
    nav(tester).pushNamed(route);
    await settle(tester);
    final thrown = tester.takeException();
    if (thrown != null) {
      overflowed.add('$id: ${'$thrown'.split('\n').first}');
      continue;
    }
    final lost = _truncated(tester);
    if (lost.isNotEmpty) truncations[id] = lost;
  }

  // ignore: avoid_print
  print('=== $tag ===');
  // ignore: avoid_print
  print('OVERFLOWED (${overflowed.length}):');
  for (final l in overflowed) {
    // ignore: avoid_print
    print('  $l');
  }
  var lines = 0;
  truncations.forEach((_, v) => lines += v.length);
  // ignore: avoid_print
  print(
    'SCREENS WITH A TRUNCATED LINE (${truncations.length}), '
    'lines lost ($lines):',
  );
  truncations.forEach((id, v) {
    for (final s in v) {
      // ignore: avoid_print
      print('  $id\t$s');
    }
  });
  expect(overflowed, isEmpty, reason: '$tag overflowed');
}

void main() {
  useShippingApp();

  testWidgets('en 1.0x', (t) => _sweep(t, const Locale('en'), 1.0, 'EN 1.0x'));
  testWidgets('ar 1.0x', (t) => _sweep(t, const Locale('ar'), 1.0, 'AR 1.0x'));
  testWidgets('en 1.6x', (t) => _sweep(t, const Locale('en'), 1.6, 'EN 1.6x'));
  testWidgets('ar 1.6x', (t) => _sweep(t, const Locale('ar'), 1.6, 'AR 1.6x'));
}
