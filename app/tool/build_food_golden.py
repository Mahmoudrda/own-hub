#!/usr/bin/env python3
"""Write `test/features/eat/food_golden.csv`: every food in the pack beside the
USDA FoodData Central record it is checked against.

`python3 -I tool/build_food_golden.py` (standard library only, needs network).

The reference figures are read live from the FoodData Central API, never typed
in, and each row names the record (dataset, fdcId, description) and the day it
was read. Set FDC_API_KEY to use your own key; the shared DEMO_KEY allows ten
calls an hour and this script makes five.

A row's `status` says what the check proves:

  * `verified`: a USDA record of the same food that the pack's recipe does not
    use, so independent of the recipe's arithmetic. Held to the production
    plan's tolerance for a composite dish (energy within 25 percent; protein,
    carbohydrate and fat within 20 percent or 3 g).
  * `record_matches`: the pack's figure for a food that is one USDA record,
    compared with that record read today. It checks the transcription, not the
    food: USDA is the source the pack was built from. Held to rounding.
  * `unverified`: nothing here says the figure is right. No reference figure is
    written, either because no source was consulted for the food itself (a
    recipe of several foods, a stand-in for a food USDA does not hold) or
    because the one independent USDA analogue read fell outside the tolerance.
    The note then gives that analogue's figures for the dietitian, and the
    recipe is not changed to chase a single analogue.

Sources the plan also names (WAFCT 2020, the Egyptian National Nutrition
Institute tables, product labels, dishes weighed in Rahma's kitchen) are not
here: none could be read in a way that leaves a checkable record.
"""

import csv
import datetime
import json
import os
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
PACK = ROOT / "app" / "assets" / "content" / "foods_eg.json"
SINGLES = ROOT / "app" / "tool" / "food_pack_singles.json"
DISHES = ROOT / "functions" / "nutrition" / "egyptian_dishes.json"
TARGET = ROOT / "app" / "test" / "features" / "eat" / "food_golden.csv"

API = "https://api.nal.usda.gov/fdc/v1/foods"
NUTRIENT_NUMBERS = {"203": "protein_g", "204": "fat_g", "205": "carbs_g", "208": "kcal"}
BATCH = 20

# Singles whose USDA record stands in for a different food, from the notes in
# food_pack_singles.json. Matching the stand-in says nothing about the food.
STAND_IN = {
    "rice_basmati": "cooked long-grain white rice stands in for basmati",
    "freekeh": "cooked bulgur stands in for freekeh",
    "laban_rayeb": "cultured buttermilk stands in for laban rayeb",
    "turkish_coffee_sada": "restaurant espresso stands in for Turkish coffee",
    "digestive_biscuit": "graham cracker stands in for a digestive biscuit",
    "protein_crisps": "a whey protein powder stands in for a branded crisp",
    "veg_mix_frozen": "frozen mixed vegetables stand in for a roasting tray",
    "spices_and_seasoning": "black pepper stands in for a pinch of seasoning",
    "zaatar_mix": "dried thyme stands in for the thyme and sesame blend",
    "spice_blend_store": "paprika stands in for a packet spice blend",
}

# Dishes that are one USDA record and named for what that record is.
ONE_RECORD_DISHES = {
    "eggs_boiled": 173424,
    "batates_maqlia": 170698,
    "termes": 172424,
    "batata": 168483,
    "aish_shami": 174915,
}

# Dishes checked against a USDA record of the same food that the recipe does not
# use: independent of the recipe's arithmetic.
INDEPENDENT = {
    "omelette": 172185,
    "egg_fried_olive": 173423,
    "falafel": 172455,
    "halawa": 167996,
}

# Foods left `unverified` whose USDA analogues are worth showing the dietitian.
COMPARE_ONLY = {"hummus": (172454, 174289)}

COLUMNS = [
    "id", "name_en", "kind", "status",
    "ours_kcal", "ours_protein_g", "ours_carbs_g", "ours_fat_g",
    "ref_kcal", "ref_protein_g", "ref_carbs_g", "ref_fat_g",
    "kcal_diff_pct", "source", "source_id", "fetched", "note",
]


def misses(per, ref):
    """What is outside the plan's composite tolerance: energy within 25 percent,
    protein, carbohydrate and fat each within 20 percent or 3 g."""
    out = []
    if abs(per["kcal"] - ref["kcal"]) > 0.25 * ref["kcal"]:
        out.append("energy")
    for ours, theirs, name in (
        (per["proteinG"], ref["protein_g"], "protein"),
        (per["carbsG"], ref["carbs_g"], "carbohydrate"),
        (per["fatG"], ref["fat_g"], "fat"),
    ):
        if abs(ours - theirs) > max(0.2 * theirs, 3):
            out.append(name)
    return out


def fetch(ids, key):
    found = {}
    ids = sorted(set(ids))
    for start in range(0, len(ids), BATCH):
        body = json.dumps({
            "fdcIds": ids[start:start + BATCH],
            "format": "abridged",
            "nutrients": [int(n) for n in NUTRIENT_NUMBERS],
        }).encode()
        request = urllib.request.Request(
            f"{API}?api_key={key}", data=body, headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            for food in json.loads(response.read()):
                figures = {NUTRIENT_NUMBERS[str(n["number"])]: float(n["amount"]) for n in food["foodNutrients"]
                           if str(n["number"]) in NUTRIENT_NUMBERS}
                missing = set(NUTRIENT_NUMBERS.values()) - set(figures)
                if missing:
                    raise SystemExit(f"{food['fdcId']}: the API gave no {sorted(missing)}")
                found[food["fdcId"]] = {**figures, "description": food["description"], "dataset": food["dataType"]}
    absent = set(ids) - set(found)
    if absent:
        raise SystemExit(f"FoodData Central returned nothing for {sorted(absent)}")
    return found


def main():
    pack = json.loads(PACK.read_text(encoding="utf-8"))["foods"]
    singles = {row["id"]: row for row in json.loads(SINGLES.read_text(encoding="utf-8"))["foods"]}
    recipes = {d["key"]: [line["fdcId"] for line in d["recipe"]]
               for d in json.loads(DISHES.read_text(encoding="utf-8"))["dishes"]}

    for food_id in STAND_IN:
        if food_id not in singles:
            raise SystemExit(f"{food_id} is not a single food")
    for food_id, fdc_id in ONE_RECORD_DISHES.items():
        if recipes[food_id] != [fdc_id]:
            raise SystemExit(f"{food_id} is not the one record {fdc_id}: {recipes[food_id]}")
    for food_id, fdc_id in INDEPENDENT.items():
        if fdc_id in recipes[food_id]:
            raise SystemExit(f"{food_id}: record {fdc_id} is one of the recipe's own, so not independent")

    # food id -> (status, fdcId)
    plan = {}
    for food in pack:
        food_id = food["id"]
        if food_id in singles and food_id not in STAND_IN:
            plan[food_id] = ("record_matches", singles[food_id]["fdcId"])
        elif food_id in ONE_RECORD_DISHES:
            plan[food_id] = ("record_matches", ONE_RECORD_DISHES[food_id])
        elif food_id in INDEPENDENT:
            plan[food_id] = ("verified", INDEPENDENT[food_id])

    wanted = {fdc for _, fdc in plan.values()} | {fdc for ids in COMPARE_ONLY.values() for fdc in ids}
    records = fetch(wanted, os.environ.get("FDC_API_KEY", "DEMO_KEY"))
    today = datetime.date.today().isoformat()

    rows = []
    for food in pack:
        food_id = food["id"]
        per = food["per100g"]
        row = {
            "id": food_id, "name_en": food["nameEn"],
            "kind": "single" if food_id in singles else "dish",
            "status": "unverified",
            "ours_kcal": per["kcal"], "ours_protein_g": per["proteinG"],
            "ours_carbs_g": per["carbsG"], "ours_fat_g": per["fatG"],
            "source": "none consulted", "note": "",
        }
        out = misses(per, records[plan[food_id][1]]) if food_id in INDEPENDENT else []
        if food_id in INDEPENDENT and out:
            ref = records[INDEPENDENT[food_id]]
            row["note"] = (
                f"USDA {ref['description']} (fdcId {INDEPENDENT[food_id]}) reads "
                f"{ref['kcal']:g} kcal, {ref['protein_g']:g} g protein, {ref['carbs_g']:g} g carbohydrate, "
                f"{ref['fat_g']:g} g fat per 100 g; outside tolerance on {', '.join(out)}, recipe left as it is"
            )
        elif food_id in plan:
            status, fdc_id = plan[food_id]
            ref = records[fdc_id]
            row.update(
                status=status,
                ref_kcal=ref["kcal"], ref_protein_g=ref["protein_g"],
                ref_carbs_g=ref["carbs_g"], ref_fat_g=ref["fat_g"],
                kcal_diff_pct=round((per["kcal"] - ref["kcal"]) / ref["kcal"] * 100, 1) if ref["kcal"] else "",
                source=f"USDA FoodData Central {ref['dataset']}: {ref['description']}",
                source_id=fdc_id, fetched=today,
            )
            if status == "verified":
                row["note"] = "a USDA record of the same food that the recipe does not use"
        elif food_id in STAND_IN:
            row["note"] = f"stand-in: {STAND_IN[food_id]}"
        elif food_id in COMPARE_ONLY:
            parts = [f"{records[i]['description']} (fdcId {i}) {records[i]['kcal']:g} kcal" for i in COMPARE_ONLY[food_id]]
            row["note"] = "USDA analogues differ from each other and from the pack: " + "; ".join(parts)
        elif food_id in recipes:
            row["note"] = f"standard recipe of USDA records {', '.join(str(i) for i in dict.fromkeys(recipes[food_id]))}"
        rows.append(row)

    with TARGET.open("w", encoding="utf-8", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    counts = {}
    for row in rows:
        counts[row["status"]] = counts.get(row["status"], 0) + 1
    print(f"{len(rows)} foods -> {TARGET.relative_to(ROOT)}  {counts}")


if __name__ == "__main__":
    sys.exit(main())
