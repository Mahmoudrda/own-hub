"""The payment screenshot: sent by the client, checked by staff.

She sends the transfer details and a screenshot. The picture is decoded and
re-encoded here (no metadata survives), kept in the personal bucket only until
staff decide, then deleted; what stays is its hash and a small difference hash,
so the same picture sent for a second subscription is still caught.

A transfer reference can belong to one subscription only (`paymentRefs`). That
is a refusal, not a flag: a reused reference never reaches staff as a payment.
The flags are what a person should look at twice.

The proof, the references and the receipt are closed to clients; she sees only
her subscription's status and the reason a proof was turned down.
"""

from __future__ import annotations

import datetime as dt
import hashlib

from google.cloud import firestore

from . import common, dhash, errors, receipts, receiving, subscriptions

LIMITS = common.LIMITS
PAGE = 25
_DEAD = ("payment_failed", "expired", "cancelled")


def _check_sub(sub: dict, now: dt.datetime) -> None:
    if sub.get("status") != "awaiting_payment":
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    pay_by = common.as_utc(sub.get("payBy"))
    if pay_by is None or now > pay_by:
        raise common.refuse(errors.PRECONDITION, errors.PAST_PAY_BY)
    if (sub.get("payment") or {}).get("attempts", 0) >= LIMITS["proofAttempts"]:
        raise common.refuse(errors.PRECONDITION, errors.ATTEMPTS_EXHAUSTED)


def submit(
    db,
    uid: str,
    data: dict,
    image: bytes,
    *,
    live: bool,
    now: dt.datetime,
    blobs,
    reencode,
) -> dict:
    common.require_payments_live(live)
    sub_id = common.text(data.get("subId"), max_len=128)
    rail = common.one_of(data.get("rail"), common.RAILS)
    reference = data.get("reference")
    if not common.reference_ok(rail, reference):
        raise common.bad()
    amount = common.whole(data.get("amountEgp"), low=1, high=100000)
    paid_at = common.parse_day(data.get("paidAt"))
    sender = common.text(data.get("senderName"), min_len=2, max_len=80)
    locale = subscriptions.locale_of(data.get("locale"))

    sub_ref = db.collection("subscriptions").document(sub_id)
    snap = sub_ref.get()
    sub = snap.to_dict() if snap.exists else None
    if sub is None or sub.get("clientUid") != uid:
        raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
    _check_sub(sub, now)
    if not isinstance((sub.get("payTo") or {}).get(rail), dict):
        raise common.bad()
    accepted = common.as_utc(sub.get("acceptedAt")) or now
    accepted_day = common.cairo_day(accepted)
    if not (accepted_day - dt.timedelta(days=1) <= paid_at <= common.cairo_day(now)):
        raise common.bad()

    if not isinstance(image, (bytes, bytearray)) or not image or len(image) > LIMITS["proofMaxBytes"]:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID)
    try:
        jpeg = reencode(bytes(image), long_side=LIMITS["proofLongSidePx"])
        digest = hashlib.sha256(jpeg).hexdigest()
        shape = dhash.dhash(jpeg)
    except Exception:
        raise common.refuse(errors.INVALID, errors.IMAGE_INVALID) from None

    proofs = db.collection("paymentProofs")
    flags = []
    if any((row.to_dict() or {}).get("subId") != sub_id for row in proofs.where("sha256", "==", digest).stream()):
        flags.append("sameImage")
    recent = proofs.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(LIMITS["nearImageWindow"])
    for row in recent.stream():
        other = row.to_dict() or {}
        if other.get("subId") == sub_id or not other.get("dHash"):
            continue
        if dhash.hamming(shape, dhash.from_text(other["dHash"])) <= LIMITS["nearImageHamming"]:
            flags.append("nearImage")
            break
    price = sub["priceFinalEgp"]
    if amount != price:
        flags.append("amountDiffers")
    if paid_at < accepted_day:
        flags.append("paidBeforeAccept")

    proof_ref = proofs.document()
    path = f"payment-proofs/{uid}/{proof_ref.id}.jpg"
    ref_ref = db.collection("paymentRefs").document(f"{rail}_{common.normalise_reference(reference)}")
    consent_ref = common.consent_ref(db, uid, "payment-proof-v1")
    blobs.write(path, jpeg, "image/jpeg")

    def body(transaction):
        row = common.read(sub_ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, errors.REQUEST_NOT_FOUND)
        _check_sub(row, now)
        used = ref_ref.get(transaction=transaction)
        seen = consent_ref.get(transaction=transaction)
        owner = (used.to_dict() or {}).get("subId") if used.exists else None
        if owner is not None and owner != sub_id:
            # Her own earlier attempt that came to nothing may be reused.
            old = db.collection("subscriptions").document(owner).get(transaction=transaction)
            old_row = old.to_dict() if old.exists else None
            if old_row is None or not (
                old_row.get("clientUid") == uid and old_row.get("status") in _DEAD
            ):
                raise common.refuse(errors.PRECONDITION, errors.REFERENCE_USED)
            if "duplicateReference" not in flags:
                # Allowed, but staff see that the same transfer was sent before.
                flags.append("duplicateReference")

        transaction.set(ref_ref, {"subId": sub_id, "proofId": proof_ref.id, "createdAt": now})
        transaction.set(
            proof_ref,
            {
                "subId": sub_id,
                "clientUid": uid,
                "coachUid": row["coachUid"],
                "rail": rail,
                "reference": reference,
                "amountEgp": amount,
                "expectedEgp": row["priceFinalEgp"],
                "paidAt": paid_at.isoformat(),
                "senderName": sender,
                "imagePath": path,
                "sha256": digest,
                "dHash": dhash.to_text(shape),
                "flags": flags,
                "status": "pending",
                "reason": None,
                "createdAt": now,
                "decidedBy": None,
                "decidedAt": None,
            },
        )
        attempts = (row.get("payment") or {}).get("attempts", 0)
        transaction.update(
            sub_ref,
            {
                "status": "payment_review",
                "payment": {"state": "review", "attempts": attempts, "lastReason": None, "proofId": proof_ref.id},
                "statusAt": now,
            },
        )
        common.record_consent(transaction, consent_ref, seen, locale, now)

    try:
        common.run(db, body)
    except BaseException:
        blobs.delete(path)
        raise
    return {"status": "payment_review", "proofId": proof_ref.id}


def list_for_staff(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    status = data.get("status", "pending")
    common.one_of(status, common.ENUMS["proofStatus"])
    after = data.get("after")
    if after is not None:
        after = common.text(after, max_len=128)
    common.log_access(db, actor_uid, "proofs.list", "paymentProofs", now)

    proofs = db.collection("paymentProofs")
    query = proofs.where("status", "==", status).order_by("createdAt")
    rows = []
    if after is None:
        rows = list(query.limit(PAGE + 1).stream())
    else:
        marker = proofs.document(after).get()
        if marker.exists:
            # The cursor is the document itself, so equal times page cleanly.
            rows = list(query.start_after(marker).limit(PAGE + 1).stream())
    more = len(rows) > PAGE
    rows = rows[:PAGE]

    coaches: dict = {}
    items = []
    for row in rows:
        proof = row.to_dict() or {}
        sub = db.collection("subscriptions").document(proof.get("subId", "-")).get()
        sub_row = sub.to_dict() if sub.exists else {}
        coach_uid = proof.get("coachUid")
        if coach_uid not in coaches:
            coach = db.collection("coaches").document(coach_uid or "-").get()
            coaches[coach_uid] = (coach.to_dict() or {}).get("displayName", "") if coach.exists else ""
        items.append(
            {
                **common.plain(proof),
                "proofId": row.id,
                "coachName": coaches[coach_uid],
                "packageTitle": (sub_row.get("package") or {}).get("title", ""),
                "paymentCode": sub_row.get("paymentCode"),
            }
        )
    return {"items": items, "next": rows[-1].id if more and rows else None}


def decide(db, actor_uid: str, data: dict, *, now: dt.datetime, blobs, notify) -> dict:
    proof_id = common.text(data.get("proofId"), max_len=128)
    decision = common.one_of(data.get("decision"), common.ENUMS["proofDecision"])
    reason = None
    if decision == "reject":
        reason = common.one_of(data.get("reason"), common.ENUMS["proofRejectReasons"])
    common.log_access(db, actor_uid, f"proofs.{decision}", proof_id, now)

    proof_ref = db.collection("paymentProofs").document(proof_id)
    seen = {}

    def body(transaction):
        proof = common.read(proof_ref, transaction)
        if proof is None:
            raise common.refuse(errors.NOT_FOUND, errors.PROOF_NOT_FOUND)
        if proof.get("status") != "pending":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        sub_id = proof["subId"]
        sub_ref = db.collection("subscriptions").document(sub_id)
        sub = common.read(sub_ref, transaction)
        if (
            sub is None
            or sub.get("status") != "payment_review"
            or (sub.get("payment") or {}).get("proofId") != proof_id
        ):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        common.refuse_if_subject(actor_uid, sub.get("clientUid"), sub.get("coachUid"))
        seen.update(client=sub["clientUid"], coach=sub["coachUid"], image=proof.get("imagePath"))
        decided = common.decided_stamp(actor_uid, now)
        if seen["image"]:
            decided["imageDeletePending"] = True
        payment = dict(sub.get("payment") or {})

        if decision == "reject":
            attempts = payment.get("attempts", 0) + 1
            failed = attempts >= LIMITS["proofAttempts"]
            transaction.update(proof_ref, {"status": "rejected", "reason": reason, **decided})
            changes = {
                "payment": {"state": "rejected", "attempts": attempts, "lastReason": reason, "proofId": None},
                "statusAt": now,
            }
            if failed:
                changes["status"] = "payment_failed"
            else:
                changes["status"] = "awaiting_payment"
                changes["payBy"] = now + common.hours(LIMITS["payByHours"])
            transaction.update(sub_ref, changes)
            return "rejected"

        coach_uid = sub["coachUid"]
        coach_ref = db.collection("coaches").document(coach_uid)
        coach = coach_ref.get(transaction=transaction)
        rel_ref = db.collection("relationships").document(sub["relId"])
        rel = rel_ref.get(transaction=transaction)
        terms = sub_ref.collection("private").document("terms").get(transaction=transaction)
        seller = receiving.seller_ref(db).get(transaction=transaction)
        if not seller.exists:
            raise common.refuse(errors.PRECONDITION, errors.SELLER_NOT_SET)
        coach_private = db.collection("coachPrivate").document(coach_uid).get(transaction=transaction)
        if coach_private.exists and (coach_private.to_dict() or {}).get("suspended"):
            # She paid, but the coach was suspended since: staff reject or
            # refund rather than start a programme nobody can deliver.
            raise common.refuse(errors.PRECONDITION, errors.COACH_SUSPENDED)
        if not terms.exists:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        coach_row = coach.to_dict() if coach.exists else {}
        receipts.issue(transaction, db, sub_id, sub, seller.to_dict(), coach_row.get("displayName", ""), now=now)

        first_time = not rel.exists or (rel.to_dict() or {}).get("status", "none") == "none"
        package = sub.get("package") or {}
        transaction.update(proof_ref, {"status": "approved", **decided})
        transaction.update(
            sub_ref,
            {
                "status": "active",
                "startsAt": now,
                "endsAt": now + common.days(package["durationDays"]),
                "payment": {**payment, "state": "approved"},
                "statusAt": now,
            },
        )
        relation = {"status": "active", "chatOpen": True, "activeSubId": sub_id}
        if not rel.exists:
            relation.update(coachUid=coach_uid, clientUid=sub["clientUid"], createdAt=now)
        transaction.set(rel_ref, relation, merge=True)
        if coach.exists:
            counters = {"activeClients": firestore.Increment(1)}
            if first_time:
                counters["stats.clientsCoached"] = firestore.Increment(1)
            transaction.update(coach_ref, counters)
        transaction.set(
            db.collection("coachPrivate").document(coach_uid).collection("ledger").document(sub_id),
            {
                "subId": sub_id,
                "clientLabel": f"#{sub_id[-4:]}",
                "packageTitle": package.get("title"),
                "coachAmountEgp": terms.to_dict()["coachPriceEgp"],
                "status": "pending",
                "eligibleAt": now + common.days(LIMITS["payoutEligibleDays"]),
                "createdAt": now,
            },
        )
        subscriptions.system_message(transaction, db, sub["relId"], "started", now)
        return "approved"

    status = common.run(db, body)
    if seen.get("image"):
        common.drop_proof_image(proof_ref, seen["image"], blobs)
    if status == "approved":
        notify(seen["client"], "paymentApproved")
        notify(seen["coach"], "coachingStarted")
    else:
        notify(seen["client"], "paymentRejected")
    return {"status": status}
