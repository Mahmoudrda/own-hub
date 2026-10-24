// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-19 to R1-27: the Eat flow and the allergy path.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  for (final id in [
    'E01',
    'E02',
    'E03',
    'E04',
    'E05',
    'E10',
    'E07',
    'E08',
    'E11',
  ]) {
    testWidgets('$id as opened, day one', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id PAINTED: ${paintedText(t).join(" | ")}');
      print('$id TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
      print(
        '$id dialogs=${find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length} sheets=${find.byType(BottomSheet).evaluate().length}',
      );
      s.dispose();
    });
  }
  testWidgets('R1-19 log a meal from E02, Find and add', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['E02']!.name, locale: const Locale('en'));
    print(
      'BEFORE: ${paintedText(t).where((e) => e.contains("Day") || e.contains("plates")).join(" | ")}',
    );
    // The first pick is the most popular Egyptian dish.
    // A day-one woman has no usual plate: the dish, then Add.
    final dish = find.byKey(const ValueKey('result-koshari_bowl'));
    expect(dish, findsOneWidget, reason: 'E02 must offer the dish');
    await t.tap(dish);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('portion-add')));
    await settle(t);
    print('AFTER LOG top=${topScreen(t)}');
    print('AFTER LOG painted: ${paintedText(t).join(" | ")}');
    print(
      'snackbars=${find.byType(SnackBar).evaluate().length} dialogs=${find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length}',
    );
    // wait past the undo window
    await t.pump(const Duration(seconds: 6));
    print('AFTER 6s snackbars=${find.byType(SnackBar).evaluate().length}');
    print('AFTER 6s painted: ${paintedText(t).join(" | ")}');
    s.dispose();
  });
}
