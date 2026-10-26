# WO-10b4: State machine part 4: refunds, "service problem", the staff queue, the evidence summary and the staff decision
Depends on: WO-10b3
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.1, 4.8, 4.9, 4.12, 4.15, 13.6, 13.9; `functions/payments/states.py` (rows for `refund_*`, `service_dispute`, `in_review`); `functions/payments/engine.py`, `activation.py`, `fees.py`; `functions/coaching/common.py` lines 238-262 (`log_access`, `staff_ref`, `refuse_if_subject`); `functions/coaching/media.py` lines 1-40 (how a woman-reviewer-only list is built, UNVERIFIED line range: `grep -n "def list_for_review" functions/coaching/media.py`); `functions/main.py` lines 925-945 (`_require_woman_reviewer`)

## Why
After money has moved, three paths remain: the client asks for a refund in the withdrawal window (the coach has 3 days; silence goes to staff), the client reports that the coach did not deliver, and staff decide disputes. Staff see one screen of evidence in a fixed order and a recommendation, and must type a reason; every read and decision leaves a log line. A woman reviewer only (not the admin claim) sees a woman's private payment data (spec 12.4). Staff never move money: "refund owed" is a decision the coach then carries out and records.

## Final result
Callables (work with the kill switch off):
- `request_refund` `{paymentId, idempotencyKey?}` client, once per payment, within 14 days of access starting.
- `deny_refund` `{paymentId, reasonCode: "sessions_delivered"|"outside_terms"|"other"}` coach.
- `record_instapay_refund` `{paymentId, txnNumber, amountPiasters, kind: "refund"|"overpayment"}` coach. `refund` ends the coaching; `overpayment` only records the extra she sent back.
- `open_service_dispute` `{paymentId, note?}` client (from `confirmed`, `resolved_paid` or after `refund_denied`), at most 3 a month.
- `get_payment_image` `{paymentId, path}` either party; returns `{imageB64}`.
- `staff_list_payment_queue` `{after?}` woman reviewer; `staff_get_payment_evidence` `{paymentId, withImages?}`; `staff_resolve_payment` `{paymentId, outcome: "resolved_paid"|"resolved_unpaid"|"no_refund"|"refund_owed"|"reopen", reason (10 to 500 characters), proofFalse?, refundPiasters?}`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/refund.py` | create | request, deny, record, service dispute |
| `functions/payments/staff.py` | create | queue, evidence, recommend, resolve, party image |
| `functions/payments/engine.py` | edit | fee state `disputed` when a payment enters review |
| `functions/main.py` | edit | eight callables |
| `functions/tests/test_entrypoints.py` | edit | eight names |
| `functions/tests/test_payments_refund.py` | create | refund and dispute tests |
| `functions/tests/test_payments_staff.py` | create | staff tests |

## Steps
1. File `functions/payments/engine.py`. Anchor: in `move`, the line `update = {"status": to, "statusAt": now, **(changes or {})}`. Right after it add:
```python
    if to == "in_review" and payment.get("feeState") == "owed" and "feeState" not in update:
        update["feeState"] = "disputed"  # the statement lists it as disputed, pending (13.5)
```
2. File `functions/payments/refund.py`, create:
```python
"""Refunds and service disputes (spec 4.8, 4.9, 4.12)."""

from __future__ import annotations

import datetime as dt

from google.cloud import firestore

from coaching import common

from . import activation, engine, errors, fees, model, profile, proof, states

LIMITS = model.LIMITS
PAID = model.PAID_STATUSES


def started_at(row: dict) -> dt.datetime:
    """When access began: the coach's confirmation, or the staff decision, or the last change."""
    return (common.as_utc((row.get("coachDecision") or {}).get("confirmedAt"))
            or common.as_utc((row.get("dispute") or {}).get("decidedAt"))
            or common.as_utc(row.get("statusAt")))


def request(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if (cur.get("refund") or {}).get("requestedAt"):
            if cur["status"] == "refund_requested":
                return {"status": "refund_requested"}  # a second tap
            raise common.refuse(errors.PRECONDITION, errors.REFUND_ALREADY_REQUESTED)
        if cur["status"] not in PAID:
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        if now > started_at(cur) + model.days(LIMITS["refundWindowDays"]):
            raise common.refuse(errors.PRECONDITION, errors.REFUND_WINDOW_CLOSED)
        held["payment"], held["from"] = cur, cur["status"]
        engine.move(transaction, db, ref, cur, "refund_requested", states.CLIENT, uid, now, code="refund_requested",
                    changes={"refund": {"requestedAt": now, "coachDueAt": now + model.days(LIMITS["refundCoachDays"])}})
        return {"status": "refund_requested"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "refund_requested")])
    return out


def deny(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    reason = common.one_of(data.get("reasonCode"), ("sessions_delivered", "outside_terms", "other"))
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "refund_denied":
            return {"status": "refund_denied"}
        held["payment"] = cur
        engine.move(transaction, db, ref, cur, "refund_denied", states.COACH, uid, now, code=f"refund_denied_{reason}",
                    changes={"refund.deniedAt": now, "refund.deniedReason": reason})
        return {"status": "refund_denied"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("refund_requested", "refund_denied")])
    return out


def record(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    """The coach sent money back by InstaPay and writes it down. Own Hub moves nothing."""
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    txn = common.text(data.get("txnNumber"), max_len=40)
    if len(proof.txn_key(txn)) < 6:
        raise common.bad()
    amount = common.whole(data.get("amountPiasters"), low=1, high=10_000_000)
    kind = common.one_of(data.get("kind"), ("refund", "overpayment"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if (cur.get("refund") or {}).get("recordedAt") and kind == "refund":
            return {"status": cur["status"]}  # already recorded
        if kind == "overpayment":
            if cur["status"] not in PAID or amount > cur.get("overpaidPiasters", 0):
                raise common.bad()
            transaction.update(ref, {"refund.overpayment": {"txnNumber": txn, "amountPiasters": amount, "recordedAt": now}})
            return {"status": cur["status"]}
        if amount > cur["amountPiasters"]:
            raise common.bad()
        if cur["status"] == "in_review" and (cur.get("dispute") or {}).get("staffDecision") != "refund_owed":
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        seen = activation.read_for_end(transaction, db, cur["subId"])
        rel_source = None
        got = (cur.get("coachDecision") or {}).get("receivedPiasters", cur["amountPiasters"])
        held["payment"], held["from"] = cur, cur["status"]
        changes = {"refund": {**(cur.get("refund") or {}), "txnNumber": txn, "amountPiasters": amount, "recordedAt": now,
                              "partial": amount < got},
                   "access": {"state": "none", "until": None}, **fees.recompute(cur, max(0, got - amount), cfg, rel_source)}
        engine.move(transaction, db, ref, cur, "refunded", states.COACH, uid, now, changes=changes, code="refund_recorded")
        activation.end(transaction, db, cur["subId"], seen, "refund", now)  # a package ends when a refund is recorded
        return {"status": "refunded"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "refunded")])
    return out


def open_service_dispute(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    note = common.optional_text(data.get("note"), max_len=model.LIMITS.get("noteMax", 500))
    month = f"disputes_{now:%Y%m}"
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if cur["status"] == "in_review" and (cur.get("dispute") or {}).get("openedBy") == "client":
            return {"status": "in_review"}  # a second tap
        standing_ref = profile.standing_ref(db, uid)
        standing = common.read(standing_ref, transaction) or {}
        if cur["status"] not in PAID + ("refund_denied",):
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        if standing.get(month, 0) >= LIMITS["disputesPerMonth"]:
            raise common.refuse(errors.EXHAUSTED, errors.DISPUTE_LIMIT)
        sub = common.read(db.collection("subscriptions").document(cur["subId"]), transaction) or {}
        kind = "refund" if cur["status"] == "refund_denied" else "service"
        facts = {"sessionsUsed": sub.get("sessionsUsed", 0), "sessionsIncluded": sub.get("sessionsIncluded", 0)}
        held["payment"], held["from"] = cur, cur["status"]
        pay = cur
        if kind == "service":
            pay = engine.move(transaction, db, ref, cur, "service_dispute", states.CLIENT, uid, now, code="service_dispute")
        engine.move(transaction, db, ref, pay, "in_review", states.CLIENT if kind == "refund" else states.SYSTEM, uid if kind == "refund" else None, now,
                    code="dispute_in_review",
                    changes={"dispute": {"kind": kind, "openedBy": "client", "openedAt": now, "serviceFacts": facts, "clientNote": note}})
        transaction.set(standing_ref, {month: firestore.Increment(1)}, merge=True)
        held["moves"] = [(cur["status"], "service_dispute"), ("service_dispute", "in_review")] if kind == "service" else [("refund_denied", "in_review")]
        return {"status": "in_review"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], held["moves"])
    return out
```
(`LIMITS["noteMax"]` is not in `payments.model.LIMITS`; the line uses `.get("noteMax", 500)`, which is 500. Keep it so.)
3. File `functions/payments/staff.py`, create:
```python
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
        used, included = (evidence["dispute"].get("serviceFacts") or {}).get("sessionsUsed", 0), (evidence["dispute"].get("serviceFacts") or {}).get("sessionsIncluded", 0)
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
```
4. File `functions/main.py`. After the payments callables of WO-10b3 add (staff callables use `_require_woman_reviewer(request)` with no admin):
```python
@https_fn.on_call()
def request_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.request, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def deny_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.deny, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def record_instapay_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.record, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def open_service_dispute(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.open_service_dispute, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def get_payment_image(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.party_image, store.db(), uid, data, blobs=_PersonalBlobs())


@https_fn.on_call()
def staff_list_payment_queue(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)  # no admin: a woman's private payment data
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.queue, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def staff_get_payment_evidence(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.get_evidence, store.db(), actor, data, now=_coaching_now(), blobs=_PersonalBlobs())


@https_fn.on_call()
def staff_resolve_payment(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.resolve, store.db(), actor, data, now=_coaching_now(), notify=_payments_notify)
```
(WO-10o adds `on_decision=_payments_after_decision` to the last call.)
5. File `functions/tests/test_entrypoints.py`: add `"request_refund", "deny_refund", "record_instapay_refund", "open_service_dispute", "get_payment_image", "staff_list_payment_queue", "staff_get_payment_evidence", "staff_resolve_payment",`. Also in the same file, in the test `test_the_live_review_callables_need_the_woman_reviewer_claim` no change; the staff names get their own test in step 7.
6. File `functions/tests/test_payments_refund.py`, create (helpers as before; a confirmed payment: `make_payment(db, status="confirmed", coachDecision={"confirmedAt": NOW, "receivedPiasters": AMOUNT}, overpaidPiasters=0, access={"state":"full","until":None}, feeState="owed", feeOwedAt=NOW, feePiasters=7500)`; the subscription is made `active` with `sessionsUsed`/`sessionsIncluded`):
| test | arrange, act, assert |
|---|---|
| `test_client_asks_for_a_refund_once_inside_14_days` | `refund.request` at NOW+13 days -> `refund_requested`, `refund.coachDueAt == +3 days`, push `instapayRefundRequested` to the coach; a second call returns the same; after `refunded` and another ask -> `REFUND_ALREADY_REQUESTED` |
| `test_the_window_closes_after_14_days` | NOW+15 days -> `(PRECONDITION, REFUND_WINDOW_CLOSED)` |
| `test_only_a_paid_payment_can_ask_and_only_its_client` | status `proof_submitted` -> `ILLEGAL_TRANSITION`; coach uid -> `PAYMENT_NOT_FOUND` |
| `test_coach_denies_and_the_client_can_appeal` | `refund.deny(... "sessions_delivered")` -> `refund_denied`, push `instapayReviewDecided`; `open_service_dispute` -> `in_review`, `dispute.kind == "refund"` |
| `test_coach_records_a_refund_the_package_ends_and_the_fee_follows_what_was_kept` | from `refund_requested`: `record(... txnNumber="R123456789012", amountPiasters=50037, kind="refund")` -> `refunded`, subscription `ended_early` with `endReason == "refund"`, coach `activeClients` down by one, `refund.partial` False, `feePiasters == 0`; push `instapayRefundRecorded`; repeat harmless |
| `test_a_partial_refund_after_sessions_were_delivered` | `amountPiasters=20000` -> `partial True`, fee recomputed on 30037 kept (`feePiasters == 4505`, 15 percent rounded down of the lower of base 50000 and 30037) |
| `test_an_overpayment_is_recorded_without_ending_anything` | `overpaidPiasters=963`; `kind="overpayment", amountPiasters=963` -> status unchanged, `refund.overpayment` stored; `amountPiasters=964` -> `bad_request` |
| `test_a_refund_cannot_exceed_the_payment_and_needs_a_valid_number` | `amountPiasters=50038` -> `bad_request`; `txnNumber="12"` -> `bad_request` |
| `test_in_review_needs_the_staff_refund_decision_before_the_coach_records` | status `in_review`, no `staffDecision` -> `ILLEGAL_TRANSITION`; with `dispute.staffDecision == "refund_owed"` -> `refunded` |
| `test_service_dispute_goes_to_review_with_the_facts_and_is_limited_to_three_a_month` | sub `sessionsUsed 1, sessionsIncluded 4`; open -> `in_review`, `dispute.serviceFacts == {1, 4}`, events `confirmed->service_dispute (client)` then `service_dispute->in_review (system)`, access still `full`; with `paymentStanding.disputes_202611 = 3` -> `(EXHAUSTED, DISPUTE_LIMIT)`; the counter is `disputes_YYYYMM` of the server month |
| `test_no_cross_party_access` | the coach cannot open a service dispute (`PAYMENT_NOT_FOUND`); the client cannot record a refund |
7. File `functions/tests/test_payments_staff.py`, create:
| test | arrange, act, assert |
|---|---|
| `test_queue_lists_in_review_oldest_first_with_waiting_hours_and_logs_the_read` | two in_review payments and one confirmed; `staff.queue` -> two items ordered by `statusAt`, `waitingHours` right, a line in `adminAccessLog` (collection name `console.access.COLLECTION`) without any uid |
| `test_evidence_has_the_seven_items_in_order_and_a_recommendation` | in_review `not_received` payment with a `staff/review` doc; keys of the answer start with `1_`..`7_` in order; `recommended.outcome` is `resolved_paid` when `staff/statement` has `amountFound True`; `resolved_unpaid` for `proof_red` with `txnReused` |
| `test_evidence_images_only_on_request` | `withImages` False -> no `images`; True -> base64 of the blob |
| `test_resolve_paid_starts_or_keeps_the_coaching_and_sets_the_fee` | in_review payment, subscription `awaiting_payment`; `resolve(outcome="resolved_paid", reason="statement shows it")` -> `resolved_paid`, subscription `active`, access `full`, `feeState owed`, `dispute.staffDecision`, decision log line holds `reasonText`, events hold no reason text; pushes `instapayReviewDecided` to the client and `instapayCoachReviewDecided` to the coach |
| `test_resolve_unpaid_ends_provisional_access_and_waives_the_fee` | provisional access, subscription `active`; `resolved_unpaid` -> subscription `ended_early` (`endReason dispute`), `feeState waived`, access `none` |
| `test_no_refund_returns_a_service_dispute_to_confirmed` | `dispute.kind service` -> `confirmed` |
| `test_refund_owed_keeps_the_payment_in_review_and_sets_a_due_date` | `refund_owed` with `refundPiasters=20000` -> still `in_review`, `dispute.refundDueAt == NOW+7d`, event code `refund_owed` |
| `test_a_reason_of_at_least_ten_characters_is_required` | `reason="ok"` -> `(INVALID, REASON_REQUIRED)`; nothing written |
| `test_staff_never_decide_a_case_about_themselves` | actor equals the coach uid -> `(PERMISSION, STAFF_IS_SUBJECT)` |
| `test_a_second_reviewer_reopens_and_the_same_one_cannot` | decide with REVIEWER, reopen with REVIEWER -> `(PRECONDITION, SAME_STAFF)`; reopen with REVIEWER2 -> `in_review`, then decide differently -> `resolved_unpaid`; the log has three lines |
| `test_resolve_from_the_wrong_status_is_illegal` | `awaiting_payment` -> `ILLEGAL_TRANSITION` |
| `test_party_image_goes_only_to_the_two_parties_and_only_for_listed_paths` | client and coach get base64; a stranger and an unlisted path get `PAYMENT_NOT_FOUND` |
| `test_the_staff_callables_need_the_woman_reviewer_claim` (in `test_entrypoints.py` style, not this file) | see below |
Add to `functions/tests/test_entrypoints.py` (uses the file's existing `raises`, `inner`, `request`, `stubbed`):
```python
@pytest.mark.parametrize("name", ["staff_list_payment_queue", "staff_get_payment_evidence", "staff_resolve_payment"])
def test_the_payment_staff_callables_refuse_a_member_and_a_plain_admin(name, stubbed):
    fn = inner(name)
    raises(lambda: fn(request({})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
    raises(lambda: fn(request({}, token={"admin": True})), https_fn.FunctionsErrorCode.PERMISSION_DENIED)
```
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_refund.py tests/test_payments_staff.py tests/test_entrypoints.py tests/test_payments_states.py -q`

## Strings to add
None. Codes the app maps: `refund_window_closed, refund_already_requested, dispute_limit, reason_required, same_staff`. Reason codes of a denial the app shows: `sessions_delivered, outside_terms, other`.

## Tests to add or change
As above.

## Verify
The command ends with `N passed`, no `failed`.

## Do not
- Do not let a refund move money or any code assume it did: the coach writes down what she sent.
- Do not let the admin claim reach these staff callables.
- Do not put the staff's typed reason into an event or a push: it goes only to the private decision log.
- Do not delete or edit a decision log line (append-only).

## Done checklist
- [ ] refund.py and staff.py created, engine and main edited
- [ ] eight callables registered and listed
- [ ] all tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
