"""Approvals without a call, pre-approved numbers, test numbers, known contacts.

One internal `approve` serves every route to `approved`: a reviewer's click, a
bulk click, a pre-approved or test phone, a store review account and a known
contact. None of them asks for an ID number, a call, a note or a confirmation.
What stays: a reviewer may never approve herself, a case that carries an ID
hash still claims the registry (so one card cannot verify two accounts), and
every approval is written to the ledger with how and by whom.

Errors are `review.ReviewError`, mapped to HttpsError by main._review_call.
"""

from __future__ import annotations

import datetime as dt
import functools
import os
import re
from typing import Any, Optional

from google.cloud import firestore

from . import config, decisions, reasons, review, store

VIA_PREAPPROVED = "preapproved"
VIA_TEST_PHONE = "testPhone"
VIA_STORE_REVIEWER = "storeReviewer"
VIA_KNOWN_CONTACT = "knownContact"
APPROVE_REASONS = ("approve", "knownPerson")

_EASTERN_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")


# ------------------------------------------------------------------ phones


def normalise_phone(raw: Any) -> Optional[str]:
    """The same rules as the app's egyptianE164, plus any other full
    international number written with a plus or 00. None when it is neither."""
    if not isinstance(raw, str):
        return None
    text = raw.translate(_EASTERN_DIGITS)
    international = text.strip().startswith("+")
    digits = re.sub(r"\D", "", text)
    if digits.startswith("00"):
        digits = digits[2:]
        international = True
    if international and not digits.startswith("20"):
        return f"+{digits}" if re.fullmatch(r"[1-9][0-9]{7,14}", digits) else None
    if digits.startswith("20") and len(digits) > 10:
        digits = digits[2:]
    if digits.startswith("0"):
        digits = digits[1:]
    return f"+20{digits}" if re.fullmatch(r"1[0-9]{9}", digits) else None


def parse_numbers(raw: Any) -> list[str]:
    """Numbers from a comma, semicolon or line separated list; invalid entries
    and repeats dropped, order kept."""
    if not isinstance(raw, str):
        return []
    out: list[str] = []
    for part in re.split(r"[,;\n]+", raw):
        number = normalise_phone(part)
        if number and number not in out:
            out.append(number)
    return out


@functools.lru_cache(maxsize=4)
def _parse_env(raw: str) -> frozenset:
    return frozenset(parse_numbers(raw))


def bypass_phones() -> frozenset:
    """TEST_BYPASS_PHONES, parsed once per value. Unset or empty is nobody."""
    return _parse_env(os.environ.get(config.TEST_BYPASS_ENV, ""))


def reset_env_cache() -> None:
    _parse_env.cache_clear()


# ------------------------------------------------------------------ approve


def _fail(kind: str, reason: str = reasons.INTERNAL_ERROR):
    raise review.ReviewError(kind, reason)


def _uid(value: Any) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 128:
        _fail(review.INVALID)
    return value.strip()


def _ledger_ref(uid: str):
    return store.db().collection(config.COL_LEDGER).document(uid)


def approve(approved_by: str, uid: Any, via: str) -> str:
    """Mint her claim, set her state, close any open flag, drop her booking.

    `approved_by` is the reviewer's uid, or "system" for a phone route. The
    flag is closed first (its registry claim can refuse a duplicate card);
    the mint then retries, and a mint that still fails is left to the hourly
    job exactly as review.decide leaves it."""
    uid = _uid(uid)
    if uid == approved_by:
        _fail(review.PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    rs = store.FirestoreReviewStore()
    flag_id = rs.open_flag_id(uid)
    if flag_id:
        record = rs.get_flag(flag_id) or {}
        refusal = rs.close_flag(
            flag_id,
            uid=uid,
            state=decisions.APPROVED,
            reviewer_uid=approved_by,
            reviewer_reason=reasons.REVIEWER_APPROVED,
            id_hmac=record.get("id_hmac") or None,
        )
        if refusal and refusal != reasons.REVIEW_NOT_PENDING:
            _fail(review.PRECONDITION, refusal)
    if not review._mint_and_approve(rs, uid):
        if not flag_id:
            _fail(review.PRECONDITION)
        rs.mark_mint_pending(flag_id)
    _ledger_ref(uid).set(
        {
            "approvedVia": via,
            "approvedBy": approved_by,
            "approvedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    rs.log_access(approved_by, flag_id or uid, f"approve:{via}")
    _drop_bookings(uid)
    return review.STATE_APPROVED


def _drop_bookings(uid: str, keep: Optional[str] = None) -> None:
    bookings = store.db().collection(config.COL_BOOKINGS)
    for snapshot in bookings.where("uid", "==", uid).stream():
        if snapshot.id != keep:
            bookings.document(snapshot.id).delete()


def approve_many(reviewer_uid: str, uids: Any) -> dict:
    if not isinstance(uids, list) or len(uids) > config.APPROVE_BATCH_MAX:
        _fail(review.INVALID)
    approved: list[str] = []
    failed: list[str] = []
    for uid in dict.fromkeys(u for u in uids if isinstance(u, str)):
        try:
            approve(reviewer_uid, uid, "approve")
            approved.append(uid)
        except Exception:  # noqa: BLE001 - one bad row must not stop the rest
            failed.append(uid)
    failed.extend(u for u in uids if not isinstance(u, str))
    return {"approved": approved, "failed": failed}


def revoke(reviewer_uid: str, uid: Any) -> str:
    """The undo: take the claim back (merged, other claims kept), put her back
    to pending and reopen a flag so she is in the queue again."""
    uid = _uid(uid)
    if uid == reviewer_uid:
        _fail(review.PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    rs = store.FirestoreReviewStore()
    try:
        store.mint_claims(uid, False)
    except Exception:  # noqa: BLE001 - no such account
        _fail(review.NOT_FOUND)
    rs.set_verification_state(uid, review.STATE_PENDING, reset_booking=True)
    rs.clear_mint_pending_for(uid)
    code = reasons.REVIEW_REVOKED
    decision = decisions.Decision(decisions.PENDING_REVIEW, (code,), (code,))
    job = rs.new_job_payload(uid, decision, rs.ocr_submissions(uid))
    flag_id, _ = rs.open_flag(uid, job, review.flag_payload(uid, None, decision))
    _ledger_ref(uid).set(
        {"revokedBy": reviewer_uid, "revokedAt": firestore.SERVER_TIMESTAMP}, merge=True
    )
    _forget_preapproved(uid)
    rs.log_access(reviewer_uid, flag_id, "revoke")
    return review.STATE_PENDING


def _forget_preapproved(uid: str) -> None:
    """Her number leaves the pre-approved list with the revoke, so the list
    cannot approve her again at her next sign-in."""
    number = phones_for([uid]).get(uid)
    if number:
        store.db().collection(config.COL_PREAPPROVED).document(number).delete()


def revoked_since_approval(uid: str) -> bool:
    """The ledger shows a revoke at or after her last approval through this
    module. Only a reviewer's approval clears it, so a fast route refuses."""
    ledger = _ledger_ref(uid).get()
    data = (ledger.to_dict() or {}) if ledger.exists else {}
    revoked = review._as_utc(data.get("revokedAt"))
    if revoked is None:
        return False
    approved = review._as_utc(data.get("approvedAt"))
    return approved is None or revoked >= approved


# ------------------------------------------------------------------- queue


def _iso(value: Any) -> str:
    when = review._as_utc(value)
    return when.strftime("%Y-%m-%dT%H:%M:%SZ") if when else ""


def phones_for(uids: list[str]) -> dict[str, str]:
    """uid -> E.164, looked up in Firebase Auth at the moment of showing it."""
    from firebase_admin import auth

    found: dict[str, str] = {}
    for start in range(0, len(uids), 100):
        batch = [auth.UidIdentifier(u) for u in uids[start : start + 100]]
        for user in auth.get_users(batch).users:
            if user.phone_number:
                found[user.uid] = user.phone_number
    return found


def _names(uids: list[str]) -> dict[str, dict]:
    if not uids:
        return {}
    refs = [store.db().collection(config.COL_USERS).document(u) for u in uids]
    out = {}
    for snapshot in store.db().get_all(refs):
        if snapshot.exists:
            out[snapshot.id] = snapshot.to_dict() or {}
    return out


def _display_name(user: dict) -> Optional[str]:
    name = user.get("displayName")
    return name.strip() if isinstance(name, str) and name.strip() else None


def list_queue(reviewer_uid: str, status: Any, query: Any) -> list[dict]:
    if status is not None and status not in ("pending", "scheduled", "approved"):
        _fail(review.INVALID)
    if query is not None and not isinstance(query, str):
        _fail(review.INVALID)
    rs = store.FirestoreReviewStore()
    rows: list[dict] = []
    if status in (None, "pending", "scheduled"):
        open_flags = rs.list_open(config.QUEUE_MAX_ROWS)
        pairs = [(d.get("uid"), fid) for fid, d in open_flags if d.get("uid")]
        consented = rs.review_consented_flags(pairs)
        users = _names([u for u, _ in pairs])
        phones = phones_for([u for u, f in pairs if f in consented])
        for flag_id, data in open_flags:
            uid = data.get("uid")
            if not uid:
                continue
            scheduled = _iso(data.get("scheduledFor"))
            row: dict = {
                "uid": uid,
                "flagId": flag_id,
                "state": "scheduled" if scheduled else "pending",
                "requestedAt": _iso(data.get("createdAt")),
            }
            user = users.get(uid, {})
            if _display_name(user):
                row["displayName"] = _display_name(user)
            if scheduled:
                row["scheduledFor"] = scheduled
            known = (user.get("verification") or {}).get("knownReviewerId")
            if isinstance(known, str) and known:
                row["knownReviewer"] = known
            if flag_id in consented and uid in phones:
                row["phone"] = phones[uid]
                rs.log_access(reviewer_uid, flag_id, "list:phone")
            rows.append(row)
    if status in (None, "approved"):
        rows.extend(_approved_rows(config.QUEUE_MAX_ROWS))
    if status in ("pending", "scheduled"):
        rows = [r for r in rows if r["state"] == status]
    rs.log_access(reviewer_uid, "*", "list")
    needle = (query or "").strip().lower()
    if needle:
        rows = [
            r
            for r in rows
            if any(needle in str(r.get(k, "")).lower() for k in ("displayName", "phone", "uid"))
        ]
    return rows


def _approval_trail(uids: list[str]) -> dict[str, dict]:
    if not uids:
        return {}
    refs = [_ledger_ref(u) for u in uids]
    trail: dict[str, dict] = {}
    for snapshot in store.db().get_all(refs):
        if not snapshot.exists:
            continue
        data = snapshot.to_dict() or {}
        via, by = data.get("approvedVia"), data.get("approvedBy")
        if not isinstance(via, str):
            continue
        revoked = review._as_utc(data.get("revokedAt"))
        approved = review._as_utc(data.get("approvedAt"))
        if revoked and (approved is None or revoked >= approved):
            continue
        trail[snapshot.id] = {"approvedVia": via}
        if isinstance(by, str) and by:
            trail[snapshot.id]["approvedBy"] = by
    return trail


def _approved_rows(limit: int) -> list[dict]:
    # Ordered by one field so no composite index is needed; the state is
    # filtered here. Newest decisions first.
    query = (
        store.db()
        .collection(config.COL_USERS)
        .order_by("verification.decidedAt", direction="DESCENDING")
        .limit(limit * 2)
    )
    rows = []
    for snapshot in query.stream():
        data = snapshot.to_dict() or {}
        verification = data.get("verification") or {}
        if verification.get("state") != review.STATE_APPROVED:
            continue
        row = {
            "uid": snapshot.id,
            "state": "approved",
            "requestedAt": _iso(verification.get("decidedAt")),
        }
        if _display_name(data):
            row["displayName"] = _display_name(data)
        rows.append(row)
    rows = rows[:limit]
    trail = _approval_trail([r["uid"] for r in rows])
    for row in rows:
        row.update(trail.get(row["uid"], {}))
    return rows


# ------------------------------------------------------------ pre-approved


def list_preapproved() -> list[str]:
    docs = store.db().collection(config.COL_PREAPPROVED).limit(2000).stream()
    return sorted(s.id for s in docs)


def set_preapproved(reviewer_uid: str, add: Any, remove: Any) -> list[str]:
    if add is not None and not isinstance(add, str):
        _fail(review.INVALID)
    if remove is not None and not isinstance(remove, list):
        _fail(review.INVALID)
    additions = parse_numbers(add)
    if len(additions) > config.PREAPPROVED_ADD_MAX:
        _fail(review.INVALID)
    col = store.db().collection(config.COL_PREAPPROVED)
    for number in additions:
        col.document(number).set(
            {"phone": number, "addedBy": reviewer_uid, "addedAt": firestore.SERVER_TIMESTAMP}
        )
    for raw in remove or []:
        number = normalise_phone(raw)
        if number:
            col.document(number).delete()
    store.FirestoreReviewStore().log_access(reviewer_uid, "*", "preapproved:edit")
    return list_preapproved()


def is_preapproved(phone: str) -> bool:
    return store.db().collection(config.COL_PREAPPROVED).document(phone).get().exists


# ------------------------------------------------------------ fast routes


def fast_via(phone: Optional[str], store_reviewer: bool) -> Optional[str]:
    """Which fast route her token qualifies for, by the phone in the verified
    ID token (never the request). None when none applies."""
    if store_reviewer:
        return VIA_STORE_REVIEWER
    number = normalise_phone(phone)
    if not number:
        return None
    if number in bypass_phones():
        return VIA_TEST_PHONE
    if is_preapproved(number):
        return VIA_PREAPPROVED
    return None


def claim_fast(uid: str, phone: Optional[str], store_reviewer: bool) -> dict:
    rs = store.FirestoreReviewStore()
    state = rs.verification_state(uid)
    if state == review.STATE_APPROVED:
        return {"state": review.STATE_APPROVED}
    via = fast_via(phone, store_reviewer)
    if via is None or revoked_since_approval(uid):
        return {"state": "none"}
    # A pre-approved number does not overturn a closed verification; a
    # reviewer can still approve her directly.
    if state == review.STATE_REJECTED and via == VIA_PREAPPROVED:
        return {"state": "none"}
    approve("system", uid, via)
    if via == VIA_PREAPPROVED:
        # The number is personal data and has done its one job.
        number = normalise_phone(phone)
        if number:
            store.db().collection(config.COL_PREAPPROVED).document(number).delete()
    return {"state": review.STATE_APPROVED, "via": via}


def known_contact_pass(uid: str, reviewer_id: Any) -> bool:
    """True when she knows a reviewer who auto-passes the people she knows,
    and she is approved on the spot. False leaves the normal request to run."""
    if not isinstance(reviewer_id, str) or not reviewer_id or reviewer_id == uid:
        return False
    rs = store.FirestoreReviewStore()
    state = rs.verification_state(uid)
    if state in (review.STATE_REJECTED, review.STATE_APPROVED) or rs.verify_in_flight(uid):
        return False
    if not reviewer_active(reviewer_id):
        return False
    settings = reviewer_doc(reviewer_id)
    if not settings.get("autoPassKnown"):
        return False
    if revoked_since_approval(uid):
        return False
    approve(reviewer_id, uid, VIA_KNOWN_CONTACT)
    note_known_reviewer(uid, reviewer_id)
    _ledger_ref(uid).set({"knownReviewerId": reviewer_id}, merge=True)
    return True


def note_known_reviewer(uid: str, reviewer_id: Any) -> None:
    """Remember who she says she knows, for the queue, when that reviewer
    has settings. Server-written; the rules keep the client out."""
    if not isinstance(reviewer_id, str) or not reviewer_id or reviewer_id == uid:
        return
    if not reviewer_doc(reviewer_id):
        return
    store.db().collection(config.COL_USERS).document(uid).set(
        {"verification": {"knownReviewerId": reviewer_id}}, merge=True
    )


def reviewer_doc(reviewer_id: str) -> dict:
    snapshot = store.db().collection(config.COL_REVIEWERS).document(reviewer_id).get()
    return (snapshot.to_dict() or {}) if snapshot.exists else {}


def reviewer_active(reviewer_id: str) -> bool:
    """The reviewer still holds the woman-reviewer claim. Her settings
    document outlives the claim, so it is never trusted on its own."""
    from firebase_admin import auth

    try:
        claims = auth.get_user(reviewer_id).custom_claims or {}
    except Exception:  # noqa: BLE001 - no such account
        return False
    return bool(claims.get("womanReviewer"))
