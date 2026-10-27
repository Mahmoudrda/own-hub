"""The coach's side of a disputed payment, and adding evidence later (spec 4.1, 13.1, 13.4, 13.5)."""

from __future__ import annotations

import datetime as dt
import hashlib
import re
import uuid

from google.cloud import firestore

from coaching import common

from . import engine, errors, model, profile, proof, receipt_checks, states

LIMITS = model.LIMITS
REASONS = ("not_seen", "wrong_amount", "wrong_name", "paid_by_someone_else", "other")
_ALNUM = re.compile(r"[^A-Z0-9]")
MAX_IMAGES = 3


def statement_checks(texts: list, amount_piasters: int, txn) -> dict:
    """What her own bank list shows. `amountFound`: the exact unique amount is
    on it (anywhere on a line; a list line carries a date and a direction).
    `txnFound`: the client's transaction number is on it (spaces and dashes
    ignored). `readable`: at least one amount with two decimals could be read,
    so 'nothing found' means something. Only these three booleans are kept."""
    amount_found = txn_found = readable = False
    key = proof.txn_key(txn) if isinstance(txn, str) and txn else ""
    for text in texts or []:
        if not isinstance(text, str):
            continue
        found = receipt_checks.amounts_in(text)
        readable = readable or bool(found)
        amount_found = amount_found or any(value == amount_piasters for value, _, _ in found)
        if len(key) >= 6 and key in _ALNUM.sub("", receipt_checks.normalise(text).upper()):
            txn_found = True
    return {"readable": readable, "amountFound": amount_found, "txnFound": txn_found}


def _read_images(images, *, reencode, reader):
    """Gate, re-encode (strips metadata), hash and read each picture: (jpegs, texts, hashes)."""
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
    if not isinstance(images, list) or not (1 <= len(images) <= MAX_IMAGES):
        raise common.bad()


def _names(payment_id: str, side: str, count: int) -> list:
    token = uuid.uuid4().hex[:12]  # unique to this call: a losing call deletes only its own files (M10)
    return [f"payment-proofs/{payment_id}/{side}-{token}-{i + 1}.jpg" for i in range(count)]


def not_received(db, uid: str, data: dict, images: list, *, coach_v, now: dt.datetime, blobs, reencode, reader, notify) -> dict:
    """She says she was not paid. She ticks that she searched her bank for the
    exact amount and number and attaches her own list for the day. If her list
    shows the payment, the claim is refused on the spot; otherwise both pictures
    go to staff. The claim never ends the client's access or cancels the fee:
    only a staff decision does (13.1)."""
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
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)  # a confirmation is final unless staff reopen
    elif row["status"] != "proof_submitted":
        raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)

    jpegs, texts, _ = _read_images(images, reencode=reencode, reader=reader)
    checks = statement_checks(texts, row["amountPiasters"], (row.get("proof") or {}).get("txnNumber"))

    if checks["amountFound"] or checks["txnFound"]:
        def reject(transaction):
            ref = engine.payment_ref(db, payment_id)
            transaction.set(profile.profile_ref(db, uid), {"autoRejectedClaims": firestore.Increment(1)}, merge=True)
            transaction.set(ref.collection("events").document(), {
                "at": now, "from": row["status"], "to": row["status"], "role": states.SYSTEM, "actor": states.SYSTEM,
                "code": "claim_rejected_by_statement"})

        common.run(db, reject)
        raise common.refuse(errors.PRECONDITION, errors.CLAIM_CONTRADICTED)

    paths = _names(payment_id, "coach", len(jpegs))
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
        return {"status": "in_review"}

    try:
        result = common.run(db, body)
    except BaseException:
        for path in paths:
            blobs.delete(path)
        raise
    engine.notify_moves(notify, held["payment"], held["moves"])
    return result


def add_evidence(db, uid: str, data: dict, images: list, *, now: dt.datetime, blobs, reencode, reader) -> dict:
    """The client's 'Add proof' after a dispute (PAY6) or the coach's optional
    bank SMS. The note goes only to the private staff/evidence document."""
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
    jpegs, texts, hashes = _read_images(images, reencode=reencode, reader=reader)
    checks = statement_checks(texts, row["amountPiasters"], (row.get("proof") or {}).get("txnNumber"))
    paths = _names(payment_id, side, len(jpegs))
    for path, jpeg in zip(paths, jpegs):
        blobs.write(path, jpeg, "image/jpeg")

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, side)
        if cur["status"] not in allowed:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        key = "screenshotPaths" if side == "client" else "statementPaths"
        holder = cur.get("proof") if side == "client" else cur.get("coachDecision")
        have = list((holder or {}).get(key) or [])
        counted = (cur.get("proof") or {}).get("screenshotCount", len(have)) if side == "client" else len(have)
        if counted + len(paths) > LIMITS["screenshotsPerPayment"]:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
        # Whole maps: coachDecision is null until the coach acts, and a path through null is not a write we rely on.
        if side == "client":
            changes = {"proof": {**(cur.get("proof") or {}), "screenshotPaths": have + paths, "screenshotCount": counted + len(paths)}}
        else:
            changes = {"coachDecision": {**(cur.get("coachDecision") or {}), "statementPaths": have + paths}}
        if cur.get("dispute"):
            changes["dispute"] = {**cur["dispute"], "evidenceAt": now}
        transaction.update(ref, changes)
        transaction.set(ref.collection("staff").document("evidence"),
                        {f"{side}_{uuid.uuid4().hex[:8]}": {**checks, "hashes": hashes, "note": note, "at": now}}, merge=True)
        return {"added": len(paths)}

    try:
        return common.run(db, body)
    except BaseException:
        for path in paths:
            blobs.delete(path)
        raise
