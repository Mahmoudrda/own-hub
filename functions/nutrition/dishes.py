"""The Egyptian and Arabic dish table, and the match against it.

egyptian_dishes.json is written by build_dishes.py: each dish is a standard
recipe of USDA ingredients, and its per-100 g numbers are computed from them.
A dish is found by its key, its Arabic name or any alias, compared after
normalising both sides the same way:

  * Arabic through identity.arabic.normalise (no tashkeel or tatweel; alef
    forms to ا, ى to ي, ة to ه), then the definite article dropped from the
    front of each word, so الكشري is كشري;
  * Latin lower-cased, with hyphens and punctuation as spaces, so
    "Ful-Medames" is "ful medames".

An exact match wins, tried on the Arabic name first (the Egyptian name
carries the variant: فول بالزيت, not just ful), then the dish_guess, then the
English name.
Failing that, the longest alias found as whole words inside the dish_guess or
the Arabic name ("koshary with extra daqqa", "طبق كشري"). The English name is
matched exactly only: a plain description such as "grilled chicken breast"
must not be claimed by the dish "grilled chicken". Aliases shorter than five
letters are never matched inside a longer name: "فول" alone must not claim
every plate that mentions beans.
"""

from __future__ import annotations

import json
import os
import re
import threading
from dataclasses import dataclass
from typing import Iterable, Optional

from identity import arabic

_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "egyptian_dishes.json")

_PUNCT = re.compile(r"[^\w\s]|_", re.UNICODE)
_MIN_PARTIAL_CHARS = 5


def normalise(text: str) -> str:
    if not isinstance(text, str):
        return ""
    text = arabic.normalise(text).lower()
    text = _PUNCT.sub(" ", text)
    words = []
    for word in text.split():
        if word.startswith("ال") and len(word) > 3:
            word = word[2:]
        words.append(word)
    return " ".join(words)


@dataclass(frozen=True)
class Dish:
    key: str
    name_en: str
    name_ar: str
    category: str
    typical_serving_g: float
    per100g: dict
    recipe: tuple
    """((fdcId, grams, label, usdaName), ...) for one typical serving. The
    grams are as the recipe weighs them; a dish that loses water in cooking
    weighs typical_serving_g once served."""
    review: str


class _Table:
    def __init__(self, rows: Iterable[dict]):
        self.dishes: list[Dish] = []
        self.exact: dict[str, Dish] = {}
        self.partial: list[tuple[str, Dish]] = []
        for row in rows:
            dish = Dish(
                key=row["key"],
                name_en=row["name_en"],
                name_ar=row["name_ar"],
                category=row["category"],
                typical_serving_g=float(row["typical_serving_g"]),
                per100g=dict(row["per100g"]),
                recipe=tuple(
                    (int(i["fdcId"]), float(i["grams"]), i["label"], i["usdaName"])
                    for i in row["recipe"]
                ),
                review=row["review"],
            )
            self.dishes.append(dish)
            names = [row["key"].replace("_", " "), row["name_en"], row["name_ar"], *row.get("aliases", [])]
            for name in names:
                folded = normalise(name)
                if not folded:
                    continue
                self.exact.setdefault(folded, dish)
                if len(folded.replace(" ", "")) >= _MIN_PARTIAL_CHARS:
                    self.partial.append((folded, dish))
        # Longest first, then table order, so the most specific alias wins.
        self.partial.sort(key=lambda pair: -len(pair[0]))


_table: Optional[_Table] = None
_lock = threading.Lock()


def table() -> _Table:
    global _table
    if _table is None:
        with _lock:
            if _table is None:
                with open(_PATH, encoding="utf-8") as handle:
                    _table = _Table(json.load(handle)["dishes"])
    return _table


def match(
    dish_guess: Optional[str], name_ar: Optional[str], name_en: Optional[str]
) -> Optional[Dish]:
    """The dish these names point at, exact matches before partial ones."""
    exact = [normalise(n) for n in (name_ar, dish_guess, name_en)]
    partial = [normalise(n) for n in (name_ar, dish_guess)]
    t = table()
    for text in exact:
        if text and text in t.exact:
            return t.exact[text]
    padded = [f" {text} " for text in partial if text]
    for alias, dish in t.partial:
        pattern = f" {alias} "
        if any(pattern in text for text in padded):
            return dish
    return None
