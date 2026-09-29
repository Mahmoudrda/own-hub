#!/usr/bin/env python3
"""Turn the extracted cards into `assets/content/rahma_recipes.json`.

`python3 tool/extract_rahma_book.py && python3 tool/build_rahma_recipes.py`.

## The one rule this file exists to keep

**Every Arabic string it writes is a slice of `bodyAr`.** `steps[].textAr` is a
run of her lines joined by the newline that already separated them, and
`ingredients[].qtyTextAr` is a span inside one line. Nothing is paraphrased,
nothing is translated and nothing is tidied. The builder asserts it on the way
out and `rahma_seed_test.dart` asserts it again on the way in, because a rule
that only one side checks is a rule that drifts.

The structured view is therefore an **index into her card**, not a replacement
for it. Tab B on E06 shows the card unsplit, which is the other half of the same
promise.

## What ships as `review`, and why none of it ships as `published`

All thirty-nine are `status: review`. Three gates in the model are open and none
of them can be closed by a program:

  * `allergenReviewedBy` must be a person, and must not be the person who
    authored the row. Two names, both real. Writing "qa" in that field would be
    forging a signature on an allergen check, which is the single worst
    fabrication available in this feature.
  * `ingredients[].foodId` must point into `foods`, and `foods` has no row with
    a verified `allergens[]` or per-100 g macros yet. So every `foodId` here is
    null, which blocks publication by design.
  * `cookedBy` is null on all thirty-nine. The book is evidence that Rahma
    *wrote* them, which is what `authoredBy` records. It is not a cooking log.

A `review` recipe is visible, is marked on screen as unsigned, and is **hidden
entirely from any woman who has declared an allergy** - `AllergyGuard`'s
fail-closed behaviour, extended from "allergens unknown" to "allergens unsigned".
That is the honest shape: the library is readable, and nobody is told a dish was
checked when it was not.

## Macros are withheld, not estimated

`macroBasis: withheld` on all thirty-nine, and `kcal`, `proteinG`, `carbsG` and
`fatG` are null. Summing them needs a verified `foods` row and a gram figure per
ingredient; six recipes state grams and the rest state household measures. A
computed-looking number over an uncomputed base is a fabricated figure driving a
woman's eating, which `stated_figure.dart` already refuses to do elsewhere.

## Allergens are derived from her own words

`allergensDerived` is whatever `allergen_tripwire.py` reads out of `bodyAr` plus
every slice taken from it. That is a statement about her text, reproducible by
re-running this script, and it is the only allergen claim in the file that is not
a human's. `allergensExtra` is empty on every recipe: extending the set is a
person's job and no person has done it. `allergensRemoved` carries a written
reason per tag, and the tripwire refuses to pass a recipe whose text fires a tag
that is in neither set.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from allergen_tripwire import scan  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CARDS = os.path.join(HERE, "rahma_book_cards.json")
OUT = os.path.join(HERE, "..", "assets", "content", "rahma_recipes.json")

SCHEMA_VERSION = 1
CONTENT_VERSION = 1

# Who wrote the structured view. `authoredBy` is a claim about provenance, and
# this one is supported by the book's own cover ("By : Rahma Mohsen") and its PDF
# author metadata. `allergenReviewedBy` is a different claim and is left null.
AUTHORED_BY = "rahma_mohsen"

# `_` is the recipe table. One entry per card, in printing order.
#
# splits     extra line indices where a new step begins, for the cards she did
#            not number. A human picks these; that is what `authoredBy` records.
# ing        her own quantity phrases, each a verbatim span of `bodyAr`.
#
#            **A phrase may cross one of her line breaks, and several do.** The
#            book is a Canva page: `نص معلقه` reaches the right margin and
#            `baking powder` starts the next line, and the phrase is one
#            phrase. Cutting it at the margin produced rows reading "half a
#            spoon" of nothing and a bare "ونص" - a woman scanning to shop
#            cannot buy either. So the span carries the newline, it is still
#            verbatim, and `_IngredientRow` draws it as one line.
#
#            The same holds for the two places the book offers a choice with
#            her own "أو" between two lines: one row, not two things to buy.
# ingredients_basis
#            what the page actually gives. Omitted means she gives a measure
#            for essentially everything. `"few"` means she names what goes in
#            and mostly not how much; `"none"` means the page has no
#            ingredient list at all and is written as a method. Both make the
#            screen say so out loud, instead of printing an Ingredients
#            heading over "the meat, the oil, the onion".
# timers     step number -> {min, temp, tool}, read off her own sentence.
# comp       (componentId, heading line index, last line index)
# variants   (variantId, label line index, first line, last line)
# closing    line index of her sign-off, which is never a step. Set on one card
#            only: `Club Sandwich` is the single place the book prints "والف هنا"
#            on a line of its own. Everywhere else it is the tail of her last
#            sentence, and lifting it out would cut that sentence in half.
# extra      allergens a person added beyond the tripwire. Empty everywhere: see
#            the module note.
# removed    tag -> the written reason it does not apply
_ = [
    dict(
        id="rahma_lazy_cake", section=1, page=3, mark="cake_slice",
        splits=[8], active=5, total=15,
        timers={3: dict(min=10, tool="oven")},
        ing=["بيضه و معلقة فانيلا سايله", "كيس\nstevia",
             "نص معلقه\nbaking powder", "معلقتين دقيق شوفان صغيرين",
             "معلقة كاكاو", "معلقه زبادي\nlow fat"],
        doneness="baked_egg_set", diet=["vegetarian"],
    ),
    dict(
        id="rahma_pancakes", section=1, page=3, mark="pancake_stack",
        active=10, total=10, timers={5: dict(min=2, tool="pan")},
        ing=["بيضه وعليها فانيلا سايله ورشه قرفه", "كيس stevia",
             "تلت معالق صغيرين\nدقيق شوفان", "معلقتين لبن"],
        doneness="egg_set", diet=["vegetarian"],
    ),
    dict(
        id="rahma_chia_pudding", section=1, page=4, mark="jar",
        splits=[5], active=5, total=245,
        timers={4: dict(min=240, tool="fridge")},
        ing=["تلت معالق صغيرين بذور شيا", "نص كوباية مايه او لبن",
             "معلقتين زبادي كامل الدسم", "نقطتين فانيليا سايله", "معلقه كاكاو",
             "كيس سكر Stevia"],
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_coconut_apple_pudding", section=1, page=4, mark="jar",
        splits=[2, 6], active=6, total=6,
        ing=["علبة زبادي يوناني كبيره\nاو زبادي عادي كامل الدسم",
             "2 رايس كيك", "كيس سكر Stevia", "نقطتين فانيليا",
             "رشة قرفه", "نص معلقة صغيرة\nجوز هند مبشور",
             "مكعبات صغيرة تفاح"],
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_overnight_oats", section=1, page=5, mark="jar",
        splits=[1, 2, 3, 4, 5, 6, 7], active=5, total=1445,
        timers={8: dict(min=1440, tool="fridge")},
        ing=["40 جم شوفان", "150 جم زبادي يوناني", "100 مل لبن", "قرفة",
             "فانيليا", "10 جم زبيب", "10 جم مكسرات مفرومة"],
        grams={"40 جم شوفان": 40, "150 جم زبادي يوناني": 150,
               "10 جم زبيب": 10, "10 جم مكسرات مفرومة": 10},
        diet=["vegetarian"],
        removed={},
    ),
    dict(
        id="rahma_simple_oat_meal", section=1, page=5, mark="bowl",
        splits=[2, 3, 4, 5], active=3, total=3,
        ing=["170 جم زبادي يوناني/زبادي عالي\nالبروتين", "30 جم شوفان",
             "100 جم فراولة أو تفاحة", "قرفة", "5-10 جم عسل اختياري"],
        grams={"170 جم زبادي يوناني/زبادي عالي\nالبروتين": 170,
               "30 جم شوفان": 30, "100 جم فراولة أو تفاحة": 100},
        optional=["5-10 جم عسل اختياري"],
        diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_club_sandwich", section=2, page=7, mark="sandwich",
        active=5, total=5, closing=6,
        ing=["قطعتين Turkey", "15 جرام جبنه موتزاريلا", "رشة زعتر",
             "شريحة فلفل احمر", "شريحتين خس", "طماطم وخيار"],
        grams={"15 جرام جبنه موتزاريلا": 15},
        diet=["high_protein"],
    ),
    dict(
        id="rahma_yummy_egg_sandwich", section=2, page=7, mark="sandwich",
        active=7, total=7,
        ing=["معلقة زيت زيتون صغيرة", "بيضتين اومليت", "واحدة توست محمص",
             "واحدة طماطم"],
        doneness="egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_cottage_freshy_salad", section=2, page=8, mark="salad_bowl",
        active=7, total=7,
        ing=["خس", "طماطم متقطعة مكعبات", "جبنة قريش ( 150 جرام )",
             "حبة عنب ( 10 وحدات )", "رشة زعتر", "زتونتين متقطعين\nصغير",
             "واحدة توست محمص\nمتقطعة مكعبات"],
        grams={"جبنة قريش ( 150 جرام )": 150},
        diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_lazy_ranch_fries", section=2, page=8, mark="fries",
        splits=[4], active=10, total=50,
        timers={2: dict(min=30), 3: dict(min=20, temp=200, tool="oven")},
        ing=["علبة زبادي يوناني", "فص توم\nمفروم", "حبة بقدونس فريش",
             "ملح وفلفل", "وواحدة بطاطس متقطعة رفيع", "رشة زيت زيتون",
             "وبهارات الضحى للبطاطس"],
        brands={"وبهارات الضحى للبطاطس": "الضحى"},
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_creamy_cottage_cheese", section=2, page=9, mark="cheese_wedge",
        splits=[5, 6], active=8, total=8,
        ing=["ربع كيلو جبنه قريش", "معلقتين زبادي", "نص فلفل احمر",
             "معلقة زعتر ( اختياري )", "رشة ملح", "معلقة صغيرة زيت زيتون",
             "واحدة توست", "بيضتين اومليت"],
        grams={"ربع كيلو جبنه قريش": 250},
        optional=["معلقة زعتر ( اختياري )"],
        doneness="egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_egg_pizza", section=2, page=9, mark="flatbread",
        active=10, total=10, ingredients_basis="few",
        ing=["بيضتين اومليت", "ملح\nوفلفل", "زيت زيتون", "واحدة تورتيلا",
             "رشة موتزاريلا لايت", "زيتونه متقطعة\nصغير", "طماطم شرايح",
             "فلفل اخضر\nشرايح"],
        doneness="egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_shakshoka", section=2, page=10, mark="pan",
        splits=[1, 2, 3, 4, 5, 6, 9], active=15, total=15,
        ing=["2 بيضة", "1 طماطم كبيرة", "½ فلفل أخضر", "¼ بصلة",
             "1 معلقة صغيرة زيت", "كمون + فلفل أسود + بابريكا",
             "½-1 رغيف عيش بلدي + خيار"],
        sides=["½-1 رغيف عيش بلدي + خيار"],
        doneness="egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_fool_wa_ta3mya", section=2, page=10, mark="bowl",
        splits=[1, 2, 3, 4, 5, 7, 9], active=12, total=12,
        ing=["150 جم فول مدمس", "½ طماطم", "½ فلفل أخضر", "ليمون + كمون",
             "1 معلقة صغيرة زيت زيتون", "اتنين طعميه بسمله",
             "½ رغيف عيش بلدي + خضار"],
        grams={"150 جم فول مدمس": 150},
        sides=["½ رغيف عيش بلدي + خضار"],
        advisories=["g6pd_fava"], diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_potato_w_eggs", section=2, page=11, mark="pan",
        splits=[1, 2, 3, 4, 5, 6, 7, 8], active=20, total=20,
        ing=["150 جم بطاطس", "2 بيضة", "½ فلفل", "¼ بصلة", "كمون + بابريكا",
             "1 معلقة صغيرة زيت"],
        grams={"150 جم بطاطس": 150},
        doneness="egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_pizza_toast", section=2, page=11, mark="flatbread",
        splits=[1, 2, 3, 4, 5], active=3, total=10,
        timers={6: dict(min=7, tool="air_fryer")},
        ing=["2 شريحة توست", "60 جم جبنة قريش أو موتزاريلا لايت", "طماطم",
             "فلفل", "زعتر"],
        grams={"60 جم جبنة قريش أو موتزاريلا لايت": 60},
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_chicken_pizza", section=3, page=13, mark="flatbread",
        active=10, total=25, ingredients_basis="few",
        timers={3: dict(min=15, temp=180, tool="oven")},
        ing=["قطعتين بانيه", "ملح وفلفل وبابريكا", "واحد عيش تورتيلا قمح كامل",
             "معلقه صلصة طماطم", "جبنه موتزاريلا قليلة الدهن", "وزعتر"],
        brands={"واحد عيش تورتيلا قمح كامل": "Breadway"},
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_bbq_burger", section=3, page=13, mark="sandwich",
        splits=[7, 14], active=20, total=20,
        timers={3: dict(min=5, tool="pan")},
        ing=["لحمه قليلة الدهن", "رشة ملح وفلفل", "بصل دواير",
             "كيس سكر Stevia", "واحدة توست بني", "( 15 جرام ) جبنة موتزاريلا",
             "20 جرام Protein puffs"],
        grams={"( 15 جرام ) جبنة موتزاريلا": 15, "20 جرام Protein puffs": 20},
        optional=["20 جرام Protein puffs"],
        brands={"20 جرام Protein puffs": "Protein puffs"},
        doneness="mince_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_hwawshi", section=3, page=14, mark="flatbread",
        splits=[1, 3], active=10, total=30, ingredients_basis="few",
        ing=["لحمة مفرومة قليلة الدهن + بصل +\nفلفل + بقدونس + بهارات لحمه",
             "عيش بلدي ريتش بيك"],
        brands={"عيش بلدي ريتش بيك": "ريتش بيك"},
        doneness="mince_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_chicken_lemon", section=3, page=14, mark="drumstick",
        splits=[2, 4, 6, 8, 10, 12], active=15, total=65,
        ingredients_basis="few",
        timers={3: dict(min=30), 5: dict(min=20, temp=200, tool="oven"),
                6: dict(min=10, tool="oven")},
        ing=["صدور الفراخ",
             "الليمون، الثوم، الزيت، البابريكا،\n"
             "الكمون، الزعتر، البصل البودر، الملح والفلفل",
             "2-3 معالق\nمياه أو شوربة"],
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_chicken_ranch_salad", section=3, page=15, mark="salad_bowl",
        active=20, total=20,
        ing=["قطعتين بانيه", "خس واي خضار بنحبه", "بطاطس مكعبات",
             "رشة زيت زيتون", "وبهارات البطاطس", "واحدة توست محمص بني",
             "زبادي وتوم مفروم وملح وفلفل وبقدونس"],
        brands={"وبهارات البطاطس": "الضحى"},
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_tuna_wrap", section=3, page=15, mark="flatbread",
        active=15, total=15, ingredients_basis="few",
        ing=["علبة تونه", "ملح وفلفل وكمون وليمون وبابريكا", "بصل متقطع شرايح",
             "كيس سكر Stevia", "عيش تورتيلا قمح كامل", "خس"],
        diet=["high_protein"],
    ),
    dict(
        id="rahma_shrimp_white_pasta", section=3, page=16, mark="pot",
        active=20, total=40,
        timers={2: dict(min=20, tool="pan")},
        ing=["جمبري",
             "بملح وفلفل وكمون وبابريكا وريحان\nوليمونتين وزيت زيتون",
             "مكرونة الخضار بتاعت الضحى", "مسحة زبدة",
             "فصين توم مفرومين", "ونص كوباية لبن", "وربع كوباية مايه مغليه",
             "مرقة خضار كنور الفورية", "ورشة بقدونس"],
        # Her "50 جرام" sits five words further along the same line, behind
        # "وهنسلق", so it cannot be joined to the pasta as one span. It is the
        # pasta's weight, so it is carried as the row's grams rather than
        # printed as a row of its own that names no food.
        grams={"مكرونة الخضار بتاعت الضحى": 50},
        brands={"مكرونة الخضار بتاعت الضحى": "الضحى",
                "مرقة خضار كنور الفورية": "كنور"},
        doneness="shrimp_opaque", diet=["high_protein"],
    ),
    dict(
        id="rahma_steak_meal", section=3, page=16, mark="steak",
        splits=[5], active=25, total=25,
        ing=["قطعتين لحمة ستيك", "15 جرام زبدة", "ملح\nوفلفل وروز ماري",
             "وفص توم فريش", "بطاطس واحدة متوسطة", "خس طماطم خيار"],
        grams={"15 جرام زبدة": 15},
        sides=["خس طماطم خيار"],
        diet=["high_protein"],
    ),
    dict(
        id="rahma_oven_tender_chicken", section=3, page=17, mark="drumstick",
        active=25, total=115,
        timers={2: dict(temp=220, tool="oven"), 4: dict(min=45, tool="oven")},
        ing=["فرخة متقطعة اربع تربع", "ملح ولمون", "2 طماطم",
             "وواحدة فلفل احمر", "وبصلة متوسطه", "معلقة ونص ملح",
             "ونص معلة فلفل اسود", "ونص\nمعلقة كمون", "ومعلقة كركم",
             "ومعلقة كاري", "ومعلقة بابريكا",
             "فلفل وكوسة وجزر وبطاطس وبصل وطماطم شرايح"],
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_buffalo_sweet_wings", section=3, page=17, mark="drumstick",
        active=20, total=90,
        timers={3: dict(min=30, tool="oven")},
        ing=["كيلو اجنحه", "ملح ولمون", "بصلة", "واتنين طماطم",
             "وواحدة فلفل\nاحمر", "وعصير لمونه", "معلقة ونص ملح",
             "ومعلقة كاري", "ورشة توم باودر", "وكيسين سكر Stevia",
             "او معلقة عسل", "مستردة صغيرة"],
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_makrona_bashmel", section=3, page=18, mark="pot",
        active=35, total=55,
        comp=[("pasta", 0, 2, [1, 2]), ("bechamel", 3, 6, [4, 6]),
              ("mince", 7, 9, [8])],
        timers={1: dict(min=20, tool="pot")},
        ing=["مكرونة الضحى بالخضار", "20 جرام زبدة", "معلقة دقيق شوفان",
             "وكوبايتين لبن نص دسم", "وحبة ملح وفلفل",
             "وكيس مرقة دجاج كنور\nالفوريه", "ربع كيلة لحمة مفرومه",
             "بصل\nمتقطع صغير", "ومعلقة ملح وفلفل وبابريكا",
             "وعصير تلاتة طماطم",
             "رشة جبنة موتزاريلا طبيعي 100%"],
        grams={"20 جرام زبدة": 20, "ربع كيلة لحمة مفرومه": 250},
        brands={"مكرونة الضحى بالخضار": "الضحى",
                "وكيس مرقة دجاج كنور\nالفوريه": "كنور"},
        doneness="mince_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_kebda_meal", section=3, page=18, mark="pan",
        active=20, total=50,
        comp=[("light_tahina", 9, 12, [10, 11, 12])],
        timers={3: dict(min=30, tool="pan")},
        ing=["نص كيلو كبدة فراخ", "ملح وفلفل وكمون وليمونة وفصين توم فريش",
             "مسحة زيت\nزيتون او سمنة بلدري",
             "كيس مرقة خضار كنور الفورية", "ونص كوباية\nصغيرة مايه مغليه",
             "عيش فينو قمح كامل", "وسلطة خضرا وطحينة", "معلقة طحينة",
             "معلقتين زبادي", "ورشة توم باودر وملح وفلفل",
             "ومعلقة صغيرة خل"],
        grams={"نص كيلو كبدة فراخ": 500},
        brands={"كيس مرقة خضار كنور الفورية": "كنور"},
        advisories=["pregnancy_liver"],
        doneness="liver_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_fattah", section=3, page=19, mark="bowl",
        active=25, total=25,
        comp=[("chicken", 0, 4, [1, 2, 3]), ("bread", 5, 8, [6, 7, 8]),
              ("yoghurt_sauce", 9, 10, [10]),
              ("tomato_sauce", 11, 14, [12, 13, 14]),
              ("assembly", 15, 16, [16])],
        timers={3: dict(min=5, tool="pan")},
        ing=["الفراخ", "بالكمون، البابريكا، الفلفل والملح", "نصف معلقة الزيت",
             "العيش", "الزبادي + فص ثوم + عصير الليمون + رشة ملح",
             "صلصة الطماطم", "طماطم مبشوره", "الثوم المتبقي + الخل + رشة كمون"],
        doneness="poultry_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_lahma_bel_basl", section=3, page=19, mark="steak",
        active=15, total=50,
        timers={2: dict(min=3, tool="pan"),
                5: dict(min=35, temp=200, tool="oven"),
                6: dict(min=10, tool="oven")},
        # The page prints twelve numbered steps and no ingredient list at
        # all. Eight bare nouns lifted out of the steps - "the meat", "the
        # oil", "the onion" - are not an ingredient list, and printing them
        # under that heading tells a woman the book gave amounts it never
        # gave. Only her own serving line survives, and `ingredients="none"`
        # is what the screen says instead.
        ing=["رز أبيض أو بسمتي"],
        sides=["رز أبيض أو بسمتي"],
        ingredients_basis="none",
        diet=["high_protein"],
    ),
    dict(
        id="rahma_shorbet_3ads", section=3, page=20, mark="pot",
        active=15, total=45,
        timers={5: dict(min=30, tool="pot")},
        ing=["العدس", "معلقة الزيت", "البصل والثوم",
             "العدس، الجزر، البطاطس والطماطم", "المياه أو الشوربة والتوابل",
             "5 جرام زبدة",
             # One choice, printed by the book across three lines with her "أو"
             # on a line of its own. Two rows would read as two things to buy.
             "1 شريحة توست محمص\nأو\n"
             "½ رغيف عيش بلدي محمص في الفرن بدل التحمير في الزيت"],
        grams={"5 جرام زبدة": 5},
        optional=["5 جرام زبدة"],
        sides=["1 شريحة توست محمص\nأو\n"
               "½ رغيف عيش بلدي محمص في الفرن بدل التحمير في الزيت"],
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_btates_bel_lahma", section=3, page=20, mark="potato",
        active=25, total=90,
        timers={2: dict(min=45, temp=200, tool="oven"),
                7: dict(min=10, tool="pan"), 9: dict(min=10, tool="oven")},
        ing=["اتنين بطاطس", "معلقة الزيت", "البصل\nوالثوم", "اللحمة المفرومة",
             "الفلفل والطماطم وصلصة الطماطم والتوابل والمياه",
             "20 جم جبنة موتزاريلا لايت", "سلطة خضراء أو زبادي بالخيار"],
        grams={"20 جم جبنة موتزاريلا لايت": 20},
        optional=["20 جم جبنة موتزاريلا لايت"],
        sides=["سلطة خضراء أو زبادي بالخيار"],
        doneness="mince_cooked_through", diet=["high_protein"],
    ),
    dict(
        id="rahma_cookies_shay_blabn", section=4, page=23, mark="cookie",
        splits=[7], active=10, total=20,
        timers={3: dict(min=10, temp=180, tool="oven")},
        ing=["نص موزة مهروسة", "معلقة زبدة فول سوداني\nصغيرة",
             "معلقة فانيليا", "ورشة\nقرفة", "ومعلقة كاكاو خام",
             "وكيسين\nStevia", "ومعلقة صغيرة لبن"],
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_bagel", section=4, page=23, mark="flatbread",
        active=20, total=40,
        timers={3: dict(min=15, temp=200, tool="oven")},
        ing=["ربع كيلو جبنة قريش", "نص كوباية شوفان", "ونص كوباية دقيق ابيض",
             "ورشة ملح", "ونص معلقة بيكنج باودر", "ومعلقتين\nزيت زيتون",
             "وحبة مايه", "بيضة", "حبة البركة وسمسم"],
        grams={"ربع كيلو جبنة قريش": 250},
        doneness="baked_egg_set", diet=["vegetarian", "high_protein"],
    ),
    dict(
        id="rahma_crepe", section=4, page=24, mark="pan",
        active=12, total=12,
        comp=[("chocolate_sauce", 6, 11, [7, 9, 10])],
        timers={2: dict(min=2, tool="pan")},
        ing=["بيضة عليها نقطة فانيليا", "وكيس سكر ستيفيا",
             "معلقتين دقيق شوفان", "ومعلقة صغيرة زبادي", "نص تفاحه مبشورة",
             "رشة قرفه", "معلقتين زبادي كامل الدسم", "نقطتين فانيليا سايله",
             "ونص\nمعلقة كاكاو خام", "وكيس سكر Stevia", "او معلقة عسل",
             "شرايح من موز", "خمس\nعنبات"],
        doneness="egg_set", diet=["vegetarian"],
    ),
    dict(
        id="rahma_banana_pudding", section=4, page=24, mark="jar",
        active=6, total=126,
        timers={5: dict(min=120, tool="fridge")},
        ing=["معلقتين شوفان صغيرين", "معلقة بذور شيا", "علبة زبادي",
             "وحبة مايه", "وكيس سكر ستيفيا", "وحبة فانيليا", "وقرفة",
             "نص موزة مهروسة", "رشة\nكاكاو خام"],
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_cheese_cake", section=4, page=25, mark="cake_slice",
        active=5, total=35,
        variants=[("method_one", 1, 3), ("method_two", 4, 5)],
        timers={},
        ing=["واحدة زبادي يوناني", "واحدة بسكوت دايجستف مكفيتيز",
             "كراميل او فراولة", "واحدة توست", "جبنة قريش عدبة",
             "معلقة فراولة لايت", "ورشه عسل"],
        brands={"واحدة بسكوت دايجستف مكفيتيز": "مكفيتيز"},
        diet=["vegetarian"],
    ),
    dict(
        id="rahma_french_toast", section=4, page=25, mark="pan",
        splits=[3, 5, 8], active=12, total=12,
        timers={3: dict(min=5, tool="pan")},
        ing=["بيضه", "كيس سكر\nدايت", "ورشة فانيليا ورشة قرفه",
             "ومعلقتين كبار لبن", "اتنين\nتوست", "مسحة زبدة",
             "واحدة زبادي يوناني", "ورشة قرفة ورشة عسل"],
        doneness="egg_set", diet=["vegetarian"],
    ),
    dict(
        id="rahma_ice_cream", section=4, page=26, mark="bowl",
        active=8, total=188,
        timers={2: dict(min=180, tool="freezer")},
        ing=["علبة زبادي يوناني", "اي ثمرة فاكهه بنحبها", "نقطتين فانيليا سايله",
             "وكيس سكر ستيفيا"],
        diet=["vegetarian"],
    ),
]

# Card title -> recipe, by printing order. The extractor keys its output by her
# English title, which is the only stable name either side agrees on.
TITLES = [
    "Lazy Cake", "Pancakes", "Chia Pudding", "Coconut apple Pudding",
    "Overnight oats", "Simple oat meal",
    "Club Sandwich", "Yummy Egg Sandwich", "Cottage Freshy salad",
    "Lazy Ranch Fries", "Creamy cottage cheese", "Egg Pizza", "Shakshoka",
    "Fool & Ta3mya", "Potato w Eggs", "Pizza toast",
    "Chicken Pizza", "BBQ Burger", "Hwawshi", "Chicken lemon",
    "Chicken Ranch Salad", "Tuna Wrap", "Shrimp white sauce pasta",
    "Steak Meal", "Oven Tender Chicken", "Buffalo sweet Wings",
    "Makrona Bashmel", "Kebda Meal", "Fattah", "Lahma bel basl",
    "shorbt 3ads", "Btates bel lahma",
    "Cookies with shay blabn", "Bagel", "Crepe", "Banana pudding",
    "Cheese cake", "French toast", "Ice cream",
]

# Latin forms a woman might type, per recipe. Never rendered: search only, which
# is why an arabizi spelling and an English gloss can sit side by side without
# either of them becoming a title. Her own title is always the first entry.
EXTRA_SEARCH = {
    "rahma_shorbet_3ads": ["shorbet ads", "lentil soup", "عدس", "شوربة عدس"],
    "rahma_fool_wa_ta3mya": ["ful", "foul", "taameya", "falafel", "فول", "طعمية"],
    "rahma_btates_bel_lahma": ["batates", "potato mince", "بطاطس", "لحمة"],
    "rahma_hwawshi": ["hawawshi", "حواوشي"],
    "rahma_makrona_bashmel": ["macarona bechamel", "مكرونة بشاميل"],
    "rahma_kebda_meal": ["kebda", "liver", "كبدة"],
    "rahma_lahma_bel_basl": ["lahma bel basal", "لحمة بالبصل"],
    "rahma_shakshoka": ["shakshuka", "شكشوكة"],
    "rahma_fattah": ["fatta", "فتة"],
    "rahma_cookies_shay_blabn": ["cookies", "كوكيز"],
}

_MARKERS = ("-", ".")


def _is_marker_line(line):
    head = line.split(" ", 1)[0]
    return len(head) > 1 and head[0] in _MARKERS and head[1:].isdigit()


def _step_bounds(lines, splits, closing, blocked=frozenset()):
    """Where each step starts and stops.

    A step begins at one of her own numbered markers, or at a split point a
    human chose for a card she ran on without numbering. It stops at the next
    start, at a line that belongs to a component or a variant, or at her
    sign-off. Line 0 is always a start, because her first line is always the
    beginning of something even when she did not number it.
    """
    end = closing if closing is not None else len(lines)
    starts = set(splits or []) | {0}
    for i, line in enumerate(lines):
        if _is_marker_line(line):
            starts.add(i)
    bounds = []
    i = 0
    while i < end:
        if i in blocked:
            i += 1
            continue
        stop = i + 1
        while stop < end and stop not in blocked and stop not in starts:
            stop += 1
        bounds.append((i, stop))
        i = stop
    return bounds


def _steps(lines, bounds, timers, body, refs_for):
    out = []
    for n, (start, stop) in enumerate(bounds, start=1):
        text = "\n".join(lines[start:stop]).strip()
        if not text:
            continue
        t = (timers or {}).get(n, {})
        assert text in body, f"step {n} is not a slice of bodyAr: {text!r}"
        out.append({
            "index": n,
            "textAr": text,
            "minutes": t.get("min"),
            "tempC": t.get("temp"),
            "tool": t.get("tool"),
            "usesRefs": refs_for(text),
            # A timer is offered only for a step she is standing over. A day in
            # the fridge is not something to count down on a phone.
            "isTimer": t.get("min") is not None
            and t.get("tool") not in ("fridge", "freezer"),
        })
    return out


def build():
    cards = json.load(open(CARDS, encoding="utf-8"))
    sections = cards["sections"]
    order_in_section = {}
    recipes = []

    for title, meta in zip(TITLES, _):
        body = cards["cards"][title]
        lines = body.split("\n")
        section = sections[meta["section"] - 1]
        order_in_section[section["sectionId"]] = (
            order_in_section.get(section["sectionId"], 0) + 1
        )

        # ---------------------------------------------------- her ingredients
        ingredients = []
        for n, text in enumerate(meta["ing"], start=1):
            assert text in body, f"{meta['id']}: {text!r} is not in bodyAr"
            ingredients.append({
                "ingredientRef": f"{meta['id']}_{n}",
                # Null blocks publication, and it is null on every row here:
                # `foods` has no verified entry to point at. See the module note.
                "foodId": None,
                "qtyTextAr": text,
                "grams": meta.get("grams", {}).get(text),
                "gramsBasis": "stated" if text in meta.get("grams", {})
                else "unknown",
                "gramsNote": None,
                "optional": text in meta.get("optional", []),
                "servingSideOnly": text in meta.get("sides", []),
                "brandHint": meta.get("brands", {}).get(text),
            })

        def refs_for(step_text, rows=ingredients):
            return [r["ingredientRef"] for r in rows
                    if r["qtyTextAr"] in step_text]

        # ------------------------------------------------- components, variants
        components = []
        for comp_id, head, last, comp_splits in meta.get("comp", []):
            outside = frozenset(range(len(lines))) - frozenset(
                range(head + 1, last + 1)
            )
            components.append({
                "componentId": comp_id,
                "headingAr": lines[head],
                "ingredients": [],
                "steps": _steps(
                    lines,
                    _step_bounds(lines, comp_splits, None, outside),
                    {}, body, refs_for,
                ),
            })
        variants = []
        for var_id, first, last in meta.get("variants", []):
            variants.append({
                "variantId": var_id,
                # Her own line introducing the two methods is the label the book
                # prints; there is no separate heading per method.
                "labelAr": lines[first],
                "ingredients": [],
                "steps": _steps(lines, [(first, last + 1)], {}, body, refs_for),
            })

        # -------------------------------------------------------- her sentences
        closing = meta.get("closing")
        # A component's lines belong to the component, not to the flat step list.
        blocked = {i for _c, head, last, _s in meta.get("comp", [])
                   for i in range(head, last + 1)}
        blocked |= {i for _v, first, last in meta.get("variants", [])
                    for i in range(first, last + 1)}
        steps = _steps(
            lines,
            _step_bounds(lines, meta.get("splits"), closing, blocked),
            meta.get("timers"), body, refs_for,
        )

        # ------------------------------------------------------------ allergens
        scanned = "\n".join(
            [body] + [r["qtyTextAr"] for r in ingredients]
        )
        derived = sorted(scan(scanned).keys())
        removed = meta.get("removed", {})
        extra = meta.get("extra", [])
        final = sorted((set(derived) | set(extra)) - set(removed))

        recipes.append({
            "recipeId": meta["id"],
            "source": "book",
            "sectionId": section["sectionId"],
            "orderInSection": order_in_section[section["sectionId"]],
            "status": "review",
            "version": 1,
            "titleEn": title,
            # Null until Rahma writes it. An MSA title over a colloquial body is
            # exactly the register mixing the voice boundary exists to prevent,
            # so the Arabic build shows her English title in an LTR span, which
            # is what she herself did.
            "titleAr": None,
            "titleSearch": [title.lower()] + EXTRA_SEARCH.get(meta["id"], []),
            "bodyAr": body,
            "closingAr": lines[closing] if closing is not None else None,
            "registerAr": "egyptian_colloquial",
            "ingredients": ingredients,
            # What the page gives, so the screen can say it rather than
            # printing an empty-looking list. See the table note.
            "ingredientsBasis": meta.get("ingredients_basis", "measures"),
            "steps": steps,
            "variants": variants,
            "components": components,
            "serves": None,
            "activeMinutes": meta.get("active"),
            "totalMinutes": meta.get("total"),
            "kcal": None,
            "proteinG": None,
            "carbsG": None,
            "fatG": None,
            "macroBasis": "withheld",
            "egpPerServing": None,
            "egpPricedAt": None,
            "allergensDerived": derived,
            "allergensExtra": extra,
            "allergensRemoved": removed,
            "allergensFinal": final,
            "advisories": meta.get("advisories", []),
            "dietTags": meta.get("diet", []),
            "doneness": meta.get("doneness"),
            "sourcePage": meta["page"],
            "authoredBy": AUTHORED_BY,
            "allergenReviewedBy": None,
            "allergenReviewedAt": None,
            "cookedBy": None,
            "cookedAt": None,
            "markKey": meta["mark"],
            "tier": "free",
            "brandHints": meta.get("brands", {}),
        })

    payload = {
        "schemaVersion": SCHEMA_VERSION,
        "contentVersion": CONTENT_VERSION,
        "sections": [
            {
                "sectionId": s["sectionId"],
                "titleEn": s["titleEn"],
                "titleAr": None,
                "psLineEn": s["psLineEn"],
                "psLineAr": None,
                "order": s["order"],
                "markKey": mark,
            }
            for s, mark in zip(sections, ["cake_slice", "fried_egg", "pot", "jar"])
        ],
        "letter": cards["cards"]["__letter__"],
        "recipes": recipes,
        # Named combinations of verified `foods` rows: macros summed rather than
        # invented, allergens unioned rather than claimed, no cooking step, and
        # never on her card. None ship, because every one of them needs a `foods`
        # row with verified per-100 g macros and `foods` has none. The list is
        # here, empty, so the shape is fixed before anyone fills it.
        "assemblies": [],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{len(recipes)} recipes, {len(payload['sections'])} sections -> {OUT}")
    print(f"{os.path.getsize(OUT) / 1024:.0f} KB")


if __name__ == "__main__":
    build()
