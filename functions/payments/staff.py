"""What staff see and decide (spec 13.6). A woman reviewer only; every read and decision is logged."""

from __future__ import annotations

import base64
import datetime as dt
from typing import Callable, Optional

from coaching import common

from . import activation, engine, errors, fees, model, profile, states

PAGE = 25
OUTCOMES = ("resolved_paid", "resolved_unpaid", "no_refund", "refund_owed", "reopen")


def recommend(evidence: dict) -> dict:
    """A simple rule set, never binding. `evidence` is the dictionary
    `get_evidence` builds. Returns {outcome, why}."""
    kind = (evidence.get("dispute") or {}).get("kind")
    stmt = evidence.get("coachStatement") or {}
    review = evidence.get("clientProof") or {}
    if stmt.get("amountFound") or stmt.get("txnFound"):
        return {"outcome": "resolved_paid", "why": "statement_contradicts_claim"}
    if kind == "proof_red" and ({"txnReused", "sameImage", "nearImage"} & set(review.get("reasons") or [])):
        return {"outcome": "resolved_unpaid", "why": "proof_reused"}
    if kind == "not_received" and review.get("outcome") == "green" and not stmt:
        return {"outcome": "resolved_paid", "why": "green_proof_no_statement"}
    if kind in ("service", "refund"):
        used = (evidence["dispute"].get("serviceFacts") or {}).get("sessionsUsed", 0)
        included = (evidence["dispute"].get("serviceFacts") or {}).get("sessionsIncluded", 0)
        return {"outcome": "refund_owed" if included and used == 0 else "no_refund", "why": "sessions_delivered" if used else "nothing_delivered"}
    return {"outcome": None, "why": "ask_for_bank_statement_line"}


def queue(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    after = data.get("after")
    common.log_access(db, actor, "payments.queue", "queue", now)
    rows = [s for s in db.collection("payments").where("status", "==", "in_review").stream()]
    rows.sort(key=lambda s: (common.as_utc((s.to_dict() or {}).get("statusAt")), s.id))
    if after:
        ids = [s.id for s in rows]
        rows = rows[ids.index(after) + 1:] if after in ids else []
    more = len(rows) > PAGE
    rows = rows[:PAGE]
    items = []
    for s in rows:
        p = s.to_dict() or {}
        review = db.collection("payments").document(s.id).collection("staff").document("review").get()
        items.append({
            "paymentId": s.id, "kind": (p.get("dispute") or {}).get("kind"), "amountPiasters": p.get("amountPiasters"),
            "reference": p.get("reference"), "waitingHours": int((now - common.as_utc(p.get("statusAt"))).total_seconds() // 3600),
            "riskScore": (review.to_dict() or {}).get("riskScore", 0) if review.exists else 0, "staffVisible": bool(p.get("staffVisible")),
        })
    return {"items": items, "next": rows[-1].id if more and rows else None}


def get_evidence(db, actor: str, data: dict, *, now: dt.datetime, blobs=None) -> dict:
    """The seven items in the order of 13.6, then the recommendation."""
    payment_id = common.text(data.get("paymentId"), max_len=128)
    with_images = data.get("withImages") is True
    common.log_access(db, actor, "payments.evidence", payment_id, now)
    snap = engine.payment_ref(db, payment_id).get()
    if not snap.exists:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    p = snap.to_dict()
    common.refuse_if_subject(actor, p.get("clientUid"), p.get("coachUid"))
    staff = snap.reference.collection("staff")
    review = staff.document("review").get()
    stmt = staff.document("statement").get()
    events = sorted((e.to_dict() for e in snap.reference.collection("events").stream()), key=lambda e: common.as_utc(e["at"]))
    prof = db.collection("coachPaymentProfiles").document(p["coachUid"]).get().to_dict() or {}
    cs = db.collection("paymentStanding").document(p["clientUid"]).get().to_dict() or {}
    ks = db.collection("paymentStanding").document(p["coachUid"]).get().to_dict() or {}
    r = review.to_dict() if review.exists else {}
    evidence = {
        "1_amountAndReference": {"amountPiasters": p["amountPiasters"], "reference": p["reference"]},
        "2_transactionNumber": {"txnNumber": (p.get("proof") or {}).get("txnNumber"),
                                "digits": len(str((p.get("proof") or {}).get("txnNumber") or "")), },
        "3_ocr": {"clientChecks": r.get("checks"), "riskScore": r.get("riskScore"), "coachStatement": stmt.to_dict() if stmt.exists else None},
        "4_flags": {"flags": r.get("flags"), "reasons": r.get("reasons"), "imageFlags": (p.get("proof") or {}).get("imageFlags")},
        "5_timeline": [{"from": e.get("from"), "to": e.get("to"), "role": e.get("role"), "code": e.get("code"), "at": common.plain(e["at"])} for e in events],
        "6_history": {"coach": {"paymentsConfirmed": prof.get("paymentsConfirmed", 0), "disputesLost": prof.get("disputesLost", 0),
                                "strikes": ks.get("coachStrikes", 0)}, "client": {"strikes": cs.get("clientStrikes", 0)}},
        "7_statementRequest": (p.get("dispute") or {}).get("statementRequests"),
        "dispute": common.plain(p.get("dispute")), "status": p["status"],
        "clientProof": {"outcome": p.get("outcome"), "reasons": r.get("reasons")},
        "coachStatement": stmt.to_dict() if stmt.exists else None,
    }
    evidence["recommended"] = recommend(evidence)
    if with_images and blobs is not None:
        paths = list((p.get("proof") or {}).get("screenshotPaths") or []) + list((p.get("coachDecision") or {}).get("statementPaths") or [])
        evidence["images"] = {path: base64.b64encode(blobs.read(path)).decode() for path in paths if blobs.exists(path)}
    return common.plain(evidence)


def resolve(db, actor: str, data: dict, *, now: dt.datetime, notify, on_decision: Optional[Callable] = None) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    outcome = common.one_of(data.get("outcome"), OUTCOMES)
    reason = common.text(data.get("reason"), min_len=10, max_len=500, reason=errors.REASON_REQUIRED)
    proof_false = data.get("proofFalse") is True
    refund = data.get("refundPiasters")
    if outcome == "refund_owed":
        refund = common.whole(refund, low=1, high=10_000_000)
    common.log_access(db, actor, f"payments.{outcome}", payment_id, now)
    held = {}

    def body(transaction):
        ref = engine.payment_ref(db, payment_id)
        cur = common.read(ref, transaction)
        if cur is None:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        common.refuse_if_subject(actor, cur.get("clientUid"), cur.get("coachUid"))
        last = list(ref.collection("staff").document("decisions").collection("log").stream(transaction=transaction))
        last_by = sorted((x.to_dict() for x in last), key=lambda x: common.as_utc(x["at"]))[-1:]
        seen_start = activation.read_for_start(transaction, db, cur["subId"])
        seen_end = activation.read_for_end(transaction, db, cur["subId"])
        cfg = model.config(db)
        log = ref.collection("staff").document("decisions").collection("log").document()
        decided = common.decided_stamp(actor, now)
        dispute = {**(cur.get("dispute") or {}), "staffDecision": outcome, "decidedAt": now, "reasonCode": outcome}
        pay = cur
        held["payment"], held["from"] = cur, cur["status"]
        held["moves"] = []

        if outcome == "reopen":
            if last_by and last_by[0].get("by") == decided["decidedBy"]:
                raise common.refuse(errors.PRECONDITION, errors.SAME_STAFF)  # a second reviewer reopens
            engine.move(transaction, db, ref, cur, "in_review", states.STAFF, actor, now, code="reopened",
                        changes={"dispute": {**dispute, "kind": (cur.get("dispute") or {}).get("kind") or "reopened", "staffDecision": None}})
            held["moves"] = [(cur["status"], "in_review")]
        elif outcome == "refund_owed":
            if cur["status"] != "in_review":
                raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
            transaction.update(ref, {"dispute": {**dispute, "refundOwedPiasters": refund, "refundDueAt": now + model.days(7)}})
            transaction.set(ref.collection("events").document(), {"at": now, "from": "in_review", "to": "in_review", "role": states.STAFF,
                                                                  "actor": common.staff_ref(actor), "code": "refund_owed"})
        else:
            target = {"resolved_paid": "resolved_paid", "resolved_unpaid": "resolved_unpaid", "no_refund": "confirmed"}[outcome]
            changes = {"dispute": dispute}
            if target == "resolved_paid" or target == "confirmed":
                changes["access"] = {"state": "full", "until": None}
                changes["feeState"] = "owed"
            else:
                changes["access"] = {"state": "none", "until": None}
                changes["feeState"] = "waived"
            pay = engine.move(transaction, db, ref, cur, target, states.STAFF, actor, now, changes=changes, code=f"staff_{outcome}")
            if target == "resolved_paid" and activation_ok(seen_start):
                rel_source = (seen_start["rel"].to_dict() or {}).get("source") if seen_start["rel"].exists else None
                fee = {} if cur.get("feeOwedAt") else fees.at_activation(pay, cfg, rel_source, now)
                if fee:
                    transaction.update(ref, fee)
                activation.grant(transaction, db, seen_start, now)
            if target == "resolved_unpaid":
                activation.end(transaction, db, cur["subId"], seen_end, "dispute", now)
            held["moves"] = [("in_review", target)]
        transaction.set(log, {"by": decided["decidedBy"], "at": now, "outcome": outcome, "reasonText": reason, "proofFalse": proof_false})
        held["kind"] = (cur.get("dispute") or {}).get("kind")
        return {"status": held["moves"][0][1] if held["moves"] else "in_review", "outcome": outcome}

    result = common.run(db, body)
    engine.notify_moves(notify, held["payment"], held["moves"])
    if on_decision is not None:
        on_decision(db, payment_id, outcome=outcome, kind=held["kind"], proof_false=proof_false, now=now, notify=notify)
    return result


def activation_ok(seen: dict) -> bool:
    return (seen["sub"] or {}).get("status") in ("awaiting_payment", "active")


def party_image(db, uid: str, data: dict, *, blobs) -> dict:
    """Either party reads a screenshot of her own payment through here, never from storage."""
    payment_id = common.text(data.get("paymentId"), max_len=128)
    path = common.text(data.get("path"), max_len=200)
    snap = engine.payment_ref(db, payment_id).get()
    p = snap.to_dict() if snap.exists else None
    if p is None or uid not in (p.get("clientUid"), p.get("coachUid")):
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    allowed = list((p.get("proof") or {}).get("screenshotPaths") or []) + list((p.get("coachDecision") or {}).get("statementPaths") or [])
    if path not in allowed or not blobs.exists(path):
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    return {"imageB64": base64.b64encode(blobs.read(path)).decode()}
