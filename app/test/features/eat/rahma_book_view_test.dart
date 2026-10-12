// The three new screens, in both languages and at the largest text size.
//
// The question these are really asking is whether a woman can tell, at a
// glance, whose words she is reading. Rahma's are on pink paper in her ink. The
// app's are in the app's voice, printed, on the app's own ground. Where that
// distinction is asserted below it is asserted by colour and by widget type
// rather than by eye, because "warmth and warning must not look the same" is a
// rule and not a preference.

import 'dart:convert';
import 'dart:io';

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
import 'package:own_hub/ui/app_button.dart';
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
  ingredientsBasis: IngredientsBasis.measures,
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

/// Thirty-nine of her cards, which is what the book actually holds.
///
/// The count is the point: Arabic agreement changes at 3 and again at 11, so a
/// one-recipe fixture cannot show whether the sentence is grammatical for the
/// number a woman actually sees.
RecipeBook _bigBook() {
  final one = _book();
  return RecipeBook(
    schemaVersion: one.schemaVersion,
    contentVersion: one.contentVersion,
    sections: one.sections,
    recipes: [
      for (var i = 0; i < 39; i++)
        Recipe(
          recipeId: 'rahma_$i',
          source: RecipeSource.book,
          sectionId: 'lunchy_junky_yum',
          orderInSection: i,
          status: RecipeStatus.review,
          version: 1,
          titleEn: 'Dish $i',
          titleSearch: ['dish $i'],
          bodyAr: 'خطوة',
          ingredients: const [],
          ingredientsBasis: IngredientsBasis.measures,
          steps: const [RecipeStep(index: 1, textAr: 'خطوة', usesRefs: [])],
          variants: const [],
          components: const [],
          macroBasis: MacroBasis.withheld,
          allergensDerived: const {},
          allergensExtra: const {},
          allergensRemoved: const {},
          allergensFinal: const {},
          advisories: const {},
          dietTags: const {},
          authoredBy: 'rahma_mohsen',
          tier: RecipeTier.free,
          brandHints: const {},
        ),
    ],
    assemblies: const [],
    letterAr: one.letterAr,
  );
}

/// The shipped seed, read off disk.
///
/// Every fixture above is hand-built and none of them carries a component, so
/// nothing in this file exercised the code path that draws one. That is how
/// `Fattah` came to print twenty-two steps for eleven and nobody noticed.
RecipeBook _shipped() => RecipeBook.fromJson(
  (jsonDecode(
    File('assets/content/rahma_recipes.json').readAsStringSync(),
  ) as Map).cast<String, Object?>(),
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

    testWidgets('the live control on arrival is the commonest answer', (
      tester,
    ) async {
      // It opened with a **disabled** filled "Save what I avoid" and put the
      // only live control, outlined, underneath it. So the answer most women
      // give was drawn as the lesser one, below a dead button.
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

      expect(
        find.text('Save what I avoid'),
        findsNothing,
        reason: 'nothing to save yet, so nothing is drawn dead',
      );
      final buttons = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      expect(buttons, hasLength(1));
      expect(buttons.single.label, 'No, nothing');
      expect(buttons.single.variant, AppButtonVariant.filled);
      expect(buttons.single.onPressed, isNotNull);
    });

    testWidgets('ticking something promotes the save button', (tester) async {
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
      await tester.tap(find.text('Sesame'));
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      expect(buttons.map((b) => b.label).toList(), [
        'Save what I avoid',
        'No, nothing',
      ]);
      expect(buttons.first.variant, AppButtonVariant.filled);
      expect(buttons.first.onPressed, isNotNull);
      expect(buttons.last.variant, AppButtonVariant.outlined);
    });

    testWidgets('"no, nothing" cannot silently throw away an allergy', (
      tester,
    ) async {
      // Both buttons stayed enabled after she ticked sesame, so one tap on the
      // outlined one saved an empty allergy list with no word said. A sheet,
      // not a dialog: `product_rules_test.dart` bans `showDialog` on these
      // paths and the ban is right.
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
      await tester.tap(find.text('No, nothing'));
      await tester.pumpAndSettle();

      expect(saved, isNull, reason: 'it asked first');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Discard what you ticked?'), findsOneWidget);

      await tester.tap(find.text('Keep what I ticked'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Sesame'), findsOneWidget, reason: 'still ticked');

      await tester.tap(find.text('No, nothing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, save nothing'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty, reason: 'she said so twice');
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
        find.text('1 dish is hidden because it contains something you avoid.'),
        findsOneWidget,
      );
      // And the other reason is NOT stated, because it is not the reason. The
      // card is signed; sesame is genuinely in it.
      expect(
        find.textContaining('nobody has checked'),
        findsNothing,
        reason: 'this one really is about what she avoids',
      );
    });

    testWidgets('an unchecked book is not blamed on her body', (tester) async {
      // **The ship-blocker this group exists for.** Every one of the
      // thirty-nine recipes is unsigned, and the guard fails closed on an
      // unsigned recipe for any woman who has declared an allergy. So
      // declaring molluscs, which appear in none of them, emptied the whole
      // book and the screen said "39 dishes are hidden because of what you
      // avoid." Nothing she avoids was in any of them. The app took its own
      // caution and told her it came out of her body.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _book(),
            asked: true,
            constraints: const DietaryConstraints(
              allergies: {'molluscs'},
              dietary: <String>{},
            ),
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kebda Meal'), findsNothing);
      expect(
        find.text(
          '1 dish is hidden because nobody has checked what is in it yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('1 dish is hidden because it contains something you avoid.'),
        findsNothing,
        reason: 'molluscs are in none of them',
      );
      expect(
        find.textContaining('This is not about what you avoid'),
        findsOneWidget,
        reason: 'the empty state names the real reason and denies the false one',
      );
      expect(find.text('Nothing matches that.'), findsNothing);
      expect(
        find.text(
          'Nothing in the book has been checked yet. Tell us about an allergy '
          'and the book waits until somebody has.',
        ),
        findsNothing,
        reason: 'the head note caveats cards she can see, and there are none',
      );
    });

    testWidgets('the Arabic count agrees with the noun it counts', (
      tester,
    ) async {
      // `39 أطباق` is ungrammatical: an Arabic count between 11 and 99 takes
      // the singular in the accusative, so it is `39 طبقًا`. The dictionary
      // carries the whole plural message and gen_l10n picks the form, which is
      // why this is correct for every count rather than for the one somebody
      // happened to look at.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: _bigBook(),
            asked: true,
            constraints: const DietaryConstraints(
              allergies: {'molluscs'},
              dietary: <String>{},
            ),
            onSelectTab: (_) {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('39 طبق'), findsOneWidget);
      expect(find.textContaining('39 أطباق'), findsNothing);
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

    testWidgets('a dead chip says why it is empty', (tester) async {
      // "Cheap" selects nothing because nobody has priced a recipe, and "No
      // nuts" selects nothing because it fails closed on `allergensReviewed`
      // and nothing is signed. Both fell through to "Nothing matches that.",
      // which reads as a fault in the app rather than as an absence in the
      // content. Ramadan already had its own honest line; these two now do too.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            // Unsigned, which is what the shipped book is: "No nuts" fails
            // closed on `allergensReviewed`, so it can only ever select
            // nothing until somebody signs a card.
            book: _book(),
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cheap'));
      await tester.pumpAndSettle();
      expect(find.text('No recipe has been priced yet.'), findsOneWidget);
      expect(find.text('Nothing matches that.'), findsNothing);
      await tester.tap(find.text('Cheap'));
      await tester.pumpAndSettle();

      // Scrolled to first: the book's own chips sit below the fold on a phone,
      // and a tap on a built-but-offscreen widget is a warning rather than a
      // failure, so the assertion after it would pass for the wrong reason.
      await tester.ensureVisible(find.text('No nuts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No nuts'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No recipe can be called nut free yet, because nobody has signed '
          'off what is in them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nothing matches that.'), findsNothing);
    });

    testWidgets('a card draws the hands-on time, not the night in the fridge', (
      tester,
    ) async {
      _phone(tester);
      final book = _shipped();
      await tester.pumpWidget(
        _host(
          RecipesView(
            book: book,
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1,445'), findsNothing);
      expect(find.text('5 min hands on'), findsWidgets);
    });

    testWidgets('a five-minute breakfast is in the quick filter', (
      tester,
    ) async {
      // "Under 20 min" read `totalMinutes`, which counts a night in the fridge,
      // so overnight oats was excluded at 1,445 and so were chia pudding, ice
      // cream and banana pudding.
      final oats = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_overnight_oats',
      );
      expect(
        recipeMatchesFilter(oats, RecipeFilter.underTwentyMinutes),
        isTrue,
      );
      // And a row that states neither time still never matches a filter.
      final silent = _shipped().recipes.firstWhere(
        (r) => r.activeMinutes == null && r.totalMinutes == null,
        orElse: () => oats,
      );
      if (silent.activeMinutes == null && silent.totalMinutes == null) {
        expect(
          recipeMatchesFilter(silent, RecipeFilter.underTwentyMinutes),
          isFalse,
        );
      }
    });

    testWidgets('the unsigned marker is one line, and the book says why', (
      tester,
    ) async {
      // Name, then "N min", then a three-line disclaimer, thirty-nine times
      // over, is wallpaper by the third card - and it never mentioned the thing
      // that actually bites, which is that the whole book vanishes the moment
      // she declares an allergy. The long sentence is still on E06 beside the
      // contents list. The consequence is said once, at the head of the book.
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

      expect(find.text('Not checked yet'), findsOneWidget);
      expect(
        find.text(
          'Nobody has signed off what is in this dish. Read the label on each '
          'product yourself.',
        ),
        findsNothing,
        reason: 'the long form belongs on the card she opens, not on the list',
      );
      expect(
        find.text(
          'Nothing in the book has been checked yet. Tell us about an allergy '
          'and the book waits until somebody has.',
        ),
        findsOneWidget,
      );
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

    testWidgets('the advisory and the doneness note are in the app\'s voice', (
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

    testWidgets('a card with components prints each step once', (tester) async {
      // **The shipped seed, not a fixture.** Every other recipe in this file is
      // hand-built with no components, so none of them touched the path where
      // `allSteps` (own steps plus every component's) was drawn flat and then
      // each component was drawn again under its heading. `Fattah` keeps all
      // eleven of its steps in components, so it read as twenty-two; Makrona
      // Bashmel eleven for six, Kebda Meal nine for six, Crepe eight for five.
      //
      // The crawler and the large-text sweep both open E06 with
      // `openRecipeId == null`, which lands on the prototype screen, so they
      // could not have caught it either.
      _phone(tester);
      final fattah = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_fattah',
      );
      expect(
        fattah.components,
        isNotEmpty,
        reason: 'this test is pointless on a recipe with no components',
      );
      expect(fattah.allSteps, hasLength(11));

      await tester.pumpWidget(_host(RahmaRecipeView(recipe: fattah)));
      await tester.pumpAndSettle();

      final drawn = <String>[];
      for (final step in fattah.allSteps) {
        drawn.add(step.textAr);
        expect(
          find.text(step.textAr),
          findsOneWidget,
          reason: 'drawn twice: ${step.textAr}',
        );
      }
      expect(
        drawn.toSet(),
        hasLength(drawn.length),
        reason: 'the seed itself must not repeat a step',
      );
      // Her component headings are still there, which is the reason the flat
      // list cannot simply include the component steps as well.
      for (final component in fattah.components) {
        expect(find.text(component.headingAr), findsOneWidget);
      }
    });

    testWidgets('cook mode walks a component card end to end', (tester) async {
      // The other side of the fix. `Fattah` has no flat steps at all, so
      // narrowing the printed list to `recipe.steps` must not narrow cook mode
      // with it, or the woman following the dish would be shown nothing.
      _phone(tester);
      final fattah = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_fattah',
      );
      expect(fattah.steps, isEmpty);

      await tester.pumpWidget(_host(RahmaRecipeView(recipe: fattah)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cook mode'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 11'), findsOneWidget);
    });

    testWidgets('a card the book gives no ingredient list for says so', (
      tester,
    ) async {
      // `Lahma bel basl` is twelve numbered steps and nothing else. Eight bare
      // nouns lifted out of the method - "the meat", "the oil", "the onion" -
      // were printed under an Ingredients heading.
      _phone(tester);
      final lahma = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_lahma_bel_basl',
      );
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: lahma)));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients'), findsNothing);
      expect(
        find.text(
          'The book writes this one as a method, with no ingredient list. '
          'What goes in is named in the steps.',
        ),
        findsOneWidget,
      );
      expect(find.text('اللحمة'), findsNothing);
    });

    testWidgets('a card with few amounts keeps its rows and says so', (
      tester,
    ) async {
      _phone(tester);
      final hwawshi = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_hwawshi',
      );
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: hwawshi)));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients'), findsOneWidget);
      expect(
        find.text('The book names what goes in, and mostly not how much.'),
        findsOneWidget,
      );
    });

    testWidgets('an ingredient that wraps in the book is one row here', (
      tester,
    ) async {
      _phone(tester);
      final lazyCake = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_lazy_cake',
      );
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: lazyCake)));
      await tester.pumpAndSettle();

      expect(find.text('نص معلقه baking powder'), findsOneWidget);
      expect(
        find.text('baking powder'),
        findsNothing,
        reason: 'a row naming a product with no amount is not a shopping line',
      );
    });

    testWidgets('her sign-off is drawn once, on the one card that has it', (
      tester,
    ) async {
      // `Club Sandwich` is the only card where `والف هنا` is both the tail of
      // `bodyAr` and the whole of `closingAr`, which reads at first glance like
      // a card that will print it twice. It does not: `closing` is an index,
      // the flat step list stops at it, and the hand note carries it instead.
      //
      // It is also the only one of the fourteen cards ending in her sign-off
      // where the book gives it a line of its own, which is why it is the only
      // one with a `closingAr` at all.
      _phone(tester);
      final club = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_club_sandwich',
      );
      expect(club.closingAr, 'والف هنا');
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: club)));
      await tester.pumpAndSettle();
      expect(find.text('والف هنا'), findsOneWidget);
      for (final step in club.allSteps) {
        expect(step.textAr, isNot(contains('والف هنا')));
      }
    });

    testWidgets('both times are drawn, and labelled', (tester) async {
      // Overnight oats is five minutes of work and a day in the fridge. The
      // facts line drew the total and only the total, so it said "1,445 min".
      _phone(tester);
      final oats = _shipped().recipes.firstWhere(
        (r) => r.recipeId == 'rahma_overnight_oats',
      );
      expect(oats.activeMinutes, 5);
      expect(oats.totalMinutes, 1445);

      await tester.pumpWidget(_host(RahmaRecipeView(recipe: oats)));
      await tester.pumpAndSettle();

      expect(find.text('5 min hands on'), findsOneWidget);
      expect(find.text('About 24 hours in all'), findsOneWidget);
      expect(find.textContaining('1,445'), findsNothing);
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
