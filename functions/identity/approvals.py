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
import logging
import os
import re
from typing import Any, Optional

from google.cloud import firestore

from . import config, decisions, reasons, review, store

VIA_PREAPPROVED = "preapproved"
VIA_TEST_PHONE = "testPhone"
VIA_STORE_REVIEWER = "storeReviewer"
APPROVE_REASONS = ("approve", "knownPerson")
DECLINE_REASONS = ("notClear", "notMatching", "other")

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


def approve(approved_by: str, uid: Any, via: str, adult_seen: bool = False, confirmed: Optional[dict] = None) -> str:
    """Mint her claim, set her state, close any open flag, drop her booking.

    `approved_by` is the reviewer's uid, or "system" for a phone route. The
    flag is closed first (its registry claim can refuse a duplicate card);
    the mint then retries, and a mint that still fails is left to the hourly
    job exactly as review.decide leaves it.

    A reviewer's approval carries no ID, so it must carry her confirmation that
    she saw proof the woman is 18 or older (`adult_seen`); the ledger keeps who
    confirmed and when. The system routes pass `adult_seen` themselves: a
    pre-approved number only after a reviewer confirmed it when adding it, test
    numbers and the store review account are not members."""
    uid = _uid(uid)
    if uid == approved_by:
        _fail(review.PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    if via in APPROVE_REASONS and adult_seen is not True:
        _fail(review.INVALID)
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
    ledger = {
        "approvedVia": via,
        "approvedBy": approved_by,
        "approvedAt": firestore.SERVER_TIMESTAMP,
    }
    if via in APPROVE_REASONS:
        ledger["adultConfirmedBy"] = approved_by
    elif confirmed:  # a pre-approved number: the reviewer who confirmed it, and when
        ledger["adultConfirmedBy"] = confirmed["by"]
        ledger["adultConfirmedAt"] = confirmed["at"]
    _ledger_ref(uid).set(ledger, merge=True)
    rs.log_access(approved_by, flag_id or uid, f"approve:{via}")
    _drop_bookings(uid)
    return review.STATE_APPROVED


def _drop_bookings(uid: str, keep: Optional[str] = None) -> None:
    bookings = store.db().collection(config.COL_BOOKINGS)
    for snapshot in bookings.where("uid", "==", uid).stream():
        if snapshot.id != keep:
            bookings.document(snapshot.id).delete()


def approve_many(reviewer_uid: str, uids: Any, adult_seen: bool = False) -> dict:
    if not isinstance(uids, list) or len(uids) > config.APPROVE_BATCH_MAX or adult_seen is not True:
        _fail(review.INVALID)
    approved: list[str] = []
    failed: list[str] = []
    for uid in dict.fromkeys(u for u in uids if isinstance(u, str)):
        try:
            approve(reviewer_uid, uid, "approve", True)
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
    _unpublish_coach(uid)
    return review.STATE_PENDING


def _unpublish_coach(uid: str) -> None:
    """A revoked woman who coaches loses her page. Never fails the revoke."""
    try:
        from coaching import claims as coach_claims

        coach_claims.on_verification_revoked(
            store.db(), uid, dt.datetime.now(dt.timezone.utc)
        )
    except Exception:  # noqa: BLE001
        logging.getLogger(__name__).error("coach_unpublish_after_revoke_failed")


def decline(reviewer_uid: str, uid: Any, reason: Any = "other") -> str:
    """The decline, as auditable as an approve: her open flag (if any) is closed
    as rejected and her state set to rejected in one transaction, the ledger
    records who, when and why (a fixed code, never free text), and the access
    log gets a line. A reviewer cannot decline herself, and an approved woman
    cannot be declined (that is the revoke): the claim would stay on. The
    verified claim is taken back and any mint retry left from an earlier
    approval is cleared, so the hourly retry cannot approve her again. An
    unknown account is refused as not found and nothing is written."""
    uid = _uid(uid)
    if uid == reviewer_uid:
        _fail(review.PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    if reason not in DECLINE_REASONS:
        _fail(review.INVALID)
    rs = store.FirestoreReviewStore()
    if rs.verification_state(uid) == review.STATE_APPROVED:
        _fail(review.PRECONDITION, reasons.REVIEW_NOT_PENDING)
    try:
        store.mint_claims(uid, False)
    except Exception:  # noqa: BLE001 - no such account
        _fail(review.NOT_FOUND)
    rs.clear_mint_pending_for(uid)
    flag_id = rs.open_flag_id(uid)
    if flag_id:
        refusal = rs.close_flag(
            flag_id,
            uid=uid,
            state=decisions.REJECTED_FAILED,
            reviewer_uid=reviewer_uid,
            reviewer_reason=reasons.REVIEWER_REJECTED,
            user_state=review.STATE_REJECTED,
        )
        if refusal:
            _fail(review.PRECONDITION, refusal)
    else:
        rs.set_verification_state(uid, review.STATE_REJECTED, decided=True)
    _ledger_ref(uid).set(
        {
            "declinedBy": reviewer_uid,
            "declinedAt": firestore.SERVER_TIMESTAMP,
            "declineReason": reason,
        },
        merge=True,
    )
    _forget_preapproved(uid)
    rs.log_access(reviewer_uid, flag_id or uid, "decline")
    _drop_bookings(uid)
    return review.STATE_REJECTED


def _forget_preapproved(uid: str) -> None:
    """Her number leaves the pre-approved list with the revoke, so the list
    cannot approve her again at her next sign-in."""
    number = phones_for([uid]).get(uid)
    if number:
        store.db().collection(config.COL_PREAPPROVED).document(number).delete()


def revoked_since_approval(uid: str) -> bool:
    """The ledger shows a revoke or a decline at or after her last approval
    through this module. Only a reviewer's approval clears it, so a fast route
    and the hourly mint retry refuse."""
    ledger = _ledger_ref(uid).get()
    data = (ledger.to_dict() or {}) if ledger.exists else {}
    stamps = [review._as_utc(data.get(k)) for k in ("revokedAt", "declinedAt")]
    stamps = [t for t in stamps if t is not None]
    if not stamps:
        return False
    approved = review._as_utc(data.get("approvedAt"))
    return approved is None or max(stamps) >= approved


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


PREAPPROVED_UNDO = dt.timedelta(minutes=5)
"""A removed number stays here this long, marked `removedAt`, so Undo can bring
back the exact record (who confirmed her age, and when). Any list or edit
afterwards deletes the ones past this."""


def _live_preapproved(now: Optional[dt.datetime] = None) -> list:
    """The numbers on the list. Removed ones past the undo window are deleted
    here; the ones inside it are not on the list."""
    now = now or dt.datetime.now(dt.timezone.utc)
    live = []
    for snapshot in store.db().collection(config.COL_PREAPPROVED).limit(2000).stream():
        removed = (snapshot.to_dict() or {}).get("removedAt")
        if removed is None:
            live.append(snapshot)
        elif now - removed > PREAPPROVED_UNDO:
            snapshot.reference.delete()
    return live


def list_preapproved() -> list[str]:
    return sorted(s.id for s in _live_preapproved())


def needing_age_tick() -> list[str]:
    """Live numbers with no recorded 18+ confirmation: they approve no one."""
    return sorted(s.id for s in _live_preapproved() if not (s.to_dict() or {}).get("adultConfirmedBy"))


def set_preapproved(
    reviewer_uid: str, add: Any, remove: Any, adult_seen: bool = False, restore: Any = None
) -> list[str]:
    if add is not None and not isinstance(add, str):
        _fail(review.INVALID)
    for names in (remove, restore):
        if names is not None and not isinstance(names, list):
            _fail(review.INVALID)
    additions = parse_numbers(add)
    if len(additions) > config.PREAPPROVED_ADD_MAX or (additions and adult_seen is not True):
        _fail(review.INVALID)
    col = store.db().collection(config.COL_PREAPPROVED)
    for number in additions:
        col.document(number).set(
            {
                "phone": number,
                "addedBy": reviewer_uid,
                "addedAt": firestore.SERVER_TIMESTAMP,
                "adultConfirmedBy": reviewer_uid,
            }
        )
    for raw in remove or []:
        number = normalise_phone(raw)
        if number and col.document(number).get().exists:
            col.document(number).set({"removedAt": firestore.SERVER_TIMESTAMP}, merge=True)
    now = dt.datetime.now(dt.timezone.utc)
    for raw in restore or []:
        number = normalise_phone(raw)
        row = (col.document(number).get().to_dict() or {}) if number else {}
        removed = row.get("removedAt")
        if removed is not None and now - removed <= PREAPPROVED_UNDO:
            row.pop("removedAt")
            col.document(number).set(row)
    store.FirestoreReviewStore().log_access(reviewer_uid, "*", "preapproved:edit")
    return list_preapproved()


def is_preapproved(phone: str) -> bool:
    """On the list with a reviewer's 18+ confirmation. A number added before
    that confirmation existed waits for the normal check instead, and a removed
    one (waiting out its undo window) is not on the list."""
    row = store.db().collection(config.COL_PREAPPROVED).document(phone).get().to_dict() or {}
    return bool(row.get("adultConfirmedBy")) and row.get("removedAt") is None


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
    number = normalise_phone(phone)
    confirmed = None
    if via == VIA_PREAPPROVED:
        row = store.db().collection(config.COL_PREAPPROVED).document(number).get().to_dict() or {}
        confirmed = {"by": row.get("adultConfirmedBy"), "at": row.get("addedAt")}
    approve("system", uid, via, confirmed=confirmed)
    if via == VIA_PREAPPROVED:
        # The number is personal data and has done its one job; the ledger
        # now keeps who confirmed her age.
        store.db().collection(config.COL_PREAPPROVED).document(number).delete()
    return {"state": review.STATE_APPROVED, "via": via}


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
