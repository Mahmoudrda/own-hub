"""The price rule, under the name the rest of the code reaches for. The
function itself lives in common, beside the other price maths."""

from __future__ import annotations

from .common import final_price

__all__ = ["final_price", "monthly_equivalent"]


def monthly_equivalent(price_final_egp: int, duration_days: int) -> int:
    """The price of 28 days; the same rounding as the app's `monthlyEquivalent`."""
    return price_final_egp * 28 // duration_days
