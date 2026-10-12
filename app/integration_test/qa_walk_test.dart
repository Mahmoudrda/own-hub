// TEMPORARY QA instrument. Delete after the walk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart' as app;
import 'package:own_hub/routing/app_router.dart';

Future<void> hold(WidgetTester t, String label) async {
  // ignore: avoid_print
  print('QA-CHECKPOINT $label ${DateTime.now().toIso8601String()}');
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    // ignore: avoid_print
    print('QA-MISS "$text"');
    return false;
  }
  await t.tap(f.first, warnIfMissed: false);
  await t.pumpAndSettle(const Duration(seconds: 2));
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk', (t) async {
    AppRouter.featureFlags = FeatureFlags.everything;
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 3));
    await hold(t, 'A-launch');

    // Bottom nav -> Eat.
    for (final label in const ['Eat', 'الأكل', 'الطعام']) {
      if (await tapText(t, label)) break;
    }
    await hold(t, 'B-eat');

    // Eat -> Recipes.
    for (final label in const ['Recipes', 'وصفات', 'الوصفات']) {
      if (await tapText(t, label)) break;
    }
    await hold(t, 'C-recipes-cold');

    await t.dragUntilVisible(
      find.byType(Scaffold).first,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    ).catchError((_) {});
    await t.pumpAndSettle();

    // Scroll the recipes list down to see the book.
    final sc = find.byType(Scrollable);
    if (sc.evaluate().isNotEmpty) {
      await t.drag(sc.first, const Offset(0, -900));
      await t.pumpAndSettle();
    }
    await hold(t, 'D-recipes-scrolled');

    if (sc.evaluate().isNotEmpty) {
      await t.drag(sc.first, const Offset(0, -900));
      await t.pumpAndSettle();
    }
    await hold(t, 'E-recipes-scrolled2');
  });
}
