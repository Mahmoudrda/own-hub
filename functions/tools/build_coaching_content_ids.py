"""Writes functions/coaching/content_ids.json: the ids a coach's plan may name.

    cd functions && .venv/bin/python -m tools.build_coaching_content_ids

Exercises are the library catalogue (6-v2/content/exercise_library/catalogue.json,
which tools/publish_exercise_library.py publishes) plus every exercise the
app's starting programmes use; recipes are the published recipes in
app/assets/content/rahma_recipes.json; foods are app/assets/content/foods_eg.json.
Re-run it whenever that content changes; test_coaching_content_ids.py fails
until the committed file matches.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOGUE = ROOT / "6-v2" / "content" / "exercise_library" / "catalogue.json"
PROGRAMMES = ROOT / "app" / "assets" / "content" / "starting_programmes.json"
RECIPES = ROOT / "app" / "assets" / "content" / "rahma_recipes.json"
FOODS = ROOT / "app" / "assets" / "content" / "foods_eg.json"
OUTPUT = Path(__file__).resolve().parents[1] / "coaching" / "content_ids.json"


def _load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _exercise_ids_in(node, found: set) -> None:
    if isinstance(node, dict):
        value = node.get("exerciseId")
        if isinstance(value, str) and value:
            found.add(value)
        for child in node.values():
            _exercise_ids_in(child, found)
    elif isinstance(node, list):
        for child in node:
            _exercise_ids_in(child, found)


def build() -> dict:
    exercises: set = set()
    _exercise_ids_in(_load(CATALOGUE), exercises)
    _exercise_ids_in(_load(PROGRAMMES), exercises)
    recipes = {
        row["recipeId"]
        for row in _load(RECIPES)["recipes"]
        if row.get("status") == "published" and row.get("recipeId")
    }
    foods = {row["id"] for row in _load(FOODS)["foods"] if row.get("id")}
    return {
        "exercises": sorted(exercises),
        "recipes": sorted(recipes),
        "foods": sorted(foods),
    }


def text(ids: dict) -> str:
    return json.dumps(ids, indent=1, ensure_ascii=False) + "\n"


def main() -> int:
    ids = build()
    OUTPUT.write_text(text(ids), encoding="utf-8")
    print({kind: len(rows) for kind, rows in ids.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
