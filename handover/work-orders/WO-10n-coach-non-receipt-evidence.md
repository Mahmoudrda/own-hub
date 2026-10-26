# WO-10n: Coach "not received" with evidence, automatic rejection when her own statement shows the payment, and adding evidence later
Depends on: WO-10b4, WO-10l-server
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.1, 13.1, 13.4 (auto-confirm and the 48 hour flag), 13.5, 13.9, 13.12 item 8; `functions/payments/receipt_checks.py` (`amounts_in`, `amount_check`, `normalise`, `sanity`); `functions/payments/proof.py` (image handling pattern, `txn_key`); `functions/payments/states.py` rows `proof_submitted -> coach_not_received`, `coach_not_received -> in_review`, `confirmed -> in_review` (coach); `functions/payments/coach.py`

## Why
A coach who falsely says she was never paid is the main fraud against the client, and the fee does not depend on her claim (13.1). To make a false claim costly and detectable (13.5): she must tick that she searched her bank for the exact amount and the transaction number, and attach a screenshot of her own bank's transaction list for that day. The server reads it. If the unique amount or the transaction number appears in her own list, her claim is rejected on the spot with "This payment appears in your statement". If the list cannot be read, or shows nothing, both pictures go to staff. Her claim never removes the client's access; only a staff decision does. The same flow lets a coach flag an auto-confirmed payment within 48 hours.

## Final result
Callables (work with the kill switch off):
- `coach_mark_not_received` `{paymentId, reasonCode: "not_seen"|"wrong_amount"|"wrong_name"|"paid_by_someone_else"|"other", note (1 to 500 characters), searched: true, images: [base64] (1 to 3)}`. Answers `{status: "in_review"}`, or refuses with `appears_in_statement` (nothing else changes, the attempt is counted), `evidence_required` (box not ticked or no picture), `illegal_transition`, `payment_not_found`.
- `add_payment_evidence` `{paymentId, images: [base64] (1 to 3), note?}` by either party while the payment is `in_review`, `coach_not_received`, or (for the coach) `proof_submitted` or `confirmed`; this is the client's "Add proof" (PAY6) and the coach's optional bank SMS (13.12 item 8). Answers `{added: n}`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/evidence.py` | create | `statement_checks`, `not_received`, `add_evidence` |
| `functions/main.py` | edit | two callables |
| `functions/tests/test_entrypoints.py` | edit | two names |
| `functions/tests/test_payments_evidence.py` | create | tests |

## Steps
1. File `functions/payments/evidence.py`, create:
```python
"""The coach's side of a disputed payment (spec 4.1, 13.1, 13.4, 13.5)."""

from __future__ import annotations

import datetime as dt
import hashlib
import re

from google.cloud import firestore

from coaching import common

from . import engine, errors, model, profile, proof, receipt_checks, states

LIMITS = model.LIMITS
REASONS = ("not_seen", "wrong_amount", "wrong_name", "paid_by_someone_else", "other")
_ALNUM = re.compile(r"[^A-Z0-9]")


def statement_checks(texts: list, amount_piasters: int, txn: str | None) -> dict:
    """What her own bank list shows. `amountFound`: the exact unique amount is
    on it. `txnFound`: the client's transaction number is on it (compared
    without spaces or dashes). `readable`: at least one amount with two decimals
    could be read, so 'nothing found' means something."""
    amount_found = txn_found = readable = False
    key = proof.txn_key(txn) if txn else ""
    for text in texts or []:
        if not isinstance(text, str):
            continue
        if receipt_checks.amounts_in(text):
            readable = True
        if receipt_checks.amount_check(text, amount_piasters) == "match":
            amount_found = True
        if key and len(key) >= 6 and key in _ALNUM.sub("", receipt_checks.normalise(text).upper()):
            txn_found = True
    return {"readable": readable, "amountFound": amount_found, "txnFound": txn_found}


def _read_images(images, *, blobs_prefix, start, blobs, reencode, reader):
    """Gate, re-encode, hash and read each picture. Returns (jpegs, texts, hashes)."""
    jpegs, texts, hashes = [], [], []
    for raw in images:
        receipt_checks.sanity(raw)
        try:
            jpeg = reencode(bytes(raw), long_side=LIMITS["screenshotLongSidePx"])
        except Exception:
            raise common.refuse(errors.INVALID, errors.IMAGE_INVALID) from None
        jpegs.append(jpeg)
        hashes.append(hashlib.sha256(jpeg).hexdigest())
        texts.append(reader.read(jpeg) or "")
    return jpegs, texts, hashes


def _images_ok(images) -> None:
    if not isinstance(images, list) or not (1 <= len(images) <= 3):
        raise common.bad()


def not_received(db, uid: str, data: dict, images: list, *, coach_v, now: dt.datetime, blobs, reencode, reader, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    reason = common.one_of(data.get("reasonCode"), REASONS)
    note = common.text(data.get("note"), max_len=500, reason=errors.REASON_REQUIRED)
    if data.get("searched") is not True:
        raise common.refuse(errors.INVALID, errors.EVIDENCE_REQUIRED)
    if not isinstance(images, list) or not images:
        raise common.refuse(errors.INVALID, errors.EVIDENCE_REQUIRED)
    _images_ok(images)

    snap = engine.payment_ref(db, payment_id).get()
    row = snap.to_dict() if snap.exists else None
    if row is None or row.get("coachUid") != uid:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    if row["status"] == "in_review" and (row.get("dispute") or {}).get("openedBy") == "coach":
        return {"status": "in_review"}  # a second tap
    auto = (row.get("coachDecision") or {}).get("autoConfirmed") is True
    if row["status"] == "confirmed":
        confirmed = common.as_utc((row.get("coachDecision") or {}).get("confirmedAt"))
        if not auto or confirmed is None or now > confirmed + model.hours(LIMITS["autoConfirmFlagHours"]):
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
    elif row["status"] != "proof_submitted":
        raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)

    start = len((row.get("coachDecision") or {}).get("statementPaths") or [])
    jpegs, texts, _ = _read_images(images, blobs_prefix=None, start=start, blobs=blobs, reencode=reencode, reader=reader)
    checks = statement_checks(texts, row["amountPiasters"], (row.get("proof") or {}).get("txnNumber"))

    if checks["amountFound"] or checks["txnFound"]:
        def reject(transaction):
            ref = engine.payment_ref(db, payment_id)
            transaction.update(profile.profile_ref(db, uid), {"autoRejectedClaims": firestore.Increment(1)})
            transaction.set(ref.collection("events").document(), {
                "at": now, "from": row["status"], "to": row["status"], "role": states.SYSTEM, "actor": states.SYSTEM,
                "code": "claim_rejected_by_statement"})
        common.run(db, reject)
        raise common.refuse(errors.PRECONDITION, errors.CLAIM_CONTRADICTED)

    paths = [f"payment-proofs/{payment_id}/coach-{start + i + 1}.jpg" for i in range(len(jpegs))]
    for path, jpeg in zip(paths, jpegs):
        blobs.write(path, jpeg, "image/jpeg")
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] not in ("proof_submitted", "confirmed"):
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        held["payment"], held["from"] = cur, cur["status"]
        decision = {**(cur.get("coachDecision") or {}), "notReceivedAt": now, "reasonCode": reason,
                    "statementPaths": list((cur.get("coachDecision") or {}).get("statementPaths") or []) + paths}
        dispute = {"kind": "not_received", "openedBy": "coach", "openedAt": now, "reasonCode": reason}
        transaction.set(ref.collection("staff").document("statement"),
                        {**checks, "note": note, "reasonCode": reason, "at": now}, merge=True)
        if cur["status"] == "proof_submitted":
            pay = engine.move(transaction, db, ref, cur, "coach_not_received", states.COACH, uid, now,
                              changes={"coachDecision": decision}, code="coach_not_received")
            engine.move(transaction, db, ref, pay, "in_review", states.SYSTEM, None, now, changes={"dispute": dispute}, code="evidence_attached")
            held["moves"] = [("proof_submitted", "coach_not_received"), ("coach_not_received", "in_review")]
        else:
            engine.move(transaction, db, ref, cur, "in_review", states.COACH, uid, now,
                        changes={"coachDecision": decision, "dispute": dispute}, code="auto_confirmed_flagged")
            held["moves"] = [("confirmed", "in_review")]
        return {"status": "in_review"}  # access is untouched: only a staff decision changes it (13.1)

    try:
        result = common.run(db, body)
    except BaseException:
        for path in paths:
            blobs.delete(path)
        raise
    engine.notify_moves(notify, held["payment"], held["moves"])
    return result


def add_evidence(db, uid: str, data: dict, images: list, *, now: dt.datetime, blobs, reencode, reader) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    note = common.optional_text(data.get("note"), max_len=500)
    _images_ok(images)
    snap = engine.payment_ref(db, payment_id).get()
    row = snap.to_dict() if snap.exists else None
    if row is None or uid not in (row.get("clientUid"), row.get("coachUid")):
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    side = "client" if uid == row["clientUid"] else "coach"
    allowed = ("in_review", "coach_not_received") if side == "client" else ("in_review", "coach_not_received", "proof_submitted", "confirmed")
    if row["status"] not in allowed:
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    key = "screenshotPaths" if side == "client" else "statementPaths"
    holder = row.get("proof") if side == "client" else row.get("coachDecision")
    have = list((holder or {}).get(key) or [])
    if len(have) + len(images) > LIMITS["screenshotsPerPayment"]:
        raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
    jpegs, texts, hashes = _read_images(images, blobs_prefix=None, start=len(have), blobs=blobs, reencode=reencode, reader=reader)
    checks = statement_checks(texts, row["amountPiasters"], (row.get("proof") or {}).get("txnNumber"))
    paths = [f"payment-proofs/{payment_id}/{side}-{len(have) + i + 1}.jpg" for i in range(len(jpegs))]
    for path, jpeg in zip(paths, jpegs):
        blobs.write(path, jpeg, "image/jpeg")

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, side)
        field = "proof.screenshotPaths" if side == "client" else "coachDecision.statementPaths"
        transaction.update(ref, {field: have + paths, "dispute.evidenceAt": now} if cur.get("dispute") else {field: have + paths})
        transaction.set(ref.collection("staff").document("evidence"),
                        {f"{side}{len(have)}": {**checks, "hashes": hashes, "note": note, "at": now}}, merge=True)
        if side == "client":
            transaction.update(ref, {"proof.screenshotCount": firestore.Increment(len(paths))})
        return {"added": len(paths)}

    try:
        return common.run(db, body)
    except BaseException:
        for path in paths:
            blobs.delete(path)
        raise
```
(`_read_images` accepts `blobs_prefix`, `start` and `blobs` for symmetry; they are unused and must stay unused. Do not add logic for them. The `note` of a client or coach goes only to the private `staff/evidence` document.)
2. File `functions/main.py`. After the payment callables add:
```python
@https_fn.on_call()
def coach_mark_not_received(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import evidence, ocr

    budget: dict = {}
    raw = data.get("images")
    if not isinstance(raw, list):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR)
    images = [_decode_image(item, budget) for item in raw[:4]]
    return _coaching_call(
        evidence.not_received, store.db(), uid, data, images, coach_v=_claim(request, "coachV"), now=_coaching_now(),
        blobs=_PersonalBlobs(), reencode=_reencode, reader=ocr.TextReader(), notify=_payments_notify,
    )


@https_fn.on_call()
def add_payment_evidence(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import evidence, ocr

    budget: dict = {}
    raw = data.get("images")
    if not isinstance(raw, list):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR)
    images = [_decode_image(item, budget) for item in raw[:4]]
    return _coaching_call(
        evidence.add_evidence, store.db(), uid, data, images, now=_coaching_now(),
        blobs=_PersonalBlobs(), reencode=_reencode, reader=ocr.TextReader(),
    )
```
3. File `functions/tests/test_entrypoints.py`: add `"coach_mark_not_received", "add_payment_evidence",` to `CALLABLES`.
4. File `functions/tests/test_payments_evidence.py`, create. Helpers: `Reader(*texts)` and `keep` as in `test_payments_proof.py` (copy the three lines, do not import from a test module); a call helper `claim(db, blobs, notes, reader, **over)` = `evidence.not_received(db, COACH, {"paymentId": PAY, "reasonCode": "not_seen", "note": "I looked at my bank", "searched": True, **over}, [make_jpeg(5)], coach_v="active", now=NOW + 1 hour, blobs=blobs, reencode=keep, reader=reader, notify=notes)`. The payment in most tests is `make_payment(db, status="proof_submitted", proof={..., "txnNumber": "301234567890123"}, outcome="green", access={"state": "provisional", "until": later(days=7)}, feeState="owed", feeOwedAt=NOW)` and the subscription is made `active` with `provisionalUntil`.
| test | arrange, act, assert |
|---|---|
| `test_statement_checks_find_the_amount_or_the_number_or_neither` | pure: text `"10/11 500.37 EGP in"` -> `amountFound True, readable True`; text with `3012 3456 7890 123` -> `txnFound True`; text `"balance 120.00"` -> `readable True`, both False; text `""` and `None` -> all False; number written with Arabic digits found |
| `test_a_statement_that_shows_the_amount_rejects_the_claim_and_changes_nothing_but_the_count` | Reader returns `"Credit 500.37 EGP"`; the call raises `(PRECONDITION, CLAIM_CONTRADICTED)`; payment status still `proof_submitted`; subscription still active; no blob; profile `autoRejectedClaims == 1`; one event `claim_rejected_by_statement`; no push |
| `test_a_statement_that_shows_the_transaction_number_rejects_the_claim` | Reader returns `"Ref 301234567890123"` -> same refusal |
| `test_a_readable_statement_without_the_payment_goes_to_staff_with_both_pictures` | Reader returns `"Credit 120.00 EGP"` -> `in_review`; events `proof_submitted->coach_not_received (coach)` then `coach_not_received->in_review (system)`; `coachDecision.reasonCode == "not_seen"`, `statementPaths == ["payment-proofs/pay-1/coach-1.jpg"]`; `dispute.kind == "not_received"`; `staff/statement` holds `readable True` and the note; pushes `instapayNotReceived`, `instapayReviewStarted` to the client |
| `test_an_unreadable_statement_goes_to_staff_marked_unreadable` | Reader returns `""` -> `in_review`, `staff/statement.readable False` |
| `test_the_claim_does_not_remove_the_clients_access_or_the_fee` | after a successful claim: subscription still `active` with `provisionalUntil`, payment `access.state == "provisional"`, `feeState == "disputed"`, `feePiasters` unchanged |
| `test_the_claim_needs_the_tick_the_picture_and_a_note` | `searched=False` -> `(INVALID, EVIDENCE_REQUIRED)`; no images -> same; `note=""` -> `(INVALID, REASON_REQUIRED)`; 4 images -> `bad_request`; unknown reason -> `bad_request` |
| `test_a_double_tap_is_harmless` | claim twice -> same answer, one `coach_not_received` event |
| `test_only_this_payments_coach_and_only_from_proof_submitted` | other coach -> `PAYMENT_NOT_FOUND`; status `awaiting_payment` -> `ILLEGAL_TRANSITION`; status `different_amount` -> same |
| `test_a_suspended_coach_cannot_open_claims` | `coachPrivate.suspended` -> `COACH_SUSPENDED` |
| `test_a_coach_can_flag_an_auto_confirmed_payment_within_48_hours_only` | status `confirmed`, `coachDecision {autoConfirmed True, confirmedAt NOW}`; at NOW+47h works (`confirmed->in_review`, role coach); at NOW+49h -> `ILLEGAL_TRANSITION`; a manually confirmed payment -> `ILLEGAL_TRANSITION` (confirmation is final unless staff reopen) |
| `test_a_failed_write_deletes_the_pictures` | monkeypatch `engine.move` to raise -> blobs empty |
| `test_client_adds_proof_while_in_review_and_the_coach_adds_a_bank_sms` | status `in_review`; `add_evidence` by the client with one image -> `{"added": 1}`, `proof.screenshotPaths` grows with `client-N.jpg`, `screenshotCount` +1, `staff/evidence` written; by the coach -> `coach-N.jpg` in `coachDecision.statementPaths` |
| `test_add_evidence_limits_and_roles` | status `confirmed` for the client -> `WRONG_STATUS`; five already + one more -> `TOO_MANY_SCREENSHOTS`; stranger -> `PAYMENT_NOT_FOUND`; zero images -> `bad_request` |
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_evidence.py tests/test_entrypoints.py tests/test_payments_proof.py -q`

## Strings to add
None. Codes the app maps: `appears_in_statement` (EN "This payment appears in your statement. Please check again and confirm it." AR "الدفع ده ظاهر في كشف حسابك. راجعي تاني وأكدي استلامه."), `evidence_required`, `reason_required`.

## Tests to add or change
As above.

## Verify
The command ends with `N passed`, no `failed`.

## Do not
- Do not let a coach's claim end or pause the client's access, or cancel the fee. Only a staff decision (WO-10b4) does.
- Do not store the OCR text of her bank list; only the three booleans.
- Do not accept a claim without the tick, a picture and a note.
- Do not give the coach's note to the client; it is in `staff/statement` only.

## Done checklist
- [ ] evidence.py created, main edited, names listed
- [ ] all tests pass
- [ ] the "access unchanged" test passes

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
