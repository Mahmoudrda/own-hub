"""The price maths, against the shared vectors."""

from __future__ import annotations

import json
import os

import pytest

from coaching import common, pricing

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
with open(os.path.join(ROOT, "contracts", "coaching_price_vectors.json"), encoding="utf-8") as handle:
    VECTORS = json.load(handle)


@pytest.mark.parametrize("row", VECTORS["vectors"], ids=lambda r: str(r["coach"]))
def test_final_price_vectors(row):
    assert pricing.final_price(row["coach"]) == row["final"]


def test_the_vector_bounds_match_the_limits():
    assert VECTORS["coachMin"] == common.LIMITS["coachPriceMinEgp"]
    assert VECTORS["coachMax"] == common.LIMITS["coachPriceMaxEgp"]


def test_the_price_rule_is_the_shared_one():
    assert pricing.final_price is common.final_price
