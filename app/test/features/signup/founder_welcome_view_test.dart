// Rahma's welcome without a video: until the address is set, the page says the
// video is coming and offers nothing to tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/founder_video_player.dart';
import 'package:own_hub/features/signup/presentation/founder_welcome_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

class _Player implements FounderVideoPlayer {
  _Player({this.opens = true});

  final bool opens;
  final List<String> opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return opens;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  bool get playing => false;

  @override
  double get aspectRatio => 0.8;

  @override
  Widget view() => const SizedBox();

  @override
  Future<void> dispose() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required String videoUrl,
  required FounderVideoPlayerFactory playerFactory,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(const Locale('en')),
      home: FounderWelcomeView(
        onContinue: () {},
        onClose: () {},
        videoUrl: videoUrl,
        playerFactory: playerFactory,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const soon = ValueKey('founder-video-unavailable');
  const play = ValueKey('founder-play');

  testWidgets('with no video address the soon message shows at once', (
    tester,
  ) async {
    var made = 0;
    await _pump(
      tester,
      videoUrl: '',
      playerFactory: () {
        made++;
        return _Player();
      },
    );

    expect(find.byKey(soon), findsOneWidget);
    expect(find.text("Rahma's video will be here soon."), findsOneWidget);
    expect(find.byKey(play), findsNothing);
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    expect(made, 0, reason: 'no player is made for a video that is not there');
  });

  testWidgets('with an address the play control shows and the note does not', (
    tester,
  ) async {
    await _pump(
      tester,
      videoUrl: 'https://example.test/rahma.mp4',
      playerFactory: _Player.new,
    );

    expect(find.byKey(play), findsOneWidget);
    expect(find.byKey(soon), findsNothing);
  });

  testWidgets('a video that will not open falls back to the soon message', (
    tester,
  ) async {
    final player = _Player(opens: false);
    await _pump(
      tester,
      videoUrl: 'https://example.test/rahma.mp4',
      playerFactory: () => player,
    );

    await tester.tap(find.byKey(play));
    await tester.pump();
    await tester.pump();

    expect(player.opened, ['https://example.test/rahma.mp4']);
    expect(find.byKey(soon), findsOneWidget);
    expect(find.byKey(play), findsNothing);
  });
}
