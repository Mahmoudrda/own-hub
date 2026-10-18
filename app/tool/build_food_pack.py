#!/usr/bin/env python3
"""Turn `functions/nutrition/egyptian_dishes.json` into `assets/content/foods_eg.json`.

`python3 -I tool/build_food_pack.py` (standard library only).

Per 100 g of the dish as served, and three portions (S, M, L) at 0.6, 1.0 and
1.5 times the dish's typical serving. Each portion carries its grams and its
kcal, protein, carbohydrate, fat and fibre rounded to whole numbers.

Allergens are deliberately absent. The source has no allergen data, and the app
reads a missing list as unknown, never as none.

Source: U.S. Department of Agriculture, Agricultural Research Service.
FoodData Central, fdc.nal.usda.gov (CC0 1.0). The dishes are our own standard
recipes computed from it, estimated and pending dietitian review. USDA has not
reviewed or endorsed them or this app. See functions/nutrition/LICENCE.md.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "functions" / "nutrition" / "egyptian_dishes.json"
TARGET = ROOT / "app" / "assets" / "content" / "foods_eg.json"

SIZES = (("S", 0.6), ("M", 1.0), ("L", 1.5))


def unique(values):
    seen = []
    for value in values:
        value = str(value).strip()
        if value and value not in seen:
            seen.append(value)
    return seen


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


def main():
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    foods = []
    for dish in data["dishes"]:
        per100 = dish["per100g"]
        serving = float(dish["typical_serving_g"])
        foods.append(
            {
                "id": dish["key"],
                "nameEn": dish["name_en"],
                "nameAr": dish["name_ar"],
                "aliases": unique(dish.get("aliases", [])),
                "category": dish["category"],
                "per100g": {
                    "kcal": round(per100["kcal"], 1),
                    "proteinG": round(per100["protein_g"], 1),
                    "carbsG": round(per100["carbs_g"], 1),
                    "fatG": round(per100["fat_g"], 1),
                    "fiberG": round(per100["fiber_g"], 1),
                },
                "sizes": {
                    size: portion(per100, serving * factor)
                    for size, factor in SIZES
                },
            }
        )

    pack = {
        "source": (
            "U.S. Department of Agriculture, Agricultural Research Service. "
            "FoodData Central. fdc.nal.usda.gov (CC0 1.0). Standard recipes of "
            "Egyptian dishes computed from it by nutrition/build_dishes.py."
        ),
        "review": "estimated from a standard recipe, pending dietitian review",
        "per": "100 g of the dish as served",
        "sizeFactors": {size: factor for size, factor in SIZES},
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
