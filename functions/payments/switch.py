"""The owner's off button for NEW InstaPay payments (spec 10, 13 header).

Only `create_payment` and the acceptance of a coaching request read the switch.
Every payment that exists stays readable, payable, confirmable, refundable and
resolvable by staff while it is off."""

from __future__ import annotations

import datetime as dt

from coaching import common


def set_enabled(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    enabled = data.get("enabled")
    if not isinstance(enabled, bool):
        raise common.bad()
    common.text(data.get("reason"), min_len=5, max_len=300)  # asked for so a switch is never flipped idly; not stored: config/payments is readable by every signed-in account
    common.log_access(db, actor, f"payments.switch.{'on' if enabled else 'off'}", "config", now)
    db.collection("config").document("payments").set(
        {"enabled": enabled, "updatedAt": now, "updatedBy": common.staff_ref(actor)}
    )
    return {"enabled": enabled}
