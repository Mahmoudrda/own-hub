// QA round 2, R2-44. Measures the other two named fixed boxes —
// app_segmented.dart's SizedBox(height: 44) and app_media.dart's
// Container(height: 26) — at Arabic locale and textScale 1.6, on the real
// Rubik font (loaded explicitly; flutter_test does not load bundled fonts by
// default).
//
// Measuring aid for the audit, not a regression test: not wired into the
// app's own suite, asserts nothing on the product's behalf.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_segmented.dart';

Future<void> _loadRubik() async {
  for (final entry in const {
    'assets/fonts/Rubik-400.ttf': FontWeight.w400,
    'assets/fonts/Rubik-500.ttf': FontWeight.w500,
    'assets/fonts/Rubik-600.ttf': FontWeight.w600,
    'assets/fonts/Rubik-700.ttf': FontWeight.w700,
  }.entries) {
    final bytes = File(entry.key).readAsBytesSync();
    final loader = FontLoader('Rubik')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadRubik);

  testWidgets(
    'R2-44: AppSegmented, E06 recipe-view labels, ar, textScale 1.6',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The exact two labels rahma_recipe_view.dart:172 passes (E06, a
      // shipping eat-flow screen), read from lib/l10n/app_ar.arb.
      const items = ['المكوّنات والخطوات', 'كما هي في الكتاب'];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: MaterialApp(
            theme: buildTheme(const Locale('ar')),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AppSegmented(items: items, selectedIndex: 0),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      // ignore: avoid_print
      print('R2-44 AppSegmented takeException at ar/1.6: $exception');

      final box = tester.getSize(find.byType(AppSegmented));
      // ignore: avoid_print
      print('R2-44 AppSegmented outer box: $box (fixed height should be 44)');

      for (final label in items) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: 'segment "$label" missing');
        final rp = tester.renderObject<RenderParagraph>(finder);
        // ignore: avoid_print
        print(
          'R2-44 segment "$label": box=${rp.size.width.toStringAsFixed(1)}x'
          '${rp.size.height.toStringAsFixed(1)} '
          'didExceedMaxLines=${rp.didExceedMaxLines}',
        );
      }
    },
  );

  testWidgets('R2-44: app_media.dart badge Container(height: 26), ar 1.6', (
    tester,
  ) async {
    // app_media.dart:99-101's exact badge style: AppText.label.copyWith(
    // fontSize: 13), inside a fixed Container(height: 26). Reproduced
    // directly rather than through AppMedia, which needs an image provider;
    // the geometry under test is the Text-in-fixed-Container pattern, not
    // the image loading.
    const style = TextStyle(
      fontFamily: 'Rubik',
      fontSize: 13,
      height: 1.333,
      fontWeight: FontWeight.w500,
    );
    // l10n.june / l10n.september, the two real callers on P04
    // (body_privately_view.dart:586,595 — a sensitive, shipping screen).
    const badges = ['يونيو', 'سبتمبر'];

    for (final badge in badges) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: Container(
                  key: key,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Text(badge, style: style),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerSize = tester.getSize(find.byKey(key));
      final rp = tester.renderObject<RenderParagraph>(find.text(badge));
      // ignore: avoid_print
      print(
        'R2-44 badge "$badge": container=$containerSize '
        'text natural size=${rp.size.width.toStringAsFixed(1)}x'
        '${rp.size.height.toStringAsFixed(1)} '
        '(fixed box height=26, text wants ${rp.size.height.toStringAsFixed(1)})',
      );
    }
  });
}
