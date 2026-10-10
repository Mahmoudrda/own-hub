// G10 and G11 as screens — the planned meal, and the log she can correct.
//
// The assertion that carries a rule here is the **blocked** state: when the
// guard's verdict is outstanding, "Ate this" is not a button she can tap. A
// conflicting meal that arrived from a coach's plan must not be one tap from
// being logged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/presentation/log_planned_meal_view.dart';
import 'package:own_hub/features/coached/presentation/meal_logged_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  group('G10 — the planned meal', () {
    testWidgets('it opens on her coach\'s item with the note ready', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LogPlannedMealView()));
      await tester.pumpAndSettle();

      expect(find.text('Koshari bowl, medium'), findsOneWidget);
      expect(find.text('From your plan'), findsOneWidget);
      expect(
        find.textContaining('Add the salad if you are still hungry after'),
        findsOneWidget,
      );
      expect(find.text('Ate this'), findsOneWidget);
    });

    testWidgets('logging is one tap, with no confirmation', (tester) async {
      var logged = 0;
      await tester.pumpWidget(_host(LogPlannedMealView(onLog: () => logged++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ate this'));
      await tester.pumpAndSettle();

      expect(logged, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'P0-INTAKE-03 — a blocked row states its reason and cannot be logged',
      (tester) async {
        var logged = 0;
        await tester.pumpWidget(
          _host(
            LogPlannedMealView(
              blockedReason: 'This contains sesame, which you cannot eat.',
              onLog: () => logged++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('This contains sesame, which you cannot eat.'),
          findsOneWidget,
        );

        final button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Ate this'),
        );
        expect(button.onPressed, isNull);

        await tester.tap(find.text('Ate this'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(logged, 0);
      },
    );

    testWidgets(
      'P0-INTAKE-04 — unknown constraints block exactly as a named allergen does',
      (tester) async {
        // Unknown is not absent. The screen shows the same closed door.
        await tester.pumpWidget(
          _host(
            const LogPlannedMealView(
              blockedReason: 'We could not read your allergies yet.',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Ate this'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'the alternatives are secondary, because most days she ate it',
      (tester) async {
        await tester.pumpWidget(_host(const LogPlannedMealView()));
        await tester.pumpAndSettle();

        final ate = tester.getTopLeft(find.text('Ate this')).dy;
        final something = tester.getTopLeft(find.text('Something else')).dy;
        expect(
          something,
          lessThan(ate),
          reason: 'the primary action sits in the footer, below the rest',
        );
      },
    );
  });

  group('G11 — one log, corrected in place', () {
    testWidgets('it states that tapping twice does not double-count', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MealLoggedView()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Changing the plan never changes a meal you already added. Tapping twice does not add it twice.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('correcting the portion and adding a helping are different', (
      tester,
    ) async {
      var portion = -1;
      var helpings = 0;
      await tester.pumpWidget(
        _host(
          MealLoggedView(
            onPortion: (i) => portion = i,
            onAddHelping: () => helpings++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('½ serving'));
      await tester.pumpAndSettle();
      expect(portion, 0);
      expect(helpings, 0, reason: 'correcting is not adding');

      await tester.tap(find.text('Add another serving'));
      await tester.pumpAndSettle();
      expect(helpings, 1);
    });

    testWidgets('the undo bar names what was logged', (tester) async {
      // onUndo is what opens the window: AppUndoBar renders a plain statement
      // once the five seconds have closed, rather than a button that would do
      // nothing. So the offer only exists while there is something to take back.
      await tester.pumpWidget(_host(MealLoggedView(onUndo: () {})));
      await tester.pumpAndSettle();

      // The bar used to read "Lunch added · 1 serving" from the dictionary
      // even when the screen had been told nothing about the meal. Given
      // nothing, it names no meal and no portion…
      expect(find.text('Meal added'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // …and given hers, it names hers.
      await tester.pumpWidget(
        _host(
          MealLoggedView(
            onUndo: () {},
            undoMessage: 'Lunch logged — ½ serving',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lunch logged — ½ serving'), findsOneWidget);
    });

    testWidgets('the protein row shows a target, never a countdown', (
      tester,
    ) async {
      // Given no protein figure the row states none: the dictionary's "53 of
      // 95 g" is the prototype's day, and it was read to every woman here.
      await tester.pumpWidget(_host(const MealLoggedView()));
      await tester.pumpAndSettle();
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('53 of 95 g'), findsNothing);

      await tester.pumpWidget(
        _host(const MealLoggedView(proteinLabel: '53 of 95 g')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('53 of 95 g'), findsOneWidget);
      // A countdown would read "42 g left". Nothing here counts down.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(texts.contains('left'), isFalse);
      expect(texts.contains('remaining'), isFalse);
    });
  });

  testWidgets('both screens render in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const LogPlannedMealView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(const MealLoggedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
