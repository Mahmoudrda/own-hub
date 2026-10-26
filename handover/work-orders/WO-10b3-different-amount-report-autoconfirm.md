# WO-10b3: State machine part 3: a different amount, "a client paid me", the client's answer, top-up, and auto-confirm of green payments
Depends on: WO-10b2
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.3, 4.5, 13.4 (auto-confirm), 13.12 item 8; `functions/payments/coach.py`, `fees.py`, `create.py`, `engine.py` (WO-10b, 10b2); `functions/payments/states.py` (the table rows for `different_amount`); `functions/tests/test_payments_proof.py` (helpers `send`, `Reader`)

## Why
Three real situations the flow must carry without a staff member: the coach got a different amount (less: she may accept it in writing, or the client pays the rest with a new reference; more: she confirms and refunds the extra); the client paid but never sent proof (the coach starts it from her side and the client confirms with one tap; silence for 72 hours goes to staff, WO-10c); and a coach who has had three clean payments may let green payments confirm themselves while keeping a 48 hour right to flag one (WO-10n). Overpayment is the coach's to refund (recorded through WO-10b4).

## Final result
Callables (all work with the kill switch off):
- `coach_mark_different_amount` `{paymentId, receivedPiasters (less than the amount), acceptLower: bool}` -> `{status: "different_amount"}`.
- `client_respond_different_amount` `{paymentId, decision: "agree"|"dispute"}` -> `{status: "confirmed"|"in_review"}`. `agree` needs `acceptLower` true. Paying the rest is `create_payment` with `topUpOf` (below); cancelling is `cancel_payment`.
- `coach_report_payment` `{subId or reference, txnNumber}` -> `{paymentId, status}` (status unchanged; the client is told).
- `client_confirm_coach_report` `{paymentId, answer: "yes"|"no"}` -> `{status}`.
- `set_auto_confirm_green` `{enabled}` -> `{autoConfirmGreen}`; enabling needs `cleanConfirmed >= 3`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/fees.py` | edit | fee base for a top-up, `recompute` |
| `functions/payments/coach.py` | edit | `set_auto_confirm` |
| `functions/payments/create.py` | edit | `topUpOf` |
| `functions/payments/amounts.py` | create | different amount, both sides |
| `functions/payments/report.py` | create | coach report and client answer |
| `functions/main.py` | edit | five callables |
| `functions/tests/test_entrypoints.py` | edit | five names |
| `functions/tests/test_payments_amounts.py` | create | tests |

## Steps
1. File `functions/payments/fees.py`. Anchor: function `at_activation`. Replace `return {"feePiasters": fee_piasters(payment["baseAmountPiasters"], bps), "feeBps": bps,` with `return {"feePiasters": fee_piasters(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), bps), "feeBps": bps,`. Append:
```python
def recompute(payment: dict, paid_piasters: int, cfg: dict, rel_source) -> dict:
    """The fee when the coach accepts less in writing: on the package price or
    what she actually received, whichever is lower."""
    bps = payment.get("feeBps") or (cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"])
    base = min(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), paid_piasters)
    return {"feePiasters": fee_piasters(base, bps), "feeBps": bps}
```
2. File `functions/payments/coach.py`. Append:
```python
def set_auto_confirm(db, uid: str, data: dict, *, coach_v, now: dt.datetime) -> dict:
    """The coach turns confirming green payments by themselves on or off. On is
    offered after 3 clean payments (13.4). Off is always allowed."""
    common.require_active_coach(db, uid, coach_v)
    enabled = data.get("enabled")
    if not isinstance(enabled, bool):
        raise common.bad()
    ref = profile.profile_ref(db, uid)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        if enabled and row.get("cleanConfirmed", 0) < model.LIMITS["cleanPaymentsForAutoConfirm"]:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"autoConfirmGreen": enabled})
        return {"autoConfirmGreen": enabled}

    return common.run(db, body)
```
3. File `functions/payments/create.py`. Four edits.
   a. Anchor: the line `base = int(sub["priceFinalEgp"]) * 100` (about the middle of `body`). Replace it and the `if base > cfg["maxAmountEgp"] * 100:` pair with:
```python
        top, top_ref = None, None
        if data.get("topUpOf") is not None:
            top_id = common.text(data.get("topUpOf"), max_len=128)
            top_ref = engine.payment_ref(db, top_id)
            top = common.read(top_ref, transaction)
            lower = (top or {}).get("coachDecision") or {}
            if (top is None or top.get("clientUid") != uid or top.get("subId") != sub_id
                    or top.get("status") != "different_amount" or lower.get("acceptLower") is True):
                raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
            base = top["amountPiasters"] - lower["differentAmountPiasters"]
        else:
            base = int(sub["priceFinalEgp"]) * 100
        if base > cfg["maxAmountEgp"] * 100:
```
   (keep the next line `raise common.refuse(errors.PRECONDITION, errors.AMOUNT_OVER_LIMIT)` as is).
   b. Anchor: `if any(r.get("subId") == sub_id and r.get("status") in model.HOLDS_AMOUNT for _, r in rows):`. Replace with `if any(r.get("subId") == sub_id and r.get("status") in model.HOLDS_AMOUNT and not (top is not None and pid == top_ref.id) for pid, r in rows):` and change the generator's tuple unpacking `for _, r in rows` accordingly (it is `for pid, r in rows` in this line only).
   c. Anchor: the payment document dict, the entry `"relSource": None, "reminded12h": False, "reminded48h": False,`. After it add `"topUpOf": top_ref.id if top_ref is not None else None, "feeBasePiasters": top["baseAmountPiasters"] if top is not None else base,`.
   d. Anchor: the line `transaction.update(prof_ref, {"paymentsCreated": firestore.Increment(1)})`. Before it add:
```python
        if top is not None:
            engine.move(transaction, db, top_ref, top, "cancelled", states.CLIENT, uid, now, code="topped_up")
```
   (The first check, `not r.get("topUpOf")` in the daily count, already exists in WO-10b. The first-payment rule is skipped for a top-up because the original is not `PAID`: add `and top is None` to that `if not has_paid ...` condition.)
4. File `functions/payments/amounts.py`, create:
```python
"""A different amount (spec 4.3)."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import activation, coach, engine, errors, fees, model, profile, states


def mark(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    """The coach received less than the amount. She may accept it in writing
    (acceptLower); the package never starts on a partial payment otherwise."""
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    received = common.whole(data.get("receivedPiasters"), low=1, high=10_000_000)
    accept = data.get("acceptLower")
    if not isinstance(accept, bool):
        raise common.bad()
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "different_amount":
            return {"status": "different_amount"}
        if received >= cur["amountPiasters"]:
            raise common.bad()  # more or equal: she just confirms (with receivedPiasters)
        held["payment"] = cur
        engine.move(transaction, db, ref, cur, "different_amount", states.COACH, uid, now, code="different_amount",
                    changes={"coachDecision": {"differentAmountPiasters": received, "acceptLower": accept, "decidedAt": now}})
        return {"status": "different_amount"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("proof_submitted", "different_amount")])
    return out


def respond(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    decision = common.one_of(data.get("decision"), ("agree", "dispute"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        lower = cur.get("coachDecision") or {}
        if cur["status"] == "confirmed" and decision == "agree":
            return {"status": "confirmed"}
        held["payment"] = cur
        if decision == "dispute":
            engine.move(transaction, db, ref, cur, "in_review", states.CLIENT, uid, now, code="client_disputes_amount",
                        changes={"dispute": {"kind": "different_amount", "openedBy": "client", "openedAt": now}})
            held["to"] = "in_review"
            return {"status": "in_review"}
        if lower.get("acceptLower") is not True:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, cur["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        rel_source = (seen["rel"].to_dict() or {}).get("source") if seen["rel"].exists else None
        out = coach.apply_confirmation(transaction, db, ref, cur, seen, prof_ref, prof, cfg, now, states.CLIENT, uid,
                                       lower["differentAmountPiasters"])
        transaction.update(ref, fees.recompute(out, lower["differentAmountPiasters"], cfg, rel_source))
        held["to"] = "confirmed"
        return {"status": "confirmed"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("different_amount", held["to"])])
    return out
```
   (In `apply_confirmation` the `overpaidPiasters` is `max(0, got - amount)` = 0 for a lower amount, and `coachDecision` is replaced by the confirmed record: before that line in `apply_confirmation` (WO-10b2) change `"coachDecision": {"confirmedAt": now, "receivedPiasters": got, "autoConfirmed": role == states.SYSTEM},` to `"coachDecision": {**(cur.get("coachDecision") or {}), "confirmedAt": now, "receivedPiasters": got, "autoConfirmed": role == states.SYSTEM},` so the accepted-lower record stays.)
5. File `functions/payments/report.py`, create:
```python
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
                                 "reportedAt": now})
        transaction.set(ref.collection("events").document(),
                        {"at": now, "from": cur["status"], "to": cur["status"], "role": states.COACH, "actor": states.COACH, "code": "coach_reported"})
        held["payment"] = cur
        return {"paymentId": payment_id, "status": cur["status"]}

    out = common.run(db, body)
    if held:
        notify(held["payment"]["clientUid"], "coachReported")
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
```
6. File `functions/main.py`. After `coach_confirm_payment` add:
```python
@https_fn.on_call()
def coach_mark_different_amount(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import amounts

    return _coaching_call(amounts.mark, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def client_respond_different_amount(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import amounts

    return _coaching_call(amounts.respond, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def coach_report_payment(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import report

    return _coaching_call(report.coach_report, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def client_confirm_coach_report(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import report

    return _coaching_call(report.client_answer, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def set_auto_confirm_green(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import coach

    return _coaching_call(coach.set_auto_confirm, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now())
```
7. File `functions/tests/test_entrypoints.py`: add `"coach_mark_different_amount", "client_respond_different_amount", "coach_report_payment", "client_confirm_coach_report", "set_auto_confirm_green",` after the previous payment names.
8. File `functions/tests/test_payments_amounts.py`, create. Each test: `seed_world(db)`; `make_payment(db, status=..., ...)`; calls the module functions directly with `coach_v="active"` and `notes`.
| test | arrange, act, assert |
|---|---|
| `test_coach_marks_less_and_the_client_is_told` | status `proof_submitted`; `amounts.mark(..., receivedPiasters=40000, acceptLower=False)`; status `different_amount`, `coachDecision.differentAmountPiasters == 40000`; push `differentAmount` to the client; repeat is harmless |
| `test_equal_or_more_is_not_a_different_amount` | `receivedPiasters=50037` and `60000` -> `bad_request`; status unchanged |
| `test_from_awaiting_payment_it_is_illegal` | status `awaiting_payment` -> `(PRECONDITION, ILLEGAL_TRANSITION)` |
| `test_client_agrees_to_a_written_lower_amount_and_the_package_starts` | status `different_amount` with `coachDecision {differentAmountPiasters: 40000, acceptLower: True}`; `amounts.respond(..., decision="agree")` -> `confirmed`, subscription `active`, `fee` on 40000 (`feePiasters == 6000`), access `full` |
| `test_agree_without_the_coach_accepting_is_refused_and_nothing_starts` | `acceptLower False`, `agree` -> `(PRECONDITION, WRONG_STATUS)`; subscription still `awaiting_payment` (the package never starts on a partial payment) |
| `test_client_disputes_a_different_amount_and_it_goes_to_review` | `dispute` -> `in_review`, `dispute.kind == "different_amount"`; push `disputeOpened` to the coach |
| `test_pay_the_rest_makes_a_new_reference_cancels_the_old_one_and_fees_the_whole_price` | status `different_amount` (40000 of 50037, `acceptLower False`) with a lock; `create.create(..., {"subId", "idempotencyKey", "topUpOf": PAY})`; new payment `topUpOf == PAY`, new `baseAmountPiasters == 10037`, a new reference, `feeBasePiasters == 50000`; old payment `cancelled`; confirming the new one gives `feePiasters == 7500` |
| `test_top_up_of_someone_elses_or_a_wrong_status_payment_is_refused` | status `proof_submitted` -> `WRONG_STATUS`; `acceptLower True` -> `WRONG_STATUS` |
| `test_coach_reports_a_payment_by_reference_and_by_subscription` | status `awaiting_payment`; `report.coach_report(..., reference="OH-4821", txnNumber="301234567890123")` -> `coachReport` stored, push `coachReported` to the client; a second call returns the same answer; the same with `subId` |
| `test_report_refuses_unknown_closed_and_reused` | unknown reference -> `PAYMENT_NOT_FOUND`; status `confirmed` -> `WRONG_STATUS`; `paymentTxnNumbers/<key>` owned by another payment -> `(PRECONDITION, TXN_REUSED)`; after `lateUntil` -> `WRONG_STATUS` |
| `test_client_says_yes_and_the_package_starts_with_the_fee` | after a report, `report.client_answer(..., "yes")` -> `confirmed`, subscription `active` full, fee owed, push `paymentConfirmedByClient` to the coach; also works from `expired` |
| `test_client_says_no_and_nothing_changes_but_the_note` | `"no"` -> status unchanged, `coachReport.clientAnswer == "no"`; no access |
| `test_client_answer_needs_a_report` | no `coachReport` -> `(PRECONDITION, NO_COACH_REPORT)` |
| `test_auto_confirm_needs_three_clean_payments` | profile `cleanConfirmed 2` enabling -> `WRONG_STATUS`; `3` -> `autoConfirmGreen True`; disabling always works; non-bool -> `bad_request` |
| `test_a_new_coach_defaults_to_manual_confirmation` | profile from `seed_world` -> `autoConfirmGreen False` |
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_amounts.py tests/test_payments_create.py tests/test_payments_proof.py tests/test_entrypoints.py -q`

## Strings to add
None. New codes the app maps: `txn_reused, no_coach_report`. Pushes already defined: `differentAmount, coachReported, paymentConfirmedByClient`.

## Tests to add or change
As above; the top-up test also needs one new row in `test_payments_create.py`? No: it lives in `test_payments_amounts.py`.

## Verify
The command ends with `N passed`, no `failed`; `tests/test_payments_create.py` still passes after the `create.py` edits.

## Do not
- Do not start a package on a partial payment unless the coach accepted in writing (`acceptLower`) AND the client agreed.
- Do not let the coach's report activate anything by itself: the client must say yes (or staff decide).
- Do not hold the coach's report text in the push.

## Done checklist
- [ ] amounts, report created; fees, coach, create, main edited
- [ ] five callables registered and listed
- [ ] tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
