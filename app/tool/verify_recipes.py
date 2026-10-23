#!/usr/bin/env python3
"""Check every recipe against the food pack, deterministically, and publish the
ones that pass.

    python3 -I tool/verify_recipes.py            # check, update the seed, print a table
    python3 -I tool/verify_recipes.py --check    # check only, change nothing

Standard library only. Same input, same output: no clock reads except the
default `checkedAt`, which is kept from the previous run when nothing else about
the record changed, and which `--now` pins.

## What passing means

A recipe passes when all of these hold (and only a recipe Own Hub wrote,
`source: authored`, is then published on that alone; a book card needs a
person's signature whatever the check says):

  * it has at least one ingredient, and every ingredient resolves by `foodId` in
    `assets/content/foods_eg.json` and carries a weight in grams (an optional or
    side-only row may be unweighed; it is not in the figures);
  * every food it uses carries an `allergens` list (an empty list is a claim, a
    missing one is "nobody has said");
  * the allergens derived from the foods, plus a keyword scan of the ingredient
    names and the method (English and Egyptian Arabic), are all on the recorded
    `allergensFinal`. A recorded set may be larger than what was derived. It may
    never be smaller;
  * the four figures recomputed from the grams are within 5 percent of the
    stated ones (rounding to a whole number is allowed for);
  * there are at least two steps;
  * the diet tags that make a claim (vegetarian, vegan, gluten free, no nuts)
    are consistent with the ingredients.

## Fail closed

Anything else and the recipe is NOT verified. It gets no `verification` record,
and a recipe nobody signed goes (back) to `review`, where `AllergyGuard` hides it
from a woman who declared an allergy. It is reported with the reason. The script
never edits an allergen list, a figure or a tag to make a recipe pass: fixing the
data is a person's job.

## What it never does

It never writes `allergenReviewedBy` or `cookedBy`. This is an automated check
of arithmetic and word lists, not a person who looked at a dish, and the record
says so (`method: ownhub-auto-check-v1`). A recipe a person has signed keeps its
signature and status whether or not it passes here; a discrepancy on one is
printed so somebody reads it.
"""

import argparse
import copy
import datetime
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# `python3 -I` leaves out the script's own folder, so it is put back by hand.
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from allergen_tripwire import scan as scan_arabic  # noqa: E402

METHOD = "ownhub-auto-check-v1"
SEED = os.path.join(HERE, "..", "assets", "content", "rahma_recipes.json")
PACK = os.path.join(HERE, "..", "assets", "content", "foods_eg.json")

# The sixteen allergen tokens the app knows.
ALLERGENS = frozenset({
    "celery", "coconut", "crustaceans", "eggs", "fava", "fish", "gluten",
    "lupin", "milk", "molluscs", "mustard", "peanuts", "sesame", "soy",
    "sulphites", "tree_nuts",
})

MACRO_TOLERANCE_PCT = 5.0
MIN_STEPS = 2

# ---------------------------------------------------------------- word lists
# Phrase -> the tags it fires. Matched longest first and consumed, so a longer
# phrase wins the words it covers: "peanut butter" is a peanut, not a butter,
# and "coconut milk" is a coconut, not a milk. A phrase mapped to no tag is
# there only to stop a shorter word firing inside it.
#
# Built to over-fire, like `allergen_tripwire.py`: a wrong hit costs a reviewer
# a minute, a missed one costs somebody a reaction.
_EN = {
    # phrases that are not what their parts say
    "peanut butter": ("peanuts",),
    "nut butter": ("peanuts", "tree_nuts"),
    "almond butter": ("tree_nuts",),
    "cashew butter": ("tree_nuts",),
    "cocoa butter": (),
    "butternut": (),
    "coconut milk": ("coconut",),
    "coconut cream": ("coconut",),
    "coconut oil": ("coconut",),
    "almond milk": ("tree_nuts",),
    "oat milk": ("gluten",),
    "soy milk": ("soy",),
    "rice milk": (),
    "soy sauce": ("soy", "gluten"),
    "stock cube": ("celery", "gluten"),
    "stock cubes": ("celery", "gluten"),
    "baking powder": ("gluten",),
    "ice cream": ("milk",),
    "dried fruit": ("sulphites",),
    "dried apricot": ("sulphites",),
    "dried mango": ("sulphites",),
    "dried fig": ("sulphites",),
    "broad bean": ("fava",),
    "ful medames": ("fava",),
    "sea bass": ("fish",),
    "shell fish": ("crustaceans", "molluscs"),
    "sea food": ("fish", "crustaceans", "molluscs"),
    "worcestershire": ("fish", "sulphites"),
    "worcester sauce": ("fish", "sulphites"),
    "pine nut": ("tree_nuts",),
    "brazil nut": ("tree_nuts",),
    # words
    "peanut": ("peanuts",), "groundnut": ("peanuts",),
    "nut": ("tree_nuts", "peanuts"),
    "almond": ("tree_nuts",), "walnut": ("tree_nuts",),
    "hazelnut": ("tree_nuts",), "cashew": ("tree_nuts",),
    "pistachio": ("tree_nuts",), "pecan": ("tree_nuts",),
    "macadamia": ("tree_nuts",), "chestnut": ("tree_nuts",),
    "coconut": ("coconut",),
    "milk": ("milk",), "buttermilk": ("milk",), "cheese": ("milk",),
    "butter": ("milk",), "yoghurt": ("milk",), "yogurt": ("milk",),
    "cream": ("milk",), "ghee": ("milk",), "whey": ("milk",),
    "labneh": ("milk",), "labna": ("milk",), "labne": ("milk",),
    "mozzarella": ("milk",), "feta": ("milk",),
    "cottage": ("milk",), "areesh": ("milk",), "kefir": ("milk",),
    "casein": ("milk",), "halloumi": ("milk",), "ricotta": ("milk",),
    "parmesan": ("milk",), "custard": ("milk",), "rumi": ("milk",),
    "egg": ("eggs",), "mayonnaise": ("eggs",), "mayo": ("eggs",),
    "omelette": ("eggs",), "omelet": ("eggs",), "meringue": ("eggs",),
    "flour": ("gluten",), "bread": ("gluten",), "breadcrumb": ("gluten",),
    "pasta": ("gluten",), "macaroni": ("gluten",), "spaghetti": ("gluten",),
    "noodle": ("gluten",), "wheat": ("gluten",), "couscous": ("gluten",),
    "bulgur": ("gluten",), "freekeh": ("gluten",), "semolina": ("gluten",),
    "barley": ("gluten",), "rye": ("gluten",), "oat": ("gluten",),
    "toast": ("gluten",), "tortilla": ("gluten",), "biscuit": ("gluten",),
    "cracker": ("gluten",), "pita": ("gluten",), "bun": ("gluten",),
    "wrap": ("gluten",), "rusk": ("gluten",), "panko": ("gluten",),
    "pane": ("gluten",), "seitan": ("gluten",), "malt": ("gluten",),
    "aish": ("gluten",), "bouillon": ("celery", "gluten"),
    "vermicelli": ("gluten",), "pastry": ("gluten", "milk"),
    "pastries": ("gluten", "milk"), "filo": ("gluten",),
    "phyllo": ("gluten",), "fillo": ("gluten",),
    "croissant": ("gluten", "milk", "eggs"),
    "bechamel": ("milk", "gluten"), "béchamel": ("milk", "gluten"),
    "nutella": ("tree_nuts", "milk", "soy"),
    "shellfish": ("crustaceans", "molluscs"),
    "seafood": ("fish", "crustaceans", "molluscs"),
    "fish": ("fish",), "tuna": ("fish",), "sardine": ("fish",),
    "salmon": ("fish",), "tilapia": ("fish",), "anchovy": ("fish",),
    "anchovies": ("fish",), "cod": ("fish",), "mackerel": ("fish",),
    "bolti": ("fish",), "trout": ("fish",), "herring": ("fish",),
    "shrimp": ("crustaceans",), "prawn": ("crustaceans",),
    "crab": ("crustaceans",), "lobster": ("crustaceans",),
    "crayfish": ("crustaceans",),
    "squid": ("molluscs",), "calamari": ("molluscs",),
    "mussel": ("molluscs",), "oyster": ("molluscs",),
    "clam": ("molluscs",), "octopus": ("molluscs",),
    "scallop": ("molluscs",), "snail": ("molluscs",),
    "sesame": ("sesame",), "tahini": ("sesame",), "tahina": ("sesame",),
    "zaatar": ("sesame",), "zatar": ("sesame",), "halva": ("sesame",),
    "halawa": ("sesame",), "dukkah": ("sesame", "tree_nuts"),
    "soy": ("soy",), "soya": ("soy",), "soybean": ("soy",), "tofu": ("soy",),
    "edamame": ("soy",), "miso": ("soy",), "tempeh": ("soy",),
    "celery": ("celery",), "celeriac": ("celery",),
    "mustard": ("mustard",),
    "lupin": ("lupin",), "lupine": ("lupin",), "termis": ("lupin",),
    "sulphite": ("sulphites",), "sulfite": ("sulphites",),
    "raisin": ("sulphites",), "sultana": ("sulphites",),
    "fava": ("fava",), "ful": ("fava",), "foul": ("fava",),
    "taameya": ("fava", "gluten", "sesame"), "falafel": ("fava", "gluten", "sesame"),
    "felafel": ("fava", "gluten", "sesame"),
}
# Plural forms are matched by an optional trailing "s" / "es" in the pattern.
_EN_ORDER = sorted(_EN, key=lambda p: (-len(p), p))
_EN_PATTERNS = [
    (
        phrase,
        re.compile(r"(?<![a-z])" + re.escape(phrase) + r"(?:e?s)?(?![a-z])"),
        _EN[phrase],
    )
    for phrase in _EN_ORDER
]

# Words that make a food flesh (meat, poultry, fish, shellfish), for the
# vegetarian and vegan tags. The pack has no such field, so it is read from the
# food's id and names. A stock cube is not flesh whatever it is flavoured with.
_FLESH = (
    "chicken", "beef", "lamb", "mutton", "veal", "meat", "mince", "minced",
    "liver", "steak", "turkey", "duck", "goat", "sausage", "sujuk", "bacon",
    "ham", "kofta", "kebab", "kebda", "frakh", "lahma", "wings", "drumstick",
    "fish", "tuna", "sardine", "salmon", "tilapia", "anchovy", "anchovies",
    "shrimp", "prawn", "crab", "lobster", "squid", "calamari", "mussel",
    "oyster", "pane", "gambari", "samak",
)
_FLESH_PATTERN = re.compile(
    r"(?<![a-z])(?:" + "|".join(_FLESH) + r")(?:e?s)?(?![a-z])"
)
_NOT_FLESH_PHRASES = re.compile(r"stock cubes?|bouillon|chicken stock cube")
# Honey is not vegan; the rest of what vegan excludes is an allergen tag.
_NOT_VEGAN_WORDS = re.compile(r"(?<![a-z])honey(?![a-z])")


def _norm(text):
    """Lower case, apostrophes dropped, separators to spaces."""
    text = (text or "").lower()
    text = text.replace("'", "").replace("’", "")
    return re.sub(r"[_\-/,;:()\n]+", " ", text)


def scan_english(text):
    """{tag: [phrase, ...]} for every allergen phrase found in [text]."""
    hits = {}
    remaining = _norm(text)
    for phrase, pattern, tags in _EN_PATTERNS:
        if not pattern.search(remaining):
            continue
        for tag in tags:
            hits.setdefault(tag, []).append(phrase)
        remaining = pattern.sub(lambda m: " " * len(m.group(0)), remaining)
    return hits


def keyword_hits(text):
    """English and Arabic keyword hits together."""
    hits = {}
    for tag, words in scan_english(text).items():
        hits.setdefault(tag, []).extend(words)
    for tag, words in scan_arabic(text or "").items():
        hits.setdefault(tag, []).extend(words)
    return hits


# --------------------------------------------------------------------- checks
def load_foods(path=PACK):
    pack = json.load(open(path, encoding="utf-8"))
    return {f["id"]: f for f in pack["foods"]}


def _all_steps(recipe):
    """The method she cooks from: flat steps, then each component's."""
    steps = list(recipe.get("steps") or [])
    for part in (recipe.get("components") or []):
        steps.extend(part.get("steps") or [])
    return steps


def _every_step(recipe):
    """Every step there is, alternative methods included, for the word scan."""
    steps = _all_steps(recipe)
    for part in (recipe.get("variants") or []):
        steps.extend(part.get("steps") or [])
    return steps


def _parts(recipe):
    """Components and variants, which can carry ingredients of their own."""
    return list(recipe.get("components") or []) + list(
        recipe.get("variants") or []
    )


def _counted(ingredient):
    return not (
        ingredient.get("optional")
        or ingredient.get("servingSideOnly")
        or ingredient.get("inFigures") is False
    )


def _is_signed(recipe):
    return bool(recipe.get("allergenReviewedBy"))


class Result:
    def __init__(self, recipe_id):
        self.recipe_id = recipe_id
        self.problems = []
        self.derived = []
        self.macro_delta_pct = None
        self.skipped = False

    @property
    def ok(self):
        return not self.skipped and not self.problems

    def fail(self, why):
        self.problems.append(why)


def verify_recipe(recipe, foods):
    """Check one recipe. Never edits it."""
    res = Result(recipe["recipeId"])
    ingredients = recipe.get("ingredients") or []
    if not ingredients:
        res.fail("no ingredients to check")
        return res
    # Ingredients inside a component or a variant are not resolved here, so a
    # recipe that carries any is not verified rather than half checked.
    if any(part.get("ingredients") for part in _parts(recipe)):
        res.fail("a component or variant has ingredients of its own")

    # 1. Every ingredient resolves and is weighed.
    used = []
    for ing in ingredients:
        ref = ing.get("ingredientRef", "?")
        food_id = ing.get("foodId")
        if not food_id:
            res.fail(f"{ref}: no foodId")
            continue
        food = foods.get(food_id)
        if food is None:
            res.fail(f"{ref}: foodId {food_id} is not in the food pack")
            continue
        grams = ing.get("grams")
        if _counted(ing) and (not isinstance(grams, (int, float)) or grams <= 0):
            res.fail(f"{ref}: no weight in grams")
            continue
        used.append((ing, food))

    # 2. Every food carries an allergen list.
    for ing, food in used:
        if not isinstance(food.get("allergens"), list):
            res.fail(f"{food['id']}: the food has no allergen list")

    # 3. Allergens: foods plus keyword scan, against the recorded set.
    from_foods = set()
    for _ing, food in used:
        if isinstance(food.get("allergens"), list):
            from_foods.update(food["allergens"])
    texts = []
    texts.extend([recipe.get("titleEn"), recipe.get("titleAr")])
    for ing, food in used:
        texts.extend([
            ing.get("qtyTextEn"), ing.get("qtyTextAr"),
            food.get("id"), food.get("nameEn"), food.get("nameAr"),
        ])
    for step in _every_step(recipe):
        texts.extend([step.get("textEn"), step.get("textAr")])
    texts.extend([recipe.get("bodyAr"), recipe.get("closingAr")])
    for part in _parts(recipe):
        texts.extend([part.get("headingAr"), part.get("labelAr")])
    from_words = {}
    for text in texts:
        for tag, words in keyword_hits(text).items():
            from_words.setdefault(tag, set()).update(words)

    derived = from_foods | set(from_words)
    res.derived = sorted(derived)
    final = set(recipe.get("allergensFinal") or [])
    removed = recipe.get("allergensRemoved") or {}
    unknown_tags = (final | set(removed)) - ALLERGENS
    if unknown_tags:
        res.fail(f"allergen tokens the app does not know: {sorted(unknown_tags)}")
    if removed and not _is_signed(recipe):
        res.fail(
            "an allergen was removed with a written reason, and only a person "
            "may do that"
        )
    reasoned = {t for t, why in removed.items() if str(why).strip()}
    for tag in sorted(from_foods - final - reasoned):
        res.fail(f"{tag} is in the foods used but not on the recorded allergens")
    for tag in sorted(set(from_words) - final - reasoned - from_foods):
        words = ", ".join(sorted(from_words[tag]))
        res.fail(
            f"the keyword scan found {tag} ({words}) but the recorded "
            f"allergens lack it"
        )

    # 4. Figures from the grams.
    _check_macros(recipe, used, res)

    # 5. A method.
    if len(_all_steps(recipe)) < MIN_STEPS:
        res.fail(f"fewer than {MIN_STEPS} steps")

    # 6. Diet tags that make a claim.
    _check_diet(recipe, used, derived, res)
    return res


def _check_macros(recipe, used, res):
    serves = recipe.get("serves")
    if not isinstance(serves, int) or serves < 1:
        res.fail("no number of servings")
        return
    if recipe.get("macroBasis") != "computed":
        res.fail("the figures are withheld, so there is nothing to compare")
        return
    total = {"kcal": 0.0, "proteinG": 0.0, "carbsG": 0.0, "fatG": 0.0}
    for ing, food in used:
        if not _counted(ing):
            continue
        per = food.get("per100g") or {}
        for key in total:
            if key not in per:
                res.fail(f"{food['id']}: the food has no {key}")
                return
            total[key] += per[key] * ing["grams"] / 100.0
    worst = 0.0
    for key, value in total.items():
        expected = value / serves
        stated = recipe.get(key)
        if not isinstance(stated, (int, float)):
            res.fail(f"{key} is not stated")
            return
        # A stated figure is a whole number, so it may sit half a unit away
        # from the exact sum before it counts as a disagreement.
        gap = max(0.0, abs(stated - expected) - 0.5)
        pct = 0.0 if gap == 0 else gap / max(expected, 1.0) * 100.0
        worst = max(worst, pct)
        if pct > MACRO_TOLERANCE_PCT:
            res.fail(
                f"{key}: stated {stated}, recomputed {expected:.1f} "
                f"({pct:.1f}% apart)"
            )
    res.macro_delta_pct = round(worst, 1)


def _is_flesh(ing, food):
    text = " ".join([
        food.get("id") or "", food.get("nameEn") or "",
        ing.get("qtyTextEn") or "",
    ])
    text = _NOT_FLESH_PHRASES.sub(" ", _norm(text))
    if _FLESH_PATTERN.search(text):
        return True
    return bool(
        set(food.get("allergens") or []) & {"fish", "crustaceans", "molluscs"}
    )


def _check_diet(recipe, used, derived, res):
    tags = {t.strip().lower() for t in recipe.get("dietTags") or []}
    counted = [(i, f) for i, f in used if _counted(i)]
    flesh = [f["id"] for i, f in counted if _is_flesh(i, f)]
    if ("vegetarian" in tags or "vegan" in tags) and flesh:
        res.fail(f"tagged vegetarian but contains {', '.join(sorted(set(flesh)))}")
    if "vegan" in tags:
        if derived & {"milk", "eggs"}:
            res.fail("tagged vegan but contains milk or eggs")
        if any(
            _NOT_VEGAN_WORDS.search(_norm(f"{f['id']} {i.get('qtyTextEn') or ''}"))
            for i, f in counted
        ):
            res.fail("tagged vegan but contains honey")
    if "gluten_free" in tags and "gluten" in derived:
        res.fail("tagged gluten free but contains gluten")
    if "no_nuts" in tags and derived & {"tree_nuts", "peanuts"}:
        res.fail("tagged no nuts but contains nuts")


# ---------------------------------------------------------------- the seed
def _record(res, checked_at):
    return {
        "method": METHOD,
        "checkedAt": checked_at,
        "macroDeltaPct": res.macro_delta_pct,
        "allergensDerived": res.derived,
    }


def _auto_publishes(recipe):
    """Only a recipe Own Hub wrote may ship on the automated check alone."""
    return recipe.get("source") == "authored"


def _kept_record(record, previous):
    if previous and {
        k: v for k, v in previous.items() if k != "checkedAt"
    } == {k: v for k, v in record.items() if k != "checkedAt"}:
        # Nothing changed, so the date it was checked does not either.
        record["checkedAt"] = previous.get("checkedAt", record["checkedAt"])
    return record


def apply_all(recipes, foods, now=None):
    """Verify [recipes] in place and return one [Result] per recipe.

    A passing recipe that Own Hub wrote (`source: authored`) gets a
    `verification` record and, when no person has signed it, `status:
    published`. A passing recipe from anywhere else (Rahma's book) is never
    published by this script: unsigned, it goes to `review` with no record.
    A failing one loses any record it carried and, when
    no person has signed it, goes back to `review`. `allergenReviewedBy` and
    `cookedBy` are never touched.
    """
    stamp = now or datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT00:00:00Z"
    )
    results = []
    for recipe in recipes:
        res = verify_recipe(recipe, foods)
        if recipe.get("status") == "draft":
            # Somebody is still writing it. Not this script's to publish.
            res.skipped = True
            results.append(res)
            continue
        previous = recipe.get("verification")
        if res.ok and not _auto_publishes(recipe):
            # Not one of Own Hub's own recipes (Rahma's book cards, for one):
            # the check passing does not publish it. A signed card keeps its
            # signature and status and may carry the record; an unsigned one
            # waits in review for a person.
            if _is_signed(recipe):
                recipe["verification"] = _kept_record(
                    _record(res, stamp), previous
                )
            else:
                recipe.pop("verification", None)
                recipe["status"] = "review"
        elif res.ok:
            record = _kept_record(_record(res, stamp), previous)
            recipe["verification"] = record
            if not _is_signed(recipe):
                recipe["status"] = "published"
        else:
            recipe.pop("verification", None)
            if not _is_signed(recipe):
                recipe["status"] = "review"
        results.append(res)
    return results


def _state(before, recipe):
    after = recipe.get("status")
    return after if before == after else f"{before}>{after}"


def format_table(rows):
    header = ("recipe", "signed", "status", "check", "macro%", "allergens", "why")
    widths = [len(h) for h in header]
    for row in rows:
        widths = [max(w, len(str(c))) for w, c in zip(widths, row)]
    line = lambda r: "  ".join(str(c).ljust(w) for c, w in zip(r, widths)).rstrip()
    return "\n".join([line(header), line(["-" * w for w in widths])] +
                     [line(r) for r in rows])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--seed", default=SEED, help="the recipe file")
    parser.add_argument("--foods", default=PACK, help="the food pack")
    parser.add_argument("--out", help="write here instead of over --seed")
    parser.add_argument(
        "--check", action="store_true",
        help="report only; exit 1 if the file would change",
    )
    parser.add_argument("--now", help="checkedAt for a new record")
    args = parser.parse_args(argv)

    seed = json.load(open(args.seed, encoding="utf-8"))
    foods = load_foods(args.foods)
    before = copy.deepcopy(seed)
    recipes = seed["recipes"] + seed.get("assemblies", [])
    statuses = [r.get("status") for r in recipes]
    results = apply_all(recipes, foods, args.now)

    rows = []
    for status, recipe, res in zip(statuses, recipes, results):
        if res.skipped:
            verdict = "draft"
        elif res.ok:
            verdict = "PASS"
        else:
            verdict = "FAIL"
        rows.append((
            recipe["recipeId"],
            "person" if _is_signed(recipe) else "-",
            _state(status, recipe),
            verdict,
            "" if res.macro_delta_pct is None else f"{res.macro_delta_pct:.1f}",
            ",".join(res.derived) or "none",
            "; ".join(res.problems),
        ))
    print(format_table(rows))

    passed = sum(1 for r in results if r.ok)
    failed = [
        (rec, res) for rec, res in zip(recipes, results)
        if not res.ok and not res.skipped
    ]
    held = [rec["recipeId"] for rec, _ in failed if not _is_signed(rec)]
    flagged = [rec["recipeId"] for rec, _ in failed if _is_signed(rec)]
    print()
    print(f"{passed} verified, {len(held)} held in review, "
          f"{len(flagged)} signed by a person but failing the check")
    if held:
        print("held in review: " + ", ".join(held))
    if flagged:
        print("signed by a person, so left published, but read these: "
              + ", ".join(flagged))

    changed = seed != before
    if args.check:
        return 1 if changed else 0
    if changed or args.out:
        target = args.out or args.seed
        with open(target, "w", encoding="utf-8") as f:
            json.dump(seed, f, ensure_ascii=False, indent=1)
            f.write("\n")
        print(f"wrote {os.path.relpath(target)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
