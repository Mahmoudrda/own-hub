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

## What ships as `published`, and what stays in `review`

`recipe_signoff.json` lists the recipes a person has cooked and checked the
allergens of, with who and when. A listed recipe is `published` and carries
`allergenReviewedBy` and `cookedBy`; an unlisted one stays `review`, is marked
on screen as unchecked, and is **hidden entirely from any woman who has declared
an allergy** (`AllergyGuard`'s fail-closed behaviour). Writing a name into that
file for a recipe nobody checked would be forging a signature on an allergen
check, which is the single worst fabrication available in this feature, so the
file is edited by a person and never by this script.

`authoredBy` is `ownhub_kitchen` on every row. The words of the thirty-nine are
Rahma's (`source: book`, `sourcePage`), and the structured record the app
ships is Own Hub's: the split into steps, the ingredient rows linked to the
food pack, the weights, the figures. The two-person rule (`firestore.rules`,
`recipe_validation.dart`) needs a reviewer who is not the author, and Rahma is
the reviewer.

## Macros are summed from the food pack

Every ingredient row carries a `foodId` into `foods_eg.json` and a weight
(`recipe_links.py`). A recipe's figures are the sum of those rows over the
pack's per-100 g values, divided by `serves`. Optional rows, serving
suggestions and the second of two alternative methods are not counted. Where
the book gives no amount the weight is ours, marked `estimated` on the row and
said in the recipe's `reviewNotes`, so the figure is never read as hers.
`egpPerServing` stays null: there is no price source.

## Allergens are the union of two readers

`allergensDerived` is whatever `allergen_tripwire.py` reads out of the card's
Arabic. `allergensExtra` is every tag the linked foods carry that the words do
not say (freekeh is wheat and nobody writes "wheat"). `allergensRemoved` is
empty on every recipe: removing a tag is a person's job and needs a written
reason.

## The eleven recipes of Own Hub's kitchen

`ownhub_recipes.py` holds recipes written by Own Hub, not by Rahma
(`source: authored`). They carry English and Egyptian Arabic, are never drawn as
hers, and stay `review` until the sign-off file lists them.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from allergen_tripwire import scan  # noqa: E402
from ownhub_recipes import RECIPES as OWNHUB  # noqa: E402
from recipe_links import LAHMA_ROWS, LINKS  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CARDS = os.path.join(HERE, "rahma_book_cards.json")
# The two paths the build reads and writes can be pointed elsewhere, so a test
# can try a sign-off without touching the real one.
OUT = os.environ.get("OWNHUB_RECIPES_OUT") or os.path.join(
    HERE, "..", "assets", "content", "rahma_recipes.json"
)
PACK = os.path.join(HERE, "..", "assets", "content", "foods_eg.json")
SIGNOFF = os.environ.get("OWNHUB_RECIPE_SIGNOFF") or os.path.join(
    HERE, "recipe_signoff.json"
)
TITLES_AR = os.path.join(HERE, "rahma_titles_ar.json")

SCHEMA_VERSION = 1
CONTENT_VERSION = 1

# Who wrote the structured record. The book's words are Rahma's (`source:
# book`); the steps, the linked ingredient rows and the figures are Own Hub's.
# See the module note on the two-person rule.
AUTHORED_BY = "ownhub_kitchen"

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
        skip_lines=[2], active=5, total=5, closing=6,
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
        skip_lines=[0], splits=[1, 3], active=10, total=30, ingredients_basis="few",
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
        skip_lines=[4, 5], active=20, total=20,
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


# Words that only link one of her quantity phrases to the next ("on it", "or",
# "with"). A line with nothing in it but her phrases and these is still an
# ingredient line, and a step with nothing else left in it has no method.
CONNECTOR_WORDS = frozenset({
    "على", "عليها", "عليهم", "عليه", "او", "أو", "مع", "من", "في", "ب",
})


def _words(text, connectors=True):
    """The words of [text] that are not a bare "and" or, when [connectors], a
    connector."""
    out = []
    for token in re.split(r"[\W_]+", text):
        token = token.lstrip("و") if len(token) > 1 else token
        if token and token != "و" and not token.isdigit() and not (
            connectors and token in CONNECTOR_WORDS
        ):
            out.append(token)
    return out


def method_words(text, ingredients):
    """What is left of a step once every ingredient phrase is taken out."""
    phrases = []
    for row in ingredients:
        phrases.append(row["qtyTextAr"])
        phrases.extend(x.strip() for x in row["qtyTextAr"].split("\n"))
    for phrase in sorted({p for p in phrases if p}, key=len, reverse=True):
        text = text.replace(phrase, " ")
    return _words(text)


def _ingredient_lines(body, ingredients):
    """Indices of the lines that are nothing but her quantity phrases.

    A card that lists what goes in, line by line, ahead of (or between) its
    method printed those lines with her own `-1`, `-2` markers, and they were
    taken for steps: step 1 of `Lazy Cake` was ingredient 1 word for word. A line
    belongs to the ingredient block when every character of it is inside one of
    her quantity phrases, or is a joiner between two of them, or a marker.

    A phrase that runs across her line break counts only when **every** line it
    touches is such a line. `كيس` ending a sentence and `stevia` opening the next
    line is one phrase, but the first line also carries a verb, so neither line
    is an ingredient line and the sentence stays whole.

    A lead-in that only introduces such a block (`المكونات:`, `تتقدم مع:`) goes
    with it: it would otherwise be a step with nothing under it. A lead-in
    that carries one of her own step numbers is her step, and stays.
    """
    lines = body.split("\n")
    starts = []
    at = 0
    for line in lines:
        starts.append(at)
        at += len(line) + 1
    covered = [False] * len(body)
    spans = []
    cursor = 0
    for text in ingredients:
        i = body.find(text, cursor)
        if i < 0:
            i = body.find(text)
        assert i >= 0, f"{text!r} is not in bodyAr"
        spans.append((i, i + len(text)))
        for k in range(i, i + len(text)):
            covered[k] = True
        cursor = i + len(text)

    def touches(index, a, c):
        lo = starts[index]
        return a < lo + len(lines[index]) and c > lo

    full = set()
    for n, line in enumerate(lines):
        lo = starts[n]
        mine = [covered[k] for k in range(lo, lo + len(line))]
        if not any(mine):
            # A stray bracket or full stop her line break left on a line of its
            # own holds no method, and is dropped with the block around it.
            if line.strip() and not any(ch.isalnum() for ch in line):
                full.add(n)
            continue
        # A connector counts as nothing only between two of her phrases
        # ("yoghurt on it garlic"). One that opens or closes the line belongs to
        # a sentence that goes on past it, and keeps the line in its step.
        first = mine.index(True)
        last = len(mine) - 1 - mine[::-1].index(True)
        rest = [
            " " if c or body[lo + k].isdigit() else body[lo + k]
            for k, c in enumerate(mine)
        ]
        edge = "".join(rest[:first] + [" "] + rest[last + 1:])
        inner = "".join(rest[first:last + 1])
        if not _words(edge, connectors=False) and not _words(inner):
            full.add(n)
    spoiled = set()
    for a, c in spans:
        hit = [n for n in range(len(lines)) if touches(n, a, c)]
        if any(n not in full for n in hit):
            spoiled.update(hit)
    block = full - spoiled
    for n in sorted(block):
        before = n - 1
        if before >= 0 and before not in block:
            if lines[before].strip().endswith(":") and not _is_marker_line(
                lines[before]
            ):
                block.add(before)
    return block


def _step_bounds(lines, splits, closing, blocked=frozenset(),
                 dropped=frozenset(), timers=None):
    """Where each step starts and stops, as (original number, start, stop).

    A step begins at one of her own numbered markers, or at a split point a
    human chose for a card she ran on without numbering. It stops at the next
    start, at a line that belongs to a component or a variant, or at her
    sign-off. Line 0 is always a start, because her first line is always the
    beginning of something even when she did not number it.

    [dropped] are the ingredient-block lines. They are cut out of a step, never
    kept in it, so a run of them between two sentences leaves each sentence as
    its own step. The original number is kept for the timers, which were read
    off her sentences before any line was dropped.
    """
    end = closing if closing is not None else len(lines)
    starts = set(splits or []) | {0}
    for i, line in enumerate(lines):
        if _is_marker_line(line):
            starts.add(i)
    bounds = []
    i = 0
    n = 0
    while i < end:
        if i in blocked:
            i += 1
            continue
        stop = i + 1
        while stop < end and stop not in blocked and stop not in starts:
            stop += 1
        n += 1
        run = None
        for k in range(i, stop):
            if k in dropped:
                if run is not None:
                    bounds.append((n, run, k))
                    run = None
            elif run is None:
                run = k
        if run is not None:
            bounds.append((n, run, stop))
        assert n not in (timers or {}) or any(b[0] == n for b in bounds), (
            f"step {n} carries a timer and was nothing but ingredient lines"
        )
        i = stop
    return bounds


_MARKER_PREFIX = r"^([-.]\d+\s+)?"
_METHOD_HEADING = re.compile(_MARKER_PREFIX + r"الطريقة\s*:\s*")
_SERVED_WITH = re.compile(_MARKER_PREFIX + r"(تتقدم|يتقدم|تقدم)\s+مع\s*:")


_LEADING_STEP_MARKER = re.compile(r"^(?:[-.]\d+|\d+-)\s+")


def _clean_step(text):
    """Her step without a "الطريقة:" heading, without the step number she
    typed in front of it (the app numbers the steps itself), and with the line
    breaks the printed page wrapped at joined into one line. Nothing else is
    touched."""
    text = _METHOD_HEADING.sub(lambda m: m.group(1) or "", text, count=1)
    text = re.sub(r"\s*\n\s*", " ", text).strip()
    return _LEADING_STEP_MARKER.sub("", text, count=1)


def _is_served_with(text, refs_for):
    """A "served with" line: it names the side the ingredient list already
    carries, so as a step it would only say the same thing twice."""
    m = _SERVED_WITH.match(text)
    if not m:
        return False
    return not text[m.end():].strip() or bool(refs_for(text))


def _steps(lines, bounds, timers, body, refs_for):
    out = []
    seen = set()
    for n, start, stop in bounds:
        text = "\n".join(lines[start:stop]).strip()
        if not text:
            continue
        t = (timers or {}).get(n, {})
        if t:
            assert n not in seen, f"two pieces of step {n} would both take its timer"
        seen.add(n)
        assert text in body, f"step {n} is not a slice of bodyAr: {text!r}"
        if _is_served_with(text, refs_for):
            continue
        text = _clean_step(text)
        out.append({
            "index": len(out) + 1,
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


def _norm_line(line):
    """A line without her step marker or her closing full stop."""
    line = line.strip()
    parts = line.split(" ", 1)
    if _is_marker_line(line) and len(parts) > 1:
        line = parts[1]
    return line.strip().rstrip(".").strip()


def _assert_no_ingredient_lines(recipe_id, steps, ingredients):
    """No step is, or holds, a line that is one of her ingredient lines.

    Read from the output rather than from the cutting that produced it, so a
    later edit to the cutting cannot quietly bring the duplicates back.
    """
    wanted = []
    for row in ingredients:
        wanted.append([_norm_line(x) for x in row["qtyTextAr"].split("\n")])
    for step in steps:
        assert method_words(step["textAr"], ingredients), (
            f"{recipe_id} step {step['index']} is only ingredient phrases: "
            f"{step['textAr']!r}"
        )
        got = [_norm_line(x) for x in step["textAr"].split("\n")]
        for ing in wanted:
            for at in range(len(got) - len(ing) + 1):
                assert got[at:at + len(ing)] != ing, (
                    f"{recipe_id} step {step['index']} holds the ingredient "
                    f"line {ing!r}"
                )


def _load_pack():
    pack = json.load(open(PACK, encoding="utf-8"))
    return {f["id"]: f for f in pack["foods"]}


def _load_titles_ar():
    """The Egyptian Arabic titles and PS lines the shipped seed carries.

    Kept in a file of their own, as they were shipped, so that rebuilding the
    seed does not drop them: the card extractor reads the book, and the book
    has no Arabic title for a card.
    """
    return json.load(open(TITLES_AR, encoding="utf-8"))


def _load_signoff():
    if not os.path.exists(SIGNOFF):
        return {}
    return json.load(open(SIGNOFF, encoding="utf-8"))["recipes"]


# Foods that are meat, poultry, fish or shellfish, for the vegetarian tag. A
# stock cube is not in the list: the cards that use one say which kind, and a
# card with a meat in it is not vegetarian for any other reason.
_FLESH = {
    "chicken_breast_raw", "chicken_breast_grilled", "chicken_liver_raw",
    "chicken_whole_raw", "chicken_wings_raw", "frakh_pane", "beef_mince_lean",
    "beef_steak_raw", "steak_grilled", "shrimp_raw", "tilapia_raw",
    "tuna_canned", "tuna_in_oil", "turkey_smoked",
}
_NOT_VEGAN = {"honey"}
_OVEN_WORDS = re.compile(r"فرن|فراير|شوايه|الشوايه|\boven\b|air fryer", re.I)


def _counted(row, ingredient):
    """Whether a row goes into the figures. See `recipe_links.py`."""
    return not (
        ingredient["optional"] or ingredient["servingSideOnly"]
        or row.get("skip")
    )


def _sum_macros(rows, ingredients, pack, serves):
    total = dict(kcal=0.0, proteinG=0.0, carbsG=0.0, fatG=0.0)
    for row, ingredient in zip(rows, ingredients):
        if not _counted(row, ingredient):
            continue
        per = pack[row["food"]]["per100g"]
        for key in total:
            total[key] += per[key] * row["grams"] / 100.0
    return {k: int(v / serves + 0.5) for k, v in total.items()}


def _food_allergens(rows, pack):
    out = set()
    for row in rows:
        out.update(pack[row["food"]]["allergens"])
    return out


def _diet(rows, ingredients, pack, allergens, macros, steps, body, minutes,
          checked):
    """The tags the filters and the index read.

    The three that rest on an allergen set (`vegan`, `gluten_free`, `no_nuts`)
    are given only to a recipe a person has signed: an unsigned recipe is not
    "nut free", it is unchecked, and a tag saying otherwise would be the app
    making the claim it refuses to make.
    """
    tags = set()
    foods = {row["food"] for row in rows}
    if macros["proteinG"] >= 20:
        tags.add("high_protein")
    if not foods & _FLESH:
        tags.add("vegetarian")
        if checked and not (allergens & {"eggs", "milk"}) and not (
            foods & _NOT_VEGAN
        ):
            tags.add("vegan")
    if checked and "gluten" not in allergens:
        tags.add("gluten_free")
    if checked and not allergens & {"tree_nuts", "peanuts"}:
        tags.add("no_nuts")
    if not any(s["tool"] in ("oven", "air_fryer") for s in steps) and not (
        _OVEN_WORDS.search(body)
    ):
        tags.add("no_oven")
    if minutes is not None and minutes < 20:
        tags.add("under_20_min")
    return sorted(tags)


def _review_notes(meta_notes, rows, ingredients, serves, stated_serves):
    notes = [
        f"Serves {serves}"
        + (": the card says so." if stated_serves else
           ": our assumption, the book does not give a number of servings.")
    ]
    assumed = [
        r["note"] for r, i in zip(rows, ingredients)
        if r["basis"] == "estimated" and r["food"] != "spices_and_seasoning"
        and r["note"]
    ]
    if assumed:
        notes.append("Amounts that are ours, marked estimated on the row: "
                     + "; ".join(assumed) + ".")
    skipped = [
        r["note"] for r, i in zip(rows, ingredients)
        if not _counted(r, i) and r["note"]
    ]
    if skipped:
        notes.append("Not counted in the figures: " + "; ".join(skipped) + ".")
    notes.extend(meta_notes)
    notes.append(
        "Figures are one serving, summed from the food pack over the weights on "
        "the rows."
    )
    return notes


def _sign(recipe, signed):
    entry = signed.get(recipe["recipeId"])
    if entry is None:
        return
    assert entry["allergenReviewedBy"] != recipe["authoredBy"], (
        f"{recipe['recipeId']}: the reviewer cannot be the author"
    )
    recipe["status"] = "published"
    recipe["allergenReviewedBy"] = entry["allergenReviewedBy"]
    recipe["allergenReviewedAt"] = entry["at"]
    recipe["cookedBy"] = entry["cookedBy"]
    recipe["cookedAt"] = entry["at"]


def _ownhub_recipe(data, section, order_in_section, pack, signed):
    """One of Own Hub's own recipes, in the shape of the book's."""
    rid = data["id"]
    rows = []
    ingredients = []
    for n, item in enumerate(data["ingredients"], start=1):
        food, grams, qty_en, qty_ar = item[:4]
        flags = item[4] if len(item) > 4 else {}
        assert food in pack, f"{rid}: {food} is not a food"
        basis = "estimated" if food == "spices_and_seasoning" else "stated"
        rows.append(dict(food=food, grams=grams, basis=basis, note=qty_en,
                         **flags))
        ingredients.append({
            "ingredientRef": f"{rid}_{n}",
            "foodId": food,
            "qtyTextAr": qty_ar,
            "qtyTextEn": qty_en,
            "grams": grams,
            "gramsBasis": basis,
            "gramsNote": None,
            "optional": bool(flags.get("opt")),
            "servingSideOnly": bool(flags.get("side")),
            "brandHint": None,
        })
    steps = []
    for n, st in enumerate(data["steps"], start=1):
        steps.append({
            "index": n,
            "textAr": st["ar"],
            "textEn": st["en"],
            "minutes": st["minutes"],
            "tempC": st["temp"],
            "tool": st["tool"],
            "usesRefs": [],
            "isTimer": st["minutes"] is not None
            and st["tool"] not in (None, "fridge", "freezer"),
        })
    body = "\n".join(st["textAr"] for st in steps)
    _assert_no_ingredient_lines(rid, steps, ingredients)
    for bad in ("\u2013", "\u2014"):
        assert bad not in body and bad not in " ".join(
            st["textEn"] for st in steps
        ), f"{rid}: a dash"
    serves = data["serves"]
    macros = _sum_macros(rows, ingredients, pack, serves)
    scanned = "\n".join([body] + [i["qtyTextAr"] for i in ingredients])
    derived = sorted(scan(scanned).keys())
    extra = sorted(_food_allergens(rows, pack) - set(derived))
    final = sorted(set(derived) | set(extra))
    minutes = data["active"] if data["active"] is not None else data["total"]
    diet = _diet(rows, ingredients, pack, set(final), macros, steps, body,
                 minutes, rid in signed)
    entry = signed.get(rid)
    if entry is None:
        first = (
            "Written by the Own Hub kitchen, not by Rahma. She has not cooked "
            "it or checked its allergens yet, so it stays in review."
        )
    else:
        first = (
            "Written by the Own Hub kitchen, not by Rahma. Signed off "
            f"{entry['at'][:10]}: cooked by {entry['cookedBy']}, allergens "
            f"checked by {entry['allergenReviewedBy']}."
        )
    notes = [
        first,
        f"Serves {serves}: the card says so.",
        "Figures are one serving, summed from the food pack over the weights on "
        "the rows. Meat, fish and liver are raw weights.",
    ]
    return {
        "recipeId": rid,
        "source": "authored",
        "sectionId": section["sectionId"],
        "orderInSection": order_in_section[section["sectionId"]],
        "status": "review",
        "version": 1,
        "titleEn": data["titleEn"],
        "titleAr": data["titleAr"],
        "titleSearch": [data["titleEn"].lower(), data["titleAr"], *data["search"]],
        "bodyAr": body,
        "closingAr": None,
        "registerAr": "egyptian_colloquial",
        "ingredients": ingredients,
        "ingredientsBasis": "measures",
        "steps": steps,
        "variants": [],
        "components": [],
        "serves": serves,
        "activeMinutes": data["active"],
        "totalMinutes": data["total"],
        "kcal": macros["kcal"],
        "proteinG": macros["proteinG"],
        "carbsG": macros["carbsG"],
        "fatG": macros["fatG"],
        "macroBasis": "computed",
        "egpPerServing": None,
        "egpPricedAt": None,
        "allergensDerived": derived,
        "allergensExtra": extra,
        "allergensRemoved": {},
        "allergensFinal": final,
        "advisories": data.get("advisories", []),
        "dietTags": diet,
        "doneness": data["doneness"],
        "sourcePage": None,
        "authoredBy": AUTHORED_BY,
        "allergenReviewedBy": None,
        "allergenReviewedAt": None,
        "cookedBy": None,
        "cookedAt": None,
        "markKey": data["mark"],
        "tier": "free",
        "brandHints": {},
        "reviewNotes": notes,
    }


def build():
    pack = _load_pack()
    signed = _load_signoff()
    titles_ar = _load_titles_ar()
    cards = json.load(open(CARDS, encoding="utf-8"))
    sections = cards["sections"]
    order_in_section = {}
    recipes = []

    for meta in _:
        if meta["id"] == "rahma_lahma_bel_basl":
            meta["ing"] = LAHMA_ROWS + meta["ing"]

    for title, meta in zip(TITLES, _):
        body = cards["cards"][title]
        lines = body.split("\n")
        section = sections[meta["section"] - 1]
        order_in_section[section["sectionId"]] = (
            order_in_section.get(section["sectionId"], 0) + 1
        )

        # ---------------------------------------------------- her ingredients
        links = LINKS[meta["id"]]
        rows = links["rows"]
        assert len(rows) == len(meta["ing"]), (
            f"{meta['id']}: {len(rows)} links for {len(meta['ing'])} rows"
        )
        ingredients = []
        for n, (text, row) in enumerate(zip(meta["ing"], rows), start=1):
            assert text in body, f"{meta['id']}: {text!r} is not in bodyAr"
            assert row["food"] in pack, f"{meta['id']}: {row['food']} is not a food"
            written = meta.get("grams", {}).get(text)
            assert written is None or written == row["grams"], (
                f"{meta['id']}: her {written} g is {row['grams']} g in the links"
            )
            ingredients.append({
                "ingredientRef": f"{meta['id']}_{n}",
                "foodId": row["food"],
                "qtyTextAr": text,
                "grams": row["grams"],
                "gramsBasis": row["basis"],
                "gramsNote": row["note"] or None,
                "optional": text in meta.get("optional", []) or bool(row.get("opt")),
                "servingSideOnly": text in meta.get("sides", [])
                or bool(row.get("side")),
                "brandHint": meta.get("brands", {}).get(text),
            })

        def refs_for(step_text, rows=ingredients):
            return [r["ingredientRef"] for r in rows
                    if r["qtyTextAr"] in step_text]

        # ------------------------------------------------- components, variants
        dropped = frozenset(_ingredient_lines(body, meta["ing"]))
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
                    _step_bounds(lines, comp_splits, None, outside, dropped),
                    {}, body, refs_for,
                ),
            })
        variants = []
        for var_id, first, last in meta.get("variants", []):
            # A variant is one method she wrote across several lines, so a line
            # of it that is only a quantity phrase is her sentence running on.
            # What must not happen is a variant that is nothing else.
            assert set(range(first, last + 1)) - dropped, (
                f"{meta['id']}: a variant is only ingredient lines"
            )
            variants.append({
                "variantId": var_id,
                # Her own line introducing the two methods is the label the book
                # prints; there is no separate heading per method.
                "labelAr": lines[first],
                "ingredients": [],
                "steps": _steps(
                    lines, [(1, first, last + 1)], {}, body, refs_for
                ),
            })

        # -------------------------------------------------------- her sentences
        closing = meta.get("closing")
        # A component's lines belong to the component, not to the flat step list.
        blocked = {i for _c, head, last, _s in meta.get("comp", [])
                   for i in range(head, last + 1)}
        blocked |= {i for _v, first, last in meta.get("variants", [])
                    for i in range(first, last + 1)}
        # Lines that are no part of a method: the dish's title, or a brand name
        # her line break left on a line of its own.
        blocked |= set(meta.get("skip_lines", []))
        steps = _steps(
            lines,
            _step_bounds(
                lines, meta.get("splits"), closing, blocked, dropped,
                meta.get("timers"),
            ),
            meta.get("timers"), body, refs_for,
        )
        every_step = steps + [
            s for c in components + variants for s in c["steps"]
        ]
        _assert_no_ingredient_lines(meta["id"], every_step, ingredients)

        # ------------------------------------------------------------ allergens
        scanned = "\n".join(
            [body] + [r["qtyTextAr"] for r in ingredients]
        )
        derived = sorted(scan(scanned).keys())
        removed = meta.get("removed", {})
        extra = sorted(_food_allergens(rows, pack) - set(derived))
        final = sorted((set(derived) | set(extra)) - set(removed))

        # ---------------------------------------------------------- the figures
        serves = links["serves"]
        macros = _sum_macros(rows, ingredients, pack, serves)
        minutes = meta.get("active")
        if minutes is None:
            minutes = meta.get("total")
        diet = _diet(rows, ingredients, pack, set(final), macros, steps, body,
                     minutes, meta["id"] in signed)

        recipes.append({
            "recipeId": meta["id"],
            "source": "book",
            "sectionId": section["sectionId"],
            "orderInSection": order_in_section[section["sectionId"]],
            "status": "review",
            "version": 1,
            "titleEn": title,
            # The Egyptian Arabic title the shipped seed carries, from
            # `rahma_titles_ar.json`. The book prints none.
            "titleAr": titles_ar["titles"][meta["id"]],
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
            "serves": serves,
            "activeMinutes": meta.get("active"),
            "totalMinutes": meta.get("total"),
            "kcal": macros["kcal"],
            "proteinG": macros["proteinG"],
            "carbsG": macros["carbsG"],
            "fatG": macros["fatG"],
            "macroBasis": "computed",
            "egpPerServing": None,
            "egpPricedAt": None,
            "allergensDerived": derived,
            "allergensExtra": extra,
            "allergensRemoved": removed,
            "allergensFinal": final,
            "advisories": meta.get("advisories", []),
            "dietTags": diet,
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
            "reviewNotes": _review_notes(
                links.get("notes", []), rows, ingredients, serves, False
            ),
        })
        _sign(recipes[-1], signed)

    for data in OWNHUB:
        section = next(x for x in sections if x["sectionId"] == data["section"])
        order_in_section[section["sectionId"]] += 1
        recipes.append(
            _ownhub_recipe(data, section, order_in_section, pack, signed)
        )
        _sign(recipes[-1], signed)

    unknown = set(signed) - {r["recipeId"] for r in recipes}
    assert not unknown, f"the sign-off names recipes that do not exist: {unknown}"

    payload = {
        "schemaVersion": SCHEMA_VERSION,
        "contentVersion": CONTENT_VERSION,
        "sections": [
            {
                "sectionId": s["sectionId"],
                "titleEn": s["titleEn"],
                "titleAr": titles_ar["sectionTitles"][s["sectionId"]],
                "psLineEn": s["psLineEn"],
                "psLineAr": titles_ar["psLines"][s["sectionId"]],
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
