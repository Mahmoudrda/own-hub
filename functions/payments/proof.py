"""submit_instapay_proof (spec 4.2, 13.3, 13.4, 13.9, 13.12)."""

from __future__ import annotations

import datetime as dt
import hashlib
import re
import uuid
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
    flags, texts, shas, dhashes, jpegs, screens = [], [], [], [], [], []
    for raw in images:
        flags += receipt_checks.sanity(raw)
        screens.append(receipt_checks.screen_like(raw))
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
        reference=row.get("reference"), screenshot=all(screens),
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
        if any(dhash.hamming(dhash.from_text(h), dhash.from_text(body_["dHash"])) <= LIMITS["nearImageHamming"] for h in dhashes):
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
            if (cur.get("proof") or {}).get("screenshotCount", 0) + len(images) > LIMITS["screenshotsPerPayment"]:
                raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
            transaction.update(ref, {
                "proof.screenshotCount": firestore.Increment(len(images)),
                "proof.amberAttempts": firestore.Increment(0 if wrong_only else 1),
            })
            result = {"paymentId": payment_id, "status": cur["status"], "outcome": "amber", "reasons": out.reasons, "retry": True}
            engine.remember(transaction, db, uid, "proof", key, result, now)
            return result

        return common.run(db, attempt)

    # --- commit: files first, rolled back if the transaction fails
    token = uuid.uuid4().hex[:12]  # names unique to this call: a losing call can only ever delete its own files (M10)
    paths = [f"payment-proofs/{payment_id}/client-{token}-{i + 1}.jpg" for i in range(len(jpegs))]
    for path, jpeg in zip(paths, jpegs):
        blobs.write(path, jpeg, "image/jpeg")
    cfg = model.config(db)
    held = {"moves": [], "wrote": False}

    def body(transaction):
        held["wrote"] = False
        again = engine.replay(transaction, db, uid, "proof", key)
        if again is not None:
            return again
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        _check_window(cur, now)
        before = (cur.get("proof") or {}).get("screenshotCount", 0)  # counted inside the transaction, never from the early read
        if before + len(paths) > LIMITS["screenshotsPerPayment"]:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_SCREENSHOTS)
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
            "screenshotCount": before + len(paths), "submittedAt": now, "paidAtClaimed": claimed,
            "imageFlags": visible,
            "amberAttempts": (cur.get("proof") or {}).get("amberAttempts", 0) + (1 if outcome == risk.AMBER else 0),
        }
        # The detailed reasons stay in staff/review; the payment keeps the colour and one hint for her next step.
        base = {"proof": proof, "outcome": outcome, "hint": reasons[0] if reasons else None, "proofSubmittedAt": now}
        pay = engine.move(transaction, db, ref, cur, "proof_submitted", states.CLIENT, uid, now, changes=base, code=f"proof_{outcome}")
        held["payment"], held["moves"] = pay, [(cur["status"], "proof_submitted")]

        if outcome == risk.RED:
            pay = engine.move(
                transaction, db, ref, pay, "in_review", states.SYSTEM, None, now,
                changes={"dispute": {"kind": "proof_red", "openedBy": "system", "openedAt": now}},
                code="proof_red")
            held["moves"].append(("proof_submitted", "in_review"))
        elif outcome == risk.GREEN:
            if prof.get("autoConfirmGreen") is True and cfg["autoConfirmAllowed"]:
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
        held["wrote"] = True
        result = {"paymentId": payment_id, "status": "in_review" if outcome == risk.RED else ("confirmed" if held["moves"][-1][1] == "confirmed" else "proof_submitted"),
                  "outcome": outcome, "reasons": reasons, "retry": False}
        engine.remember(transaction, db, uid, "proof", key, result, now)
        return result

    def drop_files():
        for path in paths:
            blobs.delete(path)

    try:
        result = common.run(db, body)
    except BaseException:
        drop_files()
        raise
    if not held["wrote"]:
        drop_files()  # an earlier call with this key already answered: these files belong to nobody
    if held.get("payment"):
        engine.notify_moves(notify, held["payment"], held["moves"])
    return result
