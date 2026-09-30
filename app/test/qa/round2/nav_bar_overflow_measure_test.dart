// QA round 2, R2-44. Measures whether the bottom nav bar's Arabic tab labels
// actually truncate at the largest accessibility text size, on the real
// Rubik font (loaded explicitly, since flutter_test does not load bundled
// fonts by default) and at the bar's actual shipped tab set.
//
// This is a measuring aid for the audit, not a regression test: it is not
// wired into the app's own suite and does not assert pass/fail on the
// product's behalf. It exists to produce a real, on-the-record number.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

Future<void> _loadRubik() async {
  for (final entry in const {
    'assets/fonts/Rubik-400.ttf': FontWeight.w400,
    'assets/fonts/Rubik-500.ttf': FontWeight.w500,
    'assets/fonts/Rubik-600.ttf': FontWeight.w600,
    'assets/fonts/Rubik-700.ttf': FontWeight.w700,
  }.entries) {
    final bytes = File(entry.key).readAsBytesSync();
    final loader = FontLoader('Rubik')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadRubik);

  final savedFlags = AppRouter.featureFlags;
  // The six features the first release ships, written out rather than borrowed.
  //
  // This read the defaults directly and was caught by
  // `test/domain/flags/flag_independence_test.dart`, correctly: the subject
  // here is what Arabic tab labels do at the largest text size, not where the
  // owner's switches happen to stand today. Borrowing the defaults would mean
  // that the day Community is switched on, this file silently starts measuring
  // a four-tab bar and its recorded number stops meaning what it says.
  //
  // Same list as `test/qa/round1/round1_harness.dart`, and for the same reason:
  // if the shipping set changes, this changes by hand.
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_(<Feature, bool>{
      Feature.today: true,
      Feature.train: true,
      Feature.eat: true,
      Feature.progress: true,
      Feature.cycle: true,
      Feature.privacyCentre: true,
    });
  });
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('R2-44: nav bar in Arabic at textScale 1.6, real Rubik font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.6),
        ),
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('ar')),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: AppNavBar(activeScreenId: 'T01'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1) Does layout throw (a hard RenderFlex overflow) at the shipped 1.35
    // clamp? Mirrors the existing app_nav_bar_test.dart assertion, kept here
    // so this file's own number is self-contained.
    final exception = tester.takeException();
    // ignore: avoid_print
    print('R2-44 takeException at ar/1.6: $exception');

    // 2) The shipped trainee tabs, in the order the bar draws them.
    final shippedLabels = <String>[
      for (final tab in tabsFor(AppRole.trainee))
        tab.label(AppL10n.of(tester.element(find.byType(AppNavBar)))),
    ];
    // ignore: avoid_print
    print('R2-44 shipped trainee tab labels (ar): $shippedLabels');

    // 3) Per label: does the rendered RenderParagraph report an ellipsis
    // truncation at its real, laid-out width?
    for (final label in shippedLabels) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: 'tab "$label" did not render');
      final rp = tester.renderObject<RenderParagraph>(finder);
      final size = rp.size;
      final exceeded = rp.didExceedMaxLines;
      // ignore: avoid_print
      print(
        'R2-44 tab "$label": box=${size.width.toStringAsFixed(1)}x'
        '${size.height.toStringAsFixed(1)} didExceedMaxLines=$exceeded',
      );
    }

    // 4) Independent arithmetic check for the vertical box, using the same
    // TextStyle the bar actually uses (AppText.nav + w600), scaled by the
    // bar's OWN clamp (1.35), not the ambient 1.6 — this is the number that
    // actually reaches the label.
    const style = TextStyle(
      fontFamily: 'Rubik',
      fontSize: 12,
      height: 1.333,
      fontWeight: FontWeight.w600,
    );
    for (final scale in [1.35, 1.6]) {
      final painter = TextPainter(
        text: TextSpan(text: shippedLabels.first, style: style),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.linear(scale),
        maxLines: 1,
      )..layout();
      // ignore: avoid_print
      print(
        'R2-44 arithmetic: "${shippedLabels.first}" at scale=$scale -> '
        'natural line height=${painter.height.toStringAsFixed(2)}px '
        '(icon 32 + gap 4 + this vs 60 box; budget for label = 24px)',
      );
    }
  });
}
