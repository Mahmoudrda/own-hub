"""'A client paid me' (spec 4.5): the coach starts it, the client answers."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import activation, coach, engine, errors, model, profile, proof, states

OPEN = ("awaiting_payment", "expired")


def coach_report(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    txn = common.text(data.get("txnNumber"), max_len=40)
    key = proof.txn_key(txn)
    if len(key) < 6:
        raise common.bad()
    sub_id = data.get("subId")
    reference = data.get("reference")
    if (sub_id is None) == (reference is None):
        raise common.bad()
    payments = db.collection("payments").where("coachUid", "==", uid)
    if reference is not None:
        found = [s for s in payments.where("reference", "==", common.text(reference, max_len=20).upper()).stream()]
    else:
        wanted = common.text(sub_id, max_len=128)
        found = [s for s in payments.where("subId", "==", wanted).stream() if (s.to_dict() or {}).get("status") in OPEN]
    if len(found) != 1:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    payment_id = found[0].id
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        late = common.as_utc(cur.get("lateUntil"))
        if cur["status"] not in OPEN or late is None or now > late:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        if cur.get("coachReport"):
            return {"paymentId": payment_id, "status": cur["status"]}
        reg_ref = db.collection("paymentTxnNumbers").document(key)
        reg = reg_ref.get(transaction=transaction)
        if reg.exists and (reg.to_dict() or {}).get("paymentId") != payment_id:
            raise common.refuse(errors.PRECONDITION, errors.TXN_REUSED)
        transaction.set(reg_ref, {"paymentId": payment_id, "createdAt": now})
        transaction.update(ref, {"coachReport": {"txnNumber": txn, "txnKey": key, "reportedAt": now, "clientAnswer": None},
                                 "reportedAt": now, "escalateAt": now + model.hours(model.LIMITS["silentEscalateHours"])})
        transaction.set(ref.collection("events").document(),
                        {"at": now, "from": cur["status"], "to": cur["status"], "role": states.COACH, "actor": states.COACH, "code": "coach_reported"})
        held["payment"] = cur
        return {"paymentId": payment_id, "status": cur["status"]}

    out = common.run(db, body)
    if held:
        notify(held["payment"]["clientUid"], "instapayCoachReported", payment_id)
    return out


def client_answer(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    answer = common.one_of(data.get("answer"), ("yes", "no"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if cur["status"] == "confirmed" and answer == "yes":
            return {"status": "confirmed"}
        if cur["status"] not in OPEN or not cur.get("coachReport"):
            raise common.refuse(errors.PRECONDITION, errors.NO_COACH_REPORT)
        if answer == "no":
            transaction.update(ref, {"coachReport.clientAnswer": "no"})  # the 72 hour pass sends it to staff
            return {"status": cur["status"]}
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, cur["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        held["payment"], held["from"] = cur, cur["status"]
        coach.apply_confirmation(transaction, db, ref, cur, seen, prof_ref, prof, cfg, now, states.CLIENT, uid, None)
        return {"status": "confirmed"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "confirmed")])
    return out
