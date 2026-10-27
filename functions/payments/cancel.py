"""cancel_payment: the client withdraws an unpaid request, or turns down a different amount."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import engine, states


def cancel(db, uid: str, data: dict, *, now: dt.datetime) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)

    def body(transaction):
        ref, row = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if row["status"] == "cancelled":
            return {"status": "cancelled"}  # a second tap changes nothing
        engine.move(transaction, db, ref, row, "cancelled", states.CLIENT, uid, now, code="client_cancelled")
        return {"status": "cancelled"}

    return common.run(db, body)
