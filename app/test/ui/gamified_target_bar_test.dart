import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/gamified_target_bar.dart';

void main() {
  Widget wrap(
    Widget child, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  group('GamifiedTargetBar', () {
    testWidgets('shows remaining amount when current is less than target', (
      tester,
    ) async {
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
      expect(find.text('80 g remaining'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('shows target reached when current meets target', (
      tester,
    ) async {
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

    testWidgets('shows Arabic text and Western digits in Arabic locale', (
      tester,
    ) async {
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

    testWidgets(
      'a screen reader hears one sentence, in the language of the screen',
      (tester) async {
        final handle = tester.ensureSemantics();
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
        final bar = find.byType(GamifiedTargetBar);
        expect(
          tester.getSemantics(bar).label,
          'Protein: 20 of 100 g. 80 g remaining.',
        );
        expect(find.bySemanticsLabel('80 g remaining'), findsNothing);

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
        expect(
          tester.getSemantics(bar).label,
          'بروتين: 30 من 120 جم. باقي 90 جم.',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'fits a 326 px phone at normal and large text, in both languages',
      (tester) async {
        tester.view.physicalSize = const Size(326, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        for (final locale in [const Locale('en'), const Locale('ar')]) {
          for (final scale in [1.0, 2.0]) {
            await tester.pumpWidget(
              wrap(
                GamifiedTargetBar(
                  label: locale.languageCode == 'ar'
                      ? 'بروتين (جم)'
                      : 'Protein (g)',
                  current: 1240,
                  target: 1600,
                  unit: locale.languageCode == 'ar' ? 'جم' : 'g',
                ),
                locale: locale,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${locale.languageCode} at $scale',
            );
          }
        }
      },
    );

    testWidgets(
      'a partial total never says remaining or reached, on screen or aloud',
      (tester) async {
        final handle = tester.ensureSemantics();
        for (final current in [40, 110, 130]) {
          await tester.pumpWidget(
            wrap(
              GamifiedTargetBar(
                label: 'Protein',
                current: current,
                target: 100,
                unit: 'g',
                partial: true,
              ),
            ),
          );
          expect(find.text('Some items have no figures.'), findsOneWidget);
          expect(find.text('Target reached'), findsNothing);
          expect(find.textContaining('remaining'), findsNothing);
          expect(
            tester.getSemantics(find.byType(GamifiedTargetBar)).label,
            'Protein: $current of 100 g. Some items have no figures.',
          );
        }
        await tester.pumpWidget(
          wrap(
            const GamifiedTargetBar(
              label: 'بروتين',
              current: 30,
              target: 120,
              unit: 'جم',
              partial: true,
            ),
            locale: const Locale('ar'),
          ),
        );
        expect(find.text('بعض الأصناف ملهاش أرقام.'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('the fill does not animate when motion is off', (tester) async {
      Duration fill() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .duration;
      const bar = GamifiedTargetBar(
        label: 'Protein',
        current: 20,
        target: 100,
        unit: 'g',
      );

      await tester.pumpWidget(wrap(bar));
      expect(fill(), const Duration(milliseconds: 300));

      await tester.pumpWidget(wrap(bar, disableAnimations: true));
      expect(fill(), Duration.zero);
    });
  });
}
