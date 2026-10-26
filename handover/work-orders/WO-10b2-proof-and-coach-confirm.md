# WO-10b2: State machine part 2: submit_instapay_proof (checks, outcome, bounded access) and coach_confirm_payment (with the fee owed at activation)
Depends on: WO-10b, WO-10l-server
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.2, 4.6, 4.7, 4.12, 13.1, 13.3, 13.4, 13.9, 13.12; `functions/coaching/proofs.py` lines 40-168 (the older proof flow: pattern for images, hashes, registry and rollback); `functions/payments/risk.py`, `receipt_checks.py`, `activation.py`, `engine.py`; `functions/coaching/dhash.py`; `functions/main.py` lines 78-120 (`_decode_image`), 1862-1875 (`_coaching_notify`)

## Why
This is the heart of the flow. The client sends one to three screenshots (one tap in the app); the server re-encodes them, reads them, runs the deterministic checks, and answers GREEN (the coach sees a matching payment and the client has bounded access at once), AMBER (one friendly retry, then the coach checks her own bank) or RED (no access, to staff). The coach confirms with one tap. Fee owed starts the moment access starts, not when the coach taps (13.1), so denying receipt gains her nothing.

## Final result
No screen. Callables:
- `submit_instapay_proof` request `{paymentId, idempotencyKey, amountPiasters, images: [base64 PNG or JPEG, ...] (1 to 3), txnNumber?, paidAtClaimed?, senderHandle?, otherPayerOk?, phoneReading?}`. Answer `{paymentId, status, outcome: "green"|"amber"|"red", reasons: [codes], retry: bool}`. `retry: true` means nothing was recorded except the attempt: ask her for a better picture.
- `coach_confirm_payment` request `{paymentId, receivedPiasters?}`. Answer `{status: "confirmed"}`.

Behaviour in numbers: images at most 3 per call and 5 per payment, each at most 5 MB (`LIMITS`); a proof is accepted while the payment is `awaiting_payment`, or `expired` and still before `lateUntil` (7 days); GREEN gives provisional access for `min(7, package days)` days; an AMBER that stands gets access only after 24 hours with no objection (WO-10c); RED goes to `in_review`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/fees.py` | create | fee at activation |
| `functions/payments/coach.py` | create | `apply_confirmation`, `confirm` |
| `functions/payments/proof.py` | create | `submit` |
| `functions/payments/engine.py` | edit | `notify_moves` |
| `functions/payments/create.py` | edit | initial `proof` map |
| `functions/main.py` | edit | `_payments_notify`, two callables |
| `functions/tests/test_entrypoints.py` | edit | two names |
| `functions/tests/test_payments_proof.py` | create | proof and confirm tests |

## Steps
1. File `functions/payments/fees.py`, create:
```python
"""Own Hub's fee (D63, spec 4.13, 13.1): owed from the moment access starts."""

from __future__ import annotations

import datetime as dt


def fee_piasters(base_piasters: int, bps: int) -> int:
    """On the package price only: the 1 to 99 extra piasters that make the amount
    unique belong to the coach. Integer arithmetic, rounded down."""
    return base_piasters * bps // 10000


def at_activation(payment: dict, cfg: dict, rel_source, now: dt.datetime) -> dict:
    """The payment fields to write when access first starts (provisional or
    full); {} when the fee was already set. 8 percent for a client the coach
    brought with her invite code (relationship source 'invite'), 15 percent
    otherwise; both come from coachingConfig/instapay (model.config)."""
    if payment.get("feeOwedAt"):
        return {}
    bps = cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"]
    return {"feePiasters": fee_piasters(payment["baseAmountPiasters"], bps), "feeBps": bps,
            "feeState": "owed", "feeOwedAt": now}
```
2. File `functions/payments/create.py` (WO-10b). Anchor: the line `"proof": None, "outcome": None, "access": {"state": "none", "until": None},` in the `transaction.set(pay_ref, {...})`. Replace it with:
```python
                "proof": {"screenshotCount": 0, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []},
                "outcome": None, "access": {"state": "none", "until": None},
```
Also in `functions/tests/payments_helpers.py` (WO-10a2), in `make_payment`, replace `"proof": None, "outcome": None,` with `"proof": {"screenshotCount": 0, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []}, "outcome": None,`.
3. File `functions/payments/engine.py`. Append at the end:
```python
def notify_moves(notify, payment: dict, moves: list) -> None:
    """Pushes for each (from, to) a call made (states.notices_for). `payment`
    names the two parties. Never raises into the caller's answer."""
    for frm, to in moves:
        for who, kind in states.notices_for(frm, to):
            uid = payment["clientUid"] if who == states.CLIENT else payment["coachUid"]
            try:
                notify(uid, kind)
            except Exception:  # noqa: BLE001
                pass
```
4. File `functions/payments/coach.py`, create:
```python
"""The coach's confirmation, shared with the automatic confirmation of a GREEN proof."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from google.cloud import firestore

from coaching import common

from . import activation, engine, errors, fees, model, profile, states


def can_grant(seen: dict) -> bool:
    return (seen["sub"] or {}).get("status") in ("awaiting_payment", "active")


def apply_confirmation(transaction, db, ref, cur: dict, seen: dict, prof_ref, prof: dict, cfg: dict,
                       now: dt.datetime, role: str, actor_uid: Optional[str], received: Optional[int]) -> dict:
    """proof_submitted -> confirmed, full access, fee owed (if not already),
    the coach's counters. All reads were done by the caller. Returns the payment."""
    rel_source = (seen["rel"].to_dict() or {}).get("source") if seen["rel"].exists else None
    got = received if received is not None else cur["amountPiasters"]
    changes = {
        "coachDecision": {"confirmedAt": now, "receivedPiasters": got, "autoConfirmed": role == states.SYSTEM},
        "overpaidPiasters": max(0, got - cur["amountPiasters"]),
        "access": {"state": "full", "until": None},
        **fees.at_activation(cur, cfg, rel_source, now),
    }
    out = engine.move(transaction, db, ref, cur, "confirmed", role, actor_uid, now, changes=changes,
                      code="auto_confirmed" if role == states.SYSTEM else "coach_confirmed")
    if can_grant(seen):
        activation.grant(transaction, db, seen, now)
    clean = 1 if (cur.get("outcome") == "green" and not cur.get("dispute")) else 0
    transaction.update(prof_ref, {"paymentsConfirmed": firestore.Increment(1), "cleanConfirmed": firestore.Increment(clean)})
    return out


def confirm(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    received = data.get("receivedPiasters")
    if received is not None:
        received = common.whole(received, low=1, high=10_000_000)
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "confirmed":
            return {"status": "confirmed"}  # a second tap changes nothing
        if received is not None and received < cur["amountPiasters"]:
            raise common.bad()  # a lower amount goes through coach_mark_different_amount
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, uid)
        prof = common.read(prof_ref, transaction) or {}
        held["payment"], held["from"] = cur, cur["status"]
        apply_confirmation(transaction, db, ref, cur, seen, prof_ref, prof, cfg, now, states.COACH, uid, received)
        return {"status": "confirmed"}

    result = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "confirmed")])
    return result
```
5. File `functions/payments/proof.py`, create:
```python
"""submit_instapay_proof (spec 4.2, 13.3, 13.4, 13.9, 13.12)."""

from __future__ import annotations

import datetime as dt
import hashlib
import re
from typing import Optional

from google.cloud import firestore

from coaching import common, dhash

from . import activation, coach, engine, errors, fees, model, profile, receipt_checks, risk, states

LIMITS = model.LIMITS
_HANDLE = re.compile(r"^[a-z0-9._-]{3,40}@[a-z]{3,20}$")
_NOT_ALNUM = re.compile(r"[^A-Z0-9]")
MAX_IMAGES_PER_CALL = 3


def txn_key(txn: str) -> str:
    return _NOT_ALNUM.sub("", txn.upper())


def _check_window(row: dict, now: dt.datetime) -> None:
    if row.get("status") not in ("awaiting_payment", "expired"):
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    late = common.as_utc(row.get("lateUntil"))
    if late is None or now > late:
        raise common.refuse(errors.PRECONDITION, errors.PROOF_WINDOW_CLOSED)


def submit(db, uid: str, data: dict, images: list, *, now: dt.datetime, blobs, reencode, reader, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    key = engine.idem_key(data.get("idempotencyKey"))
    amount = common.whole(data.get("amountPiasters"), low=1, high=10_000_000)
    typed = data.get("txnNumber")
    if typed is not None:
        typed = common.text(typed, max_len=40)
        if len(txn_key(typed)) < 6:
            raise common.bad()
    sender = data.get("senderHandle")
    if sender is not None:
        sender = common.text(sender, max_len=60).lower()
        if not _HANDLE.match(sender):
            raise common.bad()
    reading = data.get("phoneReading")
    phone = reading if isinstance(reading, dict) and len(str(reading)) <= 2000 else None  # a hint for staff, never trusted
    claimed = common.optional_text(data.get("paidAtClaimed"), max_len=40) or None  # only a claim: the server clock decides
    if not isinstance(images, list) or not (1 <= len(images) <= MAX_IMAGES_PER_CALL):
        raise common.bad()

    snap = engine.payment_ref(db, payment_id).get()
    row = snap.to_dict() if snap.exists else None
    if row is None or row.get("clientUid") != uid:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    done = db.collection("paymentIdempotency").document(f"{uid}__proof__{key}").get()
    if done.exists:
        return (done.to_dict() or {}).get("result")
    _check_window(row, now)
    if amount != row["amountPiasters"]:
        raise common.refuse(errors.INVALID, errors.AMOUNT_MISMATCH)
    prior = row.get("proof") or {}
    if prior.get("screenshotCount", 0) + len(images) > LIMITS["screenshotsPerPayment"]:
        raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
    standing_snap = profile.standing_ref(db, uid).get()
    standing = standing_snap.to_dict() if standing_snap.exists else {}
    if profile.client_suspended(standing):
        raise common.refuse(errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)

    # --- the pictures: gate, re-encode (strips metadata), hash, read
    flags, texts, shas, dhashes, jpegs = [], [], [], [], []
    for raw in images:
        flags += receipt_checks.sanity(raw)
        try:
            jpeg = reencode(bytes(raw), long_side=LIMITS["screenshotLongSidePx"])
            sha, shape = hashlib.sha256(jpeg).hexdigest(), dhash.dhash(jpeg)
        except Exception:
            raise common.refuse(errors.INVALID, errors.IMAGE_INVALID) from None
        jpegs.append(jpeg)
        shas.append(sha)
        dhashes.append(dhash.to_text(shape))
        texts.append(reader.read(jpeg) or "")
    flags = sorted(set(flags))

    # --- the checks
    snapshot = row["addressSnapshot"]
    saved_sender = sender or standing.get("senderHandle")
    checks = receipt_checks.run_checks(
        texts, expected_piasters=row["amountPiasters"], address=snapshot["address"],
        created_at=common.as_utc(row["createdAt"]), now=now, sender_handle=saved_sender, typed_txn=typed,
    )
    uniq = {"txnReusedBy": None, "sameImageOf": None, "nearImageOf": None}
    tkey = txn_key(checks["txn"]) if checks["txn"] else None
    if tkey:
        owner = db.collection("paymentTxnNumbers").document(tkey).get()
        if owner.exists and (owner.to_dict() or {}).get("paymentId") != payment_id:
            uniq["txnReusedBy"] = owner.to_dict()["paymentId"]
    new_shas = []
    for sha in shas:
        owner = db.collection("paymentImageHashes").document(sha).get()
        if owner.exists and (owner.to_dict() or {}).get("paymentId") != payment_id:
            uniq["sameImageOf"] = owner.to_dict()["paymentId"]
        elif not owner.exists:
            new_shas.append(sha)
    recent = db.collection("paymentImageHashes").order_by("createdAt", direction=firestore.Query.DESCENDING).limit(common.LIMITS["nearImageWindow"])
    for other in recent.stream():
        body_ = other.to_dict() or {}
        if body_.get("paymentId") == payment_id or not body_.get("dHash"):
            continue
        if any(dhash.hamming(dhash.from_text(h), dhash.from_text(body_["dHash"])) <= common.LIMITS["nearImageHamming"] for h in dhashes):
            uniq["nearImageOf"] = body_["paymentId"]
            break

    allow_other = bool(data.get("otherPayerOk") is True and not standing.get("otherPayerCount", 0))
    out = risk.decide(checks, uniq, flags, retry_used=prior.get("amberAttempts", 0) >= 1, other_payer_ok=allow_other)

    # --- an AMBER with a retry left records only the attempt
    if out.colour == risk.AMBER and out.retry_offered:
        wrong_only = out.reasons == ["wrongMessage"]

        def attempt(transaction):
            again = engine.replay(transaction, db, uid, "proof", key)
            if again is not None:
                return again
            ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
            _check_window(cur, now)
            transaction.update(ref, {
                "proof.screenshotCount": firestore.Increment(len(images)),
                "proof.amberAttempts": firestore.Increment(0 if wrong_only else 1),
            })
            result = {"paymentId": payment_id, "status": cur["status"], "outcome": "amber", "reasons": out.reasons, "retry": True}
            engine.remember(transaction, db, uid, "proof", key, result, now)
            return result

        return common.run(db, attempt)

    # --- commit: files first, rolled back if the transaction fails
    start = prior.get("screenshotCount", 0)
    paths = [f"payment-proofs/{payment_id}/client-{start + i + 1}.jpg" for i in range(len(jpegs))]
    for path, jpeg in zip(paths, jpegs):
        blobs.write(path, jpeg, "image/jpeg")
    cfg = model.config(db)
    held = {"moves": []}

    def body(transaction):
        again = engine.replay(transaction, db, uid, "proof", key)
        if again is not None:
            return again
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        _check_window(cur, now)
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, cur["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        reg_ref = db.collection("paymentTxnNumbers").document(tkey) if tkey else None
        reg = reg_ref.get(transaction=transaction) if reg_ref else None
        outcome, reasons = out.colour, list(out.reasons)
        if reg is not None and reg.exists and (reg.to_dict() or {}).get("paymentId") != payment_id and outcome != risk.RED:
            outcome, reasons = risk.RED, reasons + ["txnReused"]  # someone else claimed it since we looked

        # ----- writes
        for sha, shape in zip(shas, dhashes):
            if sha in new_shas and outcome != risk.RED:
                transaction.set(db.collection("paymentImageHashes").document(sha),
                                {"paymentId": payment_id, "dHash": shape, "createdAt": now})
        if reg_ref is not None and not (reg.exists and (reg.to_dict() or {}).get("paymentId") != payment_id):
            transaction.set(reg_ref, {"paymentId": payment_id, "createdAt": now})
        visible = [f for f, hit in (("sameImage", uniq["sameImageOf"]), ("nearImage", uniq["nearImageOf"]), ("txnReused", "txnReused" in reasons)) if hit]
        transaction.set(
            ref.collection("staff").document("review"),
            {"riskScore": out.score, "flags": flags, "reasons": reasons, "checks": checks, "hashes": shas,
             "dHashes": dhashes, "phoneReading": phone, "updatedAt": now},
            merge=True,
        )
        proof = {
            **(cur.get("proof") or {}), "txnNumber": checks["txn"], "txnKey": tkey,
            "screenshotPaths": list((cur.get("proof") or {}).get("screenshotPaths") or []) + paths,
            "screenshotCount": start + len(paths), "submittedAt": now, "paidAtClaimed": claimed,
            "imageFlags": visible,
            "amberAttempts": (cur.get("proof") or {}).get("amberAttempts", 0) + (1 if outcome == risk.AMBER else 0),
        }
        base = {"proof": proof, "outcome": outcome, "reasons": reasons, "proofSubmittedAt": now}
        pay = engine.move(transaction, db, ref, cur, "proof_submitted", states.CLIENT, uid, now, changes=base, code=f"proof_{outcome}")
        held["payment"], held["moves"] = pay, [(cur["status"], "proof_submitted")]

        if outcome == risk.RED:
            pay = engine.move(
                transaction, db, ref, pay, "in_review", states.SYSTEM, None, now,
                changes={"dispute": {"kind": "proof_red", "openedBy": "system", "openedAt": now, "reasons": reasons}},
                code="proof_red")
            held["moves"].append(("proof_submitted", "in_review"))
        elif outcome == risk.GREEN:
            if prof.get("autoConfirmGreen") is True:
                pay = coach.apply_confirmation(transaction, db, ref, pay, seen, prof_ref, prof, cfg, now,
                                               states.SYSTEM, None, None)
                held["moves"].append(("proof_submitted", "confirmed"))
            else:
                days = min(LIMITS["provisionalMaxDays"], (seen["sub"].get("package") or {}).get("durationDays", 7))
                until = now + model.days(days)
                changes = {"access": {"state": "provisional", "until": until}}
                rel_source = (seen["rel"].to_dict() or {}).get("source") if seen["rel"].exists else None
                changes.update(fees.at_activation(pay, cfg, rel_source, now))
                transaction.update(ref, changes)
                if coach.can_grant(seen):
                    activation.grant(transaction, db, seen, now, provisional_until=until)
        else:
            transaction.update(ref, {"amberUntil": now + model.hours(LIMITS["amberHours"])})
        if allow_other and checks.get("sender") == "different" and outcome == risk.GREEN:
            transaction.set(profile.standing_ref(db, uid), {"otherPayerCount": firestore.Increment(1)}, merge=True)
        if sender and not standing.get("senderHandle"):
            transaction.set(profile.standing_ref(db, uid), {"senderHandle": sender}, merge=True)
        result = {"paymentId": payment_id, "status": "in_review" if outcome == risk.RED else ("confirmed" if held["moves"][-1][1] == "confirmed" else "proof_submitted"),
                  "outcome": outcome, "reasons": reasons, "retry": False}
        engine.remember(transaction, db, uid, "proof", key, result, now)
        return result

    try:
        result = common.run(db, body)
    except BaseException:
        for path in paths:
            blobs.delete(path)
        raise
    if held.get("payment"):
        engine.notify_moves(notify, held["payment"], held["moves"])
    return result
```
(A replayed call has no `held` entries, so it sends no second push. In the green provisional branch `held["moves"]` has one entry, so the coach gets `instapayProofSent` only.)
6. File `functions/main.py`. (i) Anchor: the function `_instapay_on` (WO-10b). After it add:
```python
def _payments_notify(uid: str, kind: str) -> None:
    """One push for a payment event; a failed push never fails the call."""
    try:
        from firebase_admin import messaging

        from payments import notices

        notices.send_kind(uid, kind, db=store.db(), messaging=messaging)
    except Exception:
        logs.error("payments_push_failed")
```
   (ii) After `cancel_payment` add:
```python
@https_fn.on_call()
def submit_instapay_proof(request: https_fn.CallableRequest) -> dict:
    """PAY2: screenshots and the transaction number. Works with the kill switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import ocr, proof

    budget: dict = {}
    raw = data.get("images")
    if not isinstance(raw, list):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR)
    images = [_decode_image(item, budget) for item in raw[: proof.MAX_IMAGES_PER_CALL + 1]]
    return _coaching_call(
        proof.submit, store.db(), uid, data, images,
        now=_coaching_now(), blobs=_PersonalBlobs(), reencode=_reencode, reader=ocr.TextReader(), notify=_payments_notify,
    )


@https_fn.on_call()
def coach_confirm_payment(request: https_fn.CallableRequest) -> dict:
    """PAY4: 'I received it'. Works with the kill switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import coach

    return _coaching_call(
        coach.confirm, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now(), notify=_payments_notify,
    )
```
   (`_decode_image` refuses images above 8 MB before decoding; `proof.submit` then refuses above 5 MB through `receipt_checks.sanity`. A list longer than 3 reaches `submit` as 4 images and is refused there with `bad_request`.)
7. File `functions/tests/test_entrypoints.py`: add `"submit_instapay_proof", "coach_confirm_payment",` after `"create_payment", "cancel_payment",`.
8. File `functions/tests/test_payments_proof.py`, create. Imports: `from tests.test_coaching_subscriptions import make_jpeg` (a real small JPEG), `from tests.fake_blobs import FakeBlobs`, `from payments import coach, proof, risk, errors`, helpers from `payments_helpers`. Fixtures in the file: `class Reader` with `__init__(self, *texts)` and `read(self, jpeg)` returning the next text in order (cycling the last); `keep = lambda raw, long_side=None: raw`; `GREEN_TEXTS = (the INSTAPAY_FIRST and DETAILS strings, copied from WO-10l's test file, with 500.37 matching AMOUNT=50037)`. Helper `send(db, blobs, notes, reader, *, images=None, key="key-0001-abcd", **over)` calls `proof.submit(db, CLIENT, {"paymentId": PAY, "idempotencyKey": key, "amountPiasters": AMOUNT, **over}, images or [make_jpeg(1), make_jpeg(2)], now=NOW + 10 minutes, blobs=blobs, reencode=keep, reader=reader, notify=notes)`. Each test starts with `seed_world(db); make_payment(db)`.
Tests:
| test | arrange, act, assert |
|---|---|
| `test_green_two_screenshots_give_bounded_access_and_tell_the_coach` | reader GREEN_TEXTS; send; outcome `green`, status `proof_submitted`; payment `access.state == "provisional"`, `until == now + 7 days`; subscription `active` with `provisionalUntil`; relationship `active`; `feePiasters == 7500` (15 percent of 50000), `feeState == "owed"`; blobs hold `payment-proofs/pay-1/client-1.jpg` and `client-2.jpg`; `notes.sent == [(COACH, "instapayProofSent")]`; staff review doc has `riskScore`, `hashes`; registries `paymentTxnNumbers/301234567890123` and two `paymentImageHashes` exist; events `[(None,"awaiting_payment","client"), ("awaiting_payment","proof_submitted","client")]` |
| `test_the_first_screen_alone_is_amber_with_one_retry_and_records_only_the_attempt` | reader returns INSTAPAY_FIRST; send with one image; `retry True`, outcome amber, reasons contain `needDetails`; status still `awaiting_payment`; no blob; `proof.amberAttempts == 1`, `screenshotCount == 1`; then send again with another key and reader GREEN_TEXTS -> green |
| `test_a_second_amber_stands_and_waits_for_the_coach_for_24_hours` | after one retry used (`proof.amberAttempts = 1` in make_payment), amber text -> `retry False`, status `proof_submitted`, no access, subscription still `awaiting_payment`, `amberUntil == now + 24h` |
| `test_a_typed_transaction_number_lets_an_amber_stand_at_once` | one image amber text plus `txnNumber="301234567890123"` -> status `proof_submitted` (no retry) |
| `test_wrong_amount_is_red_and_goes_to_review` | text with 450.00 -> `outcome red`, `status in_review`, `dispute.kind == "proof_red"`, no access, notes include `(CLIENT,"instapayReviewStarted")` and `(COACH,"instapayDisputeOpened")`; events end with `("proof_submitted","in_review","system")` |
| `test_a_reused_transaction_number_is_red_and_flagged_for_both` | `paymentTxnNumbers/301234567890123 = {"paymentId":"other"}`; GREEN_TEXTS -> red, `proof.imageFlags` contains `txnReused`; the registry owner is unchanged |
| `test_the_same_picture_for_another_payment_is_red` | `paymentImageHashes/<sha256 of make_jpeg(1)> = {"paymentId":"other","dHash":"0000000000000000"}` -> red `sameImage` |
| `test_a_near_copy_is_red` | registry holds the `dHash` of `make_jpeg(1)` for `other`; the new image is `make_jpeg(1, noise=3)` -> red `nearImage` (UNVERIFIED that noise 3 stays within hamming 6: run the test; if it fails use `noise=1`) |
| `test_a_card_message_gets_a_retry_that_does_not_count` | text CARD_SMS -> `retry True`, `reasons == ["wrongMessage"]`, `proof.amberAttempts == 0`, `screenshotCount == 1` |
| `test_amount_typed_must_equal_the_payment` | `amountPiasters=50000` -> `(INVALID, AMOUNT_MISMATCH)`, nothing written |
| `test_five_screenshots_is_the_most_per_payment` | `proof.screenshotCount = 4`, send 2 images -> `(EXHAUSTED, TOO_MANY_SCREENSHOTS)`; 4 images in one call -> `bad_request` |
| `test_late_proof_within_seven_days_is_accepted_and_after_is_not` | status `expired`, `now = created + 6 days` works; `now = created + 8 days` -> `PROOF_WINDOW_CLOSED`; status `confirmed` -> `WRONG_STATUS` |
| `test_a_double_tap_makes_one_proof` | send twice with the same key: equal answers, blobs written once, one `proof_submitted` event, one push |
| `test_a_failing_transaction_deletes_the_files` | monkeypatch `engine.move` to raise `RuntimeError`; the call raises; `blobs.objects` empty |
| `test_a_suspended_client_cannot_send_proof` | `paymentStanding/CLIENT.clientSuspended` -> `CLIENT_PAYMENTS_SUSPENDED` |
| `test_a_phone_clock_claim_changes_nothing` | `paidAtClaimed="2031-01-01T00:00:00Z"` -> same green result; the stored field is the text only |
| `test_someone_else_paying_is_amber_then_allowed_once` | `senderHandle="mine@instapay"` while the text shows `layla@instapay` and the coach handle -> amber `someoneElsePaid`; with `otherPayerOk=True` -> green and `paymentStanding.otherPayerCount == 1`; a second time with `otherPayerCount` 1 -> amber again |
| `test_auto_confirm_green_confirms_at_once_and_keeps_the_audit` | profile `autoConfirmGreen` True; green -> status `confirmed`, `coachDecision.autoConfirmed`, access `full`, an event with role `system`, push to the client `instapayConfirmed` |
| `test_a_stranger_cannot_send_proof` | other uid -> `PAYMENT_NOT_FOUND` |
Confirm tests (same file):
| test | arrange, act, assert |
|---|---|
| `test_coach_confirms_after_a_green_proof_and_access_becomes_full` | green via send, then `coach.confirm(db, COACH, {"paymentId": PAY}, coach_v="active", now=..., notify=notes)`; status `confirmed`, access `full`, subscription `provisionalUntil` None, coach `activeClients == 1` (not 2), profile `paymentsConfirmed == 1`, `cleanConfirmed == 1`, push `instapayConfirmed` to the client |
| `test_coach_confirms_an_amber_and_the_coaching_starts_then` | amber committed (no access), confirm -> subscription `active` full |
| `test_a_repeat_confirm_changes_nothing` | confirm twice; one `confirmed` event |
| `test_nobody_but_the_payments_coach_can_confirm_and_a_record_is_needed` | other coach -> `PAYMENT_NOT_FOUND`; unknown id -> same; client calling -> same |
| `test_confirm_needs_a_proof` | status `awaiting_payment` -> `(PRECONDITION, ILLEGAL_TRANSITION)`; a coach cannot activate a package without a record |
| `test_a_suspended_coach_cannot_confirm_and_the_client_stays_protected` | `coachPrivate.suspended` -> `COACH_SUSPENDED`; the green provisional access from `send` is untouched |
| `test_received_less_is_refused_here_and_more_is_recorded_as_overpaid` | `receivedPiasters=40000` -> bad_request; `51000` -> `overpaidPiasters == 963` |
| `test_the_invite_fee_tier_is_eight_percent` | relationship `source = "invite"` -> `feePiasters == 4000`, `feeBps == 800` |

## Strings to add
None (codes and pushes are server constants, WO-10a2). Reason codes the app must map from `reasons`: see WO-10l. Refusals: `wrong_status, proof_window_closed, amount_mismatch, too_many_screenshots, image_invalid, client_payments_suspended, illegal_transition, payment_not_found, coach_suspended`.

## Tests to add or change
`functions/tests/test_payments_proof.py` as listed. Command:
`cd functions && venv/bin/python -m pytest tests/test_payments_proof.py tests/test_payments_create.py tests/test_entrypoints.py -q`

## Verify
The command ends with `N passed`, no `failed`. Then the older suites still pass: `venv/bin/python -m pytest tests/test_coaching_proofs.py tests/test_coaching_subscriptions.py -q`.

## Do not
- Do not let a phone-reported time, size, or name decide anything: the server clock and the server's own OCR do.
- Do not store the OCR text, only the `checks` fields.
- Do not read after a write in a transaction. All reads in `body` come first.
- Do not start access on a RED. Do not stop access of a GREEN from a coach's claim (that needs staff, WO-10n).
- Do not log a transaction number, amount or path.

## Done checklist
- [ ] fees, coach, proof created; engine, create, main edited
- [ ] two callables registered and listed in `CALLABLES`
- [ ] all tests pass; older proof tests still pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
