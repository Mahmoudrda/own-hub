#!/usr/bin/env python3
"""Emit the one document the recipe list screen reads, and the version beside it.

`python3 tool/build_recipe_index.py` writes
`tool/out/recipeIndex_{locale}_v{N}.json` and `tool/out/meta_recipes.json`, ready
to be uploaded to Firestore as `recipeIndex/{locale}_v{N}` and `meta/recipes`.

## The mistake this exists to avoid

Firestore bills per document read. If the library list is a query returning N
documents every time the Eat tab opens, that is N reads per open. At 200
recipes, 10,000 women and three opens a day, that is **six million reads a day**,
which at the published multi-region rate of $0.06 per 100,000 is roughly **$360 a
day**. This project has already been bitten by exactly that shape of cost, and
the head commit on this branch says so.

So the list screen reads **one** document:

  * `meta/recipes` is `{ version: N }`. Read once a session; if `N` has not
    moved, the cached index is used and the index document is not read at all.
  * `recipeIndex/{locale}_v{N}` holds one row per recipe — id, titles, section,
    tier, time, protein, EGP, allergens, diet tags, mark. Roughly 250 bytes
    each, so 200 recipes is about 50 KB and Firestore's 1 MB document ceiling
    holds to around 2,000 recipes.
  * A full body is fetched one document at a time, on open, cache first.

Steady state at 10,000 daily women is one index read plus about three recipe
reads each: roughly **$0.72 a month**. Three orders of magnitude, from one
structural decision.

The row deliberately carries `allergensFinal` and `allergenReviewedBy`. Screening
happens over the index, client side, before anything is drawn — so a recipe a
woman must not be offered is never fetched, and the guard does not need a body
to decide.

(The unit prices above must be re-checked against the project's actual Firebase
region before anyone quotes them. The orders of magnitude are the point.)
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = os.path.join(HERE, "..", "assets", "content", "rahma_recipes.json")
OUT = os.path.join(HERE, "out")

# One entry per locale the app ships. Both indexes carry the same rows today,
# because `titleAr` is null on every recipe until Rahma writes the Arabic
# titles; they are emitted separately anyway so that the day she does, the
# Arabic build gets her titles without a schema change.
LOCALES = ("en", "ar")


def row(recipe):
    """The list row. Small on purpose: every byte is multiplied by the library."""
    return {
        "recipeId": recipe["recipeId"],
        "titleEn": recipe["titleEn"],
        "titleAr": recipe["titleAr"],
        "sectionId": recipe["sectionId"],
        "orderInSection": recipe["orderInSection"],
        "source": recipe["source"],
        "status": recipe["status"],
        "tier": recipe["tier"],
        "totalMinutes": recipe["totalMinutes"],
        "proteinG": recipe["proteinG"],
        "egpPerServing": recipe["egpPerServing"],
        # Carried so the guard can screen before a body is ever fetched.
        "allergensFinal": recipe["allergensFinal"],
        "allergenReviewedBy": recipe["allergenReviewedBy"],
        "dietTags": recipe["dietTags"],
        "markKey": recipe["markKey"],
        "titleSearch": recipe["titleSearch"],
    }


def main():
    seed = json.load(open(SEED, encoding="utf-8"))
    version = seed["contentVersion"]
    os.makedirs(OUT, exist_ok=True)

    rows = [row(r) for r in seed["recipes"] + seed["assemblies"]]
    for locale in LOCALES:
        payload = {
            "version": version,
            "locale": locale,
            "sections": seed["sections"],
            "rows": rows,
        }
        path = os.path.join(OUT, f"recipeIndex_{locale}_v{version}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(path)
        print(f"{locale}: {len(rows)} rows, {size / 1024:.1f} KB -> {path}")
        if size > 900 * 1024:
            raise SystemExit(
                "the index document is approaching Firestore's 1 MB ceiling. "
                "Split it by section before it stops being one read."
            )

    meta = os.path.join(OUT, "meta_recipes.json")
    with open(meta, "w", encoding="utf-8") as f:
        json.dump({"version": version}, f)
    print(f"meta/recipes: version {version} -> {meta}")


if __name__ == "__main__":
    main()
