import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/presentation/deep_breath_view.dart';
import 'package:own_hub/features/onboarding/presentation/tick_promise_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, Locale locale, double scale, {bool still = false}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: still,
          ),
          child: child,
        ),
      ),
    );

void main() {
  const sizes = [Size(375, 667), Size(390, 844)];
  const locales = [Locale('en'), Locale('ar')];
  const scales = [1.6, 2.0];

  for (final size in sizes) {
    for (final locale in locales) {
      for (final scale in scales) {
        final label = '$size ${locale.languageCode} x$scale';

        testWidgets('tick: no overflow, Skip reachable, $label', (t) async {
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          var done = 0;
          await t.pumpWidget(
            _host(TickPromiseView(onDone: () => done++), locale, scale),
          );
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          final l10n = AppL10n.of(t.element(find.byType(TickPromiseView)));
          await t.tap(find.text(l10n.skip));
          expect(done, 1);
        });

        testWidgets('tick: "I promise" reachable, $label', (t) async {
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          var done = 0;
          await t.pumpWidget(
            _host(TickPromiseView(onDone: () => done++), locale, scale),
          );
          expect(t.takeException(), isNull);
          final l10n = AppL10n.of(t.element(find.byType(TickPromiseView)));
          await t.tap(find.text(l10n.iPromise));
          await t.pump(const Duration(seconds: 3));
          expect(t.takeException(), isNull);
          expect(done, 1);
        });

        testWidgets('breath: no overflow, Skip and Continue, $label', (
          t,
        ) async {
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          var done = 0;
          await t.pumpWidget(
            _host(
              DeepBreathView(onDone: () => done++),
              locale,
              scale,
              still: true,
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
          final l10n = AppL10n.of(t.element(find.byType(DeepBreathView)));
          await t.tap(find.text(l10n.continueLabel));
          expect(done, 1);
        });

        testWidgets('breath moving: no overflow, Skip works, $label', (
          t,
        ) async {
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          var done = 0;
          await t.pumpWidget(
            _host(DeepBreathView(onDone: () => done++), locale, scale),
          );
          await t.pump(const Duration(seconds: 2));
          expect(t.takeException(), isNull);
          final l10n = AppL10n.of(t.element(find.byType(DeepBreathView)));
          await t.tap(find.text(l10n.skip));
          expect(done, 1);
        });
      }
    }
  }
}
