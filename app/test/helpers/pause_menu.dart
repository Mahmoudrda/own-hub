// R07 and R09 keep one control in the top bar, Pause. Its sheet holds Resume,
// End workout and a "…" with everything else; these walk to a row in it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the Pause sheet.
Future<void> openPause(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pause')));
  await tester.pumpAndSettle();
}

/// Opens the Pause sheet and its "…", and returns the row [label] is on, or
/// null when the menu has no such row. The sheets stay open.
Future<Finder?> moreRow(WidgetTester tester, String label) async {
  await openPause(tester);
  if (find.byKey(const ValueKey('overflow-menu')).evaluate().isEmpty) {
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    return null;
  }
  await tester.tap(find.byKey(const ValueKey('overflow-menu')));
  await tester.pumpAndSettle();
  final row = find.byKey(ValueKey('overflow-row-$label'));
  return row.evaluate().isEmpty ? null : row;
}

/// Taps the row [label] of the Pause sheet's "…", which closes both sheets.
Future<void> pickMore(WidgetTester tester, String label) async {
  final row = await moreRow(tester, label);
  expect(row, isNotNull, reason: 'the "…" has a "$label" row');
  await tester.tap(row!);
  await tester.pumpAndSettle();
}

/// Closes the sheets opened by [moreRow].
Future<void> closeSheets(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

/// Logs the whole move from the Pause sheet's "…": "I did all 3 sets" or "I
/// did them all", whichever the move offers. False when there is no Pause
/// button on screen or the menu has neither row.
Future<bool> logWholeMove(WidgetTester tester) async {
  if (find.byKey(const ValueKey('pause')).evaluate().isEmpty) return false;
  final row =
      await moreRow(tester, 'I did all 3 sets') ??
      find.byKey(const ValueKey('overflow-row-I did them all'));
  if (row.evaluate().isEmpty) {
    await closeSheets(tester);
    return false;
  }
  await tester.tap(row);
  await tester.pumpAndSettle();
  return true;
}

/// Pause > End workout > Finish and save: ends the session early with what is
/// logged, as the old "Finish here" did.
Future<void> finishEarly(WidgetTester tester) async {
  final bar = find.byKey(const ValueKey('session-end')).hitTestable();
  if (bar.evaluate().isNotEmpty) {
    await tester.tap(bar);
  } else {
    await openPause(tester);
    await tester.tap(find.byKey(const ValueKey('pause-end')));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('end-finish')));
  await tester.pumpAndSettle();
}
