// E02 — Type it. Implements P0-LOG-07.
//
// From TEST-CASES.csv: "Sentence parses into two items with sizes pre-picked,
// adjustable as chips on the row. Resolves with no network."
//
// The size assertion is made against what gets WRITTEN rather than against what
// the row displays.
//
// That was once the ONLY option, and the reason is worth keeping: the row's
// "540 kcal · 18 g protein" line used to be a fixed dictionary string with no
// placeholder form, so it read the same whichever size was selected, and
// asserting on it would have passed for a chip that did nothing.
//
// **It is no longer fixed.** `_metaFor` now computes from the selected
// `FoodSize` and the servings, so the displayed line moves with the chip and
// asserting on it finally means something. The written-value assertion stays —
// it is the stronger of the two — and a display assertion is now a real check.
//
// That comment was written before the fix reached this screen. `_metaFor` was
// still a four-case switch on `foodId` whose default arm was
// `n540Kcal18GProtein`, so two boiled eggs were reported as koshari's 540 and
// 18, tapping "Large" left the line saying Medium's figures, and the footer
// button read "I ate both · 696 kcal" — the total of the prototype's sentence —
// whatever she had typed and however many rows there were.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/type_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

TypeItView _typeIt({
  String? text,
  MealRepository? repository,
  LogCommandBus? bus,
  ValueChanged<LogHandle>? onLogged,
}) {
  return TypeItView(
    constraints: DietaryConstraints.none,
    repository: repository,
    bus: bus,
    now: _lunchtime,
    initialText: text,
    onLogged: onLogged,
    onClose: () {},
    onSpeak: () {},
  );
}

void main() {
  group('P0-LOG-07 — a sentence becomes two rows', () {
    testWidgets('"koshari and 2 eggs" parses into two items', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt(text: 'koshari and 2 eggs')));
      await tester.pumpAndSettle();

      expect(find.text("We'll add"), findsOneWidget);
      expect(find.text('Koshari bowl'), findsOneWidget);
      expect(find.text('Boiled eggs'), findsOneWidget);
    });

    testWidgets('the sizes are pre-picked and adjustable on the row', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt(text: 'koshari and 2 eggs')));
      await tester.pumpAndSettle();

      // Koshari's three sizes, and the egg counts — chips ON the row, so she
      // never opens a food to fix one.
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('changing a size changes what is written', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(
          _typeIt(text: 'koshari and 2 eggs', repository: repository, bus: bus),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump(const Duration(seconds: 6));

      final added = repository.writes.single.added;
      final koshari = added.firstWhere((i) => i.foodId == 'koshari_bowl');
      expect(
        koshari.size,
        'L',
        reason: 'the chip is what she tapped, so it is what must be logged',
      );
      expect(koshari.kcal, 700);

      bus.dispose();
    });

    testWidgets('resolves with no network — one write, two items', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();
      final handles = <LogHandle>[];

      await tester.pumpWidget(
        _host(
          _typeIt(
            text: 'koshari and 2 eggs',
            repository: repository,
            bus: bus,
            onLogged: handles.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump();

      expect(handles, hasLength(1));
      expect(repository.writes, isEmpty, reason: 'inside the undo window');

      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes, hasLength(1));
      expect(repository.writes.single.added, hasLength(2));
      expect(repository.writes.single.kcalDelta, 696);

      bus.dispose();
    });

    testWidgets('an empty box cannot be logged', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();

      await tester.pumpWidget(_host(_typeIt(repository: repository)));
      await tester.pumpAndSettle();

      expect(find.text("We'll add"), findsNothing);
      await tester.tap(find.text('Add it'));
      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes, isEmpty);
    });
  });

  group('rule 10 — an unmatched fragment is a chip, never a guess', () {
    testWidgets('it stays visible beside what did resolve', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_typeIt(text: 'koshari and something I made up')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koshari bowl'), findsOneWidget);
      expect(find.text('something I made up'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('and the rest is still loggable', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(
          _typeIt(
            text: 'koshari and something I made up',
            repository: repository,
            bus: bus,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes.single.added, hasLength(1));
      expect(repository.writes.single.added.single.foodId, 'koshari_bowl');

      bus.dispose();
    });
  });

  group('P1-RULE-09 — no confirmation on this path either', () {
    testWidgets('logging raises no dialog', (tester) async {
      _phone(tester);
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(_typeIt(text: 'koshari and 2 eggs', bus: bus)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Undo'), findsOneWidget);

      bus.dispose();
    });
  });

  group('P0-A11Y-01', () {
    testWidgets('reads in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_typeIt(text: 'كشري'), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة سريعة'), findsNothing);
      expect(find.text('طبق كشري'), findsOneWidget);
    });

    testWidgets('does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _typeIt(text: 'koshari and 2 eggs'),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
