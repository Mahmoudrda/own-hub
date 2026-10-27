import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget host(Widget child, {String lang = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(Locale(lang)),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    );

/// 390x844 at 3.0.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// 375x667 at 3.0.
void smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1125, 2001);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}
