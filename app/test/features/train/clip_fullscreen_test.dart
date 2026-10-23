// The clip, full screen: the badge on the frame opens a view with its own
// player (play and pause, restart, half speed, close), the page's own player is
// let go while anything covers it and comes back when she does, and the view
// works with Reduce Motion on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/exercise_clip_frame.dart';
import 'package:own_hub/features/train/presentation/exercise_clip_player.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/exercise_library_fixture.dart';

/// A player that can also restart and change speed.
class _ControlledPlayer extends FakeClipPlayer implements ExerciseClipControls {
  int restarts = 0;
  final List<double> speeds = <double>[];

  static final List<_ControlledPlayer> all = <_ControlledPlayer>[];

  static ExerciseClipPlayer make() {
    final player = _ControlledPlayer();
    all.add(player);
    return player;
  }

  @override
  Future<void> restart() async {
    restarts++;
    await play();
  }

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
}

Widget _host(
  Widget home, {
  bool motionOff = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: motionOff,
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: home,
);

Widget _frame(ExerciseClipPlayerFactory players) {
  final library = sampleExerciseLibrary();
  return Scaffold(
    body: Center(
      child: ExerciseClipFrame(
        clipKey: const ValueKey('the-clip'),
        exercise: library.byId('glute_bridge')!,
        media: FakeExerciseMedia(),
        players: players,
        maxHeight: 220,
      ),
    ),
  );
}

void main() {
  setUp(() {
    FakeClipPlayer.made.clear();
    _ControlledPlayer.all.clear();
  });

  testWidgets('tapping the picture still plays and pauses', (tester) async {
    await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
    await tester.pumpAndSettle();
    final player = FakeClipPlayer.made.single;
    expect(player.playing, isTrue);

    await tester.tap(find.byKey(const ValueKey('the-clip')));
    await tester.pumpAndSettle();
    expect(player.playing, isFalse);
    await tester.tap(find.byKey(const ValueKey('the-clip')));
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    expect(find.byKey(const ValueKey('clip-fullscreen')), findsNothing);
  });

  testWidgets(
    'the badge opens the full screen view and closing it disposes it',
    (tester) async {
      await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
      await tester.pumpAndSettle();
      final page = FakeClipPlayer.made.single;

      await tester.tap(find.byKey(const ValueKey('clip-expand')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('clip-fullscreen')), findsOneWidget);
      // Its own player, not the page's.
      expect(FakeClipPlayer.made, hasLength(2));
      final big = FakeClipPlayer.made.last;
      expect(identical(big, page), isFalse);
      expect(big.playing, isTrue);
      // The page's player is let go while the full screen covers it.
      expect(page.disposed, isTrue);

      await tester.tap(find.byKey(const ValueKey('clip-fullscreen-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('clip-fullscreen')), findsNothing);
      expect(big.disposed, isTrue);
      // The page opens a fresh player when it is uncovered.
      expect(FakeClipPlayer.made, hasLength(3));
      expect(FakeClipPlayer.made.last.playing, isTrue);
    },
  );

  testWidgets('the badge is named for a screen reader and is 48 px', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Full screen'), findsOneWidget);
    final size = tester.getSize(find.byKey(const ValueKey('clip-expand')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('no players, no badge', (tester) async {
    final library = sampleExerciseLibrary();
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: ExerciseClipFrame(
            exercise: library.byId('glute_bridge')!,
            media: FakeExerciseMedia(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clip-expand')), findsNothing);
  });

  testWidgets('full screen: play, pause, restart and half speed', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frame(_ControlledPlayer.make)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clip-expand')));
    await tester.pumpAndSettle();
    final big = _ControlledPlayer.all.last;
    expect(big.playing, isTrue);

    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-play')));
    await tester.pumpAndSettle();
    expect(big.playing, isFalse);
    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-picture')));
    await tester.pumpAndSettle();
    expect(big.playing, isTrue);

    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-restart')));
    await tester.pumpAndSettle();
    expect(big.restarts, 1);

    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-half')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-normal')));
    await tester.pumpAndSettle();
    expect(big.speeds, [0.5, 1.0]);

    expect(find.bySemanticsLabel('Restart'), findsOneWidget);
    expect(find.bySemanticsLabel('Half speed'), findsOneWidget);
    expect(find.bySemanticsLabel('Normal speed'), findsOneWidget);
    expect(find.byTooltip('Close video'), findsOneWidget);
  });

  testWidgets('a player without restart or speed gets play and close only', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clip-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clip-fullscreen-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('clip-fullscreen-restart')), findsNothing);
    expect(find.byKey(const ValueKey('clip-fullscreen-half')), findsNothing);
  });

  testWidgets('under Reduce Motion it waits for her tap', (tester) async {
    await tester.pumpWidget(
      _host(_frame(_ControlledPlayer.make), motionOff: true),
    );
    await tester.pumpAndSettle();
    expect(_ControlledPlayer.all.single.plays, 0);

    await tester.tap(find.byKey(const ValueKey('clip-expand')));
    await tester.pumpAndSettle();
    final big = _ControlledPlayer.all.last;
    expect(big.playing, isFalse);
    expect(big.plays, 0);

    await tester.tap(find.byKey(const ValueKey('clip-fullscreen-play')));
    await tester.pumpAndSettle();
    expect(big.playing, isTrue);
  });

  testWidgets('a screen pushed over the clip lets its player go', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
    await tester.pumpAndSettle();
    final first = FakeClipPlayer.made.single;
    expect(first.playing, isTrue);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('over it')),
      ),
    );
    await tester.pumpAndSettle();
    expect(first.disposed, isTrue);
    expect(FakeClipPlayer.made, hasLength(1));

    navigator.pop();
    await tester.pumpAndSettle();
    expect(FakeClipPlayer.made, hasLength(2));
    expect(FakeClipPlayer.made.last.playing, isTrue);
  });

  testWidgets('a sheet over the clip does not stop it', (tester) async {
    await tester.pumpWidget(_host(_frame(FakeClipPlayer.make)));
    await tester.pumpAndSettle();
    final first = FakeClipPlayer.made.single;

    final context = tester.element(find.byType(ExerciseClipFrame));
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(height: 100, child: Text('a sheet')),
    );
    await tester.pumpAndSettle();
    expect(first.disposed, isFalse);
    expect(first.playing, isTrue);
  });

  testWidgets('under Reduce Motion the poster shows until she plays it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_frame(FakeClipPlayer.make), motionOff: true),
    );
    await tester.pumpAndSettle();
    // A player that was never started draws nothing, so it must not cover
    // the poster.
    expect(find.byKey(const ValueKey('fake-clip')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('the-clip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-clip')), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'full screen at text scale 2.0 in ${locale.languageCode} does not '
      'overflow and keeps every control 48 px',
      (tester) async {
        await tester.pumpWidget(
          _host(_frame(_ControlledPlayer.make), locale: locale, scale: 2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('clip-expand')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('clip-fullscreen')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(
            tester.element(find.byKey(const ValueKey('clip-fullscreen'))),
          ),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        for (final key in const [
          'clip-fullscreen-close',
          'clip-fullscreen-play',
          'clip-fullscreen-restart',
          'clip-fullscreen-half',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
      },
    );
  }
}
