// T03 — From the lock screen.
//
// The in-app rendering of the one nudge a day she may get. The promise is that
// the button logs the meal without opening the app, so the thing worth testing
// is that the tap is a log and not a prompt — a confirmation here would defeat
// the entire point of the surface.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/welcome_view.dart';
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

/// The nudge as it fires in the product: for a meal she has had three times or
/// more, which is what [mealLine] naming one means.
LockScreenNudgeView _view({
  TodayRepository? repository,
  DateTime? at,
  String? mealLine = 'Ful and baladi',
}) {
  return LockScreenNudgeView(
    repository: repository ?? InMemoryTodayRepository(),
    at: at ?? _at,
    mealLine: mealLine,
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
      // 08:42 is breakfast, and the heading is read from the clock rather than
      // fixed. It WAS fixed: `breakfastYourUsual_1lb0u` for every nudge at
      // every hour, so a woman whose usual log is at seven in the evening was
      // asked "Breakfast, your usual?" over her dinner. T01, T02 and E04 were
      // fixed for this and T03 was missed.
      expect(find.text('Breakfast, your usual?'), findsOneWidget);
      // The nudge fires only "for a meal she has had three times or more", and
      // the one line that had to be hers was the prototype's breakfast and its
      // macros. Named when a caller supplies it, silent otherwise.
      expect(
        find.text('Ful and baladi · 410 kcal · 22 g protein'),
        findsNothing,
      );
      expect(find.text('Add it'), findsOneWidget);
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

      await tester.ensureVisible(find.text('Add it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the heading is the hour she is actually in', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_view(at: DateTime(2026, 9, 15, 19, 10))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinner, your usual?'), findsOneWidget);
      expect(find.text('Breakfast, your usual?'), findsNothing);
    });

    testWidgets('and "your usual" is a habit, so it has to be named', (
      tester,
    ) async {
      // No meal supplied means nobody has told this screen which habit it is
      // about, and "your usual" is a claim about one. Same rule Home's meal
      // card follows.
      _phone(tester);
      await tester.pumpWidget(_host(_view(mealLine: null)));
      await tester.pumpAndSettle();

      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Breakfast, your usual?'), findsNothing);
    });
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الفطور المعتاد؟'), findsOneWidget);
    expect(find.text('أضيفيه'), findsOneWidget);
    expect(find.text('شيء آخر'), findsOneWidget);
    expect(find.text('Add it'), findsNothing);
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

  testWidgets('the app icon is the Own Hub tile, not a stock glyph', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_view()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restaurant), findsNothing);
    expect(LockScreenNudgeView.appIconAsset, WelcomeView.logoAsset);
    final icon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == LockScreenNudgeView.appIconAsset,
    );
    expect(icon, findsOneWidget);
    final image = tester.widget<Image>(icon);
    expect(image.width, 28);
    expect(image.height, 28);
    expect(
      image.excludeFromSemantics,
      isTrue,
      reason: 'decorative: the app name is written beside it',
    );
    final clip = tester.widget<ClipRRect>(
      find.ancestor(of: icon, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(9));
    expect(find.text('Own Hub'), findsOneWidget);
  });

  test('the placeholder note is gone', () {
    final source = File(
      'lib/features/today/presentation/lock_screen_nudge_view.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('TODO')));
    expect(source, isNot(contains('Icons.restaurant')));
  });
}
