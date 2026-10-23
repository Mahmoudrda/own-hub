#!/usr/bin/env python3
"""Build `assets/content/foods_eg.json`: the foods the Eat screens search offline.

`python3 -I tool/build_food_pack.py` (standard library only).

Two sources, both offline:

  * `functions/nutrition/egyptian_dishes.json`: the Egyptian dishes, computed
    from standard recipes of USDA foods by `functions/nutrition/build_dishes.py`.
    Their allergens are derived there from the ingredients.
  * `tool/food_pack_singles.json`: single foods (a banana, a tin of tuna, a
    glass of milk). Their figures are read here, by fdcId, from
    `functions/nutrition/usda_foods.json` (the USDA subset the dishes use).

Per 100 g as served, and three portions (S, M, L). A dish's portions are 0.6,
1.0 and 1.5 times its typical serving. A single food may name its own household
portions (3 slices, a handful, a small bowl) and those replace the factors.
Each portion carries its grams and its kcal, protein, carbohydrate, fat and
fibre rounded to whole numbers.

Every food carries a `category` that is one of `FoodCategory`'s names in
`lib/features/eat/domain/food_library.dart`, a `kind` (the old dish kind, which
decides whether a portion can be measured in millilitres or cups), and an
`allergens` list drawn from the sixteen `AllergenTag` tokens. An empty list is a
claim ("none of the sixteen"), so the build refuses a food without the list and
refuses a figure that does not add up. See `validate`.

Source: U.S. Department of Agriculture, Agricultural Research Service.
FoodData Central, fdc.nal.usda.gov (CC0 1.0). The dishes are our own standard
recipes computed from it, estimated and pending dietitian review. USDA has not
reviewed or endorsed them or this app. See functions/nutrition/LICENCE.md.
"""

import json
import os
import pathlib
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from allergen_tripwire import scan  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "functions" / "nutrition" / "egyptian_dishes.json"
USDA = ROOT / "functions" / "nutrition" / "usda_foods.json"
SINGLES = ROOT / "app" / "tool" / "food_pack_singles.json"
TARGET = ROOT / "app" / "assets" / "content" / "foods_eg.json"

SIZES = (("S", 0.6), ("M", 1.0), ("L", 1.5))

# FoodCategory in lib/features/eat/domain/food_library.dart.
CATEGORIES = (
    "egyptianDishes",
    "proteins",
    "dairyAndCheese",
    "grainsAndBreads",
    "vegetablesAndSalads",
    "fruitsAndNuts",
    "snacksAndDrinks",
)

# AllergenTag.wireName in lib/features/account/domain/dietary_profile.dart.
ALLERGEN_TOKENS = (
    "gluten", "crustaceans", "eggs", "fish", "peanuts", "soy", "milk", "tree_nuts",
    "celery", "mustard", "sesame", "sulphites", "lupin", "molluscs", "fava", "coconut",
)

# The dish table's own kinds, each with the category a dish of that kind falls
# in unless GROUP_OVERRIDES says otherwise. Sweets have no category of their
# own, so they sit with snacks; the sandwich kind is a plate, so it sits with
# the dishes.
GROUP_BY_KIND = {
    "main": "egyptianDishes",
    "breakfast": "egyptianDishes",
    "side": "egyptianDishes",
    "sandwich": "egyptianDishes",
    "soup": "egyptianDishes",
    "salad": "vegetablesAndSalads",
    "bread": "grainsAndBreads",
    "cheese": "dairyAndCheese",
    "drink": "snacksAndDrinks",
    "sweet": "snacksAndDrinks",
}

GROUP_OVERRIDES = {
    # eggs, grills, fish and birds are what she counts as protein
    "eggs_boiled": "proteins", "eggs_fried_ghee": "proteins", "eggs_pastirma": "proteins",
    "egga": "proteins", "omelette": "proteins", "egg_fried_olive": "proteins",
    "kofta": "proteins", "kebab": "proteins", "kebab_kofta": "proteins",
    "shish_tawook": "proteins", "kebda_iskandarani": "proteins",
    "samak_mashwi": "proteins", "samak_maqli": "proteins", "bouri": "proteins",
    "renga": "proteins", "gambari": "proteins", "frakh_mashwi": "proteins",
    "frakh_pane": "proteins", "lahma_basal": "proteins", "sogo2": "proteins",
    "hamam_mahshi": "proteins",
    # cheese and yoghurt dishes
    "mesh": "dairyAndCheese", "areesh_tomato": "dairyAndCheese", "labneh": "dairyAndCheese",
    # rice and pasta
    "roz_shareya": "grainsAndBreads", "roz_abyad": "grainsAndBreads",
    "roz_khalta": "grainsAndBreads", "roz_meammar": "grainsAndBreads",
    "macarona_salsa": "grainsAndBreads",
    # a vegetable, a pulse snack
    "batata": "vegetablesAndSalads", "dora_mashwi": "vegetablesAndSalads",
    "arnabeet_maqli": "vegetablesAndSalads", "betingan_maqli": "vegetablesAndSalads",
    "termes": "snacksAndDrinks", "batates_maqlia": "snacksAndDrinks",
    # pastries that are a plate, not a snack
    "feteer": "egyptianDishes", "feteer_cheese": "egyptianDishes",
    "manakish_zaatar": "egyptianDishes", "manakish_cheese": "egyptianDishes",
    "fatayer_spinach": "egyptianDishes", "sfiha": "egyptianDishes",
    "hummus": "snacksAndDrinks", "muhammara": "snacksAndDrinks", "salata_zabadi": "dairyAndCheese",
}

# A dish whose M portion is a countable thing says so in her words, and gets the
# smaller count as one more portion. M's grams do not change, so a meal logged
# as M keeps meaning what it meant.
M_LABELS = {
    "aish_baladi": ("1 loaf", "رغيف"),
    "aish_shami": ("1 loaf", "رغيف"),
    "eggs_boiled": ("2 eggs", "بيضتين"),
    "eggs_fried_ghee": ("2 eggs", "بيضتين"),
    "batata": ("1 sweet potato", "حبة بطاطا"),
}
EXTRA_PORTIONS = {
    "aish_baladi": (("half", "Half a loaf", "نص رغيف", 45),),
    "aish_shami": (("half", "Half a loaf", "نص رغيف", 40),),
    "eggs_boiled": (("1", "1 egg", "بيضة", 50),),
    "eggs_fried_ghee": (("1", "1 egg", "بيضة", 52),),
}

# A real food that cannot meet the energy rule. Named one by one, with the
# reason, so the rule stays strict for everything else.
ZERO_ENERGY_OK = {
    "karkadeh_unsweetened": "USDA records brewed hibiscus tea at 0 kcal (fdcId 171946)",
    "salt": "table salt carries no energy (fdcId 173468); recipes list it by weight",
    "water": "drinking water carries no energy (fdcId 173647); recipes list it by weight",
}
ATWATER_EXCEPTIONS = {
    "kharoub": (
        "carob flour is about 40 percent fibre; the figure USDA gives for its "
        "energy counts fibre below the 4 kcal per gram used here"
    ),
    "cocoa_powder": (
        "unsweetened cocoa is about a third fibre; USDA's energy figure counts "
        "fibre below the 4 kcal per gram used here"
    ),
    "strawberry_jam": (
        "USDA's no-sugar jam is sweetened with polyols that count well below "
        "4 kcal per gram, so its energy sits under the Atwater sum"
    ),
    "baking_powder": (
        "USDA counts the leavening salts as carbohydrate with no energy"
    ),
    "spices_and_seasoning": (
        "ground pepper is a quarter fibre; USDA's energy figure counts fibre "
        "below the 4 kcal per gram used here"
    ),
    "curry_powder": (
        "a dry spice blend is about a quarter fibre, which USDA counts below "
        "the 4 kcal per gram used here"
    ),
    "zaatar_mix": (
        "dried thyme is about a third fibre, which USDA counts below the "
        "4 kcal per gram used here"
    ),
    "spice_blend_store": (
        "paprika is about a quarter fibre, which USDA counts below the "
        "4 kcal per gram used here"
    ),
}

# Foods with no natural household unit, each with the reason. None today.
NO_HOUSEHOLD_OK = {}

REVIEW = (
    "Figures estimated from a standard recipe, pending dietitian review. "
    "Allergens derived from standard ingredients, over-inclusive where the usual "
    "shop-bought or restaurant form carries one, not lab tested, pending "
    "dietitian review. An empty allergens list means none of the sixteen tokens "
    "was found in the standard ingredients."
)

MULTIPLES = (0.25, 1 / 3, 0.5, 2 / 3, 0.75, 1, 1.5, 2, 3, 4, 5, 6, 8)

HOUSEHOLD_ESTIMATE = (
    "Household sizes marked estimated are standard reference weights for the unit "
    "(a loaf, a skewer, a piece, a glass, a spoon) or multiples of the standard "
    "recipe's typical serving, not weighed samples; sizes marked usda are a USDA "
    "FoodData Central household weight for the food or a simple fraction or multiple "
    "of one. Pending dietitian review."
)

NUTRIENTS = ("kcal", "protein_g", "carbs_g", "fat_g", "fiber_g")


HOUSEHOLDS = {}


def unique(values):
    seen = []
    for value in values:
        value = str(value).strip()
        if value and value not in seen:
            seen.append(value)
    return seen


def fold(text):
    """The matching form the app and the server both use: lower-case, no marks,
    alef, ta marbuta and ya folded, punctuation as spaces."""
    text = text.lower()
    text = re.sub("[ً-ْـ]", "", text)
    text = re.sub("[أإآ]", "ا", text)
    text = text.replace("ة", "ه").replace("ى", "ي")
    text = re.sub(r"[^\w؀-ۿ ]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def arabic_variants(text):
    """[text] and its other usual spellings: with and without hamza on the alef,
    ta marbuta or ha, alef maqsura or ya."""
    if not re.search("[؀-ۿ]", text):
        return [text]
    alef = re.sub("[أإآ]", "ا", text)
    ta = text.replace("ة", "ه")
    ya = text.replace("ى", "ي")
    ya_back = re.sub("ي(?=\\s|$)", "ى", text)
    everything = ya.replace("ة", "ه")
    everything = re.sub("[أإآ]", "ا", everything)
    everything_back = re.sub("ي(?=\\s|$)", "ى", everything)
    return unique([text, alef, ta, ya, ya_back, everything, everything_back])


def with_variants(names):
    out = []
    for name in names:
        out.extend(arabic_variants(name))
    return unique(out)


def portion(per100, grams):
    scale = grams / 100.0
    return {
        "grams": round(grams),
        "kcal": round(per100["kcal"] * scale),
        "proteinG": round(per100["protein_g"] * scale),
        "carbsG": round(per100["carbs_g"] * scale),
        "fatG": round(per100["fat_g"] * scale),
        "fiberG": round(per100["fiber_g"] * scale),
    }


def label(en, ar):
    return {"en": en, "ar": ar}


def by_grams(sizes):
    """The portions smallest first, so the chips read left to right."""
    return dict(sorted(sizes.items(), key=lambda item: item[1]["grams"]))


def household_sizes(key, per100, base_g, rows):
    """The portions a household spec names. A row called S, M or L replaces that
    generic portion and an other id adds one. A row gives its grams, or `x`
    times the food's typical serving, so a dish keeps following its recipe."""
    sizes = {}
    for size, factor in SIZES:
        sizes[size] = portion(per100, base_g * factor)
    seen = set()
    for row in rows:
        if row["id"] in seen:
            raise SystemExit(f"{key}: household size {row['id']!r} is named twice")
        seen.add(row["id"])
        if ("grams" in row) == ("x" in row):
            raise SystemExit(f"{key}: household size {row['id']!r} gives grams or x, one of them")
        grams = row["grams"] if "grams" in row else base_g * row["x"]
        if grams <= 0 or not row["en"].strip() or not row["ar"].strip():
            raise SystemExit(f"{key}: household size {row['id']!r} needs grams and both labels")
        if re.search("[٠-٩۰-۹]|—", row["en"] + row["ar"]):
            raise SystemExit(f"{key}: household size {row['id']!r} uses an Arabic-Indic digit or an em dash")
        sizes[row["id"]] = {**portion(per100, grams), "label": label(row["en"], row["ar"])}
    return sizes


def usda_portions(fdc):
    return [float(g) for g, _ in fdc.get("portions", [])]


def tag_basis(sizes, usda_grams):
    """`basis` on every size that carries a household label: "usda" when its
    grams are a USDA household weight for the food or a simple fraction or
    multiple of one (within 3 percent or 0.6 g), "estimated" otherwise."""
    for size in sizes.values():
        if "label" not in size:
            continue
        grams = size["grams"]
        size["basis"] = "estimated"
        for unit in usda_grams:
            for k in MULTIPLES:
                if abs(grams - k * unit) <= max(0.6, 0.03 * grams):
                    size["basis"] = "usda"
    return sizes


def dish_basis(sizes):
    for size in sizes.values():
        if "label" in size:
            size["basis"] = "estimated"
    return sizes


def dish_food(dish):
    per100 = dish["per100g"]
    serving = float(dish["typical_serving_g"])
    key = dish["key"]
    kind = dish["category"]
    if kind not in GROUP_BY_KIND:
        raise SystemExit(f"{key}: dish kind {kind!r} has no category in GROUP_BY_KIND")
    sizes = {}
    for size, factor in SIZES:
        sizes[size] = portion(per100, serving * factor)
    if key in HOUSEHOLDS:
        sizes = household_sizes(key, per100, serving, HOUSEHOLDS[key]["sizes"])
    else:
        if key in M_LABELS:
            sizes["M"]["label"] = label(*M_LABELS[key])
        for size_id, en, ar, grams in EXTRA_PORTIONS.get(key, ()):
            sizes[size_id] = {**portion(per100, grams), "label": label(en, ar)}
    return {
        "id": key,
        "nameEn": dish["name_en"],
        "nameAr": dish["name_ar"],
        "aliases": unique(dish.get("aliases", [])),
        "category": GROUP_OVERRIDES.get(key, GROUP_BY_KIND[kind]),
        "kind": kind,
        "per100g": {
            "kcal": round(per100["kcal"], 1),
            "proteinG": round(per100["protein_g"], 1),
            "carbsG": round(per100["carbs_g"], 1),
            "fatG": round(per100["fat_g"], 1),
            "fiberG": round(per100["fiber_g"], 1),
        },
        "sizes": by_grams(dish_basis(sizes)),
        "allergens": sorted(dish["allergens"]),
        "fdcIds": unique_ints(line["fdcId"] for line in dish["recipe"]),
    }


def unique_ints(values):
    out = []
    for value in values:
        if value not in out:
            out.append(value)
    return out


def single_food(row, usda):
    key = row["id"]
    fdc = usda.get(row["fdcId"])
    if fdc is None:
        raise SystemExit(f"{key}: fdcId {row['fdcId']} is not in usda_foods.json")
    if not fdc["name"].startswith(row["usdaName"]):
        raise SystemExit(f"{key}: fdcId {row['fdcId']} is {fdc['name']!r}, expected {row['usdaName']!r}")
    missing = [n for n in NUTRIENTS if fdc.get(n) is None]
    if missing:
        raise SystemExit(f"{key}: fdcId {row['fdcId']} has no {missing}")
    per100 = {n: float(fdc[n]) for n in NUTRIENTS}
    sizes = {}
    portions = row.get("portions")
    if portions:
        if len(portions) != 3:
            raise SystemExit(f"{key}: a food names exactly three portions, S, M and L")
        for (size, _factor), spec in zip(SIZES, portions):
            sizes[size] = {**portion(per100, spec["grams"]), "label": label(spec["en"], spec["ar"])}
    elif key in HOUSEHOLDS:
        sizes = household_sizes(key, per100, row["servingG"], HOUSEHOLDS[key]["sizes"])
    else:
        for size, factor in SIZES:
            sizes[size] = portion(per100, row["servingG"] * factor)
    food = {
        "id": key,
        "nameEn": row["nameEn"],
        "nameAr": row["nameAr"],
        "aliases": unique(row["aliases"]),
        "category": row["category"],
        "per100g": {
            "kcal": round(per100["kcal"], 1),
            "proteinG": round(per100["protein_g"], 1),
            "carbsG": round(per100["carbs_g"], 1),
            "fatG": round(per100["fat_g"], 1),
            "fiberG": round(per100["fiber_g"], 1),
        },
        "sizes": by_grams(tag_basis(sizes, usda_portions(fdc))),
        "allergens": sorted(row["allergens"]),
        "fdcIds": [row["fdcId"]],
    }
    if row.get("kind"):
        food["kind"] = row["kind"]
    if row.get("note"):
        food["note"] = row["note"]
    return food


def atwater_ok(protein, carbs, fat, kcal):
    return abs(4 * protein + 4 * carbs + 9 * fat - kcal) <= max(20, 0.15 * kcal)


def validate(foods):
    """Raise SystemExit, naming the food and the rule, on the first food that
    breaks one. Nothing is repaired silently."""
    problems = []
    ids = set()
    owner = {}
    for food in foods:
        key = food["id"]
        if key in ids:
            problems.append(f"{key}: duplicate id")
        ids.add(key)
        if not food["nameEn"].strip() or not food["nameAr"].strip():
            problems.append(f"{key}: a name is empty")
        if food["category"] not in CATEGORIES:
            problems.append(f"{key}: category {food['category']!r} is not one of {CATEGORIES}")
        allergens = food.get("allergens")
        if allergens is None:
            problems.append(f"{key}: no allergens list")
        else:
            bad = [a for a in allergens if a not in ALLERGEN_TOKENS]
            if bad:
                problems.append(f"{key}: {bad} are not allergen tokens")
        if not any(re.search("[a-z]", a, re.I) for a in food["aliases"]) and not re.search("[a-z]", food["nameEn"], re.I):
            problems.append(f"{key}: no Latin spelling")

        per = food["per100g"]
        rows = [("per 100 g", per["kcal"], per["proteinG"], per["carbsG"], per["fatG"])]
        named = [s for s in food["sizes"].values() if "label" in s]
        if not named and key not in NO_HOUSEHOLD_OK:
            problems.append(f"{key}: no household size (a labelled portion)")
        for size_id, size in food["sizes"].items():
            if "label" in size and size.get("basis") not in ("usda", "estimated"):
                problems.append(f"{key} size {size_id}: a household size needs basis usda or estimated")
            if size["grams"] <= 0:
                problems.append(f"{key} size {size_id}: grams {size['grams']} is not above 0")
            rows.append((f"size {size_id}", size["kcal"], size["proteinG"], size["carbsG"], size["fatG"]))
        for where, kcal, protein, carbs, fat in rows:
            if kcal <= 0 and key not in ZERO_ENERGY_OK:
                problems.append(f"{key} {where}: kcal {kcal} is not above 0")
            if min(protein, carbs, fat) < 0:
                problems.append(f"{key} {where}: a macro is below 0")
            if key in ZERO_ENERGY_OK and kcal == 0:
                if (protein, carbs, fat) != (0, 0, 0):
                    problems.append(f"{key} {where}: zero energy with macros")
                continue
            if key not in ATWATER_EXCEPTIONS and not atwater_ok(protein, carbs, fat, kcal):
                problems.append(
                    f"{key} {where}: 4P+4C+9F is {4 * protein + 4 * carbs + 9 * fat:.1f}, kcal is {kcal}"
                )

        # The words in her own Arabic say what is in the food: the tripwire reads
        # them independently of the ingredient list and may only add questions.
        for tag, words in scan(food["_scan"]).items():
            if allergens is not None and tag not in allergens:
                problems.append(f"{key}: the name or an alias says {words} ({tag}) but allergens omits it")

        for name in {fold(n) for n in [food["nameEn"], food["nameAr"], *food["aliases"]]}:
            if not name:
                continue
            if owner.setdefault(name, key) != key:
                problems.append(f"{key}: the name {name!r} also belongs to {owner[name]}")
    if problems:
        raise SystemExit("food pack refused:\n  " + "\n  ".join(problems))


def main():
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    singles = json.loads(SINGLES.read_text(encoding="utf-8"))
    HOUSEHOLDS.update(singles.get("households", {}))
    usda = {f["fdcId"]: f for f in json.loads(USDA.read_text(encoding="utf-8"))["foods"]}

    foods = [dish_food(dish) for dish in data["dishes"]]
    foods += [single_food(row, usda) for row in singles["foods"]]
    for food in foods:
        food["_scan"] = " | ".join([food["nameEn"], food["nameAr"], *food["aliases"]])
        spellings = with_variants([*food["aliases"], food["nameAr"]])
        food["aliases"] = [a for a in spellings if a not in (food["nameAr"], food["nameEn"])]
    validate(foods)
    known = {f["id"] for f in foods}
    stray = sorted(set(HOUSEHOLDS) - known)
    if stray:
        raise SystemExit(f"food pack refused: household sizes for unknown foods {stray}")
    for food in foods:
        del food["_scan"]
    notes = {}
    for food in foods:
        spec = HOUSEHOLDS.get(food["id"])
        if spec and spec["source"].startswith("dish portion"):
            continue
        if any(s.get("basis") == "estimated" for s in food["sizes"].values()):
            notes[food["id"]] = (
                spec["source"] if spec
                else "estimated: standard reference weight for the unit where USDA lists no matching household weight"
            )

    pack = {
        "source": (
            "U.S. Department of Agriculture, Agricultural Research Service. "
            "FoodData Central. fdc.nal.usda.gov (CC0 1.0). Standard recipes of "
            "Egyptian dishes computed from it by nutrition/build_dishes.py, and "
            "single foods read from it by fdcId."
        ),
        "review": REVIEW,
        "householdReview": {"basis": HOUSEHOLD_ESTIMATE, "notes": notes},
        "per": "100 g of the food as served",
        "sizeFactors": {size: factor for size, factor in SIZES},
        "categories": list(CATEGORIES),
        "foods": foods,
    }
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(
        json.dumps(pack, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"{len(foods)} foods -> {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
