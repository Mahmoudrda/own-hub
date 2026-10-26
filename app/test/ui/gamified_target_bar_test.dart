import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/gamified_target_bar.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );
  }

  group('GamifiedTargetBar', () {
    testWidgets('shows remaining amount when current is less than target', (tester) async {
      await tester.pumpWidget(
        wrap(
          const GamifiedTargetBar(
            label: 'Protein',
            current: 20,
            target: 100,
            unit: 'g',
          ),
        ),
      );

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('20 / 100 g'), findsOneWidget);
      expect(find.text('80g remaining'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('shows target reached when current meets target', (tester) async {
      await tester.pumpWidget(
        wrap(
          const GamifiedTargetBar(
            label: 'Protein',
            current: 100,
            target: 100,
            unit: 'g',
          ),
        ),
      );

      expect(find.text('100 / 100 g'), findsOneWidget);
      expect(find.text('Target reached'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows Arabic text and Western digits in Arabic locale', (tester) async {
      await tester.pumpWidget(
        wrap(
          const GamifiedTargetBar(
            label: 'بروتين',
            current: 30,
            target: 120,
            unit: 'جم',
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(find.text('بروتين'), findsOneWidget);
      expect(find.text('30 / 120 جم'), findsOneWidget);
      expect(find.text('باقي 90 جم'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });
  });
}
