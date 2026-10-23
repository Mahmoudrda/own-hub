"""Build functions/nutrition/usda_foods.json from the two FoodData Central CSV zips.

Usage: python -I build_usda.py <sr_legacy.zip> <foundation.zip> <out.json>

Reads the CSVs straight out of the zips (nothing is extracted).
"""

import csv
import io
import json
import sys
import zipfile

ENERGY = (1008, 2048, 2047)  # kcal, then Atwater specific, then general
PROTEIN = (1003,)
CARBS = (1005, 1050)  # by difference, then by summation
FAT = (1004, 1085)  # total lipid, then total fat (NLEA)
FIBER = (1079,)
WANTED = set(ENERGY + PROTEIN + CARBS + FAT + FIBER)
MAX_PORTIONS = 6


def _rows(zf, suffix):
    name = next(n for n in zf.namelist() if n.endswith("/" + suffix))
    with zf.open(name) as handle:
        for row in csv.DictReader(io.TextIOWrapper(handle, encoding="utf-8-sig")):
            key = "fdc_id" if "fdc_id" in row else "id"
            if (row.get(key) or "").strip().isdigit():
                yield row


def _num(text):
    try:
        value = float(text)
    except (TypeError, ValueError):
        return None
    return value


def _first(values, ids):
    for nid in ids:
        if nid in values:
            return values[nid]
    return None


def _amount(text):
    value = _num(text)
    if value is None:
        return ""
    if value == int(value):
        return str(int(value))
    return f"{value:g}"


def load(path, dataset, id_file):
    zf = zipfile.ZipFile(path)
    ids = {int(r["fdc_id"]) for r in _rows(zf, id_file)}
    names = {}
    for r in _rows(zf, "food.csv"):
        fid = int(r["fdc_id"])
        if fid in ids:
            names[fid] = r["description"].strip()
    units = {int(r["id"]): r["name"].strip() for r in _rows(zf, "measure_unit.csv")}
    nutrients = {}
    for r in _rows(zf, "food_nutrient.csv"):
        fid = int(r["fdc_id"])
        if fid not in names:
            continue
        nid = int(r["nutrient_id"])
        if nid not in WANTED:
            continue
        value = _num(r["amount"])
        if value is None or value < 0:
            continue
        nutrients.setdefault(fid, {})[nid] = value
    portions = {}
    for r in _rows(zf, "food_portion.csv"):
        fid = int(r["fdc_id"])
        if fid not in names:
            continue
        grams = _num(r["gram_weight"])
        if grams is None or grams <= 0:
            continue
        unit = units.get(int(r["measure_unit_id"] or 9999), "")
        if unit in ("undetermined", ""):
            unit = ""
        parts = [_amount(r["amount"]), unit, r["modifier"].strip(), r["portion_description"].strip()]
        label = " ".join(p for p in parts if p)
        label = " ".join(label.split())
        if not label:
            continue
        seq = _num(r["seq_num"]) or 0
        portions.setdefault(fid, []).append((seq, label, round(grams, 1)))
    out = []
    dropped = 0
    for fid in sorted(names):
        values = nutrients.get(fid, {})
        kcal = _first(values, ENERGY)
        if kcal is None:
            dropped += 1
            continue

        def r1(v):
            return None if v is None else round(v, 2)

        food = {
            "fdcId": fid,
            "name": names[fid],
            "dataset": dataset,
            "kcal": round(kcal, 1),
            "protein_g": r1(_first(values, PROTEIN)),
            "carbs_g": r1(_first(values, CARBS)),
            "fat_g": r1(_first(values, FAT)),
            "fiber_g": r1(_first(values, FIBER)),
        }
        seen = set()
        kept = []
        for _, label, grams in sorted(portions.get(fid, [])):
            if label in seen:
                continue
            seen.add(label)
            kept.append([grams, label])
            if len(kept) >= MAX_PORTIONS:
                break
        if kept:
            food["portions"] = kept
        out.append(food)
    return out, dropped, len(names)


def main(argv):
    sr_zip, fnd_zip, out_path = argv
    sr, sr_dropped, sr_total = load(sr_zip, "sr_legacy", "sr_legacy_food.csv")
    fnd, fnd_dropped, fnd_total = load(fnd_zip, "foundation", "foundation_food.csv")
    foods = sr + fnd
    doc = {
        "source": "USDA FoodData Central",
        "datasets": {
            "sr_legacy": "SR Legacy, April 2018 (FoodData_Central_sr_legacy_food_csv_2018-04)",
            "foundation": "Foundation Foods, April 2026 (FoodData_Central_foundation_food_csv_2026-04-30)",
        },
        "licence": "CC0 1.0",
        "per": "100 g edible portion",
        "fields": ["fdcId", "name", "dataset", "kcal", "protein_g", "carbs_g", "fat_g", "fiber_g", "portions"],
        "portions": "[gram weight, label]",
        "foods": foods,
    }
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(doc, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    missing = {k: sum(1 for f in foods if f[k] is None) for k in ("protein_g", "carbs_g", "fat_g", "fiber_g")}
    print(f"sr_legacy: {len(sr)} kept of {sr_total}, {sr_dropped} dropped (no energy)")
    print(f"foundation: {len(fnd)} kept of {fnd_total}, {fnd_dropped} dropped (no energy)")
    print(f"total {len(foods)}; missing: {missing}")
    print(f"with portions: {sum(1 for f in foods if 'portions' in f)}")


if __name__ == "__main__":
    main(sys.argv[1:])
