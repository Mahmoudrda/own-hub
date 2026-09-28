// The three new screens, in both languages and at the largest text size.
//
// The question these are really asking is whether a woman can tell, at a
// glance, whose words she is reading. Rahma's are on pink paper in her ink. The
// app's are Modern Standard, printed, on the app's own ground. Where that
// distinction is asserted below it is asserted by colour and by widget type
// rather than by eye, because "warmth and warning must not look the same" is a
// rule and not a preference.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/presentation/allergy_question_view.dart';
import 'package:own_hub/features/eat/presentation/rahma_letter_view.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/theme/recipe_book_tokens.dart';
import 'package:own_hub/ui/hand/hand.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

/// One of her cards, with everything a card can carry: two allergens, an
/// advisory, a doneness target, an optional ingredient and a brand aside.
Recipe _kebda({String? reviewedBy}) => Recipe(
  recipeId: 'rahma_kebda_meal',
  source: RecipeSource.book,
  sectionId: 'lunchy_junky_yum',
  orderInSection: 12,
  status: RecipeStatus.review,
  version: 1,
  titleEn: 'Kebda Meal',
  titleSearch: const ['kebda meal'],
  bodyAr: 'هنجيب نص كيلو كبدة فراخ\nونسيبها نص ساعه',
  ingredients: const [
    RecipeIngredient(
      ingredientRef: 'k1',
      qtyTextAr: 'نص كيلو كبدة فراخ',
      gramsBasis: GramsBasis.stated,
      grams: 500,
    ),
    RecipeIngredient(
      ingredientRef: 'k2',
      qtyTextAr: 'كيس مرقة خضار كنور الفورية',
      gramsBasis: GramsBasis.unknown,
      brandHint: 'كنور',
    ),
  ],
  steps: const [
    RecipeStep(
      index: 1,
      textAr: 'هنجيب نص كيلو كبدة فراخ',
      usesRefs: ['k1'],
    ),
    RecipeStep(
      index: 2,
      textAr: 'ونسيبها نص ساعه',
      usesRefs: [],
      minutes: 30,
      tempC: 200,
      tool: 'pan',
      isTimer: true,
    ),
  ],
  variants: const [],
  components: const [],
  totalMinutes: 50,
  macroBasis: MacroBasis.withheld,
  allergensDerived: const {'milk', 'sesame'},
  allergensExtra: const {},
  allergensRemoved: const {},
  allergensFinal: const {'milk', 'sesame'},
  advisories: const {'pregnancy_liver'},
  dietTags: const {'high_protein'},
  doneness: 'liver_cooked_through',
  sourcePage: 18,
  authoredBy: 'rahma_mohsen',
  allergenReviewedBy: reviewedBy,
  markKey: 'pan',
  tier: RecipeTier.free,
  brandHints: const {},
);

RecipeBook _book({String? reviewedBy}) => RecipeBook(
  schemaVersion: 1,
  contentVersion: 1,
  sections: const [
    RecipeSection(
      sectionId: 'lunchy_junky_yum',
      titleEn: 'Lunchy junky yum',
      psLineEn: 'WOW I am eating junky healthy food',
      order: 3,
      markKey: 'pot',
    ),
  ],
  recipes: [_kebda(reviewedBy: reviewedBy)],
  assemblies: const [],
  letterAr: 'ليه بنحاول ناكل صحي؟',
);

void main() {
  group('E10 — the one question', () {
    testWidgets('sixteen chips, and an explicit no', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          AllergyQuestionView(
            initial: DietaryProfile.unasked,
            onAnswered: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Is there anything you cannot eat?'), findsOneWidget);
      expect(find.text('Sesame'), findsOneWidget);
      expect(find.text('Fava beans'), findsOneWidget);
      expect(find.text('No, nothing'), findsOneWidget);
    });

    testWidgets('"no, nothing" is an answer, not a skip', (tester) async {
      // The whole reason this screen exists. An empty set written *by her* is
      // `DietaryProfile.noneNamed`, which is the one value the guard is
      // entitled to read as "asked, and named nothing".
      _phone(tester);
      Set<AllergenTag>? saved;
      await tester.pumpWidget(
        _host(
          AllergyQuestionView(
            initial: DietaryProfile.unasked,
            onAnswered: (allergies, _) => saved = allergies,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No, nothing'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: 'she answered');
      expect(saved, isEmpty);
      expect(
        DietaryProfile(allergies: saved).asked,
        isTrue,
        reason: 'an empty set she chose is an answer',
      );
    });

    testWidgets('a declaration comes back as a real constraint', (
      tester,
    ) async {
      _phone(tester);
      Set<AllergenTag>? saved;
      await tester.pumpWidget(
        _host(
          AllergyQuestionView(
            initial: DietaryProfile.unasked,
            onAnswered: (allergies, _) => saved = allergies,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sesame'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save what I avoid'));
      await tester.pumpAndSettle();

      expect(saved, {AllergenTag.sesame});
      expect(
        DietaryProfile(allergies: saved).toConstraints().allergies,
        {'sesame'},
      );
    });

    testWidgets('it is a screen, never a dialog', (tester) async {
      // `product_rules_test.dart` bans `showDialog` under `lib/features/`, and
      // the ban is right: a dialog is a thing you dismiss and this is a thing
      // you answer.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          AllergyQuestionView(
            initial: DietaryProfile.unasked,
            onAnswered: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('reads in Arabic at 1.6 without overflowing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          AllergyQuestionView(
            initial: DietaryProfile.unasked,
            onAnswered: (_, _) {},
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('السمسم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E05 — the book', () {
    testWidgets('nothing of hers is shown until she has been asked', (
      tester,
    ) async {
      // The ordering the whole feature turns on.
      _phone(tester);
      await tester.pumpWidget(
        _host(RecipesView(book: _book(), asked: false, onSelectTab: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text("Rahma's recipes"), findsOneWidget);
      expect(find.text('Is there anything you cannot eat?'), findsOneWidget);
      expect(find.text('Kebda Meal'), findsNothing);
    });

    testWidgets('once she has answered, her cards are drawn', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kebda Meal'), findsOneWidget);
      expect(find.text('Lunchy junky yum'), findsOneWidget);
      expect(
        find.text('WOW I am eating junky healthy food'),
        findsOneWidget,
        reason: 'her PS line, verbatim, missing PS prefix and all',
      );
      expect(find.byType(BookCard), findsWidgets);
    });

    testWidgets('a conflicting dish is absent, and the absence is stated', (
      tester,
    ) async {
      // Hiding silently is worse than hiding visibly: she has no way to tell a
      // filter from a fault.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(reviewedBy: 'qa_reviewer'),
            asked: true,
            constraints: const DietaryConstraints(
              allergies: {'sesame'},
              dietary: <String>{},
            ),
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kebda Meal'), findsNothing);
      expect(
        find.text('1 dishes are hidden because of what you avoid.'),
        findsOneWidget,
      );
    });

    testWidgets('an unsigned recipe never reaches a woman with an allergy', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: const DietaryConstraints(
              allergies: {'peanuts'},
              dietary: <String>{},
            ),
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kebda Meal'), findsNothing);
    });

    testWidgets('search narrows her titles, locally', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kebda');
      await tester.pumpAndSettle();
      expect(find.text('Kebda Meal'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'pizza');
      await tester.pumpAndSettle();
      expect(find.text('Kebda Meal'), findsNothing);
      expect(find.text('Nothing matches that.'), findsOneWidget);
    });

    testWidgets('the prototype rows still carry their cost in EGP', (
      tester,
    ) async {
      // The design note this screen has always had to keep. Rahma's cards being
      // added below must not have taken it away.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('22 min · 540 kcal · 18 g protein · 14 EGP'),
        findsOneWidget,
      );
    });

    testWidgets('reads in Arabic at 1.6 without overflowing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('وصفات رحمة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E06 — one of her cards', () {
    testWidgets('her steps are hers, and the chips are the app\'s', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();

      expect(find.text('Kebda Meal'), findsOneWidget);
      expect(find.text('هنجيب نص كيلو كبدة فراخ'), findsWidgets);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('200 degrees'), findsOneWidget);
      expect(find.text('500 g'), findsOneWidget);
    });

    testWidgets('the second tab is the page, unsplit', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('As it is in the book'));
      await tester.pumpAndSettle();
      expect(
        find.text('هنجيب نص كيلو كبدة فراخ\nونسيبها نص ساعه'),
        findsOneWidget,
      );
    });

    testWidgets('it states contents and never says the word safe', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(RahmaRecipeView(recipe: _kebda(reviewedBy: 'qa_reviewer'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contains'), findsOneWidget);
      expect(find.text('Sesame'), findsOneWidget);
      expect(find.text('Milk and dairy'), findsOneWidget);
      expect(find.textContaining('safe'), findsNothing);
      expect(
        find.text(
          "The ingredients are Rahma's. Read the label on each product "
          'yourself before use.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unsigned card says so, in the app\'s own voice', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nobody has signed off what is in this dish. Read the label on each '
          'product yourself.',
        ),
        findsWidgets,
      );
      expect(find.text('Contains'), findsOneWidget);
    });

    testWidgets('the advisory and the doneness note are Modern Standard', (
      tester,
    ) async {
      // Both are tokens on the recipe and sentences in the dictionary, which is
      // what keeps a safety line out of Rahma's mouth.
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Liver is very high in vitamin A. If you are pregnant, ask your '
          'doctor before eating it.',
        ),
        findsOneWidget,
      );
      expect(find.text('How to tell it is done'), findsOneWidget);
    });

    testWidgets('warning is not drawn like warmth', (tester) async {
      // Her card is `BookInk.paper`. The safety note is the app's own surface in
      // printed ink. Asserted by colour, because "they look different" is not
      // something a comment can hold.
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();

      final surfaces = tester
          .widgetList<HandSurface>(find.byType(HandSurface))
          .toList();
      expect(
        surfaces.any((s) => s.fill == BookInk.paper),
        isTrue,
        reason: 'her card is on her paper',
      );
      expect(
        surfaces.any(
          (s) => s.fill == AppColors.surface && s.level == HandLevel.structural,
        ),
        isTrue,
        reason: 'the safety note is square, structural and on the app ground',
      );
    });

    testWidgets('cook mode shows one step at a time', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cook mode'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('ونسيبها نص ساعه'), findsNothing);

      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('ونسيبها نص ساعه'), findsWidgets);
    });

    testWidgets('it is not a route away from anything, and holds no dialog', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: _kebda())));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('reads in Arabic at 1.6 without overflowing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RahmaRecipeView(recipe: _kebda()),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('المكوّنات والخطوات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the drawing follows the reading direction, with no branch', (
      tester,
    ) async {
      // The book puts the illustration top-RIGHT because the book is Arabic. A
      // fixed corner would put it top-right in English too, where it collides
      // with a left-aligned title. One widget, laid out by the text direction.
      _phone(tester);

      await tester.pumpWidget(
        _host(RahmaRecipeView(recipe: _kebda()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      final inArabic = tester.getCenter(find.byType(FoodMark).first);
      final cardInArabic = tester.getCenter(find.byType(BookCard).first);
      expect(
        inArabic.dx,
        greaterThan(cardInArabic.dx),
        reason: 'top right in Arabic, as the page prints it',
      );

      await tester.pumpWidget(
        _host(RahmaRecipeView(recipe: _kebda()), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      final inEnglish = tester.getCenter(find.byType(FoodMark).first);
      final cardInEnglish = tester.getCenter(find.byType(BookCard).first);
      expect(
        inEnglish.dx,
        lessThan(cardInEnglish.dx),
        reason: 'top left in English, because that is where reading starts',
      );
    });

    testWidgets('her English title is kept in reading order', (tester) async {
      // `Fool & Ta3mya` reorders around the ampersand inside an Arabic
      // paragraph and comes out as `Ta3mya & Fool`.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RahmaRecipeView(recipe: _kebda()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(BookTitle),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(title.textDirection, TextDirection.ltr);
    });
  });

  group('E11 — her letter', () {
    testWidgets('her words, and nothing else', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const RahmaLetterView(letterAr: 'ليه بنحاول ناكل صحي؟')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ليه بنحاول ناكل صحي؟'), findsOneWidget);
      // No call to action underneath a letter. An advert wearing a letter's
      // clothes is a thing a woman can tell.
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('reads in Arabic at 1.6 without overflowing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const RahmaLetterView(letterAr: 'ليه بنحاول ناكل صحي؟'),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
