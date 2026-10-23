// While she chooses a move she sees its video: tapping a row opens a sheet with
// the clip, the name, the muscles and the kit, and "Use this move" ticks it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/move_picker_view.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/exercise_library_fixture.dart';

Widget _host(Widget home, {String locale = 'ar'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(Locale(locale)),
  home: home,
);

Widget _picker({String locale = 'en', double scale = 1}) => _host(
  MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MovePickerView(
      exercises: sampleExerciseLibrary().exercises,
      media: FakeExerciseMedia(),
      players: FakeClipPlayer.make,
    ),
  ),
  locale: locale,
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(FakeClipPlayer.made.clear);

  testWidgets('tapping a move opens its video with the facts', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_picker());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('picker-glute_bridge')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('move-preview-clip')), findsOneWidget);
    expect(FakeClipPlayer.made, isNotEmpty);
    expect(FakeClipPlayer.made.first.opened, isNotNull);
    expect(find.textContaining('Muscles worked'), findsOneWidget);
    expect(find.text('Use this move'), findsOneWidget);
    // Nothing is ticked yet.
    expect(find.text('Add selected (0)'), findsOneWidget);
  });

  testWidgets('Use this move ticks it and closing does not', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_picker());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('picker-glute_bridge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-preview')), findsNothing);
    var add = tester.widget<AppButton>(
      find.byKey(const ValueKey('picker-add')),
    );
    expect(add.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('picker-glute_bridge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-preview-use')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-preview')), findsNothing);
    add = tester.widget<AppButton>(find.byKey(const ValueKey('picker-add')));
    expect(add.onPressed, isNotNull);
  });

  testWidgets('the circle ticks a move without opening the video', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_picker());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('picker-toggle-glute_bridge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-preview')), findsNothing);
    final add = tester.widget<AppButton>(
      find.byKey(const ValueKey('picker-add')),
    );
    expect(add.onPressed, isNotNull);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('the preview fits at text scale 2.0 in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_picker(locale: locale, scale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-band_pass_through')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('move-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
