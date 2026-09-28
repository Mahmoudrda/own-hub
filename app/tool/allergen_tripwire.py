#!/usr/bin/env python3
"""Read her Arabic and say what is in it, independently of the ingredient list.

`python3 tool/allergen_tripwire.py` checks the shipped seed and exits non-zero on
an unexplained hit. `build_rahma_recipes.py` imports [scan] to derive each
recipe's `allergensDerived` in the first place.

## Why a second reader exists at all

The designed path for an allergen is: every ingredient carries a `foodId`, every
`foods` row carries a verified `allergens[]`, and the union is the recipe's. That
path is correct and it has one failure mode that matters: it is only as good as
the ingredient list. Nobody remembers at eleven at night that **زعتر is a sesame
blend**, so `Club Sandwich` gets an ingredient row for za'atar, the row is
tagged for herbs, and a woman allergic to sesame is handed a sandwich.

So this reads her raw sentences instead, with a dictionary of the words Egyptian
women actually write, and reports every tag it finds. Two readers that disagree
is the whole point: the disagreement is a question for a person, and a person
answers it in `allergensExtra` or in `allergensRemoved` with a written reason.

**It is built to over-fire.** `زبيب` (raisins, recipe 5) fires `sulphites`;
dried fruit usually is sulphited in Egypt and sometimes is not, so a human reads
the packet. Over-firing costs a reviewer a minute. Under-firing costs somebody a
reaction. The asymmetry decides the design.

## Longest match first, which is not a detail

`فول` is fava and `فول سوداني` is peanut, and they share a prefix. Matching
shortest-first tags a peanut-butter cookie as a favism risk and never mentions
peanuts. Every lookup below runs longest-first for that one reason.

## What this is not

It is not a certification and it does not make a dish safe. It is one of five
layers, it is the only one that reads her own words rather than someone's
transcription of them, and it exists because the other four all read the same
transcription.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = os.path.join(HERE, "..", "assets", "content", "rahma_recipes.json")

# Tag -> the words that fire it. Egyptian colloquial spellings first, because
# that is what she writes; Modern Standard and Latin forms after, because the
# library will grow and a brand name arrives in Latin.
#
# Extended by a human who reads Arabic. Adding a word here can only ever widen
# what gets flagged for review, so a wrong addition is cheap and an omission is
# not.
DICTIONARY = {
    "sesame": ["سمسم", "طحينة", "طحينه", "طحينية", "زعتر", "tahina", "tahini"],
    "peanuts": ["فول سوداني", "زبدة فول سوداني", "peanut"],
    "tree_nuts": ["مكسرات", "لوز", "عين جمل", "بندق", "كاجو", "فستق"],
    "coconut": ["جوز هند", "جوز الهند", "coconut"],
    "milk": [
        "لبن", "حليب", "زبادي", "جبنة", "جبنه", "قريش", "موتزاريلا", "زبدة",
        "سمنة", "كريمة", "يوناني", "بشاميل", "البشاميل", "ريش",
    ],
    "eggs": ["بيض", "بيضة", "بيضه", "بيضتين", "اومليت", "مايونيز"],
    "gluten": [
        "دقيق", "شوفان", "عيش", "توست", "تورتيلا", "مكرونة", "مكرونه", "بقسماط",
        "فينو", "رغيف", "بيجل", "البيجل", "بسكوت", "بانيه", "باتيه", "برجر",
        "رايس كيك", "عجينه", "بيكنج باودر", "baking powder",
    ],
    "fish": ["سمك", "تونة", "تونه", "سردين", "بلطي", "فيليه"],
    "crustaceans": ["جمبري", "جمبرى", "استاكوزا", "shrimp"],
    "molluscs": ["كاليماري", "بلح البحر", "محار"],
    "soy": ["صويا", "صوص صويا"],
    "celery": ["كرفس", "مرقة", "مكعب مرقة", "كنور"],
    "mustard": ["مستردة", "مسطردة", "خردل"],
    "sulphites": ["فواكه مجففة", "مشمش مجفف", "زبيب"],
    "lupin": ["ترمس"],
    "fava": ["فول", "فول مدمس", "طعمية", "طعميه", "فلافل", "بصارة"],
}

# Every word, longest first. See the module note: `فول سوداني` must be consumed
# before `فول` is ever looked at.
_WORDS = sorted(
    ((w, tag) for tag, words in DICTIONARY.items() for w in words),
    key=lambda pair: -len(pair[0]),
)


# Arabic writes its articles and conjunctions joined to the word, so a bare
# "not preceded by a letter" boundary matches almost nothing real: she writes
# الزبادي, not زبادي, and وزعتر, not زعتر.
#
# That cost `Fattah` its milk tag and `Chicken lemon` its sesame tag on the first
# run of this file, which is exactly the shape of miss the tripwire exists to
# catch in somebody else's work. So a word may carry one of these in front of it
# and nothing else. The list is short on purpose: a lone alef is not in it, which
# is what stops ابيض (white, as in white rice) from firing بيض (eggs).
_PREFIX = "(?:\u0648\u0627\u0644|\u0628\u0627\u0644|\u0641\u0627\u0644|\u0643\u0627\u0644|\u0644\u0644|\u0627\u0644|\u0648|\u0641|\u0628|\u0643|\u0644)?"
_LETTER = "\u0621-\u064A"


def bounded(word):
    """[word] with one optional Arabic prefix in front and a letter boundary."""
    return f"(?<![{_LETTER}]){_PREFIX}{re.escape(word)}(?![{_LETTER}])"


def scan(text):
    """Every tag the words in [text] fire, with the word that fired each one."""
    hits = {}
    # A word already matched is blanked out, so a longer match wins the
    # characters it consumed and the shorter one never sees them.
    remaining = text
    for word, tag in _WORDS:
        pattern = bounded(word)
        if not re.search(pattern, remaining):
            continue
        hits.setdefault(tag, []).append(word)
        remaining = re.sub(pattern, lambda m: " " * len(m.group(0)), remaining)
    return hits


def check_seed(path=SEED):
    """Every recipe in the seed whose text fires a tag its final set omits."""
    seed = json.load(open(path, encoding="utf-8"))
    problems = []
    for recipe in seed["recipes"]:
        text = "\n".join(
            [recipe["bodyAr"]]
            + [s["textAr"] for s in recipe["steps"]]
            + [i["qtyTextAr"] for i in recipe["ingredients"]]
            + [
                s["textAr"]
                for c in recipe["components"] + recipe["variants"]
                for s in c["steps"]
            ]
        )
        final = set(recipe["allergensFinal"])
        removed = recipe["allergensRemoved"]
        for tag, words in scan(text).items():
            if tag in final or tag in removed:
                continue
            problems.append(
                f"{recipe['recipeId']}: {tag} fired by {', '.join(words)} "
                f"but allergensFinal is [{', '.join(sorted(final))}] and nothing "
                f"in allergensRemoved explains it"
            )
    return problems


if __name__ == "__main__":
    found = check_seed()
    for line in found:
        print("TRIPWIRE |", line)
    print(f"{len(found)} unexplained hit(s)")
    sys.exit(1 if found else 0)
