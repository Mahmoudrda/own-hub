"""Cancelling inside the window, and the refund staff pay back.

She can ask to cancel within `cancelWindowDays` of the day the subscription
started. The amount shown is the price less the share of live sessions already
held. Staff pay it back by the same rail and record the transfer here; only
then does the subscription end and the coach's share settle.
"""

from __future__ import annotations

import datetime as dt

from . import common, errors, subscriptions
from .proofs import PAGE

LIMITS = common.LIMITS


def request(db, uid: str, data: dict, *, live: bool, now: dt.datetime) -> dict:
    common.require_payments_live(live)
    sub_id = common.text(data.get("subId"), max_len=128)
    reason = common.optional_text(data.get("reason"), max_len=300)

    def body(transaction):
        ref, sub = subscriptions._own_sub(transaction, db, sub_id, "clientUid", uid)
        started = common.as_utc(sub.get("startsAt"))
        if sub.get("status") != "active" or started is None:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        if now > started + common.days(LIMITS["cancelWindowDays"]):
            raise common.refuse(errors.PRECONDITION, errors.CANCEL_WINDOW_CLOSED)
        if (sub.get("cancellation") or {}).get("state") == "requested":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        amount = common.refund_amount(sub["priceFinalEgp"], sub.get("sessionsUsed", 0), sub.get("sessionsIncluded", 0))
        transaction.update(
            ref,
            {"cancellation": {"state": "requested", "requestedAt": now, "refundEgp": amount, "reason": reason}},
        )
        return amount

    return {"state": "requested", "refundEgp": common.run(db, body)}


def list_for_staff(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    after = data.get("after")
    if after is not None:
        after = common.text(after, max_len=128)
    common.log_access(db, actor_uid, "refunds.list", "refunds", now)

    rows = list(db.collection("subscriptions").where("cancellation.state", "==", "requested").stream())
    rows.sort(key=lambda row: (common.as_utc(row.to_dict()["cancellation"].get("requestedAt")), row.id))
    if after is not None:
        ids = [row.id for row in rows]
        rows = rows[ids.index(after) + 1 :] if after in ids else []
    more = len(rows) > PAGE
    rows = rows[:PAGE]

    items = []
    for row in rows:
        sub = row.to_dict()
        proof_id = (sub.get("payment") or {}).get("proofId")
        proof = db.collection("paymentProofs").document(proof_id).get() if proof_id else None
        proof_row = proof.to_dict() if proof is not None and proof.exists else {}
        coach = db.collection("coaches").document(sub["coachUid"]).get()
        items.append(
            {
                "subId": row.id,
                "coachName": (coach.to_dict() or {}).get("displayName", "") if coach.exists else "",
                "packageTitle": (sub.get("package") or {}).get("title", ""),
                "priceFinalEgp": sub["priceFinalEgp"],
                "sessionsUsed": sub.get("sessionsUsed", 0),
                "sessionsIncluded": sub.get("sessionsIncluded", 0),
                "startsAt": common.plain(sub.get("startsAt")),
                "cancellation": common.plain(sub["cancellation"]),
                "rail": proof_row.get("rail"),
                "senderName": proof_row.get("senderName"),
            }
        )
    return {"items": items, "next": rows[-1].id if more and rows else None}


def record(db, actor_uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    sub_id = common.text(data.get("subId"), max_len=128)
    decision = common.one_of(data.get("decision"), common.ENUMS["refundDecision"])
    rail = reference = amount = None
    if decision == "refund":
        rail = common.one_of(data.get("rail"), common.RAILS)
        reference = data.get("reference")
        if not common.reference_ok(rail, reference):
            raise common.bad()
        amount = common.whole(data.get("amountEgp"), low=0, high=100000)
    common.log_access(db, actor_uid, f"refunds.{decision}", sub_id, now)

    parties = {}

    def body(transaction):
        ref = db.collection("subscriptions").document(sub_id)
        sub = common.read(ref, transaction)
        if sub is None:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        if sub.get("status") != "active" or (sub.get("cancellation") or {}).get("state") != "requested":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        common.refuse_if_subject(actor_uid, sub.get("clientUid"), sub.get("coachUid"))
        parties.update(coach=sub["coachUid"], client=sub["clientUid"])
        if decision == "decline":
            transaction.update(ref, {"cancellation.state": "declined"})
            return "active"

        # The server works the amount out; staff only confirm what they paid.
        owed = common.refund_amount(sub["priceFinalEgp"], sub.get("sessionsUsed", 0), sub.get("sessionsIncluded", 0))
        if amount != owed:
            raise common.bad()
        proof_id = (sub.get("payment") or {}).get("proofId")
        proof = db.collection("paymentProofs").document(proof_id).get(transaction=transaction) if proof_id else None
        if proof is None or not proof.exists or (proof.to_dict() or {}).get("rail") != rail:
            raise common.bad()
        seen = subscriptions.read_ending(transaction, db, sub_id, sub, money=True)
        changes = {
            "status": "ended_early",
            "endReason": "refund",
            "refund": {"amountEgp": amount, "rail": rail, "reference": reference, "at": now},
            "cancellation.state": "refunded",
            "statusAt": now,
        }
        ledger, share = "keep", 0
        if seen["terms"].exists:
            ledger = "share"
            share = common.coach_share_after_refund(
                seen["terms"].to_dict()["coachPriceEgp"], sub.get("sessionsUsed", 0), sub.get("sessionsIncluded", 0)
            )
        subscriptions.write_ending(
            transaction, db, sub_id, sub, seen, changes=changes, now=now, ledger=ledger, share=share, refund=amount
        )
        return "ended_early"

    status = common.run(db, body)
    if decision == "refund":
        subscriptions.notify_ended(notify, parties["client"], parties["coach"])
    return {"status": status}
