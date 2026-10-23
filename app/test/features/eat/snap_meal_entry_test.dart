// The camera entries are named, tappable for a screen reader, and routed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/features/today/presentation/today_cards.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_field.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('SnapMealButton exposes a tap action to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(SnapMealButton(label: 'Snap your meal', onPressed: () => taps++)),
    );
    final node = tester.getSemantics(
      find.byKey(const ValueKey('eat-snap-meal')),
    );
    expect(node.label, 'Snap your meal');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Snap your meal'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('SnapMealCard names the camera and routes onSnap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SnapMealCard(
          title: 'Scan your meal with the camera',
          subtitle: 'One photo for calories and protein',
          onPressed: () => taps++,
        ),
      ),
    );
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.text('Scan your meal with the camera'), findsOneWidget);
    expect(find.text('One photo for calories and protein'), findsOneWidget);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('eat-snap-card')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.byKey(const ValueKey('eat-snap-card')));
    expect(taps, 1);
    handle.dispose();
  });

  group('the Home eat card scan chip', () {
    testWidgets('calls onScanMeal', (tester) async {
      var scans = 0;
      await tester.pumpWidget(
        _host(HomeEatCard(onLogFood: () {}, onScanMeal: () => scans++)),
      );
      expect(find.text('Scan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('today-scan-meal')));
      expect(scans, 1);
    });

    testWidgets('is hidden when there is no callback', (tester) async {
      await tester.pumpWidget(_host(HomeEatCard(onLogFood: () {})));
      expect(find.byKey(const ValueKey('today-scan-meal')), findsNothing);
      expect(find.byKey(const ValueKey('today-log-food')), findsOneWidget);
    });
  });

  testWidgets('AppField forwards inputFormatters and textAlign', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        AppField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlign, TextAlign.center);
    expect(field.inputFormatters, isNotEmpty);
    await tester.enterText(find.byType(TextField), 'a1b2');
    expect(controller.text, '12');
  });

  testWidgets('AppField aligns to the start by default', (tester) async {
    await tester.pumpWidget(_host(const AppField()));
    expect(
      tester.widget<TextField>(find.byType(TextField)).textAlign,
      TextAlign.start,
    );
  });
}
