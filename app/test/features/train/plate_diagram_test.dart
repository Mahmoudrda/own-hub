// The plate diagram and the line beside it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/bar_preference.dart';
import 'package:own_hub/features/train/domain/plate_math.dart';
import 'package:own_hub/features/train/presentation/plate_diagram.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 800),
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  setUp(() => BarPreference.instance.reset());
  tearDown(() => BarPreference.instance.reset());

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'renders ${locale.languageCode} at text scale 2.0 without overflow',
      (tester) async {
        await tester.pumpWidget(
          _host(const PlateHelper(totalKg: 142.5), locale: locale, scale: 2),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('plate-diagram')), findsOneWidget);
        expect(find.byKey(const ValueKey('plate-line')), findsOneWidget);
      },
    );
  }

  testWidgets('says the bar and each side, and labels the picture', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PlateHelper(totalKg: 40)));
    await tester.pumpAndSettle();
    expect(find.text('20 kg bar + 10 kg each side'), findsOneWidget);
    expect(find.bySemanticsLabel('Plates on one side: 10 kg'), findsOneWidget);
  });

  testWidgets('says so when the total cannot be loaded exactly', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PlateHelper(totalKg: 41)));
    await tester.pumpAndSettle();
    expect(
      find.text('Closest you can load: 40 kg. 20 kg bar + 10 kg each side.'),
      findsOneWidget,
    );
  });

  testWidgets('draws nothing below the bar', (tester) async {
    await tester.pumpWidget(_host(const PlateHelper(totalKg: 15)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plate-helper')), findsNothing);
  });

  testWidgets('the bar is chosen once, used, and kept', (tester) async {
    await tester.pumpWidget(_host(const PlateHelper(totalKg: 40)));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('plate-change-bar'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const ValueKey('plate-change-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Which bar do you use?'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('bar-choice-15'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const ValueKey('bar-choice-15')));
    await tester.pumpAndSettle();

    expect(BarPreference.instance.kg, 15);
    expect(find.text('15 kg bar + 12.5 kg each side'), findsOneWidget);
  });

  test('only the bars on offer are kept', () {
    BarPreference.instance.choose(12);
    expect(BarPreference.instance.touched, isFalse);
    BarPreference.instance.choose(10);
    expect(BarPreference.instance.kg, 10);
    expect(kBarChoicesKg, contains(10));
  });
}
