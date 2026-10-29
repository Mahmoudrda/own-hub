"""A coach's packages and their prices.

She sets her own price. The client sees one final price (hers plus the margin)
and never the margin. The public package carries only `priceFinalEgp`; her own
price lives under `coachPrivate/{uid}/prices/{packageId}`, which no client can
read.

Her page is published while she has at least one active package, and shows the
lowest final price among the active ones.
"""

from __future__ import annotations

import datetime as dt
from typing import Optional

from . import chat, common, errors, pricing

PACKAGE_KEYS = (
    "title",
    "description",
    "durationDays",
    "includes",
    "liveSessionsPerMonth",
    "sessionMinutes",
    "checkInsPerWeek",
    "priceFinalEgp",
    "active",
    "order",
    "updatedAt",
)

_ORDER_MAX = 20


def _validate(data: dict) -> dict:
    limits = common.LIMITS
    includes = data.get("includes")
    if not isinstance(includes, list) or not (1 <= len(includes) <= limits["includesMax"]):
        raise common.bad()
    if not isinstance(data.get("active"), bool):
        raise common.bad()
    order = data.get("order", 0)
    title = common.text(data.get("title"), min_len=3, max_len=limits["packageTitleMax"])
    description = common.text(data.get("description"), min_len=20, max_len=limits["packageDescriptionMax"])
    rows = [common.text(row, min_len=2, max_len=limits["includeTextMax"]) for row in includes]
    chat.refuse_contact(title, description, rows)
    return {
        "title": title,
        "description": description,
        "durationDays": common.whole_of(data.get("durationDays"), limits["durationDays"]),
        "includes": rows,
        "liveSessionsPerMonth": common.whole(
            data.get("liveSessionsPerMonth"),
            low=limits["liveSessionsPerMonthMin"],
            high=limits["liveSessionsPerMonthMax"],
        ),
        "sessionMinutes": common.whole_of(data.get("sessionMinutes"), limits["sessionMinutes"]),
        "checkInsPerWeek": common.whole(data.get("checkInsPerWeek"), low=0, high=limits["checkInsPerWeekMax"]),
        "active": data["active"],
        "order": common.whole(order, low=0, high=_ORDER_MAX),
        "coachPriceEgp": common.whole(
            data.get("coachPriceEgp"),
            low=limits["coachPriceMinEgp"],
            high=limits["coachPriceMaxEgp"],
            reason=errors.PRICE_OUT_OF_RANGE,
        ),
    }


def save(
    db, uid: str, data: dict, *, live: bool, coach_v: Optional[str], now: dt.datetime
) -> dict:
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v)
    package_id = data.get("packageId")
    if package_id is not None and (not isinstance(package_id, str) or not package_id or "/" in package_id):
        raise common.bad()
    fields = _validate(data)
    coach_price = fields.pop("coachPriceEgp")
    price_final = pricing.final_price(coach_price)

    coach_ref = db.collection("coaches").document(uid)
    packages = coach_ref.collection("packages")
    ref = packages.document(package_id) if package_id else packages.document()
    private_ref = db.collection("coachPrivate").document(uid)
    price_ref = private_ref.collection("prices").document(ref.id)

    def body(transaction):
        coach = coach_ref.get(transaction=transaction)
        private = private_ref.get(transaction=transaction)
        existing = list(packages.stream(transaction=transaction))
        if not coach.exists:
            raise common.refuse(errors.PERMISSION, errors.NOT_A_COACH)
        if (private.to_dict() or {}).get("suspended"):
            raise common.refuse(errors.PERMISSION, errors.COACH_SUSPENDED)
        known = {snapshot.id: snapshot.to_dict() or {} for snapshot in existing}
        if package_id and package_id not in known:
            raise common.refuse(errors.NOT_FOUND, errors.PACKAGE_NOT_FOUND)
        if not package_id and len(known) >= common.LIMITS["maxPackages"]:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_PACKAGES)

        public = {**fields, "priceFinalEgp": price_final, "updatedAt": now}
        assert set(public) == set(PACKAGE_KEYS)
        known[ref.id] = public
        active_rows = [row for row in known.values() if row.get("active")]
        active = [row["priceFinalEgp"] for row in active_rows]
        monthly = [pricing.monthly_equivalent(r["priceFinalEgp"], r["durationDays"]) for r in active_rows]

        transaction.set(ref, public)
        transaction.set(
            price_ref, {"coachPriceEgp": coach_price, "priceFinalEgp": price_final, "updatedAt": now}
        )
        transaction.update(
            coach_ref,
            {
                "fromPriceEgp": min(active) if active else None,
                "fromMonthlyEgp": min(monthly) if monthly else None,
                "published": bool(active),
                "updatedAt": now,
            },
        )

    common.run(db, body)
    # She is paid her own price in full; the margin is on top of it.
    return {"packageId": ref.id, "priceFinalEgp": price_final, "youReceiveEgp": coach_price}
