// The square crop for her profile photo: the arithmetic on its own, then the
// sheet she sees.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/profile_photo_crop.dart';

import '../helpers/profile_photo_fixture.dart';

void main() {
  group('PhotoCropGeometry', () {
    // 800 x 600 picture in a 300 square: the short side fills it.
    final geometry = PhotoCropGeometry(
      image: const Size(800, 600),
      viewport: 300,
    );

    test('starts on the middle square at the full height of the picture', () {
      final rect = geometry.cropRect(geometry.centered());

      expect(rect.left, closeTo(100, 0.001));
      expect(rect.top, closeTo(0, 0.001));
      expect(rect.width, closeTo(600, 0.001));
      expect(rect.height, closeTo(600, 0.001));
    });

    test('zooming in about the middle halves the square', () {
      final zoomed = geometry.zoomed(geometry.centered(), 2);
      final rect = geometry.cropRect(zoomed);

      expect(rect.width, closeTo(300, 0.001));
      expect(rect.center.dx, closeTo(400, 0.001));
      expect(rect.center.dy, closeTo(300, 0.001));
    });

    test('zooming never goes past the limit or out past the fit', () {
      var m = geometry.centered();
      for (var i = 0; i < 20; i++) {
        m = geometry.zoomed(m, 1.5);
      }
      expect(m.getMaxScaleOnAxis(), closeTo(kProfilePhotoMaxZoom, 0.001));
      expect(geometry.cropRect(m).width, closeTo(600 / 4, 0.001));

      for (var i = 0; i < 20; i++) {
        m = geometry.zoomed(m, 1 / 1.5);
      }
      expect(m.getMaxScaleOnAxis(), closeTo(1, 0.001));
      expect(geometry.cropRect(m).width, closeTo(600, 0.001));
    });

    test('a pan past the edge is held at the edge', () {
      final zoomed = geometry.zoomed(geometry.centered(), 2);
      final far = zoomed.clone()..translateByDouble(9999, 9999, 0, 1);
      final rect = geometry.cropRect(geometry.clamped(far));

      expect(rect.left, closeTo(0, 0.001));
      expect(rect.top, closeTo(0, 0.001));

      final other = zoomed.clone()..translateByDouble(-9999, -9999, 0, 1);
      final back = geometry.cropRect(geometry.clamped(other));
      expect(back.right, closeTo(800, 0.001));
      expect(back.bottom, closeTo(600, 0.001));
    });

    test('the square never leaves the picture, even for a tall one', () {
      final tall = PhotoCropGeometry(
        image: const Size(600, 1000),
        viewport: 300,
      );
      final rect = tall.cropRect(tall.centered());

      expect(rect.width, closeTo(600, 0.001));
      expect(rect.left, closeTo(0, 0.001));
      expect(rect.top, closeTo(200, 0.001));
    });
  });

  group('the crop sheet', () {
    Widget host(Widget child, {Locale locale = const Locale('en')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(locale),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    Future<ui.Image> image(WidgetTester tester) async {
      late ui.Image decoded;
      await tester.runAsync(() async {
        final bytes = await twoToneImage(800, 600);
        final codec = await ui.instantiateImageCodec(bytes);
        decoded = (await codec.getNextFrame()).image;
      });
      return decoded;
    }

    testWidgets('Use this photo returns the middle square', (tester) async {
      final picture = await image(tester);
      ui.Rect? chosen;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<ui.Rect>(
                  MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(body: ProfilePhotoCropper(image: picture)),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Fit your photo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-photo-use')));
      await tester.pumpAndSettle();

      expect(chosen, isNotNull);
      expect(chosen!.width, chosen!.height);
      expect(chosen!.width, closeTo(600, 0.5));
      expect(chosen!.left, closeTo(100, 0.5));
    });

    testWidgets('the zoom buttons shrink the square, and cancel returns null', (
      tester,
    ) async {
      final picture = await image(tester);
      ui.Rect? chosen = const ui.Rect.fromLTWH(1, 1, 1, 1);
      var closed = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<ui.Rect>(
                  MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(body: ProfilePhotoCropper(image: picture)),
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Each button is a real tap target.
      for (final key in ['profile-photo-zoom-in', 'profile-photo-zoom-out']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.byKey(const ValueKey('profile-photo-zoom-in')));
      await tester.tap(find.byKey(const ValueKey('profile-photo-zoom-in')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('profile-photo-use')));
      await tester.pumpAndSettle();
      expect(chosen!.width, lessThan(600));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-photo-cancel')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(chosen, isNull);
    });

    testWidgets('reads in Arabic, right to left', (tester) async {
      final picture = await image(tester);
      await tester.pumpWidget(
        host(ProfilePhotoCropper(image: picture), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ظبّطي الصورة'), findsOneWidget);
      expect(find.text('استخدمي الصورة دي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('ظبّطي الصورة'))),
        TextDirection.rtl,
      );
    });
  });
}
