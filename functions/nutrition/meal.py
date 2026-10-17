"""From the model's foods and grams to the numbers she checks on E13.

Each item is resolved in this order:

  1. a model confidence under MIN_CONFIDENCE: returned with matched=false and
     no numbers, because a number built on a guess looks like a fact;
  2. the dish table (dishes.match on dish_guess, then the Arabic name, then
     the English name): source "dish", the dish's per-100 g values, its review
     note, and its recipe scaled to her grams as the ingredient breakdown;
  3. the model's own ingredients, each matched to a USDA food: source
     "ingredients", the item's grams are the ingredients' sum, and its
     per-100 g values are the sum of what was found over those grams;
  4. the item's own USDA terms: source "usda" with the food's fdcId;
  5. nothing found: matched=false and no numbers.

`per100g` is returned on every item that has numbers, so the app recomputes
grams/100 x per-100 g when she edits the weight, exactly as this module does.
`matched` is false when any part of the item was not found; the numbers then
cover only the parts that were. A nutrient USDA does not list is null on the
single food it belongs to and counts as nothing in any sum.
"""

from __future__ import annotations

from typing import Optional

from . import config, dishes, model, usda

WIRE = {
    "kcal": "kcal",
    "protein_g": "proteinG",
    "carbs_g": "carbsG",
    "fat_g": "fatG",
    "fiber_g": "fiberG",
}


def _round(key: str, value: Optional[float]):
    if value is None:
        return None
    if key == "kcal":
        return int(round(value))
    return round(value, 1)


def _wire_per100g(per100g: dict) -> dict:
    return {WIRE[k]: per100g.get(k) for k in usda.NUTRIENTS}


def _wire_amounts(amounts: dict) -> dict:
    return {WIRE[k]: _round(k, amounts.get(k)) for k in usda.NUTRIENTS}


def _no_numbers() -> dict:
    return {WIRE[k]: None for k in usda.NUTRIENTS}


def _base(item: model.Item) -> dict:
    return {
        "nameEn": item.name_en,
        "nameAr": item.name_ar,
        "grams": item.grams,
        "confidence": round(item.confidence, 2),
    }


def _unmatched(item: model.Item) -> dict:
    return {
        **_base(item),
        "matched": False,
        "source": None,
        "fdcId": None,
        "usdaName": None,
        "per100g": None,
        **_no_numbers(),
    }


def _sum(parts: list) -> dict:
    """Nutrient sums of a list of amount dicts, a missing value counting as 0."""
    return {k: sum((p.get(k) or 0.0) for p in parts) for k in usda.NUTRIENTS}


def _per100_from(amounts: dict, grams: float) -> dict:
    return {k: round(amounts[k] * 100.0 / grams, 2) for k in usda.NUTRIENTS}


def _from_dish(item: model.Item, dish: dishes.Dish) -> dict:
    """The dish's numbers for her grams, and its recipe scaled to them. The
    recipe's grams are as the recipe weighs them (before any water a baked or
    fried dish loses), so their nutrients add up to the item's."""
    scale = item.grams / dish.typical_serving_g
    breakdown = []
    for fdc_id, grams, label, usda_name in dish.recipe:
        food = usda.food(fdc_id)
        part_grams = round(grams * scale, 1)
        breakdown.append(
            {
                "nameEn": label,
                "grams": part_grams,
                "matched": food is not None,
                "fdcId": fdc_id,
                "usdaName": usda_name,
                "per100g": _wire_per100g(food.per100g) if food else None,
                **(_wire_amounts(usda.scaled(food.per100g, part_grams)) if food else _no_numbers()),
            }
        )
    return {
        **_base(item),
        "matched": True,
        "source": "dish",
        "fdcId": None,
        "usdaName": None,
        "dishKey": dish.key,
        "dishNameEn": dish.name_en,
        "dishNameAr": dish.name_ar,
        "review": dish.review,
        "per100g": _wire_per100g(dish.per100g),
        **_wire_amounts(usda.scaled(dish.per100g, item.grams)),
        "ingredients": breakdown,
    }


def _from_ingredients(item: model.Item) -> Optional[dict]:
    parts = []
    found_amounts = []
    for ingredient in item.ingredients:
        food = usda.match_terms(ingredient.usda_terms or [ingredient.name_en])
        if food is None:
            parts.append(
                {
                    "nameEn": ingredient.name_en,
                    "grams": ingredient.grams,
                    "matched": False,
                    "fdcId": None,
                    "usdaName": None,
                    "per100g": None,
                    **_no_numbers(),
                }
            )
            continue
        amounts = usda.scaled(food.per100g, ingredient.grams)
        found_amounts.append(amounts)
        parts.append(
            {
                "nameEn": ingredient.name_en,
                "grams": ingredient.grams,
                "matched": True,
                "fdcId": food.fdc_id,
                "usdaName": food.name,
                "per100g": _wire_per100g(food.per100g),
                **_wire_amounts(amounts),
            }
        )
    if not found_amounts:
        return None
    grams = sum(i.grams for i in item.ingredients)
    per100g = _per100_from(_sum(found_amounts), grams)
    return {
        **_base(item),
        "grams": grams,
        "matched": all(p["matched"] for p in parts),
        "source": "ingredients",
        "fdcId": None,
        "usdaName": None,
        "per100g": _wire_per100g(per100g),
        **_wire_amounts(usda.scaled(per100g, grams)),
        "ingredients": parts,
    }


def _from_usda(item: model.Item) -> Optional[dict]:
    food = usda.match_terms(item.usda_terms or [item.name_en])
    if food is None:
        return None
    return {
        **_base(item),
        "matched": True,
        "source": "usda",
        "fdcId": food.fdc_id,
        "usdaName": food.name,
        "per100g": _wire_per100g(food.per100g),
        **_wire_amounts(usda.scaled(food.per100g, item.grams)),
    }


def resolve_item(item: model.Item) -> dict:
    if item.confidence < config.MIN_CONFIDENCE:
        return _unmatched(item)
    dish = dishes.match(item.dish_guess, item.name_ar, item.name_en)
    if dish is not None:
        return _from_dish(item, dish)
    if item.ingredients:
        resolved = _from_ingredients(item)
        if resolved is not None:
            return resolved
    return _from_usda(item) or _unmatched(item)


def resolve(items: list) -> dict:
    """The response body: every item, and the meal's totals."""
    resolved = [resolve_item(item) for item in items]
    totals = {}
    for key, wire in WIRE.items():
        total = sum((r[wire] or 0) for r in resolved)
        totals[wire] = int(total) if key == "kcal" else round(total, 1)
    return {"items": resolved, "totals": totals, "estimate": True}
