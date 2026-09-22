// T03 — From the lock screen.
//
// The in-app rendering of the one nudge a day she may get. The promise is that
// the button logs the meal without opening the app, so the thing worth testing
// is that the tap is a log and not a prompt — a confirmation here would defeat
// the entire point of the surface.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/lock_screen_nudge_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _at = DateTime(2026, 9, 15, 8, 42);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        // copyWith, not a bare MediaQueryData: a fresh one zeroes the window
        // size, so any widget that measures itself against the screen lays out
        // to nothing here while working perfectly in production.
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

LockScreenNudgeView _view({TodayRepository? repository}) {
  return LockScreenNudgeView(
    repository: repository ?? InMemoryTodayRepository(),
    at: _at,
    onLogged: () {},
    onSomethingElse: () {},
  );
}

void main() {
  group('one nudge, and one tap', () {
    testWidgets('the meal is named in full before she decides', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      // The day comes off `at`, like the clock below it. "Tuesday 16
      // September" was fixed, so the lock screen showed 16 September for ever
      // while the time beside it moved.
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Tuesday 16 September'), findsNothing);
      expect(find.text('Breakfast, your usual?'), findsOneWidget);
      // The nudge fires only "for a meal she has had three times or more", and
      // the one line that had to be hers was the prototype's breakfast and its
      // macros. Named when a caller supplies it, silent otherwise.
      expect(
        find.text('Ful and baladi · 410 kcal · 22 g protein'),
        findsNothing,
      );
      expect(find.text('Log it'), findsOneWidget);
      expect(find.text('Something else'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the clock is a formatted time, not a translated string', (
      tester,
    ) async {
      // There is no dictionary key for "8:42" and there should not be — a time
      // is formatted in her locale's own convention.
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      expect(find.textContaining('8:42'), findsOneWidget);
    });
  });

  group('RULE 9 — logging never asks permission', () {
    testWidgets('it logs and offers undo', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_view()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Log it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الفطور المعتاد؟'), findsOneWidget);
    expect(find.text('سجّليها'), findsOneWidget);
    expect(find.text('شيء آخر'), findsOneWidget);
    expect(find.text('Log it'), findsNothing);
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    // The largest type on any screen in this product sits here — an 82pt clock.
    _phone(tester);
    await tester.pumpWidget(
      _host(_view(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
