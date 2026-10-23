"""USDA FoodData Central foods, and a deterministic match from search terms.

The model writes short USDA-style terms ("rice, white, cooked"): the food
first, then descriptors, separated by commas. A term is matched by token
overlap against every food name:

  * every word of the term's head (before its first comma), cooking words
    aside, must appear in the food's name, so "chicken, breast" can never land
    on "Chickpeas";
  * at least half of the term's other words must appear too;
  * then the score: coverage of the term, weighted towards words the food
    names early (in "Oil, olive, ..." olive is a defining word, in "Oil,
    corn, peanut, and olive" it is an afterthought); a food whose own head the
    term names; the cooking state the term asks for (raw against cooked);
    fewer extra words; the everyday form of a staple (COMMON) when the term
    does not say otherwise; SR Legacy before Foundation; and penalties for
    baby food, fast-food and restaurant entries the term did not ask for;
  * ties go to the shorter name, then the lower fdcId.

The same input always gives the same food. The index is built once per
process and kept in memory.
"""

from __future__ import annotations

import json
import os
import re
import threading
from dataclasses import dataclass
from typing import Iterable, Optional

_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "usda_foods.json")

NUTRIENTS = ("kcal", "protein_g", "carbs_g", "fat_g", "fiber_g")

COMMON = frozenset(
    {
        168878,  # Rice, white, long-grain, regular, enriched, cooked
        170457,  # Tomatoes, red, ripe, raw, year round average
        171413,  # Oil, olive, salad or cooking
        168409,  # Cucumber, with peel, raw
        172421,  # Lentils, mature seeds, cooked, boiled, without salt
        169737,  # Pasta, cooked, enriched, without added salt
        171265,  # Milk, whole, 3.25% milkfat, with added vitamin D
        173227,  # Beverages, tea, black, brewed, prepared with tap water
        171890,  # Beverages, coffee, brewed, prepared with tap water
        169655,  # Sugars, granulated
        171477,  # Chicken, broilers or fryers, breast, meat only, cooked, roasted
        172388,  # Chicken, broilers or fryers, thigh, meat only, cooked, roasted
        169247,  # Lettuce, cos or romaine, raw
        170000,  # Onions, raw
        174032,  # Beef, ground, 85% lean meat / 15% fat, patty, cooked, broiled
        170698,  # Fast foods, potato, french fried in vegetable oil
        171284,  # Yogurt, plain, whole milk
        171688,  # Apples, raw, with skin
        169097,  # Oranges, raw, all commercial varieties
        174924,  # Bread, white, commercially prepared
        174915,  # Bread, pita, white, enriched
        173424,  # Egg, whole, cooked, hard-boiled
        173420,  # Cheese, feta
        173753,  # Broadbeans (fava beans), mature seeds, cooked, boiled, without salt
        173757,  # Chickpeas, mature seeds, cooked, boiled, without salt
        170440,  # Potatoes, boiled, cooked without skin, flesh, without salt
        168604,  # Seeds, sesame butter, tahini
        174683,  # Grapes, red or green, raw
        172179,  # Cheese, cottage, creamed, large or small curd
        169641,  # Jams and preserves
    }
)
"""The everyday form of a staple on an Egyptian plate, chosen when a term
names the food without saying which form. A term that does say ("rice,
brown") still reaches the brown rice, and a term that names a cooking method
("eggs, fried") still reaches that method: the nudge is smaller than either."""

_STOP = frozenset(
    {"a", "an", "and", "the", "of", "with", "without", "in", "on", "or", "for", "to", "style", "type", "plain"}
)
_SYNONYM = {"fry": "fried", "fries": "fried", "grill": "grilled", "roast": "roasted"}
_COOKED = frozenset(
    {
        "cooked", "boiled", "baked", "roasted", "grilled", "broiled", "fried",
        "stewed", "steamed", "braised", "simmered", "sauteed", "toasted",
        "heated", "microwaved", "poached", "scrambled",
    }
)
_RAW = frozenset({"raw", "fresh", "uncooked", "dry", "unprepared"})
_STATE = _COOKED | _RAW
_CATEGORY = frozenset(
    {
        "beverage", "spice", "nut", "seed", "cereal", "candy", "snack",
        "fish", "crustacean", "mollusk", "game meat", "leavening agent",
        "alcoholic beverage", "fast food",
    }
)
"""SR Legacy files many foods under a category word ("Beverages, tea, black,
brewed"). For the head of such a name the next segment counts."""
_UNWANTED = {
    "babyfood": 4.0,
    "infant": 4.0,
    "toddler": 4.0,
    "restaurant": 1.0,
}
_WORD = re.compile(r"[a-z0-9]+")
_ASIDE = re.compile(r"\([^)]*\)")
_BRAND = re.compile(r"\b[A-Z][A-Z'&]{2,}\b")
"""A word in capitals is a brand in SR Legacy names (QUAKER, DENNY'S, UNCLE
BENS). A branded product is never what a photo of home food shows."""


def _stem(word: str) -> str:
    word = _SYNONYM.get(word, word)
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 4 and word.endswith("oes"):
        return word[:-2]
    if len(word) > 3 and word.endswith("s") and not word.endswith(("ss", "us", "is")):
        return word[:-1]
    return word


def tokens(text: str) -> list[str]:
    return [_stem(w) for w in _WORD.findall(text.lower()) if w not in _STOP]


@dataclass(frozen=True)
class Food:
    fdc_id: int
    name: str
    dataset: str
    per100g: dict
    words: frozenset
    head: frozenset
    branded: bool
    position: dict
    """Each word's earliest comma segment in the name, counted after any
    category word."""


def _segments(name: str, keep_asides: bool) -> list[list[str]]:
    """The comma segments of a name, after any category word.

    A parenthetical aside's commas never split a segment: in "Chickpeas
    (garbanzo beans, bengal gram), mature seeds" the first segment is the whole
    "Chickpeas (...)". With keep_asides False the aside is dropped, which is
    how the head is read: the food there is chickpeas."""
    if keep_asides:
        name = _ASIDE.sub(lambda m: m.group(0).replace(",", " "), name)
    else:
        name = _ASIDE.sub("", name)
    parts = [tokens(p) for p in name.split(",")]
    parts = [p for p in parts if p]
    if len(parts) > 1 and " ".join(parts[0]) in _CATEGORY:
        parts = parts[1:]
    return parts


def _make_food(row: dict) -> Food:
    name = row["name"]
    position: dict = {}
    for i, segment in enumerate(_segments(name, keep_asides=True)):
        for word in segment:
            position.setdefault(word, i)
    bare = _segments(name, keep_asides=False)
    head = frozenset(w for w in (bare[0] if bare else []) if w not in _STATE)
    return Food(
        fdc_id=int(row["fdcId"]),
        name=name,
        dataset=row["dataset"],
        per100g={k: row.get(k) for k in NUTRIENTS},
        words=frozenset(tokens(name)),
        head=head,
        branded=bool(_BRAND.search(name.replace("USDA", ""))),
        position=position,
    )


class _Index:
    def __init__(self, rows: Iterable[dict]):
        self.foods: list[Food] = []
        self.by_id: dict[int, Food] = {}
        self.postings: dict[str, list[int]] = {}
        for row in rows:
            food = _make_food(row)
            position = len(self.foods)
            self.foods.append(food)
            self.by_id[food.fdc_id] = food
            for word in food.words:
                self.postings.setdefault(word, []).append(position)


_index: Optional[_Index] = None
_lock = threading.Lock()


def index() -> _Index:
    """Loaded once per process, behind a lock, then shared read-only."""
    global _index
    if _index is None:
        with _lock:
            if _index is None:
                with open(_PATH, encoding="utf-8") as handle:
                    _index = _Index(json.load(handle)["foods"])
    return _index


def food(fdc_id: int) -> Optional[Food]:
    return index().by_id.get(fdc_id)


_POSITION_WEIGHT = (1.0, 0.85, 0.7, 0.55)


def _score(content: list[str], state: set, term_words: set, food: Food) -> float:
    weight = 0.0
    for word in content:
        if word in food.words:
            at = food.position.get(word, len(_POSITION_WEIGHT))
            weight += _POSITION_WEIGHT[min(at, len(_POSITION_WEIGHT) - 1)]
    score = 3.0 * weight / max(1, len(content))
    if food.head and food.head <= set(content):
        score += 1.0
    score -= 0.5 * len(food.head - term_words)
    cooked = bool(food.words & _COOKED)
    raw = bool(food.words & _RAW)
    if state & _RAW:
        score += 1.0 if raw else (-1.0 if cooked else 0.0)
    elif state & _COOKED:
        score += 1.0 if cooked else (-1.0 if raw else 0.0)
        method = state - {"cooked"}
        score += 1.0 * len(method & food.words)
    score -= 0.05 * len(food.words - term_words)
    if food.fdc_id in COMMON:
        score += 0.75
    if food.branded:
        score -= 1.5
    if food.dataset == "sr_legacy":
        score += 0.1
    for word, penalty in _UNWANTED.items():
        if word in food.words and word not in term_words:
            score -= penalty
    return score


def match_term(term: str) -> Optional[Food]:
    """The best food for one USDA-style term, or None."""
    if not isinstance(term, str):
        return None
    words = tokens(term)
    required = [w for w in tokens(term.split(",")[0]) if w not in _STATE]
    if not required:
        return None
    content = [w for w in words if w not in _STATE]
    state = set(words) & _STATE
    term_words = set(words)
    idx = index()
    postings = [idx.postings.get(w) for w in required]
    if any(p is None for p in postings):
        return None
    candidates = set(postings[0])
    for posting in postings[1:]:
        candidates &= set(posting)
    best: Optional[Food] = None
    best_key = None
    for position in candidates:
        candidate = idx.foods[position]
        hit = sum(1 for w in content if w in candidate.words)
        if hit * 2 < len(content):
            continue
        key = (
            -round(_score(content, state, term_words, candidate), 6),
            len(candidate.name),
            candidate.fdc_id,
        )
        if best_key is None or key < best_key:
            best, best_key = candidate, key
    return best


def match_terms(terms: Iterable[str]) -> Optional[Food]:
    """The first term, in the model's order, that finds a food."""
    for term in terms:
        found = match_term(term)
        if found is not None:
            return found
    return None


def scaled(per100g: dict, grams: float) -> dict:
    """grams/100 x per-100 g. A nutrient USDA does not list stays None."""
    return {
        k: (None if per100g.get(k) is None else per100g[k] * grams / 100.0)
        for k in NUTRIENTS
    }
