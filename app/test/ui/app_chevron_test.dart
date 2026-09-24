// The forward chevron.
//
// Arabic is the primary language of this product, and a chevron is the mark at
// the end of nearly every list row in it. Pointing right in a right-to-left
// layout means pointing backwards, so the direction is not a detail of one
// screen — it is the same defect repeated everywhere at once.
//
// Two things are pinned here. That [AppChevron] resolves the direction from the
// ambient Directionality and draws the glyph that points forward in it; and
// that no screen in the areas this widget covers has gone back to a bare
// `Icons.chevron_right`, where the correctness would depend on a flag on a
// Material constant instead of on anything this repository asserts.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/ui/app_chevron.dart';

Widget _host(Widget child, TextDirection direction) => Directionality(
  textDirection: direction,
  child: Center(child: child),
);

/// The files this worker owns, swept for chevrons that went round the widget.
const List<String> _ownedDirectories = [
  'lib/ui',
  'lib/features/train',
  'lib/features/today',
];

void main() {
  group('points forward, in her direction', () {
    testWidgets('left under RTL', (tester) async {
      await tester.pumpWidget(_host(const AppChevron(), TextDirection.rtl));

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(
        find.byIcon(Icons.chevron_right),
        findsNothing,
        reason: 'in Arabic a right-pointing chevron points backwards',
      );
    });

    testWidgets('right under LTR', (tester) async {
      await tester.pumpWidget(_host(const AppChevron(), TextDirection.ltr));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('and the framework does not mirror it a second time', (
      tester,
    ) async {
      // The trap: `Icons.chevron_left` carries `matchTextDirection: true`, so
      // an Icon left on the ambient direction would flip the glyph this widget
      // has already chosen and send it back where it started. The rendered
      // Icon must therefore be pinned to LTR whatever the layout is doing.
      await tester.pumpWidget(_host(const AppChevron(), TextDirection.rtl));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.chevron_left);
      expect(icon.textDirection, TextDirection.ltr);
    });

    test('the glyph is chosen in one place', () {
      expect(AppChevron.forward(TextDirection.rtl), Icons.chevron_left);
      expect(AppChevron.forward(TextDirection.ltr), Icons.chevron_right);
    });
  });

  test('no screen draws a bare chevron', () {
    final offenders = <String>[];
    for (final directory in _ownedDirectories) {
      for (final entity in Directory(directory).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The widget itself is the one place allowed to name the glyphs.
        if (entity.path.endsWith('ui/app_chevron.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('Icons.chevron_right') ||
              line.contains('Icons.chevron_left')) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'use AppChevron() from lib/ui/app_chevron.dart. A bare chevron is '
          'correct today only because of matchTextDirection on a Material '
          'constant, which nothing here asserts:\n${offenders.join('\n')}',
    );
  });
}
