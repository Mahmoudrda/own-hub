"""Own Hub's fee (D63, spec 4.13, 13.1): owed from the moment access starts."""

from __future__ import annotations

import datetime as dt


def fee_piasters(base_piasters: int, bps: int) -> int:
    """On the package price only: the 1 to 99 extra piasters that make the amount
    unique belong to the coach. Integer arithmetic, rounded down."""
    return base_piasters * bps // 10000


def at_activation(payment: dict, cfg: dict, rel_source, now: dt.datetime) -> dict:
    """The payment fields to write when access first starts (provisional or
    full); {} when the fee was already set. 8 percent for a client the coach
    brought with her invite code (relationship source 'invite'), 15 percent
    otherwise; both come from coachingConfig/instapay (model.config)."""
    if payment.get("feeOwedAt"):
        return {}
    bps = cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"]
    return {"feePiasters": fee_piasters(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), bps), "feeBps": bps,
            "feeState": "owed", "feeOwedAt": now}


def recompute(payment: dict, paid_piasters: int, cfg: dict, rel_source) -> dict:
    """The fee when the coach accepts less in writing: on the package price or
    what she actually received, whichever is lower."""
    bps = payment.get("feeBps") or (cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"])
    base = min(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), paid_piasters)
    return {"feePiasters": fee_piasters(base, bps), "feeBps": bps}
