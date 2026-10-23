"""The ids a coach's plan may name are the ones the app ships."""

import json

import pytest

from coaching import plans
from tools import build_coaching_content_ids as build


def test_the_committed_file_is_a_fresh_build():
    if not (build.ROOT / "app").exists() or not build.CATALOGUE.exists():
        pytest.skip("app/ or the exercise catalogue is not in this checkout")
    committed = json.loads(build.OUTPUT.read_text(encoding="utf-8"))
    assert committed == build.build(), "run: python -m tools.build_coaching_content_ids"
    assert build.OUTPUT.read_text(encoding="utf-8") == build.text(committed)


def test_every_list_is_sorted_and_not_empty():
    ids = plans.load_content_ids()
    assert set(ids) == {"exercises", "recipes", "foods"}
    for kind, rows in ids.items():
        assert rows, kind
    raw = json.loads(build.OUTPUT.read_text(encoding="utf-8"))
    for kind, rows in raw.items():
        assert rows == sorted(set(rows)), kind


def test_a_known_id_of_each_kind_is_there():
    ids = plans.load_content_ids()
    assert "barbell_back_squat" in ids["exercises"]
    assert "koshary" in ids["foods"]
    assert "rahma_lazy_cake" in ids["recipes"]
