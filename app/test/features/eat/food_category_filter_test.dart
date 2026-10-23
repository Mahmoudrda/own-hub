// The food shelves: one tap narrows E02's list and E01's quick strip to a
// category, and what she types searches inside the shelf.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/eat/presentation/type_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 10, 17, 13, 12);

Food _food(String id, String name, FoodCategory? category) => Food(
  foodId: id,
  names: [name],
  category: category,
  allergens: const <String>{},
  popularity: 50,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 100, proteinG: 5)],
);

final FoodLibrary _library = FoodLibrary([
  _food('ful', 'Ful medames', FoodCategory.egyptianDishes),
  _food('tuna', 'Canned tuna', FoodCategory.proteins),
  _food('turkey', 'Smoked turkey', FoodCategory.proteins),
  _food('apple', 'Apple', FoodCategory.fruitsAndNuts),
  _food('mystery', 'Mystery plate', null),
]);

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

Future<void> _chip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

TypeItView _typeIt() => TypeItView(
  constraints: DietaryConstraints.none,
  library: _library,
  repository: InMemoryMealRepository(),
  now: _lunchtime,
  onClose: () {},
);

EatView _eat() => EatView(
  constraints: DietaryConstraints.none,
  library: _library,
  repository: InMemoryMealRepository(),
  now: _lunchtime,
  onType: () {},
  onSelectTab: (_) {},
);

void main() {
  group('E02 — Type it', () {
    testWidgets('All and the seven shelves are chips', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt()));
      await tester.pumpAndSettle();

      for (final label in const [
        'All',
        'Egyptian dishes',
        'Proteins',
        'Dairy and cheese',
        'Grains and breads',
        'Vegetables and salads',
        'Fruits and nuts',
        'Snacks and drinks',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('one tap on a shelf lists only its foods', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt()));
      await tester.pumpAndSettle();

      await _chip(tester, 'Proteins');

      expect(find.byKey(const ValueKey('result-tuna')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-turkey')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-apple')), findsNothing);
      expect(find.byKey(const ValueKey('result-ful')), findsNothing);
      expect(find.byKey(const ValueKey('result-mystery')), findsNothing);
    });

    testWidgets('All lists everything again', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt()));
      await tester.pumpAndSettle();

      await _chip(tester, 'Proteins');
      await _chip(tester, 'All');

      expect(find.byKey(const ValueKey('result-apple')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-tuna')), findsOneWidget);
    });

    testWidgets('typing searches inside the shelf', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt()));
      await tester.pumpAndSettle();

      await _chip(tester, 'Proteins');
      await tester.enterText(find.byType(TextField), 'tu');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('result-tuna')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-turkey')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tuna');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('result-tuna')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-turkey')), findsNothing);

      // The same word on another shelf finds nothing: the chip still holds.
      await _chip(tester, 'Fruits and nuts');
      expect(find.byKey(const ValueKey('result-tuna')), findsNothing);
    });

    testWidgets('the shelves read in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_typeIt(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('أكلات مصرية'), findsOneWidget);
      expect(find.text('بروتينات'), findsOneWidget);
      expect(find.text('سناكس ومشروبات'), findsOneWidget);
    });
  });

  group('E01 — Eat', () {
    testWidgets('a shelf fills the quick strip with its foods', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_eat()));
      await tester.pumpAndSettle();

      await _chip(tester, 'Fruits and nuts');
      expect(find.byKey(const ValueKey('quick-add-apple')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-add-tuna')), findsNothing);
      expect(find.byKey(const ValueKey('quick-add-mystery')), findsNothing);

      await _chip(tester, 'Proteins');

      expect(find.byKey(const ValueKey('quick-add-tuna')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-add-turkey')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-add-apple')), findsNothing);
      expect(find.byKey(const ValueKey('quick-add-mystery')), findsNothing);

      await _chip(tester, 'All');
      expect(find.byKey(const ValueKey('quick-add-mystery')), findsOneWidget);
    });
  });
}
