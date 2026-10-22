"""The receipt a client keeps for a programme she paid for.

Issued inside the transaction that starts the subscription, so a receipt number
is never skipped or reused. Numbers run OH-{year}-{000001} and start again each
calendar year. The seller block is a copy of coachingConfig/seller at that
moment: a later change of address does not rewrite an old receipt.

A receipt never holds the coach's own price.
"""

from __future__ import annotations

import datetime as dt

COUNTER = ("coachingConfig", "receiptCounter")

_SELLER_SKIP = ("updatedAt",)


def seller_block(seller: dict) -> dict:
    """The seller fields a receipt (and the staff screen) shows."""
    return {key: value for key, value in seller.items() if key not in _SELLER_SKIP}


def vat_included(price_final: int, rate_percent: int) -> int:
    """The VAT inside a price that already includes it."""
    if rate_percent <= 0:
        return 0
    return price_final * rate_percent // (100 + rate_percent)


def issue(transaction, db, sub_id: str, sub: dict, seller: dict, coach_name: str, *, now: dt.datetime) -> str:
    """Writes receipts/{subId} and bumps the counter; returns the number.

    Reads the counter, so call it after every other read of the transaction and
    before its last writes."""
    counter_ref = db.collection(COUNTER[0]).document(COUNTER[1])
    current = counter_ref.get(transaction=transaction)
    data = current.to_dict() if current.exists else {}
    seq = data.get("seq", 0) + 1 if data.get("year") == now.year else 1
    transaction.set(counter_ref, {"year": now.year, "seq": seq})

    number = f"OH-{now.year}-{seq:06d}"
    package = sub.get("package") or {}
    rate = seller.get("vatRatePercent") or 0
    price = sub["priceFinalEgp"]
    transaction.set(
        db.collection("receipts").document(sub_id),
        {
            "number": number,
            "clientUid": sub["clientUid"],
            "seller": seller_block(seller),
            "line": {
                "title": package.get("title"),
                "durationDays": package.get("durationDays"),
                "liveSessionsPerMonth": package.get("liveSessionsPerMonth"),
                "sessionMinutes": package.get("sessionMinutes"),
            },
            "coachName": coach_name,
            "priceFinalEgp": price,
            "vatRatePercent": rate,
            "vatEgp": vat_included(price, rate),
            "issuedAt": now,
        },
    )
    return number
