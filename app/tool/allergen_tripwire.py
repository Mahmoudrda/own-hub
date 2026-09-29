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
# A word may appear under several tags, and several do. An Egyptian spice blend
# is one ingredient and three vectors, and `scan` fires all of them — see the
# note on `_WORDS`.
DICTIONARY = {
    "sesame": ["سمسم", "طحينة", "طحينه", "طحينية", "زعتر", "tahina", "tahini"],
    "peanuts": ["فول سوداني", "زبدة فول سوداني", "peanut"],
    "tree_nuts": ["مكسرات", "لوز", "عين جمل", "بندق", "كاجو", "فستق"],
    "coconut": ["جوز هند", "جوز الهند", "coconut"],
    "milk": [
        "لبن", "حليب", "زبادي", "جبنة", "جبنه", "قريش", "موتزاريلا", "زبدة",
        "سمنة", "كريمة", "يوناني", "بشاميل", "البشاميل", "ريش",
        # Whey is the commonest base for an extruded protein snack, and the
        # packet is the only thing that says which. See `soy`.
        "protein puffs",
    ],
    "eggs": ["بيض", "بيضة", "بيضه", "بيضتين", "اومليت", "مايونيز"],
    "gluten": [
        "دقيق", "شوفان", "عيش", "توست", "تورتيلا", "مكرونة", "مكرونه", "بقسماط",
        "فينو", "رغيف", "بيجل", "البيجل", "بسكوت", "بانيه", "باتيه", "برجر",
        "عجينه", "بيكنج باودر", "baking powder",
        # A commercial blend is cut with wheat flour as an anticaking agent as
        # often as not, and the packet is where that is written.
        "بهارات", "بهارات اللحمة",
        # Egyptian deli meat is bulked with rusk or starch.
        "turkey", "لانشون",
    ],
    "fish": ["سمك", "تونة", "تونه", "سردين", "بلطي", "فيليه"],
    "crustaceans": ["جمبري", "جمبرى", "استاكوزا", "shrimp"],
    "molluscs": ["كاليماري", "بلح البحر", "محار"],
    "soy": [
        "صويا", "صوص صويا",
        # Soy protein isolate is the other half of the protein-snack market,
        # and soy protein is what Egyptian luncheon meat is extended with.
        # Before these three words `soy` fired on nothing in the whole book,
        # which is not a statement about the book so much as about this list.
        "protein puffs", "turkey", "لانشون",
    ],
    "celery": [
        "كرفس", "مرقة", "مكعب مرقة", "كنور",
        # The same ingredient as `مرقة`, spelled the way she spells it. It
        # fired nothing while `مرقة` and `كنور` fired celery, so one stock cube
        # had two spellings and two different outcomes across three cards. In
        # Egypt "الشوربة" in a method almost always means a cube.
        "شوربة",
        # Celery salt is in most Egyptian commercial spice blends.
        "بهارات", "بهارات اللحمة", "كاري",
    ],
    "mustard": [
        "مستردة", "مسطردة", "خردل",
        # Mustard flour is a standard extender in both, and neither is sold
        # with an ingredient list a woman can read across a kitchen.
        "بهارات", "بهارات اللحمة", "كاري",
    ],
    "sulphites": ["فواكه مجففة", "مشمش مجفف", "زبيب"],
    "lupin": ["ترمس"],
    "fava": ["فول", "فول مدمس", "طعمية", "طعميه", "فلافل", "بصارة"],
}
#
# `رايس كيك` was in `gluten` and is not any more. A plain rice cake is rice and
# salt, and firing gluten on it was not caution, it was a wrong fact: it was the
# only gluten claim on `Coconut apple Pudding`, so a coeliac lost a dish she can
# actually eat. Over-firing is cheap when the word really is a vector; this one
# never was.

# Every word, longest first, each carrying **every** tag it belongs to.
#
# Two things matter here. The first is the length order — see the module note:
# `فول سوداني` must be consumed before `فول` is ever looked at. The second is
# that the tags are collected per word rather than per (word, tag) pair, because
# `scan` blanks out the characters a match consumed. Listing `بهارات` as three
# separate pairs would let the first tag win the characters and silently lose
# the other two, which is the failure mode this whole file exists to catch.
_WORDS = sorted(
    (
        (word, tuple(sorted(
            tag for tag, words in DICTIONARY.items() if word in words
        )))
        for word in {w for words in DICTIONARY.values() for w in words}
    ),
    key=lambda pair: (-len(pair[0]), pair[0]),
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
    """Every tag the words in [text] fire, with the word that fired each one.

    Case-insensitive, because the Latin words arrive as brand names and a
    reaction does not care whether she typed `Turkey` or `turkey`. Arabic has
    no case, so this changes nothing on her own spellings.
    """
    hits = {}
    # A word already matched is blanked out, so a longer match wins the
    # characters it consumed and the shorter one never sees them.
    remaining = text
    for word, tags in _WORDS:
        pattern = bounded(word)
        if not re.search(pattern, remaining, re.IGNORECASE):
            continue
        for tag in tags:
            hits.setdefault(tag, []).append(word)
        remaining = re.sub(
            pattern, lambda m: " " * len(m.group(0)), remaining, flags=re.IGNORECASE
        )
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
