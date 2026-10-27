"""How long a payment's pictures are kept, and the uploads nothing refers to.

Counsel confirms the numbers (spec 12.4); until then these are the defaults and
the only place they live. The payment record itself is never deleted here."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import model

SCREENSHOT_RETENTION_DAYS = 90      # UNVERIFIED with counsel
RECORD_RETENTION_YEARS = 5          # UNVERIFIED with counsel; nothing deletes the record in this release
ORPHAN_AFTER_HOURS = 24             # an upload no message or payment names, this long after it was written
ORPHAN_LOOKBACK_HOURS = 96          # a daily run looks at files 24 to 96 hours old, so one missed run loses nothing

FINISHED = ("confirmed", "resolved_paid", "resolved_unpaid", "refunded", "cancelled")


def paths_of(payment: dict) -> list:
    return list(((payment.get("proof") or {}).get("screenshotPaths")) or []) + list(
        ((payment.get("coachDecision") or {}).get("statementPaths")) or []
    )


def sweep_screenshots(db, *, now: dt.datetime, blobs) -> int:
    """Deletes the pictures of payments finished for longer than the retention
    period. A payment under review keeps them. Returns how many payments were
    cleaned. A failed delete leaves the pointer in place, so the next run retries."""
    cutoff = now - model.days(SCREENSHOT_RETENTION_DAYS)
    cleaned = 0
    for status in FINISHED:
        for snap in list(db.collection("payments").where("status", "==", status).where("statusAt", "<=", cutoff).stream()):
            paths = paths_of(snap.to_dict() or {})
            if not paths:
                continue
            try:
                for path in paths:
                    blobs.delete(path)
            except Exception:  # noqa: BLE001
                continue
            row = snap.to_dict() or {}
            changes = {"proof": {**(row.get("proof") or {}), "screenshotPaths": [], "screenshotsDeletedAt": now}}
            if row.get("coachDecision"):  # null until the coach acts: write the whole map, never a path through it
                changes["coachDecision"] = {**row["coachDecision"], "statementPaths": []}
            snap.reference.update(changes)
            cleaned += 1
    return cleaned


def _chat_file_is_used(db, name: str) -> bool:
    parts = name.split("/")  # chat-media/{relId}/{uid}/{file}
    if len(parts) != 4:
        return True  # not a shape the app writes: leave it for a person to look at
    lines = db.collection("relationships").document(parts[1]).collection("messages").where("mediaPath", "==", name).limit(1)
    return any(True for _ in lines.stream())


def _proof_file_is_used(db, name: str) -> bool:
    parts = name.split("/")  # payment-proofs/{paymentId}/{file}, or the older payment-proofs/{uid}/{file}
    if len(parts) != 3:
        return True
    snap = db.collection("payments").document(parts[1]).get()
    if snap.exists:
        return name in paths_of(snap.to_dict() or {})
    older = db.collection("paymentProofs").where("imagePath", "==", name).limit(1)
    return any(True for _ in older.stream())


def sweep_orphan_uploads(db, *, now: dt.datetime, blobs) -> dict:
    """Phones cannot delete what they upload, so a chat photo whose message was
    never written, or a payment picture whose commit failed, would stay for
    ever. This deletes such a file once it is a day old and no message or
    payment names it. Files younger than a day may still be on their way."""
    newest, oldest = now - model.hours(ORPHAN_AFTER_HOURS), now - model.hours(ORPHAN_LOOKBACK_HOURS)
    counts = {"chat": 0, "payment": 0}
    for prefix, used, key in (("chat-media/", _chat_file_is_used, "chat"), ("payment-proofs/", _proof_file_is_used, "payment")):
        for name, created in list(blobs.list_files(prefix)):
            when = common.as_utc(created)
            if when is None or not (oldest <= when <= newest) or used(db, name):
                continue
            try:
                blobs.delete(name)
            except Exception:  # noqa: BLE001
                continue
            counts[key] += 1
    return counts
