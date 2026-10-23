"""Which food each ingredient row is, and how many grams of it.

Read by `build_rahma_recipes.py`. One entry per book recipe, one row per
ingredient in the order `build_rahma_recipes.py` lists them. The macros of a
recipe are the sum of these rows over the food pack
(`assets/content/foods_eg.json`), divided by `serves`.

## What the two weight bases mean here

  * `S` (stated): the grams are the book's own figure, or an exact conversion of
    her unit: a tablespoon or a cup of a known food, an egg at 50 g, a USDA
    household weight (a medium tomato is 123 g), the pack weight the food pack
    already uses (a can of tuna is 107 g drained).
  * `E` (estimated): the book gives no weight and no unit that converts, so the
    amount is ours: a pinch of seasoning, the size of a yoghurt tub, how much
    chicken a card that names no amount means. Said on the row in `gramsNote`
    and again in the recipe's `reviewNotes`. Every recipe that rests on such an
    amount carries that note, so the figure is never read as hers.

## Units

A spoon without a qualifier is a tablespoon (15 ml) and `معلقة صغيرة` is a
teaspoon (5 ml); a cup is 240 ml; milk weighs 1.03 g a millilitre. Rolled oats
are 80 g a cup and 3 g a teaspoon of oat flour. These are the conversions
behind the `S` rows, and the only ones.

## What is left out of the sum

A row that is optional, or only a serving suggestion, or the second of two
alternatives (`skip`), is not counted: the recipe's figures describe the dish
she wrote without them. The alternatives are named in `reviewNotes`.

## The negligible class

Salt, pepper, a pinch of cumin or paprika, a stevia sachet, vanilla, a clove of
garlic, parsley, a few drops of vinegar: a gram or two each, never more than a
few kcal a serving. They share one food, `spices_and_seasoning`, instead of a
dozen pack entries that would each be rounded away. Salt and water, which weigh
enough to matter on the scale and carry no energy, have their own.
"""

NEG = "spices_and_seasoning"


def S(food, grams, note="", **flags):
    return dict(food=food, grams=grams, basis="stated", note=note, **flags)


def E(food, grams, note="", **flags):
    return dict(food=food, grams=grams, basis="estimated", note=note, **flags)


TUB = "a tub of Greek yoghurt, 150 g assumed"
BIG_TUB = "a large tub of Greek yoghurt, 200 g assumed"

LINKS = {
    "rahma_lazy_cake": dict(serves=1, rows=[
        S("egg_whole", 50, "1 egg = 50 g"),
        E(NEG, 1, "stevia sachet"),
        S("baking_powder", 7, "half a tablespoon"),
        S("oats_rolled", 6, "2 teaspoons of oat flour, 3 g each"),
        S("cocoa_powder", 5, "1 tablespoon"),
        S("greek_yoghurt", 15, "1 tablespoon"),
    ]),
    "rahma_pancakes": dict(serves=1, rows=[
        S("egg_whole", 50, "1 egg = 50 g"),
        E(NEG, 1, "stevia sachet"),
        S("oats_rolled", 9, "3 teaspoons of oat flour, 3 g each"),
        S("milk_full", 31, "2 tablespoons = 30 ml"),
    ]),
    "rahma_chia_pudding": dict(serves=1, rows=[
        S("chia_seeds", 18, "3 teaspoons, 6 g each"),
        S("milk_full", 124, "half a cup of milk, the higher of her two choices"),
        S("yoghurt_baladi", 31, "2 tablespoons = 30 ml"),
        E(NEG, 1, "vanilla drops"),
        S("cocoa_powder", 5, "1 tablespoon"),
        E(NEG, 1, "stevia sachet"),
    ]),
    "rahma_coconut_apple_pudding": dict(serves=1, rows=[
        E("greek_yoghurt", 200, BIG_TUB),
        S("rice_cakes", 18, "2 cakes, 9 g each"),
        E(NEG, 1, "stevia sachet"),
        E(NEG, 1, "vanilla drops"),
        E(NEG, 1, "a pinch of cinnamon"),
        S("coconut_shredded", 1, "half a teaspoon"),
        E("apple", 60, "small cubes, about a third of an apple"),
    ]),
    "rahma_overnight_oats": dict(serves=1, rows=[
        S("oats_rolled", 40, "her 40 g"),
        S("greek_yoghurt", 150, "her 150 g"),
        S("milk_full", 103, "100 ml of milk"),
        E(NEG, 1, "a pinch of cinnamon"),
        E(NEG, 1, "vanilla"),
        S("raisins", 10, "her 10 g"),
        S("almonds", 10, "her 10 g of chopped nuts, counted as almonds"),
    ]),
    "rahma_simple_oat_meal": dict(serves=1, rows=[
        S("greek_yoghurt", 170, "her 170 g"),
        S("oats_rolled", 30, "her 30 g"),
        S("strawberries", 100, "her 100 g of strawberries or apple, counted as strawberries"),
        E(NEG, 1, "a pinch of cinnamon"),
        S("honey", 8, "her 5 to 10 g, optional"),
    ]),
    "rahma_club_sandwich": dict(serves=1, rows=[
        S("turkey_smoked", 56, "2 slices of 28 g"),
        S("mozzarella_light", 15, "her 15 g"),
        E("zaatar_mix", 1, "a pinch"),
        E("bell_pepper_red", 15, "one thin slice"),
        E("lettuce", 20, "2 slices of lettuce"),
        E("tomato", 80, "tomato and cucumber together, counted as tomato"),
    ]),
    "rahma_yummy_egg_sandwich": dict(serves=1, rows=[
        S("olive_oil", 5, "1 teaspoon"),
        S("egg_whole", 100, "2 eggs = 100 g"),
        S("toast_ww", 25, "1 slice"),
        S("tomato", 123, "1 medium tomato (USDA 123 g)"),
    ]),
    "rahma_cottage_freshy_salad": dict(serves=1, rows=[
        E("lettuce", 40, "a few leaves"),
        E("tomato", 100, "diced tomato, amount not in the book"),
        S("gebna_areesh", 150, "her 150 g"),
        S("grapes", 50, "10 grapes of 5 g"),
        E("zaatar_mix", 1, "a pinch"),
        E("olives_green", 10, "2 small olives"),
        S("toast_ww", 25, "1 slice"),
    ]),
    "rahma_lazy_ranch_fries": dict(serves=1, rows=[
        E("greek_yoghurt", 150, TUB),
        E(NEG, 3, "a minced clove of garlic"),
        E(NEG, 3, "fresh parsley"),
        E(NEG, 1, "salt and pepper"),
        S("potato_raw", 170, "1 medium potato"),
        E("olive_oil", 2, "a light spray"),
        E("spice_blend_store", 3, "her shop-bought potato seasoning"),
    ]),
    "rahma_creamy_cottage_cheese": dict(serves=1, rows=[
        S("gebna_areesh", 250, "her quarter of a kilo"),
        S("yoghurt_baladi", 31, "2 tablespoons = 30 ml"),
        E("bell_pepper_red", 60, "half a pepper"),
        E("zaatar_mix", 3, "1 tablespoon, optional"),
        S("salt", 1, "a pinch"),
        S("olive_oil", 5, "1 teaspoon"),
        S("toast_ww", 25, "1 slice"),
        S("egg_whole", 100, "2 eggs = 100 g"),
    ]),
    "rahma_egg_pizza": dict(serves=1, rows=[
        S("egg_whole", 100, "2 eggs = 100 g"),
        E(NEG, 1, "salt and pepper"),
        E("olive_oil", 3, "a light smear, amount not in the book"),
        S("tortilla_ww", 41, "1 tortilla"),
        E("mozzarella_light", 15, "a sprinkle, amount not in the book"),
        E("olives_green", 8, "one small olive"),
        E("tomato", 60, "a few slices, amount not in the book"),
        E("bell_pepper_green", 30, "a few slices, amount not in the book"),
    ]),
    "rahma_shakshoka": dict(serves=1, rows=[
        S("egg_whole", 100, "2 eggs = 100 g"),
        S("tomato", 182, "1 large tomato (USDA 182 g)"),
        S("bell_pepper_green", 60, "half of a 120 g pepper"),
        S("onion_raw", 28, "a quarter of a 110 g onion"),
        S("olive_oil", 5, "1 teaspoon"),
        E(NEG, 2, "cumin, black pepper and paprika"),
        S("aish_baladi", 45, "half a loaf, her serving suggestion", side=True),
    ]),
    "rahma_fool_wa_ta3mya": dict(serves=1, rows=[
        S("ful_medames", 150, "her 150 g"),
        S("tomato", 62, "half of a 123 g tomato"),
        S("bell_pepper_green", 60, "half of a 120 g pepper"),
        E(NEG, 5, "lemon and cumin"),
        S("olive_oil", 5, "1 teaspoon"),
        E("taameya", 60, "2 baked pieces, 30 g each assumed"),
        S("aish_baladi", 45, "half a loaf, her serving suggestion", side=True),
    ]),
    "rahma_potato_w_eggs": dict(serves=1, rows=[
        S("potato_raw", 150, "her 150 g"),
        S("egg_whole", 100, "2 eggs = 100 g"),
        S("bell_pepper_green", 60, "half of a 120 g pepper"),
        S("onion_raw", 28, "a quarter of a 110 g onion"),
        E(NEG, 2, "cumin and paprika"),
        S("olive_oil", 5, "1 teaspoon"),
    ]),
    "rahma_pizza_toast": dict(serves=1, rows=[
        S("toast_ww", 50, "2 slices"),
        S("gebna_areesh", 60,
          "her 60 g; the first of her two cheeses (light mozzarella is higher in fat)"),
        E("tomato", 40, "a few slices, amount not in the book"),
        E("bell_pepper_green", 20, "a few slices, amount not in the book"),
        E("zaatar_mix", 1, "a pinch"),
    ]),
    "rahma_chicken_pizza": dict(serves=1, rows=[
        E("frakh_pane", 180, "2 pane fillets of 90 g, size assumed"),
        E(NEG, 2, "salt, pepper and paprika"),
        S("tortilla_ww", 41, "1 tortilla"),
        S("tomato_sauce", 16, "1 tablespoon"),
        E("mozzarella_light", 20, "a sprinkle, amount not in the book"),
        E("zaatar_mix", 1, "a pinch"),
    ], notes=["The card names what goes on the pizza and not how much: the pane, "
              "the cheese and the sauce are our assumed amounts."]),
    "rahma_bbq_burger": dict(serves=1, rows=[
        E("beef_mince_lean", 120, "one burger, 120 g assumed"),
        E(NEG, 1, "salt and pepper"),
        E("onion_raw", 60, "onion rings, amount not in the book"),
        E(NEG, 1, "stevia sachet"),
        S("toast_ww", 25, "1 slice"),
        S("mozzarella_light", 15, "her 15 g"),
        S("protein_crisps", 20, "her 20 g, optional"),
    ]),
    "rahma_hwawshi": dict(serves=1, rows=[
        E("beef_mince_lean", 120,
          "the card gives no amount; 100 g mince with 20 g onion, pepper and parsley"),
        E("aish_baladi", 90, "one loaf, size assumed"),
    ], notes=["The card names the filling and gives no amounts: the mince and "
              "the bread are our assumed amounts."]),
    "rahma_chicken_lemon": dict(serves=2, rows=[
        E("chicken_breast_raw", 400, "two breasts, 400 g raw assumed"),
        E("olive_oil", 15,
          "1 tablespoon of oil for the marinade; the lemon, garlic and spices are seasoning"),
        E(NEG, 1, "water or stock"),
    ], notes=["The card names no amount of chicken: 400 g raw, two servings, is "
              "our assumption."]),
    "rahma_chicken_ranch_salad": dict(serves=1, rows=[
        E("frakh_pane", 180, "2 pane fillets of 90 g, size assumed"),
        E("lettuce", 60, "lettuce and other vegetables, amount not in the book"),
        E("potato_raw", 150, "cubes, amount not in the book"),
        E("olive_oil", 3, "a light spray"),
        E("spice_blend_store", 3, "her shop-bought potato seasoning"),
        S("toast_ww", 25, "1 slice"),
        E("greek_yoghurt", 60, "the ranch sauce: yoghurt, garlic, parsley"),
    ]),
    "rahma_tuna_wrap": dict(serves=1, rows=[
        S("tuna_in_oil", 107, "1 can drained (the pack's own portion); drained from oil"),
        E(NEG, 3, "salt, pepper, cumin, lemon and paprika"),
        E("onion_raw", 60, "caramelised onion, amount not in the book"),
        E(NEG, 1, "stevia sachet"),
        S("tortilla_ww", 41, "1 tortilla"),
        E("lettuce", 20, "a few leaves"),
    ]),
    "rahma_shrimp_white_pasta": dict(serves=1, rows=[
        E("shrimp_raw", 150, "amount not in the book"),
        E("olive_oil", 10, "her marinade, 2 teaspoons assumed; salt, spices and lemon are seasoning"),
        S("pasta_dry", 50, "her 50 g, dry weight"),
        E("butter", 3, "a smear"),
        E(NEG, 6, "two cloves of garlic"),
        S("milk_full", 124, "half a cup"),
        S("water", 60, "a quarter of a cup of boiled water"),
        E("stock_cube", 10, "one sachet"),
        E(NEG, 3, "fresh parsley"),
    ]),
    "rahma_steak_meal": dict(serves=1, rows=[
        E("beef_steak_raw", 160, "two small steaks, 80 g each assumed"),
        S("butter", 15, "her 15 g"),
        E(NEG, 3, "salt, pepper and rosemary"),
        E(NEG, 3, "a clove of fresh garlic"),
        S("potato_raw", 170, "1 medium potato"),
        E("lettuce", 100, "lettuce, tomato and cucumber, her serving suggestion", side=True),
    ]),
    "rahma_oven_tender_chicken": dict(serves=4, rows=[
        E("chicken_whole_raw", 800,
          "one chicken cut in four, about 800 g of meat and skin, bones not counted"),
        E("lemon_juice", 15, "salt and lemon to wash the chicken"),
        S("tomato", 246, "2 medium tomatoes"),
        S("bell_pepper_red", 120, "1 pepper"),
        S("onion_raw", 110, "1 medium onion"),
        S("salt", 27, "1.5 tablespoons"),
        S(NEG, 3, "half a tablespoon of black pepper"),
        S(NEG, 4, "half a tablespoon of cumin"),
        S(NEG, 6, "1 tablespoon of turmeric"),
        S("curry_powder", 6, "1 tablespoon"),
        S(NEG, 6, "1 tablespoon of paprika"),
        E("veg_mix_frozen", 600, "pepper, zucchini, carrot, potato, onion and tomato in the tray"),
    ], notes=["The card is for a whole chicken cut in four; four servings is our "
              "assumption."]),
    "rahma_buffalo_sweet_wings": dict(serves=4, rows=[
        E("chicken_wings_raw", 600, "a kilo of wings with bone is about 600 g of meat and skin"),
        E("lemon_juice", 15, "salt and lemon to wash the wings"),
        S("onion_raw", 110, "1 medium onion"),
        S("tomato", 246, "2 medium tomatoes"),
        S("bell_pepper_red", 120, "1 pepper"),
        S("lemon_juice", 45, "the juice of one lemon"),
        S("salt", 27, "1.5 tablespoons"),
        S("curry_powder", 6, "1 tablespoon"),
        E(NEG, 1, "a pinch of garlic powder"),
        E(NEG, 2, "two stevia sachets"),
        S("honey", 21, "1 tablespoon, her alternative to the stevia", opt=True),
        E(NEG, 5, "a teaspoon of mustard"),
    ], notes=["The card is for a kilo of wings; four servings is our assumption."]),
    "rahma_makrona_bashmel": dict(serves=4, rows=[
        E("pasta_dry", 200, "half of a 400 g bag, bag size assumed"),
        S("butter", 20, "her 20 g"),
        S("oats_rolled", 8, "1 tablespoon of oat flour"),
        S("milk_half_fat", 490, "2 cups of half-fat milk = 480 ml"),
        E(NEG, 1, "a pinch of salt and pepper"),
        E("stock_cube", 10, "one sachet"),
        S("beef_mince_lean", 250, "her quarter of a kilo"),
        E("onion_raw", 70, "one small onion"),
        E(NEG, 6, "1 tablespoon of salt, pepper and paprika"),
        S("tomato", 369, "the juice of 3 medium tomatoes"),
        E("mozzarella_light", 40, "a sprinkle, amount not in the book"),
    ], notes=["The card is for half a bag of pasta and a quarter kilo of mince; "
              "four servings is our assumption."]),
    "rahma_kebda_meal": dict(serves=4, rows=[
        S("chicken_liver_raw", 500, "her half kilo"),
        E(NEG, 8, "salt, pepper, cumin, lemon and two cloves of garlic"),
        E("olive_oil", 10, "a smear of oil or ghee, 10 g assumed"),
        E("stock_cube", 10, "one sachet"),
        S("water", 100, "half a small cup of boiled water"),
        S("aish_fino", 60, "one loaf, her serving suggestion", side=True),
        E("lettuce", 100, "green salad, her serving suggestion", side=True),
        S("tahini_paste", 15, "1 tablespoon"),
        S("yoghurt_baladi", 31, "2 tablespoons = 30 ml"),
        E(NEG, 2, "garlic powder, salt and pepper"),
        E(NEG, 5, "a teaspoon of vinegar"),
    ], notes=["The card is for half a kilo of liver; four servings is our "
              "assumption. The bread and the salad are her serving suggestions "
              "and are not counted."]),
    "rahma_fattah": dict(serves=1, rows=[
        E("chicken_breast_raw", 120, "amount not in the book"),
        E(NEG, 3, "cumin, paprika, pepper and salt"),
        S("olive_oil", 7, "half a tablespoon, shared by the chicken and the bread"),
        E("aish_baladi", 45, "half a loaf, amount not in the book"),
        E("yoghurt_baladi", 60, "yoghurt sauce, amount not in the book"),
        S("tomato_sauce", 5, "1 teaspoon"),
        E("tomato", 60, "grated tomato, amount not in the book"),
        E(NEG, 3, "garlic, vinegar and cumin"),
    ], notes=["The card gives no amounts for the chicken, the bread or the "
              "sauces: they are our assumed amounts. The rice in her assembly "
              "line is not in her ingredients and is not counted."]),
    "rahma_lahma_bel_basl": dict(serves=1, rows=[
        E("beef_steak_raw", 150, "the card gives no amount; 150 g assumed"),
        E(NEG, 3, "salt, pepper, cumin, paprika and meat spices"),
        E("olive_oil", 5, "1 teaspoon assumed"),
        E("onion_raw", 110, "onion, garlic and pepper, 110 g assumed"),
        E("tomato", 123, "sliced tomato, one medium tomato assumed"),
        S("rice_basmati", 150, "her serving suggestion", side=True),
    ], notes=["The card is written as a method with no amounts: the meat, the oil, "
              "the vegetables and the tomato are our assumed amounts for one "
              "serving, and the rice is her serving suggestion, not counted."]),
    "rahma_shorbet_3ads": dict(serves=2, rows=[
        E("lentils_dry", 100, "amount not in the book; 100 g dry for two"),
        S("olive_oil", 14, "1 tablespoon"),
        E("onion_raw", 110, "one onion, with the garlic"),
        E("veg_mix_frozen", 300, "carrot, potato and tomato, amounts not in the book"),
        E(NEG, 2, "stock and spices"),
        S("butter", 5, "her 5 g, optional"),
        S("toast_ww", 25, "1 slice, her serving suggestion", side=True),
    ], notes=["The card gives no weight for the lentils or the vegetables: the "
              "lentils, onion and vegetables are our assumed amounts for two "
              "servings."]),
    "rahma_btates_bel_lahma": dict(serves=2, rows=[
        S("potato_raw", 340, "2 medium potatoes of 170 g"),
        S("olive_oil", 14, "1 tablespoon"),
        E("onion_raw", 110, "onion and garlic, amount not in the book"),
        E("beef_mince_lean", 200, "amount not in the book; 100 g a serving assumed"),
        E("tomato", 200, "pepper, tomato and tomato sauce, amounts not in the book"),
        S("mozzarella_light", 20, "her 20 g a serving, optional"),
        E("lettuce", 100, "green salad or cucumber yoghurt, her serving suggestion", side=True),
    ], notes=["The card is for two potatoes (her 20 g of cheese is 'per serving'), "
              "so two servings; the mince and the sauce are our assumed "
              "amounts."]),
    "rahma_cookies_shay_blabn": dict(serves=1, rows=[
        S("banana", 59, "half a banana"),
        S("peanut_butter", 5, "1 teaspoon"),
        E(NEG, 5, "a teaspoon of vanilla"),
        E(NEG, 1, "a pinch of cinnamon"),
        S("cocoa_powder", 5, "1 tablespoon"),
        E(NEG, 2, "two stevia sachets"),
        S("milk_full", 5, "1 teaspoon"),
    ]),
    "rahma_bagel": dict(serves=4, rows=[
        S("gebna_areesh", 250, "her quarter of a kilo"),
        S("oats_rolled", 40, "half a cup of rolled oats"),
        S("flour_white", 62, "half a cup of flour"),
        S("salt", 1, "a pinch"),
        S("baking_powder", 2, "half a teaspoon"),
        S("olive_oil", 28, "2 tablespoons"),
        S("water", 30, "a splash"),
        S("egg_whole", 50, "1 egg = 50 g"),
        E("sesame_seeds", 5, "nigella and sesame for the top"),
    ], notes=["The dough makes about four bagels; four servings is our "
              "assumption."]),
    "rahma_crepe": dict(serves=1, rows=[
        S("egg_whole", 50, "1 egg = 50 g"),
        E(NEG, 1, "stevia sachet"),
        S("oats_rolled", 16, "2 tablespoons of oat flour, 8 g each"),
        S("yoghurt_baladi", 5, "1 teaspoon"),
        S("apple", 90, "half a grated apple"),
        E(NEG, 1, "a pinch of cinnamon"),
        S("yoghurt_baladi", 31, "2 tablespoons = 30 ml"),
        E(NEG, 1, "vanilla drops"),
        S("cocoa_powder", 3, "half a tablespoon"),
        E(NEG, 1, "stevia sachet"),
        S("honey", 21, "1 tablespoon, her alternative to the stevia", opt=True),
        E("banana", 40, "a few slices, amount not in the book"),
        S("grapes", 25, "5 grapes of 5 g"),
    ]),
    "rahma_banana_pudding": dict(serves=1, rows=[
        S("oats_rolled", 6, "2 teaspoons, 3 g each"),
        S("chia_seeds", 12, "1 tablespoon"),
        E("yoghurt_baladi", 105, "a small Egyptian yoghurt cup, 105 g assumed"),
        S("water", 30, "a splash"),
        E(NEG, 1, "stevia sachet"),
        E(NEG, 1, "vanilla"),
        E(NEG, 1, "a pinch of cinnamon"),
        S("banana", 59, "half a banana"),
        S("cocoa_powder", 2, "a pinch"),
    ]),
    "rahma_cheese_cake": dict(serves=1, rows=[
        E("greek_yoghurt", 150, TUB),
        E("digestive_biscuit", 15, "one biscuit, 15 g assumed"),
        E("strawberries", 40, "strawberries for the topping"),
        S("toast_ww", 25, "1 slice (method two)", skip=True),
        E("gebna_areesh", 60, "sweet cottage cheese, 60 g assumed (method two)", skip=True),
        S("strawberry_jam", 20, "1 tablespoon (method two)", skip=True),
        E("honey", 5, "a drizzle (method two)", skip=True),
    ], notes=["The card gives two methods. The figures are for the first (Greek "
              "yoghurt, biscuit and strawberries); the second method's rows are "
              "not counted."]),
    "rahma_french_toast": dict(serves=1, rows=[
        S("egg_whole", 50, "1 egg = 50 g"),
        E(NEG, 1, "sweetener sachet"),
        E(NEG, 1, "vanilla and cinnamon"),
        S("milk_full", 31, "2 tablespoons = 30 ml"),
        S("toast_ww", 50, "2 slices"),
        E("butter", 3, "a smear"),
        E("greek_yoghurt", 150, TUB),
        E("honey", 5, "a drizzle, with the cinnamon"),
    ]),
    "rahma_ice_cream": dict(serves=1, rows=[
        E("greek_yoghurt", 150, TUB),
        E("strawberries", 100, "any fruit she likes, counted as strawberries"),
        E(NEG, 1, "vanilla drops"),
        E(NEG, 1, "stevia sachet"),
    ]),
}

# Phrases the card prints in its method that carry the amounts of a card with
# no ingredient list. `build_rahma_recipes.py` appends them to the card's rows;
# each is a verbatim slice of her text, and the screen draws none of them (the
# card says it has no list). They exist so the figures rest on named rows.
LAHMA_ROWS = [
    "اللحمة",
    "الملح، الفلفل، الكمون، البابريكا وبهارات اللحمة",
    "الزيت",
    "البصل والثوم والفلفل",
    "شرائح الطماطم",
]
