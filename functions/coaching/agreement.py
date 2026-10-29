"""Coach Agreement v2: accepted in the app, signed on paper, verified by staff.

Three steps keep three records, all server-written:

* `users/{uid}/consents/coach-terms-v2 {version, at, locale, textHash}`, the
  acceptance, with the SHA-256 of the agreement text she read
  (agreement_hashes.json, made from the site source by tools/agreement_hash.py);
* `coachPrivate/{uid}.agreement`, her state: `{version, acceptedAt, status,
  path, uploadedAt, decidedAt, decidedBy, reason}` where status is `accepted`
  (agreed in the app, no copy yet), `uploaded` (waiting for Own Hub),
  `verified` or `rejected` (a new copy is needed, with the reason). It lives in
  coachPrivate and not on the public coaches/{uid} page, which every verified
  member can read;
* the signed copy itself under `coach-docs/{uid}/agreement/` (storage rules:
  hers to write, staff to read). Her national ID number is on the paper only.

`ready()` is the gate `subscriptions.respond` applies to a new client. Clients a
coach already has are never touched by it.
"""

from __future__ import annotations

import datetime as dt
import json
import logging
import os
import re
from typing import Callable

from . import common, errors

VERSION = 2
CONSENT = "coach-terms-v2"
PUSH = "agreementDecision"
STATUSES = ("accepted", "uploaded", "verified", "rejected")
REASON_MAX = 200

_MEDIA = re.compile(r"^coach-docs/(?P<uid>[A-Za-z0-9_-]{1,128})/agreement/[A-Za-z0-9_-]{1,80}\.(?:jpg|jpeg|png|pdf)$")

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "agreement_hashes.json"), encoding="utf-8") as _fh:
    HASHES = json.load(_fh)


def text_hash(locale: str) -> str:
    return HASHES["ar" if locale == "ar" else "en"]


def locale_of(value) -> str:
    return value if value in ("ar", "en") else "ar"


def ready(private_row: dict) -> bool:
    """Accepted v2 and the signed copy verified."""
    agreement = (private_row or {}).get("agreement") or {}
    return agreement.get("version") == VERSION and agreement.get("status") == "verified"


def consent_record(now, locale: str) -> dict:
    return {"version": VERSION, "at": now, "locale": locale, "textHash": text_hash(locale)}


def _keep_only(blobs, uid: str, keep: str) -> None:
    """Deletes every other file in her agreement folder (a replaced or rejected
    copy, an upload never submitted). Best effort: a failure leaves a stray
    file, never a wrong record."""
    if blobs is None:
        return
    try:
        for name, _ in blobs.list_files(f"coach-docs/{uid}/agreement/"):
            if name != keep:
                blobs.delete(name)
    except Exception:  # noqa: BLE001
        logging.getLogger(__name__).error("agreement_cleanup_failed")


def accept(db, uid: str, data: dict, *, live: bool, coach_v, now: dt.datetime) -> dict:
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v, allow_hold=True)
    if isinstance(data.get("version"), bool) or data.get("version") != VERSION:
        raise common.bad()
    locale = locale_of(data.get("locale"))
    private_ref = db.collection("coachPrivate").document(uid)
    consent = common.consent_ref(db, uid, CONSENT)

    def body(transaction):
        agreement = (private_ref.get(transaction=transaction).to_dict() or {}).get("agreement") or {}
        if agreement.get("version") == VERSION:
            return agreement["status"]
        transaction.set(consent, consent_record(now, locale))
        transaction.update(private_ref, {"agreement": {"version": VERSION, "acceptedAt": now, "status": "accepted"}})
        return "accepted"

    return {"status": common.run(db, body)}


def submit(
    db, uid: str, data: dict, *, live: bool, coach_v, object_exists: Callable[[str], bool], now: dt.datetime,
    blobs=None,
) -> dict:
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v, allow_hold=True)
    path = data.get("mediaRef")
    match = _MEDIA.match(path) if isinstance(path, str) else None
    if match is None or match.group("uid") != uid:
        raise common.bad()
    if not object_exists(path):
        raise common.refuse(errors.PRECONDITION, errors.AGREEMENT_NOT_UPLOADED)
    private_ref = db.collection("coachPrivate").document(uid)

    def body(transaction):
        agreement = (private_ref.get(transaction=transaction).to_dict() or {}).get("agreement") or {}
        if agreement.get("version") != VERSION or agreement.get("status") not in ("accepted", "uploaded", "rejected"):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(
            private_ref,
            {"agreement": {
                "version": VERSION,
                "acceptedAt": agreement.get("acceptedAt"),
                "status": "uploaded",
                "path": path,
                "uploadedAt": now,
            }},
        )

    common.run(db, body)
    _keep_only(blobs, uid, path)  # the copy it replaces goes
    return {"status": "uploaded"}


def decide(db, actor_uid: str, data: dict, *, notify, now: dt.datetime, blobs=None) -> dict:
    uid = common.text(data.get("uid"), max_len=128)
    common.refuse_if_subject(actor_uid, uid)
    decision = common.one_of(data.get("decision"), ("verify", "reject"))
    reason = common.text(data.get("reason"), max_len=REASON_MAX) if decision == "reject" else None
    private_ref = db.collection("coachPrivate").document(uid)
    snap = private_ref.get()
    if not snap.exists:
        raise common.refuse(errors.NOT_FOUND, errors.APPLICATION_NOT_FOUND)

    def body(transaction):
        agreement = (private_ref.get(transaction=transaction).to_dict() or {}).get("agreement") or {}
        if agreement.get("version") != VERSION or agreement.get("status") != "uploaded":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        status = "verified" if decision == "verify" else "rejected"
        changes = {**agreement, "status": status, **common.decided_stamp(actor_uid, now)}
        if reason:
            changes["reason"] = reason
        else:
            changes.pop("reason", None)
        transaction.update(private_ref, {"agreement": changes})
        return status

    status = common.run(db, body)
    if status == "verified":
        _keep_only(blobs, uid, (private_ref.get().to_dict() or {}).get("agreement", {}).get("path"))
    common.log_access(db, actor_uid, f"agreement_{decision}", uid, now)
    notify(uid, PUSH)
    return {"status": status}


def list_waiting(db) -> dict:
    """Signed copies waiting for a decision, oldest first, for the staff view.
    Her legal name is on the paper anyway; the national ID number is not here."""
    rows = []
    query = db.collection("coachPrivate").where("agreement.status", "==", "uploaded").order_by("agreement.uploadedAt")
    for snap in query.limit(50).stream():
        row = snap.to_dict() or {}
        shown = row.get("agreement") or {}
        rows.append({
            "uid": snap.id,
            "fullName": row.get("fullName", ""),
            "path": shown.get("path"),
            "uploadedAt": shown.get("uploadedAt"),
            "acceptedAt": shown.get("acceptedAt"),
        })
    return {"items": rows}
