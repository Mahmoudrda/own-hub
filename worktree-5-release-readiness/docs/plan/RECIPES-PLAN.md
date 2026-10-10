# Rahma's recipe book in Own Hub

A plan for bringing `Rahoma's Recipe Book.pdf` into the app, growing it into a
library, and restyling the Eat surface to look like the book.

Written to be implemented by one agent and tested by another. Everything here is
checked against the code as it stands on `worktree-release-readiness`
(`6791719`). Where I could not check something, I say so.

`docs/` is gitignored (`.gitignore:39-44`). This file stays local and never
ships.

---

## 0. The short version

The book is **39 recipes**, not 28 to 35. Four sections. Egyptian colloquial
Arabic, English titles, one illustration per card.

Three things in the owner's brief are wrong as stated and I am recommending
against them:

1. **200+ recipes.** 161 of those would be invented. This repo has a standing
   rule against exactly that, written down in five places, and the reasoning
   applies to food. See §3.5. I propose a different shape that gets the number
   honestly.
2. **"Use the same design as the PDF."** The PDF's section-title rose
   (`#D3737E`) is **2.51:1** against its own paper. That fails WCAG AA at any
   size. Everything else in the book's palette is excellent, better than the
   app's current rose. See §3.7.
3. **"Free 50, Pro 200+."** `Feature.payments` is `false`, its parent
   `Feature.marketplace` is `false`, `PaymentProvider` has only
   `UnavailablePaymentProvider`, and `CheckoutOutcome` has no `paid` variant.
   A paywall shipped now is a lie. See §3.6 for what to build instead.

And one thing nobody asked about that blocks the whole feature:

4. **`app/test/features/eat/allergy_interlock_test.dart:41` goes red the moment
   a recipe carrying allergen data ships.** Not as a nuisance: it is correct,
   and it is protecting a woman with a nut allergy from a guard that looks live
   and is not. Nothing in §5 can merge until §3.4's capture surface lands.
   This is the critical path.

---

## 1. The exact inventory

Source: `/Users/mahmoudreda/Downloads/Rahoma's Recipe Book.pdf`, 26 pages,
1057.5 x 1687.5 pt, produced in Canva, author metadata `Rahma Mohssen1234`,
created 23 September 2026.

Page layout: 1 cover, 4 full-page section dividers, 20 recipe pages (two cards
per page, except p26 which is one card plus the closing letter), and one
duplicated spread.

**Pages 20 and 21 are the same two recipes.** Identical text. The only
difference is that `Btates bel lahma`'s illustration sits top-right on p20 and
centred above the title on p21. It is a production error in the book. So the
book prints 41 cards and contains **39 recipes**.

### 1.1 Sections

| # | English title (verbatim) | PS line (verbatim) | Divider page | Recipes |
|---|---|---|---|---|
| 1 | Sweet Tooth Breakfast | `PS: You may need it on your period girl i got you :)` | 2 | 6 |
| 2 | Salty fulling Breakfast | `PS: I am keeping you full until lunch dear` | 6 | 10 |
| 3 | Lunchy junky yum | `WOW I am eating junky healthy food` | 12 | 16 |
| 4 | Comfy Dinner | `Eating light to sleep comfy girlie` | 22 | 7 |

The brief called section 4 "Dinner". The page says **Comfy Dinner**. Section 2's
"fulling" is her spelling of "filling" and section 3's PS has no `PS:` prefix
where the other three do. **Keep all four exactly as printed.** They are hers.
They are not typos to fix; they are the voice the owner is paying for.

### 1.2 The 39 recipes

`id` is my proposal: `rahma_` prefix so a seeded recipe is never confused with
the nine existing `seed_library.dart` rows (`lentil_soup`, `koshari_home`, ...).
`Qty` says whether the card states usable quantities. `T/t` says whether it
states a temperature and a time.

#### Section 1 — Sweet Tooth Breakfast (p3-p5)

| # | id | Title (verbatim) | p | Qty | T/t | Allergens (provisional) |
|---|---|---|---|---|---|---|
| 1 | `rahma_lazy_cake` | Lazy Cake | 3 | household | 10 min oven / 2 min microwave, no temp | gluten, milk, eggs |
| 2 | `rahma_pancakes` | Pancakes | 3 | household | 2 min a side, low heat | gluten, milk, eggs |
| 3 | `rahma_chia_pudding` | Chia Pudding | 4 | household | 4 h fridge | milk |
| 4 | `rahma_coconut_apple_pudding` | Coconut apple Pudding | 4 | household | none | milk, gluten, coconut |
| 5 | `rahma_overnight_oats` | Overnight oats | 5 | **grams** | 1 day fridge | gluten, milk, tree_nuts |
| 6 | `rahma_simple_oat_meal` | Simple oat meal | 5 | **grams** | none | gluten, milk |

#### Section 2 — Salty fulling Breakfast (p7-p11)

| # | id | Title (verbatim) | p | Qty | T/t | Allergens (provisional) |
|---|---|---|---|---|---|---|
| 7 | `rahma_club_sandwich` | Club Sandwich | 7 | mixed (15 g cheese) | none | milk, **sesame**, gluten? |
| 8 | `rahma_yummy_egg_sandwich` | Yummy Egg Sandwich | 7 | household | none | eggs, gluten |
| 9 | `rahma_cottage_freshy_salad` | Cottage Freshy salad | 8 | **grams** | none | milk, gluten, **sesame** |
| 10 | `rahma_lazy_ranch_fries` | Lazy Ranch Fries | 8 | household | 20 min at 200 | milk, *see brands* |
| 11 | `rahma_creamy_cottage_cheese` | Creamy cottage cheese | 9 | household (¼ kg) | none | milk, **sesame**, gluten, eggs |
| 12 | `rahma_egg_pizza` | Egg Pizza | 9 | household | none | eggs, gluten, milk |
| 13 | `rahma_shakshoka` | Shakshoka | 10 | counts | none | eggs, gluten |
| 14 | `rahma_fool_wa_ta3mya` | Fool & Ta3mya | 10 | **grams** | none | **fava**, gluten, **sesame** |
| 15 | `rahma_potato_w_eggs` | Potato w Eggs | 11 | **grams** | none | eggs |
| 16 | `rahma_pizza_toast` | Pizza toast | 11 | **grams** | 5-7 min, no temp | gluten, milk, **sesame** |

#### Section 3 — Lunchy junky yum (p13-p21)

| # | id | Title (verbatim) | p | Qty | T/t | Allergens (provisional) |
|---|---|---|---|---|---|---|
| 17 | `rahma_chicken_pizza` | Chicken Pizza | 13 | counts | 15 min at 180 | gluten, milk, eggs, **sesame** |
| 18 | `rahma_bbq_burger` | BBQ Burger | 13 | household (15 g cheese) | 5 min a side | gluten, milk, soy?, *see brands* |
| 19 | `rahma_hwawshi` | Hwawshi | 14 | **none at all** | none | gluten |
| 20 | `rahma_chicken_lemon` | Chicken lemon | 14 | **none at all** | 200 C, 20 min + 5-10 | **sesame** |
| 21 | `rahma_chicken_ranch_salad` | Chicken Ranch Salad | 15 | counts | none | gluten, milk, eggs |
| 22 | `rahma_tuna_wrap` | Tuna Wrap | 15 | counts | none | **fish**, gluten |
| 23 | `rahma_shrimp_white_pasta` | Shrimp white sauce pasta | 16 | **grams** (50 g) | 20 min boil | **crustaceans**, gluten, milk, celery?, *see brands* |
| 24 | `rahma_steak_meal` | Steak Meal | 16 | **grams** (15 g butter) | none | milk |
| 25 | `rahma_oven_tender_chicken` | Oven Tender Chicken | 17 | counts + spoons | 220 C, 30-45 min a side | mustard?, celery? |
| 26 | `rahma_buffalo_sweet_wings` | Buffalo sweet Wings | 17 | 1 kg + spoons | 30 min a side + 10 grill | **mustard** |
| 27 | `rahma_makrona_bashmel` | Makrona Bashmel | 18 | mixed (20 g butter, ¼ kg) | 20 min at 200 | gluten, milk, celery?, *see brands* |
| 28 | `rahma_kebda_meal` | Kebda Meal | 18 | household (½ kg) | 30 min covered | **sesame**, gluten, milk, celery? |
| 29 | `rahma_fattah` | Fattah | 19 | **none at all** | 5 min sauce | gluten, milk |
| 30 | `rahma_lahma_bel_basl` | Lahma bel basl | 19 | **none at all** | 200 C, 25-35 min | none |
| 31 | `rahma_shorbet_3ads` | shorbt 3ads | 20 (dup 21) | **none at all** | 25-30 min simmer | milk, gluten, celery? |
| 32 | `rahma_btates_bel_lahma` | Btates bel lahma | 20 (dup 21) | 2 potatoes only | 200 C, 35-45 + 10 min | milk |

#### Section 4 — Comfy Dinner (p23-p26)

| # | id | Title (verbatim) | p | Qty | T/t | Allergens (provisional) |
|---|---|---|---|---|---|---|
| 33 | `rahma_cookies_shay_blabn` | Cookies with shay blabn | 23 | household | 10 min at 180 / 2 min microwave | **peanuts**, milk |
| 34 | `rahma_bagel` | Bagel | 23 | household (¼ kg) | 200 C, 15 min + 2 grill | gluten, milk, eggs, **sesame** |
| 35 | `rahma_crepe` | Crepe | 24 | household | 2 min a side | eggs, gluten, milk |
| 36 | `rahma_banana_pudding` | Banana pudding | 24 | household | 2 h fridge | gluten, milk |
| 37 | `rahma_cheese_cake` | Cheese cake | 25 | counts | 30 min freezer | milk, gluten, *see brands* |
| 38 | `rahma_french_toast` | French toast | 25 | household | 5 min a side | eggs, gluten, milk |
| 39 | `rahma_ice_cream` | Ice cream | 26 | counts | 3 h freezer | milk |

### 1.3 What the book contains besides recipes

- **Cover** (p1): "My recipe book / By : Rahma Mohsen", a chef's hat, bread,
  cupcake, whisk, rolling pin, over a pink ground with a white line-art pattern
  of kitchen tools and a spiral binding down the left edge.
- **The closing letter** (p26, under `Ice cream`): `A message to you :)` /
  `ليه بنحاول ناكل صحي؟` ... `With all my love / Rahma`. Roughly 120 words of
  Egyptian colloquial. **This is the single warmest thing in the source and it
  should have a screen.** See E11 in §4.

### 1.4 Components named inside a card, which are not recipes

These must be modelled as sub-blocks of their parent card, not as separate
library entries, or the count inflates dishonestly.

| Component | Lives inside | Arabic heading in the book |
|---|---|---|
| Chocolate sauce | `rahma_crepe` | `Chocolate sauce` |
| Light tahina | `rahma_kebda_meal` | `طحينه لايت:` |
| Healthy ranch sauce | `rahma_chicken_ranch_salad` | (inline, step 4) |
| Yogurt sauce, tomato sauce, assembly | `rahma_fattah` | `صوص الزبادي:` / `صوص الطماطم:` / `التجميع:` |
| Bechamel, mince | `rahma_makrona_bashmel` | `البشاميل:` / `اللحمه المفرومه :` |
| Caramelised onion | `rahma_bbq_burger`, `rahma_tuna_wrap` | (inline) |
| Method B | `rahma_cheese_cake` | `طريقتين واختاري منهم` |

`rahma_cheese_cake` is one card with **two complete alternative methods**. The
model must hold both (`variants[]`), not pick one.

### 1.5 Problems in the source that a human must resolve

Give this list to Rahma. It is not a criticism of the book; it is what changes
when a page becomes a screen a woman cooks from.

1. **Five recipes state no quantities at all.** `Hwawshi`, `Chicken lemon`,
   `Fattah`, `Lahma bel basl`, `shorbt 3ads`. `Chicken lemon` names a marinade
   of eight ingredients and gives no amount for any of them. `shorbt 3ads` has
   eight numbered steps and never says how much lentil. On paper you infer;
   on a phone at 7am you cannot.
2. **`Btates bel lahma` gives quantities for the potatoes only.** Onion, garlic,
   pepper, mince, spices and water are all unquantified.
3. **Five recipes give a time with no temperature.** `Lazy Cake` (10 min oven),
   `Pizza toast` (5-7 min), `BBQ Burger`, `Pancakes`, `Crepe`.
4. **Doneness is never stated for poultry, mince, liver or shrimp.** `Shakshoka`
   ends `سيبيه يستوي`. `Chicken Pizza` uses pre-made *panée*. For a general
   audience that is normal Egyptian cooking. For a shipped app with a duty of
   care it is not enough. See §3.4.
5. **Seven brand names.** `Breadway`, `Rich bake`, `الضحى` (Al Doha) potato
   spice and vegetable pasta, `كنور` (Knorr) stock cubes, `مكفيتيز` (McVitie's)
   digestives, `Stevia`, `Protein puffs`. Shipping these means (a) a recipe that
   breaks when a product is reformulated or leaves the market, (b) an
   unremunerated endorsement, (c) an allergen claim about someone else's
   product. **Recommendation:** keep the brand as a `brandHint` field displayed
   in her voice, and make the `foodId` point at the generic. "كيس مرقة خضار
   (رحمة بتستخدم كنور)" rather than a Knorr dependency.
6. **`Club Sandwich` never says bread.** The title implies it; the ingredient
   list does not. Ask her.
7. **`Kebda Meal` is chicken liver.** Liver is very high in preformed vitamin A
   and is contraindicated in pregnancy. This is a women's app. It needs a
   pregnancy note, not a removal.
8. **`Fool & Ta3mya` contains fava beans.** G6PD deficiency (favism) is common
   enough in Egypt that this is a real medical flag, not a theoretical one.
9. **Missing Arabic titles.** Every card's title is English or arabizi. There is
   no Arabic title anywhere in the book. Thirty-nine Arabic titles must be
   authored by Rahma; **I am not proposing to invent them.** Until they exist,
   the Arabic UI shows her English title as-is inside an LTR span, which is
   truthful and is what she herself did.

### 1.6 Illustrations

Confirmed by pixel comparison: **`app/assets/art/cupcake.webp` is byte-for-byte
the cupcake on the Sweet Tooth divider.** The book and the app already share the
same illustration pack. `pubspec.yaml:120` says the pack came from "the owner's
Icons.pdf".

The book uses 32 raster illustrations plus a handful of vector ones (pages 7,
13, 22 and 26 carry no raster image object at all). The app ships 57 at three
densities, 4.8 MB, of which roughly 28 are food.

Provisional mapping of recipe to an existing `AppArt` name, **to be confirmed
by eye, one by one, by a human** (§3.7 explains why this cannot be automated):

`rahma_lazy_cake`→`cake_slice`, `rahma_pancakes`→`pancakes`,
`rahma_yummy_egg_sandwich`→`toast_egg`, `rahma_lazy_ranch_fries`→`fries`,
`rahma_cottage_freshy_salad`→`salad_blue`, `rahma_chicken_ranch_salad`→`salad_wood`,
`rahma_tuna_wrap`→`wrap`, `rahma_shrimp_white_pasta`→`pasta`,
`rahma_makrona_bashmel`→`pasta`, `rahma_steak_meal`→`steak`,
`rahma_btates_bel_lahma`→`bowl_potato`, `rahma_fattah`→`plate_mixed`,
`rahma_oven_tender_chicken`→`platter_grill`, `rahma_cookies_shay_blabn`→`cookies`,
`rahma_cheese_cake`→`cake_slice`, `rahma_pizza_toast`→`bruschetta`.

That is **16 of 39**. The gap is **23 recipe illustrations plus 4 section
illustrations**. See §3.7 for what to do about it.

---

## 2. The data model

### 2.1 Where each thing lives, and why

| Thing | Home | Reason |
|---|---|---|
| Her recipe text (Arabic) | `assets/content/rahma_recipes.json` (seed) and Firestore `recipes/{id}` (live) | `app/test/i18n_guard_test.dart:78` forbids Arabic literals under `lib/**.dart` outside a three-entry allowlist, and line 108 refuses any `presentation/` path joining it. `seed_library.dart` works around this with `\u` escapes and its own header calls that "a workaround, not the right end state". A JSON asset is not scanned. **This is the right end state.** |
| UI chrome (buttons, labels, errors) | `app/lib/l10n/app_{en,ar}.arb` via `app/tool/add_strings.py` | The only sanctioned route. Key parity enforced at `i18n_guard_test.dart:180`. |
| Numbers rendered in prose | ARB, **parameterised** | `app/test/baked_in_samples_test.dart:57` pins a ceiling of 117 number-bearing unparameterised rendered strings and says "Do NOT raise the ceiling". `"20 دقيقة"` as a literal ARB value fails the build. It must be `l10n.nMinutes(20)`. |
| Illustrations | `app/assets/art/` + `AppArt` | Existing mechanism, existing test (`app/test/theme/app_art_test.dart`). |
| Entitlement | Firestore `users/{uid}/private/entitlement`, server-written only | §3.6. |

### 2.2 `Recipe` — every field

Dart home: `app/lib/features/eat/domain/recipe.dart` (new). `@immutable`, no
Flutter import, so it is testable without a widget tree, matching
`food_library.dart`.

```
Recipe
  recipeId            String        required   'rahma_lazy_cake'
  source              RecipeSource  required   book | authored | assembly  (§3.5)
  sectionId           String        required   'sweet_tooth_breakfast'
  orderInSection      int           required   printing order in the book
  status              RecipeStatus  required   draft | review | published
  version             int           required   bumped on every published edit

  -- titles ---------------------------------------------------------------
  titleEn             String        required   VERBATIM from the book
  titleAr             String?       nullable   null until Rahma authors it (§1.5.9)
  titleSearch         List<String>  required   normalised forms for search only,
                                               never rendered ('shorbet ads',
                                               'شوربة عدس', 'lentil soup')

  -- her voice ------------------------------------------------------------
  bodyAr              String        required   the card's text, verbatim, one block,
                                               newlines exactly as the book breaks them
  closingAr           String?       nullable   'والف هنا' etc., her sign-off, if any
  registerAr          Register      required   egyptianColloquial  (§3.1)

  -- the cookable view (DERIVED, never a rewrite) -------------------------
  ingredients         List<RecipeIngredient>   §2.3
  steps               List<RecipeStep>         §2.4
  variants            List<RecipeVariant>      §2.5  (cheese_cake has 2)
  components          List<RecipeComponent>    §2.6  (sauces, bechamel)

  -- facts ----------------------------------------------------------------
  serves              int?          nullable   null = the book does not say
  activeMinutes       int?          nullable   hands-on time
  totalMinutes        int?          nullable   including fridge/freezer waits
  kcal                int?          nullable   per serving; null unless computed
                                               from foodIds with known grams
  proteinG            int?
  carbsG              int?
  fatG                int?
  macroBasis          MacroBasis    required   computed | withheld   (§3.3)
  egpPerServing       int?          nullable   E05 renders this today
  egpPricedAt         DateTime?     required if egpPerServing != null   (§3.3)

  -- safety ---------------------------------------------------------------
  allergensDerived    Set<String>   required   union of ingredients' foods
  allergensExtra      Set<String>   required   cross-contact, serving suggestions,
                                               brand products
  allergensRemoved    Map<String,String> required  tag -> written reason
  allergensFinal      Set<String>   required   derived ∪ extra − removed
  advisories          Set<String>   required   'pregnancy_liver', 'g6pd_fava', ...
  dietTags            Set<String>   required   'vegetarian', 'vegan', 'gluten_free',
                                               'high_protein', or 'none'
  doneness            String?       nullable   the target for poultry/mince/liver/
                                               shellfish; REQUIRED when the recipe
                                               contains one (§3.4)

  -- provenance -----------------------------------------------------------
  sourcePage          int?          nullable   3..26 for book recipes
  authoredBy          String        required   who wrote the structured view
  allergenReviewedBy  String?       nullable   MUST be non-null to publish,
                                               MUST differ from authoredBy (§3.4)
  allergenReviewedAt  DateTime?
  cookedBy            String?       nullable   who actually cooked it (§3.5)
  cookedAt            DateTime?

  -- presentation ---------------------------------------------------------
  artKey              String?       nullable   an AppArt name that DEPICTS this dish
  tier                RecipeTier    required   free | pro   (§3.6)
  brandHints          Map<String,String> required  ingredientRef -> her brand words
```

Sentinel discipline, copied from `RecipeRow` (`recipes_view.dart:49`): "Null
means the row does not say, and a row that does not say never matches a filter."
Every nullable above obeys that. `allergensFinal` is **not** nullable and is
**not** allowed to be empty-by-default: an empty set means "reviewed, and
contains none of the 16", and only a signed review can assert it.

### 2.3 `RecipeIngredient`

```
ingredientRef   String    required   stable within the recipe, e.g. 'oat_flour_1'
foodId          String?   nullable   into `foods`. NULL BLOCKS PUBLICATION (§3.4)
qtyTextAr       String    required   HER WORDS, verbatim: 'معلقتين دقيق شوفان صغيرين'
grams           int?      nullable
gramsBasis      GramsBasis required  stated | measured | estimated | unknown
gramsNote       String?   nullable   'Juhayna 105 g tub, weighed 2026-10-02'
optional        bool      required   'اختياري' in her text
servingSideOnly bool      required   true for 'تتقدم مع: ½ رغيف عيش بلدي'
brandHint       String?   nullable   'الضحى', 'كنور'
```

`gramsBasis`:

- `stated` — she wrote the grams. Six recipes do (`40 جم شوفان`, `170 جم زبادي`,
  `150 جم فول مدمس`, `60 جم جبنة`, `50 جرام` pasta, `15 جرام` cheese).
- `measured` — someone weighed it in an Egyptian kitchen and recorded who, when
  and what product, in `gramsNote`.
- `estimated` — from the household-measure table (§3.3). **Only permitted where
  the ingredient contributes under 20 kcal per serving.**
- `unknown` — the book does not say and nobody has measured. Permitted in
  `status: review`, never in `status: published`.

### 2.4 `RecipeStep`

```
index       int      required   1-based, HER numbering where she numbers
textAr      String   required   HER SENTENCE, VERBATIM. Never rewritten. (§3.2)
minutes     int?     nullable
tempC       int?     nullable
tool        String?  nullable   'oven' | 'air_fryer' | 'microwave' | 'pan' |
                                'blender' | 'hand_blender' | 'fridge' | 'freezer'
usesRefs    List<String> required  ingredientRefs this step consumes
isTimer     bool     required   true when minutes != null and the step is active
```

The rule that makes §3.2 work: **`textAr` is a substring of `bodyAr`.** A test
asserts it. The structured view is a split, not a paraphrase. Where the book
runs on without numbering (`Lazy Cake`, `Coconut apple Pudding`, `Bagel`), a
human chooses the split points; the substring test still holds.

### 2.5 `RecipeVariant`

```
variantId    String   required
labelAr      String   required   'الطريقة الأولى' / 'الطريقة التانية'
steps        List<RecipeStep>
ingredients  List<RecipeIngredient>
```

Used by `rahma_cheese_cake` only, today. A variant is **not** a separate recipe
and must not be counted as one.

### 2.6 `RecipeComponent`

```
componentId  String   required   'chocolate_sauce'
headingAr    String   required   as the book prints it, 'Chocolate sauce' /
                                 'طحينه لايت:' / 'البشاميل:'
ingredients  List<RecipeIngredient>
steps        List<RecipeStep>
```

### 2.7 `RecipeSection`

```
sectionId    String   'sweet_tooth_breakfast'
titleEn      String   VERBATIM: 'Sweet Tooth Breakfast'
titleAr      String?  null until authored
psLineEn     String   VERBATIM, including 'PS:' where she wrote it
psLineAr     String?  null until authored
order        int      1..4
artKeyMain   String   the large divider illustration
artKeysFoot  List<String>  the two or three small ones along the bottom
```

### 2.8 Changes to `content_schema.dart`

`app/lib/features/admin/domain/content_schema.dart:233-247` currently gives
`recipes` eight columns. Z08's expected-column table, the importer, the
validator and the exporter all read from this one place, so adding here is the
whole job on the admin side.

Add, in this order, after `minutes`:

```dart
ContentColumn('sectionId', required: true),
ContentColumn('source', required: true),
ContentColumn('status', required: true),
ContentColumn('serves', numeric: true),
ContentColumn('activeMinutes', numeric: true),
ContentColumn('kcal', numeric: true),
ContentColumn('proteinG', numeric: true),
ContentColumn('carbsG', numeric: true),
ContentColumn('fatG', numeric: true),
ContentColumn('macroBasis', required: true),
ContentColumn('egpPerServing', numeric: true),
ContentColumn('egpPricedAt'),
ContentColumn('advisories', required: true, list: true, safetyTag: true),
ContentColumn('doneness'),
ContentColumn('artKey', media: true),
ContentColumn('tier', required: true),
ContentColumn('authoredBy', required: true),
ContentColumn('allergenReviewedBy'),
ContentColumn('sourcePage', numeric: true),
```

**`bodyAr`, `steps`, `ingredients` and `components` do not go in the CSV.** A
40-line Egyptian colloquial paragraph does not survive a CSV round trip, and
`csv_parser.dart` was not built for it. The CSV stays the *facts* sheet; the
text arrives as a JSON sidecar keyed by `recipeId`. Say so in the schema header
so the next reader does not "fix" it.

### 2.9 The seed asset

`app/assets/content/rahma_recipes.json`, registered in `pubspec.yaml` under
`assets:`. One object per recipe, the full §2.2 shape, plus a top-level
`{"schemaVersion": 1, "contentVersion": N, "sections": [...]}`.

Estimated size: 39 recipes x roughly 2.5 KB of UTF-8 Arabic = **under 120 KB**.
That is the right price for the Eat tab working with no network in Egypt.

Loader: `app/lib/features/eat/data/seeded_recipe_library.dart`, reading through
`rootBundle`, parsed once and cached. Firestore wins when its `version` is
higher; the seed is the floor, never overwritten by a lower version.

---

## 3. The eight questions

### 3.1 Her voice versus the app's Arabic

**The boundary is the boundary between content and chrome, and it is already
enforced by a test.**

`app/pubspec.yaml:8` says it plainly: "Arabic is Modern Standard Arabic; the ARB
files in lib/l10n are generated from the mockup's translation dictionary and
must not be hand-edited." `6-v2/plans/G15-assistant.md:535` says "A wrong
register here reads worse than a wrong colour." And `G5-eat-food-logging.md:594`
already drew this exact line for voice input: "**interface stays MSA while
speech input accepts Egyptian dialect**."

So the rule is not new. It is:

> **Everything that goes through `add_strings.py` is MSA. Everything that comes
> out of `rahma_recipes.json` or Firestore is hers.**

That is mechanically checkable, because the two sets of strings arrive through
different pipes and never mix.

Concretely, by string:

| MSA, in the ARB | Egyptian colloquial, in the content |
|---|---|
| `Recipes`, `Ingredients`, `Steps`, `Save`, `Share`, `Cooked it` | every word of `bodyAr` |
| `This recipe contains {allergen}` | every word of `steps[].textAr` |
| `We have not checked this dish for what you told us` | `qtyTextAr` ("معلقتين", "ربع كيلو") |
| `Your portion` | the four section titles and PS lines |
| `{n} min`, `{n} g`, `{n} kcal` | the closing letter |
| every error, every empty state, every button | `closingAr` ("والف هنا") |
| the pregnancy note, the fava note, the doneness note | her `brandHints` |

Three consequences worth stating, because they are where this goes wrong:

1. **Section titles and PS lines are content, not chrome.** They sit in
   `rahma_recipes.json`, not the ARB. The MSA navigation label above them
   (`الوصفات`) is chrome. So a screen reads "الوصفات" in the app's voice and
   "Sweet Tooth Breakfast / PS: You may need it on your period girl i got you
   :)" in hers, one above the other. That is the register change made visible
   and deliberate, rather than smeared.

2. **Safety copy is never hers and never colloquial.** The allergen warning, the
   pregnancy note, the doneness target, the "check the label yourself"
   disclaimer. All MSA, all ARB, and typographically distinct: they render in
   `HandInk.print` inside a `HandSurface(level: HandLevel.structural)` note, not
   on the pink card in `#610904`. **Warmth and warning must not look the same.**
   If a woman cannot tell at a glance whether a line is Rahma being lovely or
   the app being careful, the careful line has failed.

3. **Her English titles are not corrected.** `Shakshoka`, `Fool & Ta3mya`,
   `Hwawshi`, `shorbt 3ads`, `Btates bel lahma`, `Makrona Bashmel`, `Lahma bel
   basl`, `Cookies with shay blabn`. The arabizi *is* the voice. Search is
   served by `titleSearch[]`, which is never rendered.

**Owner decision:** the 39 Arabic titles and the 4 Arabic section titles must be
written by Rahma, in her register. I am not proposing to invent them and I am
not proposing to have the MSA dictionary translate them, because an MSA title
over a colloquial body is exactly the mixing this section exists to prevent.

### 3.2 Structure versus voice

**Do not rewrite her steps. Split them. She already numbered most of them.**

The premise of the question is that her writing blends ingredients and method.
It does, but look at what she actually wrote:

```
-1 بيضه و معلقة فانيلا سايله
-2 هنضربهم ونحط عليهم كيس stevia
```

Step 1 is an ingredient. Step 2 is an ingredient and an action. The numbering is
hers. What is missing is not structure, it is a **shopping view**: you cannot
see what to take out of the fridge without reading the whole card.

So the recipe screen has two tabs, and the default is the first:

**Tab A — `المقادير والخطوات`** (MSA label)

1. An ingredients block at the top. **Derived, never rewritten.** Each row is
   her `qtyTextAr` verbatim, with the grams beside it, muted. This block is the
   only genuinely new writing on the screen, and it is not writing: it is her
   own noun phrases lifted out and listed.
2. Then her numbered steps, `textAr` verbatim, one per row, with a timer chip
   where `minutes != null` and a temperature chip where `tempC != null`.
3. Then `closingAr` in her hand, outside the numbering, in `HandNote` with
   `ArefRuqaa` (which `handStyle()` at `hand_marks.dart:340` already picks for
   Arabic). "والف هنا" is never a step.

**Tab B — `زي ما هي في الكتاب`**

The card as the book prints it. One block. `bodyAr`, unsplit, on the pink paper
with the clips and the illustration. Nothing extracted, nothing reordered.

**What is lost, precisely.** Three things, and none of them is recoverable:

1. **The breath.** Her cards read as one exhale. A step list reads as a list,
   even with identical words. Tab B exists because of this, and because a woman
   who bought the book should be able to see the book.
2. **The join between an ingredient and its moment.** In "هنقلبها ونحطها في
   الفرن 10 دقايق" the oat flour, cocoa and yogurt are already in the bowl from
   two lines up. Lifting them into an ingredients block means they appear twice,
   and the second appearance is slightly redundant. The alternative, showing
   them once, is worse.
3. **Three cards lose the author's own segmentation.** `Lazy Cake`, `Coconut
   apple Pudding` and `Bagel` run on without numbering past a point. A human
   picks the split. Record who picked it, in `authoredBy`.

**What is gained**, and why it is worth the loss: a timer, a temperature, a
shopping list, an allergen check, a gram figure that can be logged, and a screen
that does not need to be read twice at 7am.

**Cook mode.** Not a separate route (the route budget and the two-tap budget both
say no; `nav_reachability_test.dart:474`). A full-width toggle at the top of Tab
A that enlarges the step type, shows one step at a time with a big next control,
and holds the screen awake. `WakelockPlus` is a new dependency; if the owner
does not want one, the toggle simply enlarges and paginates and the screen
sleeps, which is honest and still better than nothing.

### 3.3 Quantities

**Authored per recipe by a human. Never computed at runtime. Both held, hers
first.**

A generic conversion table cannot do this job, for three reasons that are
specific to Egypt:

- `علبة زبادي` is a Juhayna cup, not a US greek tub. The difference between 105 g
  and 170 g is about 40 kcal, repeated across nine recipes.
- `ربع كيلو جبنة قريش` is exactly 250 g and needs no table. `معلقة` needs one and
  the Egyptian spoon is not the US tablespoon.
- `كيس ستيفيا` is a sachet whose sweetness-to-mass ratio is brand-specific and
  whose kcal is effectively zero, so its gram figure is irrelevant and its
  presence is not.

Therefore:

1. **Every ingredient carries both.** `qtyTextAr` is hers, verbatim, and is what
   the screen shows first, at full size. `grams` sits beside it, muted, smaller,
   in `onSurfaceVariant`: `معلقتين دقيق شوفان صغيرين · ١٢ جم`. A switch in Eat
   settings swaps the emphasis for women who cook by weight. Neither is ever
   hidden.
2. **`gramsBasis` is mandatory and is shown when it is `estimated`.** The
   ingredients block carries one MSA line at the foot: "الأوزان تقديرية إلا
   المكتوب في الكتاب." Only when at least one row is `estimated`.
3. **The household-measure table is a build-time artefact, not a runtime one.**
   `app/tool/household_measures.ar-EG.json`, one row per measure, each with a
   gram figure, a product it was measured against, who measured it and when.
   `app/tool/derive_grams.py` reads it and writes `grams` into the recipe JSON.
   The app never sees the table.
4. **The publication rule, which is testable:** a recipe cannot reach
   `status: published` if any non-`optional`, non-`servingSideOnly` ingredient
   has `gramsBasis == unknown`, or has `gramsBasis == estimated` while
   contributing more than 20 kcal per serving.
5. **Macros follow the grams, or they are withheld.** `macroBasis: computed`
   means every ingredient resolved to a `foodId` with known per-100 g macros and
   a known gram figure, and kcal/protein/carbs/fat were summed. Anything else is
   `macroBasis: withheld` and the four fields are null and the screen says
   nothing. This is the pattern `app/lib/domain/rewards/stated_figure.dart`
   already establishes and `recipe_view.dart:279-283` already practises for the
   cook-time line: withhold rather than state.
6. **EGP is a dated claim.** `app/test/features/eat/recipes_view_test.dart:49`
   already asserts "every card carries its cost per serving in EGP", and
   `recipes_view.dart:69` sets `kCheapEgp = 15`. In Egypt in 2026 an undated EGP
   figure is wrong within a quarter. So `egpPerServing` requires `egpPricedAt`,
   the screen renders the month next to it, and a test fails the build when any
   published `egpPricedAt` is more than 180 days old. **Owner decision: is
   `kCheapEgp = 15` still meaningful? It almost certainly is not.**

### 3.4 Allergens

This is the section that gates the feature.

#### The state today

- `AllergenTag` (`app/lib/features/account/domain/dietary_profile.dart:64`) has
  **four** members: `nuts`, `dairy`, `gluten`, `shellfish`. Its doc says "Four,
  and no more until content authors more." This plan is content authoring more.
- The seed already writes `sesame` and `egg` on dishes "truthfully, although no
  capture surface can name them yet" (`seed_library.dart`). So a woman allergic
  to sesame cannot tell the app.
- `eatSampleLibrary` ships eight foods with `allergens: null`, deliberately: "No
  allergen tag has been invented."
- `AllergyGuard.screen()` (`allergy_guard.dart:157`) removes any food with
  `allergens == null` when she has declared an allergy. **The guard already
  fails closed.** The complaint that "saving an allergy empties the Eat tab" is
  the guard working correctly against an empty library, not a bug in the guard.
- `AppRouter.eatConstraints` (`app_router.dart:4498`) returns
  `DietaryConstraints.none` when `profile.asked` is false. `none` is **a claim**:
  asked, and named nothing. It is true of nobody.
- `allergy_interlock_test.dart:41` fails the build the moment any food carries
  allergen data while that claim stands.

#### The vocabulary

Sixteen tokens. The EU/UK 14 (which is a superset of Codex STAN 1-1985 and of
the FDA 9, so it maps cleanly to Egyptian labelling) plus two that Egypt needs.

```
gluten        الجلوتين          (wheat, barley, rye, oats)
crustaceans   القشريات          (shrimp, crab)
eggs          البيض
fish          السمك
peanuts       الفول السوداني
soy           الصويا
milk          الحليب ومنتجاته
tree_nuts     المكسرات
celery        الكرفس
mustard       المسطردة
sesame        السمسم
sulphites     الكبريتيت
lupin         الترمس
molluscs      الرخويات
fava          الفول                 <- not an allergen. G6PD / favism.
coconut       جوز الهند             <- FDA calls it a tree nut, the EU does not.
```

Two of the sixteen are deliberate departures and both matter here:

- **`fava` is not an allergen; it is a metabolic contraindication.** G6PD
  deficiency is common enough in Egypt that `Fool & Ta3mya` needs a flag. It
  lives in the same vocabulary because it is the same user action: she ticks a
  thing she cannot eat.
- **`lupin` (الترمس) is in the EU 14 and is Egyptian street food.** Nothing in
  the book contains it. It is in the vocabulary because the library will grow
  and because lupin cross-reacts with peanut.
- **`coconut` is its own token** rather than folded into `tree_nuts`, because
  the two standards disagree and folding it produces either false positives for
  every woman with a nut allergy or a false negative for the one who reacts to
  coconut. `Coconut apple Pudding` is recipe 4.

Mapping the four existing tokens forward: `nuts` → `tree_nuts`, `dairy` →
`milk`, `gluten` → `gluten`, `shellfish` → `crustaceans` **and** `molluscs`.
`AllergenTag.fromWire` keeps accepting the four old spellings as aliases so
already-saved profiles do not silently lose a declaration. A test asserts the
alias table is total.

`advisories` is a **separate** set, because it is not a thing she ticks:
`pregnancy_liver` (recipe 28), `pregnancy_soft_egg`, `g6pd_fava` (recipe 14),
`high_caffeine`. Rendered as a note, never used to filter.

#### Who assigns a tag

Derived, then extended, then signed, in that order.

1. **Derived.** Every `RecipeIngredient.foodId` points into `foods`, and every
   `foods` row carries `allergens[]` (`content_schema.dart:227`, already
   `required: true, safetyTag: true`). `allergensDerived` is the union, computed
   by the authoring tool at build time and stored, so the app never computes it.
2. **Extended by a human.** `allergensExtra` holds what the ingredient list
   cannot know: sesame from `زعتر` (za'atar is a sesame blend), sesame from a
   `طعمية` crust, celery and soy from a Knorr cube, wheat and soy from a
   McVitie's digestive, cross-contact in a kitchen.
3. **Removed only with a reason.** `allergensRemoved` is a map of tag to a
   written sentence. An empty reason is a validation failure.
4. **Signed.** `allergenReviewedBy` must be non-null, and **must differ from
   `authoredBy`**. Two people, enforced in the Firestore rule, not in Dart.

#### How a wrong tag is caught before it reaches a woman who reacts to sesame

Five layers. None is sufficient. I am not claiming any of them makes this safe;
I am claiming they make a single mistake survivable.

**1. Unreviewed means hidden, not shown.** A recipe with
`allergenReviewedBy == null` is never returned to a woman who has declared any
allergy, and carries a visible MSA note for everyone else. It is never silently
presented as fine. This is the guard's existing fail-closed behaviour extended
from `allergens == null` to `allergenReviewedBy == null`.

**2. A free-text ingredient cannot be published.** `foodId == null` on any
ingredient blocks `status: published`. An ingredient nobody can look up is an
allergen nobody can check. This is a unit test over the seed JSON, run in CI.

**3. A keyword tripwire over her raw Arabic, independent of the ingredient
list.** `app/tool/allergen_tripwire.py` runs a dictionary of Egyptian colloquial
allergen words across `bodyAr` and every `steps[].textAr`. If a word fires and
its tag is absent from `allergensFinal`, the build fails, naming the word, the
recipe and the line. This is the layer that catches za'atar, because nobody
remembers that za'atar is sesame at 11pm.

The dictionary, as a starting point, to be extended by a human who reads Arabic:

```
sesame       سمسم، طحينة، طحينه، طحينية، زعتر، tahina, tahini
peanuts      فول سوداني، زبدة فول سوداني، peanut
tree_nuts    مكسرات، لوز، عين جمل، جوز، بندق، كاجو، فستق
coconut      جوز هند، جوز الهند، coconut
milk         لبن، حليب، زبادي، جبنة، جبنه، قريش، موتزاريلا، زبدة، سمنة، كريمة، يوناني
eggs         بيض، بيضة، بيضه، بيضتين، اومليت، مايونيز
gluten       دقيق، شوفان، عيش، توست، تورتيلا، مكرونة، بقسماط، فينو، رغيف، بيجل، بسكوت، بانيه، باتيه، برجر
fish         سمك، تونة، تونه، سردين، بلطي، فيليه
crustaceans  جمبري، جمبرى، استاكوزا، shrimp
molluscs     كاليماري، بلح البحر، محار
soy          صويا، صوص صويا
celery       كرفس، مرقة، مكعب مرقة، كنور
mustard      مستردة، مسطردة، خردل
sulphites    فواكه مجففة، مشمش مجفف، زبيب
lupin        ترمس
fava         فول، فول مدمس، طعمية، فلافل، بصارة
```

Note that `فول` fires `fava` and `فول سوداني` fires `peanuts`, so the tripwire
must match longest-first. `زبيب` (raisins, recipe 5) fires `sulphites`, which is
a false positive the reviewer will dismiss. That is the correct direction: the
tripwire over-fires and a human clears it.

**4. Two people.** `authoredBy != allergenReviewedBy`, enforced in
`firestore.rules` on the `recipes` write, so a Dart bug cannot bypass it.

**5. The app filters and warns. It never certifies.** Three rules:

- A recipe whose `allergensFinal` intersects her declarations is **removed from
  every list**, exactly as `AllergyGuard.screen()` already does for foods.
- Reaching one anyway (a saved bookmark, a deep link, a share) shows a full
  interstitial before the card. **Not a dialog.**
  `app/test/product_rules_test.dart:325` bans `showDialog` and `AlertDialog` on
  every line under `lib/features/`. Use `showAppSheet`, which `profile_view.dart`
  already uses, or a route. The copy already exists in the dictionary:
  `l10n.thisDishHasAllergenYouToldUs`, `l10n.notThis`, `l10n.logItAnyway`
  (named in `allergy_interlock_test.dart`).
- **The app never says "آمن لكِ".** It says what the recipe contains. A standing
  MSA line sits at the foot of every recipe card: "المقادير من رحمة. راجعي
  ملصق كل منتج بنفسك قبل الاستخدام." We can state contents. We cannot certify a
  kitchen we do not control, and saying otherwise is both a moral and a legal
  error.

#### The ordering problem, which is the actual blocker

`allergy_interlock_test.dart` is right and must not be edited. The sequence is:

1. Extend `AllergenTag` to sixteen, with the four aliases.
2. Ship **an allergy question that every woman actually answers**, before any
   allergen-tagged recipe is visible. A02's `_DietaryEditor` sheet exists but is
   opt-in and buried; `profile.asked` stays false for everyone who never opens
   it, so `eatConstraints` keeps returning the fiction `none`.
   **Recommendation: a one-question screen (E10, §4) shown once, the first time
   she opens the recipe library.** Sixteen chips and an explicit "لا، ولا حاجة"
   which writes `asked: true, allergies: {}`. That is an answer, not a default.
   Switching `eatConstraints` to `unknown` instead also clears the interlock,
   but `app_router.dart:4451-4497` explains why that is worse: the Eat tab then
   cannot log anything, for everyone, on day one.
3. Only then do allergen-tagged recipes become visible.

**Owner decision:** does the allergy question go in onboarding (better coverage,
one more step before value) or at first open of the library (better timing,
misses women who never open it)? I recommend the library, because that is the
moment it is true.

### 3.5 Generating roughly 170 more recipes

**I recommend against 200+ as a content target, and I recommend against
generating recipes in her voice at all.**

#### Why

This repo has already reasoned this through, for training, and wrote it down at
`app/lib/features/onboarding/domain/starting_program.dart:3-21`:

> "Inventing them would be worse than having none: a plausible-looking week of
> made-up training is indistinguishable from a real one in review, and it would
> reach a pregnant woman's phone."

And `DECISIONS.md` on the Phase 2 blockers:

> "These are content obligations, not engineering tasks. Each blocks a named P0
> case, and none may be invented — a plausible-looking guess in any of these
> four reaches a woman's phone as fact."

And `BUILD-BRIEF.md` §2 rule 10:

> "The assistant selects, never generates. It cannot invent an exercise, an
> ingredient or a quantity."

And `G5-eat-food-logging.md:388`:

> "never an invented food or an invented gram figure"

The brief's framing, that "recipes are lower risk than a training week", is
right about the *median* case and wrong about the tail. A generated recipe can
be wrong in four ways a generated workout cannot:

1. **Undercooking.** "Chicken breast, 180 C, 15 minutes" is a plausible sentence
   and a campylobacter risk. Poultry, mince, liver and shellfish are all in this
   book.
2. **An allergen claim.** Every generated recipe generates an allergen set. §3.4
   builds five layers to catch a human's mistake; a generator produces mistakes
   at a rate five layers were not designed for, and produces them *confidently*.
3. **A macro claim.** This app logs meals against a target. A generated kcal
   figure is a fabricated number driving a woman's eating.
4. **Voice theft.** Your own standing rule, from another project, is that the
   founder's Egyptian voice stays the founder's and tools index and retrieve,
   never write. 161 recipes written in Rahma's colloquial by a model is 161
   sentences she never said, attributed to her, on a page with her name on it.
   That is a worse problem than any of the first three, because it is not
   detectable by testing.

#### What to do instead

Split the library into two kinds, labelled differently on screen, counted
separately. `Recipe.source` carries the distinction.

**Kind A — `source: book` and `source: authored`. Rahma's recipes.**

Her card, her voice, her illustration, her name. These grow slowly and every one
of them is cooked before it ships.

The pipeline for an `authored` recipe:

1. A model may produce a **brief**, never a recipe: a target (section, protein
   band, cook time, technique, Egyptian ingredient availability) and a skeleton
   drawn only from the vocabulary already in her book. It produces no prose in
   Arabic and no voice.
2. **Rahma, or a named Egyptian cook, cooks it.** `cookedBy` and `cookedAt` are
   non-null or it does not publish. This is the gate that makes everything else
   true: times, temperatures, quantities and doneness all come out of a real
   kitchen.
3. **Rahma writes the card**, in her own colloquial, as she wrote the 39.
4. §3.3's grams and §3.4's allergen review, two people.

Realistic throughput: a cook can develop, cook, photograph and write perhaps
5 to 8 a week alongside a job. **50 recipes is 39 plus 11, which is six to eight
weeks. 200 is a year and a half.**

**Kind B — `source: assembly`. Not recipes, and not presented as recipes.**

An assembly is a named combination of `foods` rows with stated portions and no
cooking step. `170 جم زبادي يوناني + 30 جم شوفان + 100 جم فراولة + قرفة` is
recipe 6 in her book. Hundreds of such combinations are legitimate, because:

- every component is an existing `foods` row with verified per-100 g macros, so
  the macros are **summed, not invented** (`macroBasis: computed`);
- the allergens are the **union of verified sets**, not a claim;
- there is no cooking step, so there is no undercooking;
- nothing is written in her voice, so nothing is put in her mouth.

They live under their own MSA heading, `تركيبات سريعة`, in the app's own visual
language, **not on the pink card**. They carry no PS line and no sign-off.
A woman can tell in a glance which is which, which is the whole point.

#### So what is the number

| | Launch | 6 months |
|---|---|---|
| Rahma's recipes (`book` + `authored`) | 39 to 50 | 70 to 90 |
| Assemblies | 60 to 120 | 200+ |
| **Honest headline** | **"100+ meals, 50 of them Rahma's"** | |

The paid tier should not be sold on a count at all. It should be sold on the
week plan, the grocery list, the macro logging and **new recipes from Rahma
every week**, which is a promise that gets more true over time rather than less.
If a number must go in the App Store description, it must be true on the day it
is written: Apple has rejected apps under Guideline 2.3.1 and 2.3.7 for
describing content that does not exist.

**Never auto-generated, under any circumstances:**

- any `allergensFinal`, `allergensExtra` or `advisories` value;
- any `tempC`, `minutes` or `doneness` on a recipe containing poultry, mince,
  liver, eggs or shellfish;
- any `grams` on an ingredient contributing over 20 kcal;
- any kcal, protein, carb or fat figure that is not a sum over verified foods;
- any Arabic sentence attributed to Rahma;
- any section title or PS line.

### 3.6 Free 50 versus Pro 200+

**Model the entitlement now. Sell nothing. Ship no paywall.**

`Feature.payments` is `false` and its parent `Feature.marketplace` is `false`
(`feature_flags.dart:117,128,190,191`). `PaymentProvider` has exactly one
implementation, `UnavailablePaymentProvider`, and its own header says "There is
no working implementation of this interface". `CheckoutOutcome` has `unavailable`
and `started` and **no `paid`**. `CheckoutRequest` carries no amount.
`release_readiness_test.dart:75` asserts "the test payment rail is closed".

A paywall shipped against that is a screen that takes a decision and cannot
honour it. So:

#### What ships now

1. **`RecipeTier { free, pro }` on every recipe**, set to `free` on all of them.
   The field exists, is populated, and is inert.
2. **An entitlement document**, `users/{uid}/private/entitlement`:
   `{ tier: 'free'|'pro', source: 'none'|'appstore'|'playstore'|'grant',
   expiresAt: Timestamp?, updatedAt: Timestamp }`.
   Firestore rule: `allow read: if isSelf(uid); allow write: if false;` for the
   client. Written by a Cloud Function or an admin only. This mirrors how
   `verified`, `coachV` and `admin` are already handled
   (`firestore.rules:30-46,124-131`): server-minted, never client-asserted.
3. **`Feature.recipeTiering`, with `parent => Feature.payments`.**
   `feature_flags.dart:123` already walks ancestors in `isOn()`, so the gate is
   **structurally impossible** to switch on while payments is off. That is the
   honest version of "the flag is off".
4. **`RecipeAccessGate`**, modelled directly on
   `app/lib/features/coaching/domain/checkout_gate.dart`: a pure function
   returning `RecipeAccess.open` or `RecipeAccess.locked(reason)` with
   `enum RecipeLockReason { tieringOff, paymentsOff, notEntitled, expired,
   unknownEntitlement }`. No `force`, no `skipChecks`, matching the existing
   gate's discipline.
5. **The rules-level gate, written now and inert now.** The client gate is a lie
   if the document is readable anyway. A `pro` recipe must not be *readable* by
   a `free` account:

   ```
   match /recipes/{id} {
     allow read: if isVerified()
                 && (resource.data.tier == 'free'
                     || request.auth.token.tier == 'pro');
     allow write: if isAdmin()
                  && request.resource.data.authoredBy
                     != request.resource.data.allergenReviewedBy
                  && request.resource.data.allergenReviewedBy != null;
   }
   ```

   Note `request.auth.token.tier`, a custom claim, not a document read: the
   existing `isVerified()` comment at `firestore.rules:341-342` gives the
   reason ("a rules get() here would bill one extra read on every gated
   operation"). The cost of a claim is staleness: a claim can be up to an hour
   behind unless the client forces `getIdToken(true)` after purchase. The
   purchase flow must force it.

6. **No paywall UI at all.** No locked cards, no "upgrade" row, no price. A
   locked state that cannot be unlocked is worse than no locked state.

#### What is needed later to actually charge

- `in_app_purchase` (a new dependency), StoreKit 2 on iOS, Play Billing 7 on
  Android.
- **Server-side receipt validation**: App Store Server API v2 (signed JWS
  transactions, verified against Apple's root certificates) and Google Play
  Developer API `purchases.subscriptionsv2.get`. Never trust the client.
- **Notifications**: App Store Server Notifications V2 and Play Real-time
  Developer Notifications, both to a Cloud Function that writes the entitlement
  document and sets the custom claim. The functions here are Python
  (`functions/main.py`), so this is a Python endpoint.
- **Restore purchases**, reachable without an account (Guideline 5.1.1(v)) and
  from the Egyptian storefront.
- A grace-period and billing-retry state, or a woman whose card fails loses the
  library mid-week.

#### The store rules, concretely

- **Digital content consumed in the app must use IAP.** Guideline 3.1.1. A Fawry
  or InstaPay link for the same recipes is a rejection, not a grey area.
- **Apple's commission is 30%, or 15% under the Small Business Program**
  (under $1m proceeds per year, which this is), and 15% on subscriptions after
  the first year regardless. Google is 15% on the first $1m of earnings per year
  and 15% on subscription revenue.
- **Guideline 3.1.2** requires the title, duration, price per period and what is
  included to be visible *before* purchase, plus functional links to terms and
  privacy policy. `docs/release/` already has both documents.
- **Price in EGP deliberately.** Apple's Egyptian price tiers moved sharply
  after the 2024 devaluation; converting a USD figure produces a number that is
  either insulting or invisible. This is a pricing decision, not an engineering
  one.
- **Auto-renewal must be cancellable through the store** and the app must not
  obstruct it.

**Owner decisions:** (a) does a paid tier ship in v1 at all? (b) if yes, what
EGP price per month and per year? (c) does the free tier keep working offline
when the subscription lapses, or does the seed asset become inaccessible? I
recommend the seed stays readable forever: it is on her device and taking it
away is an ugly thing to do.

### 3.7 The design

**A theme inside the existing hand system, scoped to Eat. Not a fork.**

The two languages are closer than they look. Both are paper, rose, hand-drawn.
The book's ink is *more* accessible than the app's.

#### The measured palette

Sampled from a 1175 px render of page 3, and from page 2 for the divider.

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `bookBg` | `#F5A6AF` | the deeper pink behind the cards | |
| `bookPaper` | `#FBDCD9` | the card, and the divider's inner panel | |
| `bookInk` | `#610904` | titles and body, on paper | **10.55:1** |
| `bookInkSoft` | `#4B0009` | the PS line | **12.54:1** on paper |
| `bookClip` | `#BF9A5E` | the wooden clip | decorative only |
| ~~`#D3737E`~~ | | the book's big section title | **2.51:1 — FAILS** |
| `bookRoseTitle` | **`#7F454C`** | replacement for the above | 5.72:1 on paper, 3.83:1 on `bookBg` |

For comparison, the app's own `AppColors.primary` `#B4526E` on
`AppColors.surface` `#FFF8F9` is 4.58:1. The book's `#610904` on `#FBDCD9` is
10.55:1. **Adopting the book's ink improves the app's contrast.**

`#D3737E` is the one thing in the book that must change. It is the divider's
huge stacked title. At 2.51:1 it fails AA even at large size (3:1). `#7F454C` is
the same hue and saturation at 55% value, and clears large-text AA on both
grounds. A designer may prefer a different landing point; the constraint is
3:1 on `#F5A6AF` and 4.5:1 on `#FBDCD9`.

Home: `app/lib/theme/recipe_book_tokens.dart`, an `abstract final class
BookInk` beside `HandInk`, matching its shape exactly.

#### The card is not a new painter

`HandSurface` (`app/lib/ui/hand/hand_surface.dart:15`) already draws an
irregular container with a wobbly edge, a seeded offset outline and RTL
awareness. The book's card is:

```dart
HandSurface(
  seed: handSeed([recipe.recipeId]),
  fill: BookInk.paper,
  frame: null,                       // the book has no border
  level: HandLevel.expressive,       // wobble 1.6, overshoot 7, taper 0.55
  radius: 10,
  looseCorner: 22,
  offsetOutline: null,
  padding: const EdgeInsets.fromLTRB(20, 34, 20, 26),
  child: ...,
)
```

The two clips are a small `CustomPainter` beside the existing ones in
`hand_painters.dart`, painted in the card's `Stack` above the top edge,
`ExcludeSemantics`, symmetric so they need no mirroring. They carry no
information and take no tap, which is exactly what `hand_marks.dart:1-7` says
every mark in that layer must be.

#### The seven accessibility constraints, one by one

- **Contrast.** Handled above. One replacement token. The QA agent should assert
  the ratios programmatically; `app/test/features/coachbrand/contrast_test.dart`
  already has a helper to copy.
- **Dark mode.** **There is none.** `buildTheme()` at `app_tokens.dart:76` uses
  `const ColorScheme.light(...)` only; there is no `darkTheme`, no `ThemeMode`,
  no `Brightness.dark` anywhere in `lib/`. So this surface does not need one and
  **must not invent one**, because a dark Eat tab in a light app is worse than
  no dark mode. For the day it arrives, the inversion that works is
  `paper #1A1114` with ink `#FBDCD9` (14.41:1), pink surviving only as the clip,
  a hairline edge and the section titles. Record it in the token file as a
  comment; do not wire it.
- **Tap targets.** Every interactive element 48x48 minimum. The clips are
  decoration and are excluded from the semantics tree. The illustration is
  decoration.
- **Reduced motion.** `handMotionOff(context)` (`draw_on.dart:11`) already reads
  `disableAnimations || accessibleNavigation`. Any card entry animation goes
  through `DrawOn`, which honours it. No page-turn, no parallax.
- **RTL.** The illustration sits top-**right** in the book because the book is
  Arabic. Use `AlignmentDirectional.topStart` so it follows the text direction
  rather than a fixed corner. `HandCorner` (`hand_painters.dart:560`) is already
  named `topStart`/`topEnd` for this reason. The English title is LTR inside an
  RTL card: wrap it in `Directionality(textDirection: TextDirection.ltr)` or
  `Fool & Ta3mya` reorders around the ampersand.
- **Large text.** `app/test/qa/large_text_sweep_test.dart:33` pumps every
  destination at 1.6x on a 1170x2532 viewport and fails on overflow, and the Eat
  suite adds Arabic-at-1.6 per view. The book's card is a fixed-aspect page; the
  app's must be intrinsically sized and scrollable. **This is the reason the
  card must be laid out in Flutter and can never be shipped as a picture of a
  card.** The title in particular: 38 pt display at 1.6x is 61 pt and wraps to
  three lines for `Shrimp white sauce pasta`.
- **Screen reader.** `bodyAr`, `steps[].textAr` and `qtyTextAr` are read. The
  clips, the illustration, the paper grain and every hand mark are
  `ExcludeSemantics`. The English title is announced with
  `Semantics(attributedLabel:)` carrying an LTR locale hint, or a screen reader
  in Arabic mode will attempt to read `Hwawshi` as Arabic.

#### What the illustrations actually are

Three options.

**(a) Extract the images from the PDF. Do not do this.** The book was made in
Canva. Canva's Content Licence Agreement permits using an element within a
design and explicitly prohibits extracting an element and using it as a
stand-alone asset or sublicensing it. Shipping extracted elements in an app
binary is precisely that. This is a licence violation, not a grey area.

**(b) A permissively licensed set.** Real candidates: **Twemoji** (CC-BY 4.0,
good food coverage, one licence for everything), **Noto Emoji** (SIL OFL 1.1).
Avoid **OpenMoji** (CC BY-SA 4.0 — share-alike on an app's assets is a problem)
and avoid Flaticon/Freepik (per-asset licence, attribution obligations, 40
separate documents to track).

**(c) Commission Rahma's own set.** Roughly 45 flat vector spot illustrations in
the book's palette, work for hire, copyright assigned, one invoice, one licence
file. At Egyptian illustrator rates this is a realistic line item and it is the
only option under which the art is genuinely hers.

**Recommendation: (c), with (b) Twemoji as the placeholder during the build**, so
no screen is ever blocked on art. Ship as SVG through `flutter_svg` (a new
dependency), not WebP: 45 flat spot illustrations as SVG is roughly 400 KB
against several megabytes as three-density raster. If the owner refuses a new
dependency, keep WebP and accept the size.

**A licence file is mandatory either way.** `app/assets/art/LICENCE.md`, one row
per asset: file, source, licence, date, and the attribution string if one is
required. The QA agent must check it exists and covers every bundled file.

**And a finding the owner needs:** `app/assets/art/` already ships 57
illustrations with **no licence record anywhere in the repository**
(`find . -iname "*licen*"` returns only the two ONNX model licences and the two
OFL font licences). `cupcake.webp` is byte-identical to the cupcake in this
Canva-produced book. If that pack came from Canva or Freepik, **it is already
shipping in violation, before this feature adds anything.** This needs resolving
regardless of whether this plan proceeds.

#### The rule about illustrations on rows

`app/lib/theme/app_art.dart:14-18` says:

> "They are deliberately not attached to individual rows. Putting `bowlSalad` on
> a food she logged, when the food is not a salad bowl, tells her something
> untrue about her own data."

And `screen_art.dart:16-18`:

> "No treats on food screens. Cake, cupcakes, cookies and fries are in the set
> but appear nowhere a food is logged or planned: a picture there would imply a
> judgement the product itself refuses to make."

The book breaks both, deliberately: a cupcake heads the period-cravings section
and every card carries a picture of its dish.

My reading, which the owner should ratify:

- The **first** rule forbids *mismatch*, not depiction. A picture of Lazy Cake
  on the Lazy Cake card is a label, not a lie. So `artKey` is allowed, and is
  guarded by a test: every published recipe's `artKey` must exist in `AppArt`
  and must appear in a human-signed `recipe_art_mapping` table. An unreviewed
  mapping means no illustration, not a guessed one.
- The **second** rule is about *ambient* art on a logging screen, where a
  cupcake floating beside a calorie total is a nudge. On a recipe card for
  cookies, a picture of cookies is the dish. But `fries` on
  `rahma_lazy_ranch_fries` and `cake_slice` on `rahma_lazy_cake` sit closest to
  the line, and the owner wrote the line.

**Owner decision: does `artKey` on a recipe card count as a "treat on a food
screen"?** I think not, and I think the book answers it, but it is her rule.

#### Fonts

The book's display face is a rounded hand face (Canva's; not licensed to us) and
its Arabic is a rounded face. The app is on Rubik, with `LaBelleAurore` and
`ArefRuqaa` for hand marks only.

- **Do not add a Latin display font.** Rubik 700 with `letterSpacing: -0.4` at
  the `EditorialType.cover` size (38/1.08) is close and already loaded.
- **If the owner insists on the rounded look**, the right pick is **Baloo
  Bhaijaan 2** (SIL OFL 1.1), which carries Latin and Arabic in one rounded
  family: one licence, two scripts, consistent between a title and its body.
  Cost is roughly 120 KB per script as a subset. The existing `OFL-*.txt`
  pattern and the `main.dart` licence registration give it a home.
- `handStyle()` (`hand_marks.dart:340`) already picks `ArefRuqaa` for Arabic and
  `LaBelleAurore` for Latin, sized 1.05x and 1.28x. Her sign-off line uses it
  unchanged.

**Owner decision: Rubik, or add Baloo Bhaijaan 2?**

### 3.8 Scale

#### What ships in the binary

| Item | Size |
|---|---|
| `assets/content/rahma_recipes.json` (39 recipes, Arabic UTF-8) | ~120 KB |
| 27 new illustrations as SVG (23 recipes + 4 dividers) | ~250 KB |
| Baloo Bhaijaan 2, if adopted, two subset scripts | ~240 KB |
| **Total added** | **under 700 KB** |

Against 4.8 MB of existing art, this is nothing, and it buys an Eat tab that
works with no network at all. In Egypt that is not a nicety.

If the recipe illustrations must be WebP at three densities to match the
existing pack, 27 illustrations is roughly **2.3 MB** rather than 250 KB. That
is the whole argument for `flutter_svg`.

#### What comes from Firestore

Everything beyond the seed, plus corrections to seeded recipes. The seed is the
floor: Firestore wins when its `version` is higher, and never replaces a seeded
recipe with a lower version.

#### What is never in the binary

Photographs. There are none today (`photoFile` is `''` on all nine seeded
recipes: "no media has been shot"). If real photography happens, it goes to
Cloud Storage behind a CDN with sized variants, not into the bundle.

#### Read cost, and the mistake to avoid

Firestore bills per document read. **If the library list is a query returning N
documents every time the Eat tab opens, that is N reads per open.** At 200
recipes, 10,000 women, three opens a day: 6,000,000 reads a day. At the
published multi-region rate of $0.06 per 100,000 reads that is roughly **$360 a
day**. This project has already been bitten by exactly this shape of cost, per
the head commit message on this branch.

The fix is one document.

1. **`recipeIndex/{locale}_v{N}`** — a single document holding, for every recipe:
   `recipeId`, `titleEn`, `titleAr`, `sectionId`, `tier`, `totalMinutes`,
   `proteinG`, `egpPerServing`, `allergensFinal`, `dietTags`, `artKey`. Roughly
   250 bytes each. **200 recipes is 50 KB; the 1 MB document ceiling holds to
   about 2,000 recipes.** The whole list screen is **one read**.
2. **`meta/recipes`** — `{ version: N }`. Read once per session; if `N` is
   unchanged, the cached index is used and the index document is not read at
   all. So steady state is **one read per session**, not per tab open.
3. Full recipe bodies are fetched **one document at a time, on open**, with
   `GetOptions(source: Source.cache)` first and a network fetch only on a miss
   or a version bump.
4. `firestore.indexes.json` needs **no new composite index**: the index document
   is fetched by id and everything else is client-side filtering over 50 KB.
   It should get **field exemptions** in the same spirit as the existing ones, so
   nobody can query the library by `proteinG` or `egpPerServing` across
   documents when the index document already answers it.

Steady state at 10,000 daily women: 1 index read + roughly 3 recipe reads each =
40,000 reads a day = **about $0.72 a month**. Three orders of magnitude apart
from the naive version, from one structural decision.

Storage bandwidth is **zero** while the art is bundled. If photography arrives:
200 photos at 80 KB WebP, fetched once by 10,000 women, is about 160 GB of
egress, roughly $19 at $0.12/GB **once**, and roughly zero thereafter **only if**
every object carries `Cache-Control: public, max-age=31536000, immutable`.
Without that header the $19 repeats every month.

*(Both unit prices must be re-checked against the project's actual Firebase
region before anyone quotes them. The orders of magnitude are the point.)*

---

## 4. The Eat surface, screen by screen

Route ids follow `app/lib/routing/app_routes.dart`. Two new routes, which means
`routing_test.dart:13` moves 177 to 179 and line 31 moves 169 to 171, and both
new ids need `ScreenArt.forScreen` entries (`screen_art_test.dart:61`).

### E01 — Eat (modified)

Today, recipes are one row: `_recipesRow` at `eat_view.dart:753-763`, a
`menu_book` icon, a title, a chevron.

Replace it with a **shelf**: a horizontally scrolling strip of four small book
cards, one per section, each in `bookPaper` with its illustration and its
English section title, under a single MSA heading `وصفات رحمة`. Tapping a card
opens E05 scrolled to that section.

Everything else on E01 is unchanged. The `DayCard`, the suggestions, the
`SayOrTypeBox`, the guard note all stay exactly as they are. **This screen is
not restyled.** It is the logging screen; the book lives one tap away. Restyling
the whole tab pink would mean restyling the day totals pink, and the day totals
are not a recipe book.

Keeps `AppArt.buddhaBowl` as its screen art.

### E05 — The recipe book (rebuilt)

Replaces `recipes_view.dart` entirely.

- `PaperPage(color: BookInk.bg)` as the ground, so the existing grain painter
  gives the pink its texture.
- A `CustomScrollView` with four `SliverStickyHeader`-style section headers:
  each is a compressed version of the book's divider — the large illustration,
  the English title stacked in `bookRoseTitle` at `EditorialType.cover`, and the
  PS line beneath in `bookInkSoft`. The two or three small foot illustrations
  from the book appear only when the header is expanded at the top of its
  section, not when it pins.
- Under each header, the recipe cards, **one per row** at phone width. Two per
  row is the book's layout on a 1057 pt page and it produces a 170 pt card on a
  390 pt phone, which fails at 1.6x text. One per row.
- Each card: `HandSurface` in `bookPaper`, two clips, the English title in
  `bookInk` wrapped LTR, the illustration at `AlignmentDirectional.topStart`
  overlapping the title as in the book, and beneath it a two-line summary in
  MSA: time, protein, EGP. Those three are `RecipeRow`'s existing fields and
  `recipes_view_test.dart:49` already requires the EGP one.
- **The filter chips stay**, as `AppChipRow`, but above the first header, and
  the vocabulary grows: `عالي البروتين`, `أقل من ٢٠ دقيقة`, `اقتصادي`, `رمضان`,
  and new: `بدون فرن`, `جاهز في الثلاجة`, `بدون مكسرات`. `ramadan` currently
  returns `false` at `recipes_view.dart:79` because no recipe carries the tag;
  with `dietTags` authored it can start returning something true.
- **A search field**, because `RecipesView` has a search `IconButton` today that
  the router never wires (`app_router.dart:1352-1363` passes no `onSearch`) and
  therefore does nothing. Searching `titleSearch[]` over a 50 KB index is
  instant and local.
- A footer row to E07 (week plan), unchanged.
- A footer row to **E11**, "رسالة من رحمة".
- Screen art: keep `[AppArt.pasta, AppArt.bowlPotato]`.

**Allergy behaviour on this screen.** If she has declared allergies, matching
recipes are absent, and a single MSA line sits at the foot of the list saying how
many were hidden and why, with a link to change her answer. Hiding silently is
worse than hiding visibly. The existing `l10n.weCannotCheckTheseDishesForWhat`
string covers the unreviewed case.

### E06 — A recipe (rebuilt)

Replaces `recipe_view.dart`. Today it is built from the *food* pack because the
recipe pack does not exist (`recipe_view.dart:73-75`); now it is built from the
recipe.

Top to bottom:

1. **The card.** `bookPaper`, two clips, illustration at `topStart`, English
   title in `bookInk` inside an LTR span, Arabic title beneath in
   `bookRoseTitle` when `titleAr != null`.
2. **A two-segment control** directly under the title, MSA labels:
   `المقادير والخطوات` (default) and `زي ما هي في الكتاب`. The choice is
   remembered per woman in `shared_preferences`, which is already the one local
   store (`pubspec.yaml`).
3. **Tab A.**
   - The facts strip: `{n} دقيقة`, `{n} ج بروتين`, `{n} سعر`, `{n} جنيه/حصة`,
     each **only when non-null**, each a parameterised ARB string so
     `baked_in_samples_test` stays green. `egpPricedAt`'s month renders beside
     the EGP figure.
   - Allergens: a row of MSA chips naming what it contains. Present on every
     recipe, including when the set is empty, where it reads
     `لا يحتوي على أي من الـ١٦`. An unreviewed recipe shows
     `l10n.weCannotCheckTheseDishesForWhat` instead, and no chips.
   - Advisories: `pregnancy_liver` and `g6pd_fava` render as an MSA note in a
     `HandSurface(level: HandLevel.structural)` with `HandInk.print`, visually
     unlike the card.
   - **المقادير**: her `qtyTextAr` at full size, grams muted beside it,
     `اختياري` marked, serving sides in their own short group under
     `يتقدم مع`. Brand hints in her words, in brackets.
   - **الخطوات**: her `textAr` verbatim, numbered as she numbered, with a timer
     chip and a temperature chip where known. Components (`Chocolate sauce`,
     `البشاميل:`) render under their own headings, as the book prints them.
     Variants render as a second toggle, only on `rahma_cheese_cake`.
   - `closingAr` in `HandNote` with `ArefRuqaa`, tilted, outside the numbering.
   - The standing disclaimer at the very foot, MSA, small: "المقادير من رحمة.
     راجعي ملصق كل منتج بنفسك قبل الاستخدام."
4. **Tab B.** `bodyAr` as one block on the card, with the illustration and the
   clips. No extraction, no numbering beyond hers, no chips. This is the page.
5. **Cook mode**, a toggle at the top of Tab A: one step at a time, larger type,
   a big next control, a running timer when the step has one.
6. **Footer buttons**, as today: `cookedItLogMyBowl` (which logs through
   `MealLogService` with `origin: MealOrigin.recipe`, unchanged) and a share.
   The portion picker stays. `onSeeSteps`, which currently shows
   `showHonestNotice(l10n.theStepsForThisDishHaveNot)`, is deleted, because the
   steps now exist.
7. **No `AppNavBar`**, as today.

Screen art: keep `[AppArt.buddhaBowl]`.

### E10 — "Is there anything you cannot eat?" (new)

Stands in front of the book the first time she opens E05, and sets
`DietaryProfile.asked`.

**Corrected from "shown once, the first time she opens E05".** That sentence
described an automatic push, and what ships is a gate: until `asked` is true,
E05 renders none of Rahma's cards and puts one row where they would be, which
opens E10. The effect the plan was buying is intact — no allergen-tagged recipe
is reachable before the question is answered — and it is bought without pushing
a route out of a `build`, which is what an automatic open would mean.

A QA pass read "shown once, on first open" alongside the fact that **E10 is not
in `app_router.dart`'s `firstRunStates`** and concluded the wiring was missing.
It is not, and E10 must stay out of that set. `firstRunStates` is not a list of
screens shown at first run: it is the six-plus-two **day-one renderings of a
tab whose collection is empty** (`T06`, `E09`, `M17`, `K24`, `W11`, `B14`,
`Y11`, `Y14`), and its whole purpose is that `appDestinations` excludes them so
nothing can navigate to "Home, empty" while Home is not empty. Adding E10 would
make it unroutable and take the question away entirely. `routing_test.dart`
pins the set for exactly this reason.

The two rows on E05 and the one on A02 are therefore the complete and correct
set of ways in.

- MSA heading, MSA body, one sentence of why.
- Sixteen allergen chips, multi-select, each with its Arabic name.
- Two dietary chips (`everything`, `vegetarian_weekdays`), unchanged.
- **An explicit `لا، ولا حاجة`** which writes `asked: true, allergies: {}`.
  That is an answer.
- `تقدري تغيّري ده في أي وقت من حسابك` with a link to A02.
- **No skip that leaves `asked` false.** Dismissing by back button leaves it
  false and the library stays hidden behind the question, which is the honest
  fail-closed behaviour.
- **Not a dialog.** `product_rules_test.dart:325` bans `showDialog` and
  `AlertDialog` under `lib/features/`. A route, or `showAppSheet`.
- Route: `'E10': AppRoute(name: '/eat/e10', flow: 'eat', title: "What you cannot eat")`.
- Screen art: something neutral, not food. `AppArt.fruitBasket` is the least
  judgemental in the set.

### E11 — A message from Rahma (new)

The closing letter, p26. Her 120 words on why we try to eat well, on the pink
paper, in her hand, with her sign-off and the heart outline the book draws
beneath it. Nothing else. No buttons except back.

- Route: `'E11': AppRoute(name: '/eat/e11', flow: 'eat', title: "A message from Rahma")`.
- Reached from the foot of E05. That is three taps from the tab bar, so it may
  need an entry in `nav_reachability_test.dart`'s exemption list; check the 80%
  budget at line 474 before assuming.
- Screen art: none, or `AppArt.fruitSalad`. It should not compete with the
  letter.

### E07, E08 — Week plan, grocery list (unchanged in this phase)

They will want the book's styling and the grocery list will want to be
buildable from a recipe's `ingredients[]` with real grams. Both are out of
scope here and are named in §7.

---

## 5. Acceptance criteria

For the QA agent. Each is a single checkable claim.

### Content fidelity

1. The seed contains exactly **39** recipes with `source: book`.
2. The seed contains exactly **4** sections, whose `titleEn` and `psLineEn` match
   §1.1 character for character, including `fulling` and the missing `PS:` on
   section 3.
3. Every `titleEn` matches §1.2 character for character, including `shorbt 3ads`,
   `Btates bel lahma`, `Fool & Ta3mya` and `Cookies with shay blabn`.
4. `rahma_cheese_cake` has exactly **2** entries in `variants[]`.
5. `rahma_crepe` has a component with `componentId: 'chocolate_sauce'`.
6. `rahma_kebda_meal` has a component for `طحينه لايت`.
7. No recipe has `sourcePage == 21`. (Page 21 is a duplicate of page 20.)
8. For every recipe and every step, `steps[i].textAr` is a substring of
   `bodyAr`. **This is the test that proves nothing was rewritten.**
9. Every `qtyTextAr` is a substring of `bodyAr`.
10. No `bodyAr`, `textAr`, `qtyTextAr` or `closingAr` value appears in either ARB
    file.
11. No section title or PS line appears in either ARB file.

### Safety

12. `AllergenTag` has 16 members, and `AllergenTag.fromWire` accepts `nuts`,
    `dairy`, `gluten` and `shellfish` as aliases.
13. Every published recipe has `allergenReviewedBy != null` and
    `allergenReviewedBy != authoredBy`.
14. Every ingredient on every published recipe has `foodId != null`.
15. Every entry in `allergensRemoved` has a non-empty reason string.
16. The tripwire (§3.4 layer 3) reports zero unexplained hits across all 39.
17. `rahma_fool_wa_ta3mya.advisories` contains `g6pd_fava`.
18. `rahma_kebda_meal.advisories` contains `pregnancy_liver`.
19. Every recipe containing poultry, mince, liver, eggs or shellfish has a
    non-null `doneness`.
20. `AllergyGuard.screen()` removes every recipe whose `allergensFinal`
    intersects a declared allergy, case-insensitively.
21. A recipe with `allergenReviewedBy == null` is never returned to a woman with
    any declared allergy.
22. No string anywhere in the feature asserts that a dish is safe for her. Grep
    the ARB for `آمن` and `safe for`.
23. `app/test/features/eat/allergy_interlock_test.dart` passes, **unmodified**.
24. E10 is reachable, and `AppRouter.eatConstraints` returns a profile with
    `asked: true` after she answers, including when she answers "nothing".

### Quantities and figures

25. No published recipe has an ingredient with `gramsBasis == unknown` unless it
    is `optional` or `servingSideOnly`.
26. No `gramsBasis == estimated` ingredient contributes over 20 kcal.
27. Every recipe with `macroBasis: computed` has all four macro fields non-null;
    every recipe with `macroBasis: withheld` has all four null.
28. No macro field is rendered when it is null. The screen shows nothing, not a
    zero and not a dash.
29. Every recipe with `egpPerServing != null` has `egpPricedAt != null`, and no
    `egpPricedAt` is older than 180 days.
30. `app/test/baked_in_samples_test.dart` passes with its ceiling **unchanged at
    117**.

### Design and accessibility

31. `#D3737E` appears nowhere in `lib/`.
32. `BookInk.ink` on `BookInk.paper` measures at least 7:1; `BookInk.roseTitle`
    on `BookInk.paper` at least 4.5:1 and on `BookInk.bg` at least 3:1.
33. Every English recipe title renders inside an explicit
    `Directionality(TextDirection.ltr)` in an Arabic build.
34. In an Arabic build, the card illustration sits at the top **right**; in
    English, top **left**. Same widget, no branch.
35. `app/test/qa/large_text_sweep_test.dart` passes for E05, E06, E10 and E11 at
    1.6x in both locales.
36. Every interactive element on E05, E06 and E10 has a hit area of at least
    48x48.
37. The clips, the illustration and every hand mark are excluded from the
    semantics tree; `bodyAr`, `textAr` and `qtyTextAr` are in it.
38. With `disableAnimations` on, no card animates in.
39. `app/test/theme/screen_art_test.dart` passes with E10 and E11 registered.
40. `app/test/theme/app_art_test.dart` passes: every `artKey` on every published
    recipe exists in `AppArt` at 1x, 2x and 3x, and every shipped file is
    claimed.
41. `app/assets/art/LICENCE.md` exists and names a licence, a source and a date
    for every file under `app/assets/art/`.

### Structure and routing

42. `app/test/routing_test.dart` passes with its pinned counts updated to 179
    and 171, and both new routes have unique absolute names.
43. `app/test/qa/tap_crawler_test.dart` passes: no tap on E05, E06, E10 or E11
    throws or lands on a placeholder.
44. `app/test/nav_reachability_test.dart` passes, including the two-tap budget at
    line 474.
45. `app/test/product_rules_test.dart` passes. In particular, **no file under
    `lib/features/` contains `showDialog` or `AlertDialog`.**
46. `app/test/i18n_guard_test.dart` passes. No new entry in the three-item
    Arabic allowlist, and no `presentation/` path in it.
47. `app/test/features/eat/recipes_view_test.dart` still passes, including
    "every card carries its cost per serving in EGP" and "a recipe opens by id,
    not by position".

### Tiering

48. `Feature.recipeTiering` exists, its `parent` is `Feature.payments`, and
    `FeatureFlags.shipped.isOn(Feature.recipeTiering)` is `false`.
49. Every seeded recipe has `tier: 'free'`.
50. No paywall, price, "upgrade" affordance or locked card appears anywhere in a
    shipped build.
51. The emulator rules suite proves a client cannot write
    `users/{uid}/private/entitlement`.
52. The emulator rules suite proves a `recipes` write is refused when
    `allergenReviewedBy` is null or equals `authoredBy`.

### Scale

53. Opening E05 from cold performs **one** Firestore document read (the index),
    or zero when the cached `meta/recipes` version is current.
54. Opening a recipe performs at most one read, and zero on a second open in the
    same session.
55. The added bundle size is under 1 MB, measured as the delta in
    `flutter build apk --analyze-size`.
56. The Eat tab, E05 and E06 all work with the network disabled, from the seed.

---

## 6. Implementation order

`[P]` marks work that can run in parallel with anything else at the same step.

### Step 0 — blocking, sequential

**0.1** Get owner decisions on §8 items 1, 2, 3 and 7. Nothing downstream is
safe to build without 1 and 2.

**0.2** Resolve the `app/assets/art/` licence question. This blocks shipping,
not building.

### Step 1 — content, no app code

**1.1** Transcribe the 39 recipes into `rahma_recipes.json` from the extracted
text at `/tmp/rb/book.txt` and the page renders at `/tmp/rbpages/`. Verbatim.
`bodyAr`, `titleEn`, `sourcePage`, `sectionId`, `orderInSection` only. No
splitting yet. **A human who reads Arabic must diff every one against the page
render**, because `pdftotext` on right-to-left Canva output reorders. `[P]`

**1.2** Build `app/tool/household_measures.ar-EG.json`. Weigh things. Record
product, date and person per row. `[P]`

**1.3** Write the §1.5 question list to Rahma and get answers: the five recipes
with no quantities, the five with no temperature, the `Club Sandwich` bread, the
39 Arabic titles, the 4 Arabic section titles.

**1.4** Split `bodyAr` into `steps[]` and lift `ingredients[]`. Every `textAr`
and `qtyTextAr` a verbatim substring. Assign `foodId` to every ingredient,
creating `foods` rows where they do not exist.

**1.5** Derive grams. Run `derive_grams.py`. Fill `gramsBasis` honestly.

**1.6** Compute `allergensDerived`, author `allergensExtra`, write
`allergensRemoved` reasons, author `advisories` and `doneness`. **A second
person reviews and signs.**

**1.7** Run the tripwire. Clear every hit.

### Step 2 — domain, parallel with step 1 from 1.1 onward

**2.1** `AllergenTag` to 16 with aliases + tests. `[P]`

**2.2** `app/lib/features/eat/domain/recipe.dart`, the §2.2 model, pure Dart,
`@immutable`, no Flutter import + tests. `[P]`

**2.3** `app/lib/features/eat/data/seeded_recipe_library.dart`, the bundle
loader, with a Firestore-wins-on-version merge + tests. `[P]`

**2.4** `RecipeAccessGate` + `Feature.recipeTiering` with
`parent => Feature.payments` + tests. `[P]`

**2.5** Extend `AllergyGuard` to screen recipes as well as foods, including the
`allergenReviewedBy == null` rule + tests. `[P]`

**2.6** Extend `content_schema.dart:_recipes` per §2.8 + update
`content_schema_test.dart` and `seed_library_test.dart`. `[P]`

### Step 3 — the safety interlock, sequential, gates step 5

**3.1** Build E10. Route, screen art entry, routing counts.

**3.2** Wire `AppRouter.eatConstraints` so `asked` becomes true only through a
real answer.

**3.3** Confirm `allergy_interlock_test.dart` still passes **unmodified** with
allergen-tagged content present.

### Step 4 — design foundation, parallel with steps 1 to 3

**4.1** `app/lib/theme/recipe_book_tokens.dart` with the measured palette and
the `#7F454C` replacement + a contrast test. `[P]`

**4.2** `BookCard`, a `HandSurface` configuration plus a clip painter, in
`app/lib/ui/hand/` beside the existing marks. RTL, `ExcludeSemantics`, tested at
1.6x. `[P]`

**4.3** Illustration mapping: confirm the 16 in §1.6 by eye, commission or
source the missing 27, write `LICENCE.md`. **Long lead time; start at step 0.**
`[P]`

**4.4** Add `flutter_svg` if §8 item 6 is approved, or keep WebP. `[P]`

### Step 5 — screens, after steps 2, 3 and 4

**5.1** E05, the book. Route already exists.

**5.2** E06, the card, both tabs, cook mode.

**5.3** E01's shelf strip. `[P]` with 5.2.

**5.4** E11, the letter. `[P]` with 5.2.

**5.5** All strings through `add_strings.py`, one run, one lock. It takes
`/tmp/ownhub-l10n.lock` and retries 600 times; **do not run two instances**.
Read back the generated getter names, because short words collide and get
fingerprinted.

### Step 6 — back end, parallel with step 5

**6.1** `recipes` rules per §3.6, including the two-person check. `[P]`

**6.2** `users/{uid}/private/entitlement` rules, client-read-only. `[P]`

**6.3** The `recipeIndex` and `meta/recipes` documents and a build script that
emits them from the seed JSON. `[P]`

**6.4** Field exemptions in `firestore.indexes.json` for the recipe fields that
the index document already answers. `[P]`

**6.5** Emulator rules tests. `[P]`

### Step 7 — the pinned numbers, last

**7.1** `routing_test.dart` 177 to 179 and 169 to 171.

**7.2** `screen_art.dart` entries for E10 and E11.

**7.3** Full suite: `flutter test`, then `flutter test --tags qa`, then
`app/tool/release_preflight.sh`.

### The critical path

`0.1 → 1.3 → 1.4 → 1.6 → 3.1 → 3.3 → 5.1 → 5.2 → 7.3`

Everything else fits around it. **4.3, the illustrations, has the longest lead
time and no dependencies. Start it on day one.**

---

## 7. What I am not proposing, and why

1. **Not 200+ recipes at launch.** §3.5. The count is achievable only by
   inventing, and this repo has decided, five times over, not to invent content
   that reaches a woman's phone. The honest number is 50 of hers plus a
   separately-labelled set of assemblies.

2. **Not a paywall.** §3.6. `Feature.payments` is off, there is no billing back
   end, `CheckoutOutcome` has no `paid` variant. A gate that cannot be opened is
   worse than no gate. I propose the entitlement model and the rules, inert.

3. **Not a dark mode for the recipe surface.** The app has no dark mode at all
   (`ColorScheme.light` only, no `darkTheme`, no `ThemeMode`). Building one for a
   single tab would make Eat the only dark screen in a light app. The dark
   palette is recorded in the token file as a comment for when the app gets one.

4. **Not extracting the PDF's illustrations.** §3.7(a). Canva's licence forbids
   extracting an element as a stand-alone asset. This is not a risk assessment;
   it is the licence text.

5. **Not translating her Arabic to MSA.** §3.1. The colloquial is what the owner
   is buying. MSA in a recipe body would read like a ministry leaflet and would
   make the book worth less than the PDF it came from.

6. **Not rewriting her steps into imperative recipe prose.** §3.2. The steps are
   split at her own numbering and every `textAr` is asserted to be a substring of
   `bodyAr`. The structured view is an index into her words, not a replacement
   for them.

7. **Not computing gram conversions at runtime.** §3.3. An Egyptian `علبة زبادي`
   is not a US tub and a generic table gets it wrong by about 40 kcal, nine times
   over. Grams are authored per ingredient with a recorded basis.

8. **Not inferring allergens from a name.** §3.4. Every allergen is derived from
   a `foodId` with a verified set, extended by a human, signed by a second human,
   and cross-checked by an independent keyword tripwire.

9. **Not photography.** There is none and shooting 39 dishes is a production, not
   a task. The illustrations are the book's own language and they scale.

10. **Not restyling E01, E07 or E08 in this phase.** E01 is the logging screen and
    the day totals are not a recipe book. E07 and E08 want the treatment and want
    to be built from real `ingredients[]`; they are a second phase.

11. **Not a new recipe *photo* field or Storage path.** `photoFile` exists in the
    schema and stays empty, as it already is on all nine seeded recipes.

12. **Not `wakelock_plus`** unless the owner wants cook mode to hold the screen
    awake. Without it, cook mode still works and the screen sleeps.

13. **Not touching `allergy_interlock_test.dart`.** It is correct. The plan
    satisfies it by ordering, which is what its own failure message asks for.

14. **Not removing or "correcting" anything she wrote.** `fulling`, `shorbt 3ads`,
    the missing `PS:` on section 3, the duplicated spread's second copy (dropped
    as a duplicate, not as an error in her text). Her spelling is hers.

---

## 8. Owner decisions

These are guesses I refuse to make.

| # | Decision | Blocks | My recommendation |
|---|---|---|---|
| 1 | **Where does the allergy question go: onboarding, or first open of the recipe library?** | Everything. §3.4. | First open of the library, because that is the moment it is true. |
| 2 | **Who is the second person who signs every allergen review?** It cannot be whoever authored the recipe. | Publication of any recipe. §3.4. | A named person with a role, not "whoever is free". |
| 3 | **Is a paid tier in v1?** If yes, what EGP price per month and per year? | §3.6, and the App Store listing copy. | Not in v1. Ship everything free, build the model, sell when billing exists. |
| 4 | **Does `artKey` on a recipe card violate the "no treats on food screens" rule she wrote?** | §3.7, the illustration mapping. | It does not: a picture of the dish is a label, not a nudge. But it is her rule. |
| 5 | **Rubik, or add Baloo Bhaijaan 2 (SIL OFL 1.1, Latin + Arabic, rounded)?** | §3.7. | Rubik 700 first. Add Baloo only if the rounded look is felt to be missing. |
| 6 | **Commission 27 illustrations as work for hire, or licence a set?** And may we add `flutter_svg`? | §3.7, step 4.3, the longest lead time. | Commission, work for hire, copyright assigned. SVG, which is a tenth of the bundle cost. |
| 7 | **The seven brand names.** Keep as `brandHint`, or strip? | §1.5.5. | Keep as her aside, point the `foodId` at the generic. |
| 8 | **Is `kCheapEgp = 15` still a meaningful "cheap" threshold in 2026 Egypt?** | The `اقتصادي` filter. | Almost certainly not. Needs a number from someone who shops. |
| 9 | **Does the free tier keep working offline after a lapsed subscription?** | §3.6. | Yes. The seed is on her phone; taking it back is ugly. |
| 10 | **Where did `app/assets/art/` come from and under what licence?** 57 files already shipping, no licence record, and `cupcake.webp` is byte-identical to a Canva-produced book. | Shipping, today, independent of this plan. | Find out before the next release. |
| 11 | **Rahma must author 39 Arabic recipe titles and 4 Arabic section titles.** | The Arabic build's titles. §1.5.9. | Until they exist, show her English title in an LTR span, which is what she did. |
| 12 | **Rahma must answer the §1.5 gaps**: quantities for 5 recipes, temperatures for 5, the `Club Sandwich` bread. | Publication of those recipes. | They stay `status: review` and out of the library until she answers. |

---

## Appendix — working files

| What | Where |
|---|---|
| Extracted text, whole book | `/tmp/rb/book.txt` |
| Page renders, 26 pages at 80 dpi | `/tmp/rbpages/pg-01.png` to `pg-26.png` |
| Source PDF | `/Users/mahmoudreda/Downloads/Rahoma's Recipe Book.pdf` |

Re-render with:

```
pdftotext -layout "Rahoma's Recipe Book.pdf" book.txt
pdftoppm -png -r 80 "Rahoma's Recipe Book.pdf" pages/pg
```

Colour sampling was done by cropping with `sips -c 1 1 --cropOffset Y X` and
decoding the resulting PNG in Python; there is no ImageMagick and no PIL on this
machine.
