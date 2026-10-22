"""Paying coaches what they have earned.

Staff send the money by hand, then record it here. The server adds up the
ledger lines itself; nothing the browser sends decides the amount. A payout
goes only to an account Own Hub confirmed as the coach's own.
"""

from __future__ import annotations

import datetime as dt

from google.cloud import firestore

from . import common, errors

MAX_ENTRIES = 200


def owed(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """Every coach staff must act on: money owed, or a payout account waiting
    to be confirmed (a first account or a requested change), even when nothing
    is owed yet. The waiting account comes with whether its holder name matches
    the name on her application."""
    from .profiles import _same_name

    common.log_access(db, actor_uid, "payouts.owed", "payouts", now)
    totals: dict = {}
    for snap in db.collection_group("ledger").where("status", "==", "eligible").stream():
        coach_uid = snap.reference.parent.parent.id
        row = totals.setdefault(coach_uid, {"amountEgp": 0, "entryIds": []})
        row["amountEgp"] += (snap.to_dict() or {}).get("coachAmountEgp", 0)
        row["entryIds"].append(snap.id)

    privates = db.collection("coachPrivate")
    waiting = {snap.id for snap in privates.where("payoutState", "==", "pending").stream()}
    waiting |= {
        snap.id for snap in privates.where("pendingPayout.requestedAt", ">=", _EPOCH).stream()
    }

    coaches = []
    for coach_uid in sorted(set(totals) | waiting):
        row = totals.get(coach_uid, {"amountEgp": 0, "entryIds": []})
        private = privates.document(coach_uid).get()
        info = private.to_dict() if private.exists else {}
        coach = db.collection("coaches").document(coach_uid).get()
        state = info.get("payoutState")
        account_waiting = info.get("pendingPayout") or (info.get("payout") if state == "pending" else None)
        coaches.append(
            {
                "coachUid": coach_uid,
                "displayName": (coach.to_dict() or {}).get("displayName", "") if coach.exists else "",
                "amountEgp": row["amountEgp"],
                "entryIds": sorted(row["entryIds"]),
                "payoutState": state,
                "account": info.get("payout") if state == "confirmed" else None,
                "pendingPayout": (
                    {k: account_waiting.get(k) for k in ("rail", "account", "holderName")}
                    if isinstance(account_waiting, dict) else None
                ),
                "payoutNameMatches": (
                    _same_name(account_waiting.get("holderName"), info.get("fullName"))
                    if isinstance(account_waiting, dict) else None
                ),
            }
        )
    return {"coaches": coaches}


_EPOCH = dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc)


def record(db, actor_uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    coach_uid = common.text(data.get("coachUid"), max_len=128)
    common.refuse_if_subject(actor_uid, coach_uid)
    ids = data.get("entryIds")
    if not isinstance(ids, list) or len(ids) > MAX_ENTRIES:
        raise common.bad()
    ids = [common.text(item, max_len=128) for item in ids]
    if len(set(ids)) != len(ids):
        raise common.bad()
    rail = common.one_of(data.get("rail"), common.RAILS)
    reference = data.get("reference")
    if not common.reference_ok(rail, reference):
        raise common.bad()
    paid_at = common.parse_day(data.get("paidAt"))
    if paid_at > common.cairo_day(now):
        raise common.bad()
    if not ids:
        raise common.refuse(errors.PRECONDITION, errors.NOTHING_OWED)
    common.log_access(db, actor_uid, "payouts.record", coach_uid, now)

    private = db.collection("coachPrivate").document(coach_uid)
    payout_ref = private.collection("payouts").document()

    def body(transaction):
        info = private.get(transaction=transaction)
        if not info.exists or (info.to_dict() or {}).get("payoutState") != "confirmed":
            raise common.refuse(errors.PRECONDITION, errors.PAYOUT_ACCOUNT_PENDING)
        if ((info.to_dict() or {}).get("payout") or {}).get("rail") != rail:
            raise common.bad()
        entries = [private.collection("ledger").document(item) for item in ids]
        total = 0
        for ref in entries:
            snap = ref.get(transaction=transaction)
            row = snap.to_dict() if snap.exists else None
            if row is None or row.get("status") != "eligible":
                raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
            sub = db.collection("subscriptions").document(ref.id).get(transaction=transaction)
            if sub.exists and ((sub.to_dict() or {}).get("cancellation") or {}).get("state") == "requested":
                # Never pay a share a waiting refund may take back.
                raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
            total += row.get("coachAmountEgp", 0)
        if total <= 0:
            raise common.refuse(errors.PRECONDITION, errors.NOTHING_OWED)

        transaction.set(
            payout_ref,
            {
                "amountEgp": total,
                "rail": rail,
                "reference": reference,
                "paidAt": paid_at.isoformat(),
                "entryIds": ids,
                "recordedBy": common.staff_ref(actor_uid),
                "createdAt": now,
            },
        )
        for ref in entries:
            transaction.update(ref, {"status": "paid", "payoutId": payout_ref.id})
        transaction.set(
            private,
            {"owedEgp": firestore.Increment(-total), "paidEgp": firestore.Increment(total)},
            merge=True,
        )
        return total

    total = common.run(db, body)
    notify(coach_uid, "payoutRecorded")
    return {"payoutId": payout_ref.id, "amountEgp": total}
