// C01 shows the real brand mark, not a stock icon in a rose square.
//
// The release walk found a generic meditation glyph above "Own Hub" on the
// first screen of the app. The mark is the Concept 02 monogram, rendered from
// assets/brand/ownhub-mark.svg at the size it is shown and at 2x and 3x, so it
// is sharp on every phone without bundling a 1024 px bitmap.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  int read(int at) =>
      (bytes[at] << 24) |
      (bytes[at + 1] << 16) |
      (bytes[at + 2] << 8) |
      bytes[at + 3];
  return (read(16), read(20));
}

void main() {
  testWidgets('the logo is the brand tile, not a stock icon', (tester) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.self_improvement), findsNothing);
    final logo = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == WelcomeView.logoAsset,
    );
    expect(logo, findsOneWidget);
    final image = tester.widget<Image>(logo);
    expect(image.width, 88);
    expect(image.height, 88);
    expect(
      image.excludeFromSemantics,
      isTrue,
      reason: 'decorative: the caption under it already says Own Hub',
    );
    expect(find.text('Own Hub'), findsOneWidget);
  });

  test('the tile is rendered at 1x, 2x and 3x of its shown size', () {
    const base = 'assets/brand/logo';
    expect(WelcomeView.logoAsset, '$base/ownhub-tile.png');
    expect(_pngSize('$base/ownhub-tile.png'), (88, 88));
    expect(_pngSize('$base/2.0x/ownhub-tile.png'), (176, 176));
    expect(_pngSize('$base/3.0x/ownhub-tile.png'), (264, 264));
  });

  test('the tile is bundled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- ${WelcomeView.logoAsset}'));
  });
}
