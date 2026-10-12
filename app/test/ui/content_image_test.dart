// A content library picture, or the drawn placeholder. Never a broken image:
// no resolver, signed out, offline, refused, or a picture that will not load
// all draw the placeholder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/content_images.dart';
import 'package:own_hub/ui/content_image.dart';

const _placeholder = SizedBox(key: ValueKey('placeholder'), height: 10);

Widget _host(String? path) => MaterialApp(
  home: Scaffold(
    body: ContentImage(path: path, placeholder: _placeholder, height: 120),
  ),
);

void main() {
  tearDown(() {
    ContentImage.resolver = null;
    ContentImages.reset();
  });

  testWidgets('no path: the placeholder', (tester) async {
    ContentImage.resolver = (_) async => 'https://example.com/x.webp';
    await tester.pumpWidget(_host(null));
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('no resolver (no Firebase, a test): the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_host('content/recipes/om_ali/om_ali.webp'));
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
  });

  testWidgets('signed out or offline: the placeholder', (tester) async {
    ContentImage.resolver = (_) async => null;
    await tester.pumpWidget(_host('content/recipes/om_ali/om_ali.webp'));
    await tester.pump();
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
  });

  testWidgets('a refused lookup: the placeholder, and nothing thrown', (
    tester,
  ) async {
    ContentImage.resolver = (_) => Future<String?>.error(StateError('denied'));
    await tester.pumpWidget(_host('content/recipes/om_ali/om_ali.webp'));
    await tester.pump();
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a URL: a sized network image that falls back when it fails', (
    tester,
  ) async {
    ContentImage.resolver = (_) async => 'https://example.com/om_ali.webp';
    await tester.pumpWidget(_host('content/recipes/om_ali/om_ali.webp'));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(
      (provider.imageProvider as NetworkImage).url,
      'https://example.com/om_ali.webp',
    );
    expect(provider.width, isNotNull, reason: 'decoded at the drawn width');
    // The test binding answers every request with an error: the fallback.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
  });

  group('the URL resolver', () {
    test('only content/ paths are asked for', () async {
      var asked = 0;
      ContentImages.lookup = (_) async {
        asked++;
        return 'https://example.com/a';
      };
      expect(await ContentImages.url('users/her/photo.jpg'), isNull);
      expect(await ContentImages.url('content/../users/x'), isNull);
      expect(asked, 0);
    });

    test('each URL is asked for once a run', () async {
      var asked = 0;
      ContentImages.lookup = (_) async {
        asked++;
        return 'https://example.com/a';
      };
      await ContentImages.url('content/recipes/a/a.webp');
      await ContentImages.url('content/recipes/a/a.webp');
      expect(asked, 1);
    });

    test('a failure is null, and is asked again next time', () async {
      var asked = 0;
      ContentImages.lookup = (_) async {
        asked++;
        throw StateError('offline');
      };
      expect(await ContentImages.url('content/events/e/c.webp'), isNull);
      expect(await ContentImages.url('content/events/e/c.webp'), isNull);
      expect(asked, 2);
    });
  });
}
